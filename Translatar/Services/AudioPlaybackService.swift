// AudioPlaybackService.swift
// Translatar - AI实时翻译耳机应用
//
// 音频播放服务（v2 - 模式感知）
//
// v2 修复说明（2026-02-15）：
// - 添加 currentMode 属性，感知当前翻译模式
// - 同声传译模式下不重新配置音频会话（避免覆盖AudioCaptureService的路由设置）
// - 仅户外模式下启用双通道输出（扬声器+耳机）
//
// 技术说明：
// - 接收PCM16格式的音频数据块（24kHz，Gemini输出格式）
// - 使用AVAudioPlayerNode进行低延迟流式播放
// - 支持音频队列管理，确保播放的连续性和流畅性

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
    
    /// 当前翻译模式（v2新增）
    /// 用于决定是否需要重新配置音频会话
    var currentMode: TranslationMode = .conversation
    
    /// 播放音频的格式（Gemini Live API 输出格式）
    /// PCM16, 24000Hz, 单声道
    private let playbackFormat: AVAudioFormat
    
    /// 音频缓冲区队列（线程安全）
    private let bufferQueue = DispatchQueue(label: "com.translatar.audioPlayback", qos: .userInteractive)
    
    // MARK: - 初始化
    
    init() {
        // 创建播放格式：PCM16, 24kHz, 单声道
        self.playbackFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 24000.0,
            channels: 1,
            interleaved: true
        )!
    }
    
    /// 配置并启动音频引擎
    private func setupAndStartEngine() {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        
        // 将播放器节点附加到音频引擎
        engine.attach(player)
        
        // 连接播放器节点到主混音器
        // 音频引擎会自动处理格式转换（从24kHz到设备输出采样率）
        engine.connect(
            player,
            to: engine.mainMixerNode,
            format: playbackFormat
        )
        
        self.audioEngine = engine
        self.playerNode = player
    }
    
    // MARK: - 播放控制
    
    /// 启动音频引擎（如果尚未启动）
    private func ensureEngineRunning() {
        // 如果引擎已在运行，直接返回
        if let engine = audioEngine, engine.isRunning { return }
        
        do {
            // 仅户外模式下配置双通道输出
            // 同声传译模式和对话模式不重新配置音频会话
            // 避免覆盖AudioCaptureService设置的麦克风路由
            if isDualOutputEnabled && currentMode == .outdoor {
                configureDualOutput()
            }
            
            // 创建新的音频引擎
            setupAndStartEngine()
            
            guard let engine = audioEngine, let player = playerNode else { return }
            
            engine.prepare()
            try engine.start()
            player.play()
            isPlaying = true
            print("[AudioPlayback] 音频播放引擎已启动（模式: \(currentMode.displayName), 双通道: \(isDualOutputEnabled ? "开" : "关"))")
        } catch {
            print("[AudioPlayback] 音频引擎启动失败: \(error.localizedDescription)")
        }
    }
    
    /// 配置双通道音频输出（耳机+扬声器同时播放）
    /// 户外模式专用：用户通过耳机听翻译，对方通过扬声器听翻译
    private func configureDualOutput() {
        let session = AVAudioSession.sharedInstance()
        do {
            // 使用 .playAndRecord + .defaultToSpeaker 确保扬声器输出
            // 同时允许蓝牙耳机输出
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
            )
            
            // 启用扬声器输出
            try session.overrideOutputAudioPort(.speaker)
            
            try session.setActive(true)
            print("[AudioPlayback] 双通道输出已配置（扬声器+耳机）")
            print("[AudioPlayback] 当前输出设备: \(session.currentRoute.outputs.map { $0.portName })")
        } catch {
            print("[AudioPlayback] 双通道配置失败: \(error.localizedDescription)")
        }
    }
    
    /// 将翻译后的音频数据块加入播放队列
    /// - Parameter data: PCM16格式的音频数据
    func enqueueAudio(data: Data) {
        bufferQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 确保引擎正在运行
            self.ensureEngineRunning()
            
            // 将Data转换为AVAudioPCMBuffer
            guard let buffer = self.dataToPCMBuffer(data: data) else {
                print("[AudioPlayback] 音频数据转换失败")
                return
            }
            
            // 调度缓冲区进行播放
            self.playerNode?.scheduleBuffer(buffer, completionHandler: nil)
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
            
            print("[AudioPlayback] 音频播放已停止")
        }
    }
    
    // MARK: - 数据转换
    
    /// 将PCM16 Data转换为AVAudioPCMBuffer
    private func dataToPCMBuffer(data: Data) -> AVAudioPCMBuffer? {
        let frameCount = UInt32(data.count) / UInt32(MemoryLayout<Int16>.size)
        
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: playbackFormat,
            frameCapacity: frameCount
        ) else { return nil }
        
        buffer.frameLength = frameCount
        
        // 将Data中的字节复制到缓冲区
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
