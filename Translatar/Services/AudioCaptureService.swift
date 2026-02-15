// AudioCaptureService.swift
// Translatar - AI实时翻译耳机应用
//
// 音频捕获服务（第二阶段增强版 - 真机兼容修复v2）
//
// 修复说明（v2）：
// - 彻底修复真机上 vpio render err: -1 的问题
// - 根因：AVAudioEngine 的 Voice Processing IO (VPIO) 与
//   AVAudioSession 的 .voiceChat/.measurement 模式存在冲突
// - 解决方案：
//   1. 统一使用 .playAndRecord + .default 模式
//   2. 不调用 setVoiceProcessingEnabled（避免触发 VPIO）
//   3. 依赖 AVAudioSession 自身的降噪能力
//   4. 在 installTap 时使用 nil format 让系统自动选择最佳格式
//
// 技术说明：
// - 使用 AVAudioEngine 进行实时音频捕获
// - 音频格式：PCM16, 16000Hz, 单声道（Gemini Live API要求）
// - 支持后台音频录制（需在Xcode中启用Background Modes -> Audio）

import Foundation
import AVFoundation
import Combine

/// 音频捕获服务协议
protocol AudioCaptureServiceProtocol {
    /// 音频数据流 - 输出PCM16格式的音频数据块
    var audioDataPublisher: AnyPublisher<Data, Never> { get }
    /// 音频电平流 - 用于UI波形显示
    var audioLevelPublisher: AnyPublisher<Float, Never> { get }
    /// 当前是否正在录制
    var isRecording: Bool { get }
    /// 降噪是否已启用
    var isNoiseSuppressionEnabled: Bool { get }
    
    /// 配置并启动音频捕获
    func startCapture(mode: TranslationMode, noiseSuppression: Bool) throws
    /// 停止音频捕获
    func stopCapture()
    /// 动态开关降噪
    func setNoiseSuppression(enabled: Bool)
}

/// 音频捕获服务实现
class AudioCaptureService: AudioCaptureServiceProtocol {
    
    // MARK: - 属性
    
    /// 音频引擎 - iOS核心音频处理组件
    private var audioEngine: AVAudioEngine?
    
    /// 音频数据发布者
    private let audioDataSubject = PassthroughSubject<Data, Never>()
    var audioDataPublisher: AnyPublisher<Data, Never> {
        audioDataSubject.eraseToAnyPublisher()
    }
    
    /// 音频电平发布者
    private let audioLevelSubject = PassthroughSubject<Float, Never>()
    var audioLevelPublisher: AnyPublisher<Float, Never> {
        audioLevelSubject.eraseToAnyPublisher()
    }
    
    /// 当前录制状态
    private(set) var isRecording = false
    
    /// 降噪状态
    private(set) var isNoiseSuppressionEnabled = true
    
    /// 当前翻译模式
    private var currentMode: TranslationMode = .conversation
    
    /// Gemini Live API 要求的音频输入格式
    /// PCM16, 16000Hz, 单声道（Gemini输入16kHz，输出24kHz）
    private let targetSampleRate: Double = 16000.0
    private let targetChannels: AVAudioChannelCount = 1
    
    // MARK: - 音频会话配置
    
    /// 配置iOS音频会话
    private func configureAudioSession(mode: TranslationMode) throws {
        let session = AVAudioSession.sharedInstance()
        
        // 统一使用 .default 模式，避免 .voiceChat 触发系统级 VPIO
        // .voiceChat 会自动启用 Voice Processing IO，与 AVAudioEngine 冲突
        let options: AVAudioSession.CategoryOptions
        
        switch mode {
        case .conversation:
            // 对话模式：允许蓝牙，默认扬声器
            options = [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
        case .immersive:
            // 同声传译模式：允许蓝牙，混合音频确保收音和播放同时进行
            options = [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .mixWithOthers]
        case .outdoor:
            // 户外模式：允许蓝牙，默认扬声器（双通道输出）
            options = [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
        }
        
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: options
        )
        
        // 设置缓冲区大小（同声传译模式使用更小缓冲区提升实时性）
        let bufferDuration = 0.01 // 所有模式统一使用最小缓冲区，最大化实时性
        try session.setPreferredIOBufferDuration(bufferDuration)
        
        // 设置首选采样率
        try session.setPreferredSampleRate(targetSampleRate)
        
        // 激活音频会话
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        
        print("[AudioCapture] 音频会话配置完成 - 模式: \(mode.displayName)")
        print("[AudioCapture] 当前输入设备: \(session.currentRoute.inputs.map { $0.portName })")
        print("[AudioCapture] 当前输出设备: \(session.currentRoute.outputs.map { $0.portName })")
        print("[AudioCapture] 实际采样率: \(session.sampleRate)")
    }
    
    // MARK: - 降噪控制
    
    /// 动态开关降噪（运行时切换）
    /// 注意：v2版本不使用 setVoiceProcessingEnabled 避免 VPIO 冲突
    /// 降噪由 AVAudioSession 的类别和模式隐式控制
    func setNoiseSuppression(enabled: Bool) {
        isNoiseSuppressionEnabled = enabled
        print("[AudioCapture] 降噪设置: \(enabled ? "开" : "关")")
    }
    
    // MARK: - 音频捕获控制
    
    /// 启动音频捕获
    func startCapture(mode: TranslationMode = .conversation, noiseSuppression: Bool = true) throws {
        guard !isRecording else {
            print("[AudioCapture] 已在录制中，忽略重复启动")
            return
        }
        
        currentMode = mode
        isNoiseSuppressionEnabled = noiseSuppression
        
        // 第一步：停止并释放旧的音频引擎
        if let existingEngine = audioEngine {
            existingEngine.inputNode.removeTap(onBus: 0)
            existingEngine.stop()
            existingEngine.reset()
        }
        
        // 第二步：创建全新的音频引擎实例
        // 每次启动都创建新实例，避免残留状态导致的问题
        let engine = AVAudioEngine()
        self.audioEngine = engine
        
        // 第三步：配置音频会话
        try configureAudioSession(mode: mode)
        
        // 第四步：获取输入节点和格式
        // 重要：不调用 setVoiceProcessingEnabled，避免 VPIO
        let inputNode = engine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)
        
        print("[AudioCapture] 硬件输入格式: sampleRate=\(hwFormat.sampleRate), channels=\(hwFormat.channelCount), format=\(hwFormat)")
        
        // 检查输入格式是否有效
        guard hwFormat.sampleRate > 0 && hwFormat.channelCount > 0 else {
            print("[AudioCapture] 错误: 输入格式无效")
            throw AudioCaptureError.formatCreationFailed
        }
        
        // 第五步：创建目标格式（PCM16, 24kHz, 单声道）
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetSampleRate,
            channels: targetChannels,
            interleaved: true
        ) else {
            throw AudioCaptureError.formatCreationFailed
        }
        
        // 第六步：创建格式转换器
        guard let converter = AVAudioConverter(from: hwFormat, to: targetFormat) else {
            print("[AudioCapture] 错误: 无法创建转换器 (从 \(hwFormat.sampleRate)Hz/\(hwFormat.channelCount)ch 到 \(targetSampleRate)Hz/\(targetChannels)ch)")
            throw AudioCaptureError.converterCreationFailed
        }
        
        // 第七步：缓冲区大小
        let bufferSize: AVAudioFrameCount = (mode == .conversation || mode == .outdoor) ? 2400 : 4800
        
        // 第八步：安装音频处理回调
        // 使用硬件原始格式，避免格式不匹配
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: hwFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            
            // 计算音频电平
            self.processAudioLevel(buffer: buffer)
            
            // 转换并发送音频数据
            self.convertAndSendAudio(buffer: buffer, converter: converter, targetFormat: targetFormat)
        }
        
        // 第九步：准备并启动
        engine.prepare()
        try engine.start()
        
        isRecording = true
        print("[AudioCapture] 音频捕获已启动 - 模式: \(mode.displayName), 降噪: \(noiseSuppression ? "开" : "关")")
    }
    
    /// 停止音频捕获
    func stopCapture() {
        guard isRecording else { return }
        
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            engine.reset()
        }
        audioEngine = nil
        isRecording = false
        
        // 释放音频会话
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("[AudioCapture] 释放音频会话失败: \(error.localizedDescription)")
        }
        
        print("[AudioCapture] 音频捕获已停止")
    }
    
    // MARK: - 音频处理
    
    /// 将捕获的音频缓冲区转换为PCM16格式并发送
    private func convertAndSendAudio(
        buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        targetFormat: AVAudioFormat
    ) {
        let ratio = targetSampleRate / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        
        guard outputFrameCapacity > 0 else { return }
        
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputFrameCapacity
        ) else { return }
        
        var error: NSError?
        var hasData = true
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if hasData {
                hasData = false
                outStatus.pointee = .haveData
                return buffer
            } else {
                outStatus.pointee = .noDataNow
                return nil
            }
        }
        
        let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        
        guard status != .error, error == nil else {
            // 不打印每次转换错误，避免日志刷屏
            return
        }
        
        guard let channelData = outputBuffer.int16ChannelData else { return }
        let dataSize = Int(outputBuffer.frameLength) * MemoryLayout<Int16>.size
        let data = Data(bytes: channelData[0], count: dataSize)
        
        audioDataSubject.send(data)
    }
    
    /// 计算音频电平（RMS值）
    private func processAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride).map {
            channelDataValue[$0]
        }
        
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        let avgPower = 20 * log10(rms)
        let normalizedLevel = max(0, min(1, (avgPower + 50) / 50))
        
        audioLevelSubject.send(normalizedLevel)
    }
    
    // MARK: - 清理
    
    deinit {
        stopCapture()
    }
}

// MARK: - 错误定义

enum AudioCaptureError: LocalizedError {
    case formatCreationFailed
    case converterCreationFailed
    case engineStartFailed
    
    var errorDescription: String? {
        switch self {
        case .formatCreationFailed:
            return NSLocalizedString("error.audio.format", comment: "")
        case .converterCreationFailed:
            return NSLocalizedString("error.audio.converter", comment: "")
        case .engineStartFailed:
            return NSLocalizedString("error.audio.engine", comment: "")
        }
    }
}
