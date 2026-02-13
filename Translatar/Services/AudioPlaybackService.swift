// AudioPlaybackService.swift
// Translatar - AI实时翻译耳机应用
//
// 音频播放服务
// 负责将从OpenAI Realtime API返回的翻译音频数据
// 通过AirPods实时播放给用户
//
// 技术说明：
// - 接收PCM16格式的音频数据块
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
    private let audioEngine = AVAudioEngine()
    /// 播放器节点
    private let playerNode = AVAudioPlayerNode()
    
    /// 播放状态
    private(set) var isPlaying = false
    
    /// 播放音频的格式（与OpenAI Realtime API输出一致）
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
        
        setupAudioEngine()
    }
    
    /// 配置音频引擎和播放器节点
    private func setupAudioEngine() {
        // 将播放器节点附加到音频引擎
        audioEngine.attach(playerNode)
        
        // 连接播放器节点到主混音器
        // 音频引擎会自动处理格式转换（从24kHz到设备输出采样率）
        audioEngine.connect(
            playerNode,
            to: audioEngine.mainMixerNode,
            format: playbackFormat
        )
    }
    
    // MARK: - 播放控制
    
    /// 启动音频引擎（如果尚未启动）
    private func ensureEngineRunning() {
        guard !audioEngine.isRunning else { return }
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
            playerNode.play()
            isPlaying = true
            print("[AudioPlayback] 音频播放引擎已启动")
        } catch {
            print("[AudioPlayback] 音频引擎启动失败: \(error.localizedDescription)")
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
            self.playerNode.scheduleBuffer(buffer, completionHandler: nil)
        }
    }
    
    /// 停止播放并清空队列
    func stopPlayback() {
        bufferQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.playerNode.stop()
            self.audioEngine.stop()
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
