// AudioCaptureService.swift
// Translatar - AI实时翻译耳机应用
//
// 音频捕获服务
// 负责配置AVAudioSession、管理AirPods麦克风输入、
// 捕获实时音频流并将PCM16数据传递给翻译引擎
//
// 技术说明（面向开发者）：
// - 使用 AVAudioEngine 进行实时音频捕获
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
    
    /// 配置并启动音频捕获
    func startCapture() throws
    /// 停止音频捕获
    func stopCapture()
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
    
    /// OpenAI Realtime API 要求的音频格式
    /// PCM16, 24000Hz, 单声道
    private let targetSampleRate: Double = 24000.0
    private let targetChannels: AVAudioChannelCount = 1
    
    // MARK: - 音频会话配置
    
    /// 配置iOS音频会话
    /// 这是使用AirPods麦克风的关键步骤
    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        
        // 设置音频类别为"播放和录制"
        // - .playAndRecord: 同时支持麦克风输入和扬声器/耳机输出
        // - .defaultToSpeaker: 默认使用扬声器（当没有耳机时）
        // - .allowBluetooth: 允许蓝牙设备（AirPods）作为输入/输出
        // - .allowBluetoothA2DP: 允许高质量蓝牙音频
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
        )
        
        // 设置首选采样率
        try session.setPreferredSampleRate(targetSampleRate)
        
        // 设置首选IO缓冲区大小（越小延迟越低，但CPU开销越大）
        // 0.01秒 = 10ms，在延迟和性能之间取得平衡
        try session.setPreferredIOBufferDuration(0.01)
        
        // 激活音频会话
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        
        print("[AudioCapture] 音频会话配置完成")
        print("[AudioCapture] 当前输入设备: \(session.currentRoute.inputs.map { $0.portName })")
        print("[AudioCapture] 当前输出设备: \(session.currentRoute.outputs.map { $0.portName })")
        print("[AudioCapture] 实际采样率: \(session.sampleRate)")
    }
    
    // MARK: - 音频捕获控制
    
    /// 启动音频捕获
    /// 配置音频引擎，安装音频处理节点，开始录制
    func startCapture() throws {
        guard !isRecording else {
            print("[AudioCapture] 已在录制中，忽略重复启动")
            return
        }
        
        // 第一步：配置音频会话
        try configureAudioSession()
        
        // 第二步：获取输入节点（麦克风）
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        print("[AudioCapture] 输入音频格式: \(inputFormat)")
        
        // 第三步：创建目标格式（PCM16, 24kHz, 单声道）
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetSampleRate,
            channels: targetChannels,
            interleaved: true
        ) else {
            throw AudioCaptureError.formatCreationFailed
        }
        
        // 第四步：创建格式转换器
        // 将麦克风的原始格式转换为OpenAI API要求的格式
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioCaptureError.converterCreationFailed
        }
        
        // 第五步：在输入节点上安装音频处理回调
        // 每当有新的音频数据到达时，此回调会被调用
        inputNode.installTap(onBus: 0, bufferSize: 2400, format: inputFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            
            // 计算音频电平（用于UI显示）
            self.processAudioLevel(buffer: buffer)
            
            // 将音频数据转换为目标格式并发送
            self.convertAndSendAudio(buffer: buffer, converter: converter, targetFormat: targetFormat)
        }
        
        // 第六步：准备并启动音频引擎
        audioEngine.prepare()
        try audioEngine.start()
        
        isRecording = true
        print("[AudioCapture] 音频捕获已启动")
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
            return "无法创建目标音频格式"
        case .converterCreationFailed:
            return "无法创建音频格式转换器"
        case .engineStartFailed:
            return "音频引擎启动失败"
        }
    }
}
