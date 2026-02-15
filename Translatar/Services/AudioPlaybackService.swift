// AudioPlaybackService.swift
// Translatar - AI实时翻译耳机应用
//
// 音频播放服务（v4 - 统一AVAudioEngine播放）
//
// v4 修复说明（2026-02-15）：
// 【问题：同声传译模式下手机和耳机都没有声音】
// 根因：v3使用AVAudioPlayer在后台DispatchQueue播放，
//       AVAudioPlayer依赖RunLoop，后台队列没有RunLoop导致播放静默失败。
// 修复：所有模式统一使用AVAudioEngine + AVAudioPlayerNode播放。
//       关键：播放引擎启动时不重新配置音频会话（不调用setCategory/setActive），
//       这样就不会覆盖AudioCaptureService设置的麦克风路由。
//       AVAudioEngine.start()本身不会改变音频路由，只是启动音频处理图。
//
// 技术说明：
// - 接收PCM16格式的音频数据块（24kHz，Gemini输出格式）
// - 所有模式使用AVAudioEngine + AVAudioPlayerNode流式播放
// - 仅户外模式在播放前配置双通道输出（扬声器+耳机）
// - 同声传译和对话模式不触碰音频会话配置

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
    
    /// 音频引擎
    private var audioEngine: AVAudioEngine?
    /// 播放器节点
    private var playerNode: AVAudioPlayerNode?
    
    /// 播放状态
    private(set) var isPlaying = false
    
    /// 是否启用双通道输出（耳机+扬声器同时播放）
    /// 户外模式下启用，让对方也能听到翻译
    var isDualOutputEnabled = false
    
    /// 当前翻译模式
    var currentMode: TranslationMode = .conversation
    
    /// 播放音频的格式（Gemini Live API 输出格式）
    /// PCM16, 24000Hz, 单声道
    private let playbackFormat: AVAudioFormat
    
    /// 播放采样率
    private let playbackSampleRate: Double = 24000.0
    
    /// 音频缓冲区队列（线程安全）
    private let bufferQueue = DispatchQueue(label: "com.translatar.audioPlayback", qos: .userInteractive)
    
    /// 是否已经打印过首次播放日志
    private var hasLoggedFirstPlay = false
    
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
    
    // MARK: - AVAudioEngine 管理
    
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
    /// v4关键：同声传译模式下不重新配置音频会话
    private func ensureEngineRunning() {
        if let engine = audioEngine, engine.isRunning { return }
        
        do {
            // 仅户外模式下配置双通道输出
            // 同声传译和对话模式不触碰音频会话，保持AudioCaptureService的配置
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
            
            // 打印当前音频路由，帮助调试
            let session = AVAudioSession.sharedInstance()
            print("[AudioPlayback] 当前输出路由: \(session.currentRoute.outputs.map { "\($0.portName) (\($0.portType.rawValue))" })")
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
    
    // MARK: - 统一播放入口
    
    /// 将翻译后的音频数据块加入播放队列
    /// - Parameter data: PCM16格式的音频数据
    func enqueueAudio(data: Data) {
        bufferQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 确保引擎运行
            self.ensureEngineRunning()
            
            // 将PCM数据转换为AVAudioPCMBuffer
            guard let buffer = self.dataToPCMBuffer(data: data) else {
                print("[AudioPlayback] 音频数据转换失败，数据大小: \(data.count)")
                return
            }
            
            // 调度播放
            self.playerNode?.scheduleBuffer(buffer, completionHandler: nil)
            
            // 首次播放时打印日志
            if !self.hasLoggedFirstPlay {
                self.hasLoggedFirstPlay = true
                print("[AudioPlayback] ✅ 首次音频数据已调度播放，大小: \(data.count)字节，帧数: \(buffer.frameLength)")
            }
        }
    }
    
    /// 停止播放并清空队列
    func stopPlayback() {
        bufferQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.playerNode?.stop()
            self.audioEngine?.stop()
            self.audioEngine = nil
            self.playerNode = nil
            
            self.isPlaying = false
            self.hasLoggedFirstPlay = false
            print("[AudioPlayback] 音频播放已停止")
        }
    }
    
    // MARK: - 数据转换
    
    /// 将PCM16 Data转换为AVAudioPCMBuffer
    private func dataToPCMBuffer(data: Data) -> AVAudioPCMBuffer? {
        let frameCount = UInt32(data.count) / UInt32(MemoryLayout<Int16>.size)
        
        guard frameCount > 0 else { return nil }
        
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
