// AudioPlaybackService.swift
// Translatar - AI实时翻译耳机应用
//
// 音频播放服务（v3 - 双引擎策略）
//
// v3 修复说明（2026-02-15）：
// 【问题：同声传译模式下AirPods没有声音】
// 根因：AudioPlaybackService创建了独立的AVAudioEngine，
//       和AudioCaptureService的录音引擎冲突，导致播放输出路由异常。
// 修复：同声传译模式下不使用AVAudioEngine，
//       改用AVAudioPlayer直接播放，利用当前音频会话的输出路由。
//       对话模式和户外模式保持原有AVAudioEngine播放方式。
//
// 技术说明：
// - 接收PCM16格式的音频数据块（24kHz，Gemini输出格式）
// - 同声传译模式：AVAudioPlayer播放（不创建新引擎，不影响录音路由）
// - 对话/户外模式：AVAudioEngine + AVAudioPlayerNode（低延迟流式播放）

import Foundation
import AVFoundation
import Combine

/// 音频播放服务协议
protocol AudioPlaybackServiceProtocol {
    /// 当前是否正在播放
    var isPlaying: Bool { get }
    /// 将翻译后的音频数据块加入播放队列
    func enqueueAudio(data: Data)
    /// 停止播放并清空队列
    func stopPlayback()
}

/// 音频播放服务实现
class AudioPlaybackService: AudioPlaybackServiceProtocol {
    
    // MARK: - 属性
    
    /// 音频引擎（对话/户外模式使用）
    private var audioEngine: AVAudioEngine?
    /// 播放器节点（对话/户外模式使用）
    private var playerNode: AVAudioPlayerNode?
    
    /// 音频播放器队列（同声传译模式使用）
    /// 保持对AVAudioPlayer的强引用，防止播放中被释放
    private var activePlayers: [AVAudioPlayer] = []
    
    /// 播放状态
    private(set) var isPlaying = false
    
    /// 是否启用双通道输出（耳机+扬声器同时播放）
    /// 户外模式下启用，让对方也能听到翻译
    var isDualOutputEnabled = false
    
    /// 当前翻译模式
    /// 用于决定播放策略：同声传译用AVAudioPlayer，其他用AVAudioEngine
    var currentMode: TranslationMode = .conversation
    
    /// 播放音频的格式（Gemini Live API 输出格式）
    /// PCM16, 24000Hz, 单声道
    private let playbackFormat: AVAudioFormat
    
    /// 播放采样率
    private let playbackSampleRate: Double = 24000.0
    
    /// 音频缓冲区队列（线程安全）
    private let bufferQueue = DispatchQueue(label: "com.translatar.audioPlayback", qos: .userInteractive)
    
    /// 累积的音频数据（同声传译模式下累积小块后一起播放）
    private var accumulatedAudioData = Data()
    
    /// 累积计时器
    private var accumulateTimer: DispatchWorkItem?
    
    // MARK: - 初始化
    
    init() {
        // 创建播放格式：PCM16, 24kHz, 单声道
        self.playbackFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: playbackSampleRate,
            channels: 1,
            interleaved: true
        )!
    }
    
    // MARK: - AVAudioEngine 播放（对话/户外模式）
    
    /// 配置并启动音频引擎
    private func setupAndStartEngine() {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        
        engine.attach(player)
        engine.connect(
            player,
            to: engine.mainMixerNode,
            format: playbackFormat
        )
        
        self.audioEngine = engine
        self.playerNode = player
    }
    
    /// 启动音频引擎（如果尚未启动）
    private func ensureEngineRunning() {
        if let engine = audioEngine, engine.isRunning { return }
        
        do {
            // 仅户外模式下配置双通道输出
            if isDualOutputEnabled && currentMode == .outdoor {
                configureDualOutput()
            }
            
            setupAndStartEngine()
            
            guard let engine = audioEngine, let player = playerNode else { return }
            
            engine.prepare()
            try engine.start()
            player.play()
            isPlaying = true
            print("[AudioPlayback] AVAudioEngine已启动（模式: \(currentMode.displayName)）")
        } catch {
            print("[AudioPlayback] AVAudioEngine启动失败: \(error.localizedDescription)")
        }
    }
    
    /// 配置双通道音频输出（户外模式专用）
    private func configureDualOutput() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
            )
            try session.overrideOutputAudioPort(.speaker)
            try session.setActive(true)
            print("[AudioPlayback] 双通道输出已配置（扬声器+耳机）")
        } catch {
            print("[AudioPlayback] 双通道配置失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - AVAudioPlayer 播放（同声传译模式）
    
    /// 使用AVAudioPlayer播放PCM音频数据
    /// 不创建新的AVAudioEngine，直接利用当前音频会话的输出路由
    private func playWithAVAudioPlayer(data: Data) {
        // 将PCM数据包装成WAV格式（AVAudioPlayer需要带头的音频文件格式）
        let wavData = createWAVData(from: data, sampleRate: UInt32(playbackSampleRate), channels: 1, bitsPerSample: 16)
        
        do {
            let player = try AVAudioPlayer(data: wavData)
            player.volume = 1.0
            player.prepareToPlay()
            
            // 保持强引用
            activePlayers.append(player)
            
            // 设置代理清理已完成的播放器
            player.delegate = AudioPlayerDelegateHandler.shared
            AudioPlayerDelegateHandler.shared.onFinish = { [weak self] finishedPlayer in
                self?.bufferQueue.async {
                    self?.activePlayers.removeAll { $0 === finishedPlayer }
                }
            }
            
            player.play()
            isPlaying = true
        } catch {
            print("[AudioPlayback] AVAudioPlayer播放失败: \(error.localizedDescription)")
        }
    }
    
    /// 将PCM原始数据包装成WAV格式
    private func createWAVData(from pcmData: Data, sampleRate: UInt32, channels: UInt16, bitsPerSample: UInt16) -> Data {
        var wavData = Data()
        
        let dataSize = UInt32(pcmData.count)
        let fileSize = dataSize + 36 // 文件总大小 - 8
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        
        // RIFF header
        wavData.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        wavData.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        wavData.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"
        
        // fmt chunk
        wavData.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) }) // chunk size
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // PCM format
        wavData.append(contentsOf: withUnsafeBytes(of: channels.littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })
        
        // data chunk
        wavData.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        wavData.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
        wavData.append(pcmData)
        
        return wavData
    }
    
    // MARK: - 统一播放入口
    
    /// 将翻译后的音频数据块加入播放队列
    /// - Parameter data: PCM16格式的音频数据
    func enqueueAudio(data: Data) {
        bufferQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.currentMode == .immersive {
                // 同声传译模式：累积小块音频后一起播放
                // Gemini返回的音频块很小（几百字节），直接播放会产生卡顿
                // 累积到一定大小（约100ms的音频）后再播放
                self.accumulatedAudioData.append(data)
                
                // 取消之前的计时器
                self.accumulateTimer?.cancel()
                
                // 每次收到数据后设置一个短延迟
                // 如果50ms内没有新数据到来，就播放累积的数据
                let timer = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    let audioToPlay = self.accumulatedAudioData
                    self.accumulatedAudioData = Data()
                    
                    if !audioToPlay.isEmpty {
                        self.playWithAVAudioPlayer(data: audioToPlay)
                    }
                }
                self.accumulateTimer = timer
                self.bufferQueue.asyncAfter(deadline: .now() + 0.05, execute: timer)
                
                // 如果累积超过4800字节（约100ms@24kHz），立即播放
                if self.accumulatedAudioData.count >= 4800 {
                    self.accumulateTimer?.cancel()
                    let audioToPlay = self.accumulatedAudioData
                    self.accumulatedAudioData = Data()
                    self.playWithAVAudioPlayer(data: audioToPlay)
                }
            } else {
                // 对话/户外模式：使用AVAudioEngine流式播放
                self.ensureEngineRunning()
                
                guard let buffer = self.dataToPCMBuffer(data: data) else {
                    print("[AudioPlayback] 音频数据转换失败")
                    return
                }
                
                self.playerNode?.scheduleBuffer(buffer, completionHandler: nil)
            }
        }
    }
    
    /// 停止播放并清空队列
    func stopPlayback() {
        bufferQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 停止AVAudioEngine（对话/户外模式）
            self.playerNode?.stop()
            self.audioEngine?.stop()
            self.audioEngine = nil
            self.playerNode = nil
            
            // 停止所有AVAudioPlayer（同声传译模式）
            for player in self.activePlayers {
                player.stop()
            }
            self.activePlayers.removeAll()
            self.accumulatedAudioData = Data()
            self.accumulateTimer?.cancel()
            
            self.isPlaying = false
            print("[AudioPlayback] 音频播放已停止")
        }
    }
    
    // MARK: - 数据转换（AVAudioEngine模式使用）
    
    /// 将PCM16 Data转换为AVAudioPCMBuffer
    private func dataToPCMBuffer(data: Data) -> AVAudioPCMBuffer? {
        let frameCount = UInt32(data.count) / UInt32(MemoryLayout<Int16>.size)
        
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: playbackFormat,
            frameCapacity: frameCount
        ) else { return nil }
        
        buffer.frameLength = frameCount
        
        data.withUnsafeBytes { rawBufferPointer in
            guard let sourcePointer = rawBufferPointer.baseAddress else { return }
            if let channelData = buffer.int16ChannelData {
                memcpy(channelData[0], sourcePointer, data.count)
            }
        }
        
        return buffer
    }
    
    // MARK: - 清理
    
    deinit {
        stopPlayback()
    }
}

// MARK: - AVAudioPlayer代理处理器（清理已完成的播放器）

/// 单例代理处理器，用于在AVAudioPlayer播放完成后清理资源
class AudioPlayerDelegateHandler: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayerDelegateHandler()
    
    /// 播放完成回调
    var onFinish: ((AVAudioPlayer) -> Void)?
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?(player)
    }
}
