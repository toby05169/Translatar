// AudioCaptureService.swift
// Translatar - AI实时翻译耳机应用
//
// 音频捕获服务（第二阶段增强版）
// 负责配置AVAudioSession、管理AirPods麦克风输入、
// 捕获实时音频流并将PCM16数据传递给翻译引擎
//
// 第二阶段新增能力：
// - Apple原生Voice Processing降噪（回声消除+噪声抑制+自动增益控制）
// - 沉浸模式支持（后台持续监听，适合机场广播等场景）
// - 降噪开关控制
//
// 技术说明（面向开发者）：
// - 使用 AVAudioEngine 进行实时音频捕获
// - 使用 setVoiceProcessingEnabled(true) 启用Apple原生AI降噪
// - 音频格式：PCM16, 24000Hz, 单声道（OpenAI Realtime API要求）
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
    private let audioEngine = AVAudioEngine()
    
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
    
    /// OpenAI Realtime API 要求的音频格式
    /// PCM16, 24000Hz, 单声道
    private let targetSampleRate: Double = 24000.0
    private let targetChannels: AVAudioChannelCount = 1
    
    // MARK: - 音频会话配置
    
    /// 配置iOS音频会话
    /// 根据翻译模式选择不同的配置策略
    private func configureAudioSession(mode: TranslationMode) throws {
        let session = AVAudioSession.sharedInstance()
        
        switch mode {
        case .conversation:
            // 对话模式：优化面对面交流
            // - .voiceChat 模式会自动启用部分回声消除
            // - .allowBluetooth 确保AirPods可用
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
            )
            // 对话模式使用较小的缓冲区，追求低延迟
            try session.setPreferredIOBufferDuration(0.01)
            
        case .immersive:
            // 沉浸模式：优化环境音捕获（机场广播等）
            // - .measurement 模式提供最原始的音频信号，不做额外处理
            // - 这样可以更好地捕获远处的广播声音
            try session.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .mixWithOthers]
            )
            // 沉浸模式使用稍大的缓冲区，优先保证稳定性
            try session.setPreferredIOBufferDuration(0.02)
        }
        
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
    
    /// 启用/禁用Apple原生Voice Processing降噪
    /// Voice Processing 包含：
    /// 1. 回声消除（AEC）- 消除扬声器播放的声音被麦克风捕获
    /// 2. 噪声抑制（NS）- 抑制环境背景噪声
    /// 3. 自动增益控制（AGC）- 自动调整音量到合适水平
    private func configureVoiceProcessing(enabled: Bool) {
        let inputNode = audioEngine.inputNode
        
        do {
            try inputNode.setVoiceProcessingEnabled(enabled)
            isNoiseSuppressionEnabled = enabled
            print("[AudioCapture] Voice Processing \(enabled ? "已启用" : "已禁用")")
            
            if enabled {
                print("[AudioCapture] → 回声消除(AEC): 已激活")
                print("[AudioCapture] → 噪声抑制(NS): 已激活")
                print("[AudioCapture] → 自动增益控制(AGC): 已激活")
            }
        } catch {
            print("[AudioCapture] Voice Processing配置失败: \(error.localizedDescription)")
        }
    }
    
    /// 动态开关降噪（运行时切换）
    func setNoiseSuppression(enabled: Bool) {
        guard isRecording else {
            isNoiseSuppressionEnabled = enabled
            return
        }
        configureVoiceProcessing(enabled: enabled)
    }
    
    // MARK: - 音频捕获控制
    
    /// 启动音频捕获
    /// - Parameters:
    ///   - mode: 翻译模式（对话/沉浸）
    ///   - noiseSuppression: 是否启用降噪
    func startCapture(mode: TranslationMode = .conversation, noiseSuppression: Bool = true) throws {
        guard !isRecording else {
            print("[AudioCapture] 已在录制中，忽略重复启动")
            return
        }
        
        currentMode = mode
        
        // 第一步：配置音频会话（根据模式选择不同策略）
        try configureAudioSession(mode: mode)
        
        // 第二步：启用Voice Processing降噪
        // 必须在安装tap之前配置
        configureVoiceProcessing(enabled: noiseSuppression)
        
        // 第三步：获取输入节点（麦克风）
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        print("[AudioCapture] 输入音频格式: \(inputFormat)")
        
        // 第四步：创建目标格式（PCM16, 24kHz, 单声道）
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetSampleRate,
            channels: targetChannels,
            interleaved: true
        ) else {
            throw AudioCaptureError.formatCreationFailed
        }
        
        // 第五步：创建格式转换器
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioCaptureError.converterCreationFailed
        }
        
        // 第六步：根据模式选择不同的缓冲区大小
        // 对话模式：较小缓冲区（2400帧 ≈ 100ms），追求低延迟
        // 沉浸模式：较大缓冲区（4800帧 ≈ 200ms），追求稳定性
        let bufferSize: AVAudioFrameCount = mode == .conversation ? 2400 : 4800
        
        // 第七步：在输入节点上安装音频处理回调
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            
            // 计算音频电平（用于UI显示）
            self.processAudioLevel(buffer: buffer)
            
            // 将音频数据转换为目标格式并发送
            self.convertAndSendAudio(buffer: buffer, converter: converter, targetFormat: targetFormat)
        }
        
        // 第八步：准备并启动音频引擎
        audioEngine.prepare()
        try audioEngine.start()
        
        isRecording = true
        print("[AudioCapture] 音频捕获已启动 - 模式: \(mode.displayName), 降噪: \(noiseSuppression ? "开" : "关")")
    }
    
    /// 停止音频捕获
    func stopCapture() {
        guard isRecording else { return }
        
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRecording = false
        
        // 释放音频会话
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        
        print("[AudioCapture] 音频捕获已停止")
    }
    
    // MARK: - 音频处理
    
    /// 将捕获的音频缓冲区转换为PCM16格式并发送
    private func convertAndSendAudio(
        buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        targetFormat: AVAudioFormat
    ) {
        // 计算转换后的帧数
        let ratio = targetSampleRate / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        
        guard outputFrameCapacity > 0 else { return }
        
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputFrameCapacity
        ) else { return }
        
        // 执行格式转换
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        
        guard status != .error, error == nil else {
            print("[AudioCapture] 音频转换错误: \(error?.localizedDescription ?? "未知错误")")
            return
        }
        
        // 将PCM缓冲区转换为Data
        guard let channelData = outputBuffer.int16ChannelData else { return }
        let dataSize = Int(outputBuffer.frameLength) * MemoryLayout<Int16>.size
        let data = Data(bytes: channelData[0], count: dataSize)
        
        // 通过Combine发布音频数据
        audioDataSubject.send(data)
    }
    
    /// 计算音频电平（RMS值）
    private func processAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride).map {
            channelDataValue[$0]
        }
        
        // 计算RMS（均方根）值
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        
        // 将RMS转换为0-1范围的电平值
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

/// 音频捕获相关错误
enum AudioCaptureError: LocalizedError {
    case formatCreationFailed
    case converterCreationFailed
    case engineStartFailed
    
    var errorDescription: String? {
        switch self {
        case .formatCreationFailed:
            return String(localized: "error.audio.format")
        case .converterCreationFailed:
            return String(localized: "error.audio.converter")
        case .engineStartFailed:
            return String(localized: "error.audio.engine")
        }
    }
}
