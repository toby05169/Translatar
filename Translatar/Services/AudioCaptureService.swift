// AudioCaptureService.swift
// Translatar - AI实时翻译耳机应用
//
// 音频捕获服务（v3 - 同声传译麦克风修复）
//
// v3 修复说明（2026-02-15）：
// 【问题：电脑播放手机收不到】
// - AirPods连接后，iOS默认将麦克风输入切换到AirPods麦克风
// - AirPods麦克风离电脑扬声器太远，无法有效拾取电脑播放的音频
// - 修复：同声传译模式下强制使用iPhone内置麦克风（底部麦克风）
//   输入：iPhone底部麦克风（拾取环境声音/电脑播放）
//   输出：AirPods（用户通过耳机听翻译结果）
//
// v2 保留功能：
// - 避免 VPIO 冲突（不调用 setVoiceProcessingEnabled）
// - 统一使用 .playAndRecord + .default 模式

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
    /// v3: 同声传译模式强制使用iPhone内置麦克风
    private func configureAudioSession(mode: TranslationMode) throws {
        let session = AVAudioSession.sharedInstance()
        
        let options: AVAudioSession.CategoryOptions
        
        switch mode {
        case .conversation:
            // 对话模式：允许蓝牙（AirPods麦克风+AirPods播放）
            options = [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
        case .immersive:
            // v3.2 核心修复：同声传译模式
            //
            // 只用 .allowBluetoothA2DP，不用 .allowBluetooth
            // 原理：
            //   - .allowBluetooth 会启用HFP协议，导致AirPods麦克风变成输入源
            //   - .allowBluetoothA2DP 只允许A2DP输出（高质量立体声）
            //   - 不启用HFP = AirPods不作为麦克风 = 输入自动回退到iPhone内置麦克风
            //   - 效果：iPhone麦克风收音 + AirPods A2DP高质量播放
            // Apple文档确认：iOS 10+的playAndRecord支持allowBluetoothA2DP
            options = [.allowBluetoothA2DP, .defaultToSpeaker]
        case .outdoor:
            // 户外模式：允许蓝牙，默认扬声器（双通道输出）
            options = [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
        }
        
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: options
        )
        
        // v3.2: 同声传译模式不需要手动指定麦克风
        // 因为没有启用.allowBluetooth，输入自动回退到iPhone内置麦克风
        // 保留forceBuiltInMicrophone作为双保险（以防某些iOS版本行为不一致）
        if mode == .immersive {
            try forceBuiltInMicrophone(session: session)
        }
        
        // 设置缓冲区大小（最小缓冲区，最大化实时性）
        let bufferDuration = 0.01
        try session.setPreferredIOBufferDuration(bufferDuration)
        
        // 设置首选采样率
        try session.setPreferredSampleRate(targetSampleRate)
        
        // 激活音频会话
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        
        print("[AudioCapture] 音频会话配置完成 - 模式: \(mode.displayName)")
        print("[AudioCapture] 当前输入设备: \(session.currentRoute.inputs.map { "\($0.portName) (\($0.portType.rawValue))" })")
        print("[AudioCapture] 当前输出设备: \(session.currentRoute.outputs.map { "\($0.portName) (\($0.portType.rawValue))" })")
        print("[AudioCapture] 实际采样率: \(session.sampleRate)")
    }
    
    /// v3: 强制选择iPhone内置麦克风
    /// 遍历可用输入设备，找到内置麦克风并设为首选输入
    private func forceBuiltInMicrophone(session: AVAudioSession) throws {
        guard let availableInputs = session.availableInputs else {
            print("[AudioCapture] 警告: 无法获取可用输入设备列表")
            return
        }
        
        print("[AudioCapture] 可用输入设备:")
        for input in availableInputs {
            print("[AudioCapture]   - \(input.portName) (\(input.portType.rawValue))")
        }
        
        // 查找内置麦克风
        if let builtInMic = availableInputs.first(where: { $0.portType == .builtInMic }) {
            try session.setPreferredInput(builtInMic)
            print("[AudioCapture] ✅ 已强制选择内置麦克风: \(builtInMic.portName)")
            
            // 尝试选择底部麦克风数据源（如果可用）
            // iPhone有多个内置麦克风（底部、前置、后置），底部麦克风最适合拾取外部声音
            if let dataSources = builtInMic.dataSources {
                print("[AudioCapture] 内置麦克风数据源:")
                for source in dataSources {
                    print("[AudioCapture]   - \(source.dataSourceName) (方向: \(source.orientation?.rawValue ?? "无"), 位置: \(source.location?.rawValue ?? "无"))")
                }
                
                // 优先选择底部麦克风
                if let bottomMic = dataSources.first(where: { $0.location == .lower }) {
                    try builtInMic.setPreferredDataSource(bottomMic)
                    print("[AudioCapture] ✅ 已选择底部麦克风: \(bottomMic.dataSourceName)")
                }
                // 如果没有底部，尝试前置麦克风
                else if let frontMic = dataSources.first(where: { $0.orientation == .front }) {
                    try builtInMic.setPreferredDataSource(frontMic)
                    print("[AudioCapture] ✅ 已选择前置麦克风: \(frontMic.dataSourceName)")
                }
            }
        } else {
            print("[AudioCapture] ⚠️ 未找到内置麦克风，将使用默认输入设备")
            // 如果没有内置麦克风（比如iPad外接键盘），回退到默认
        }
    }
    
    // MARK: - 降噪控制
    
    /// 动态开关降噪（运行时切换）
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
        let engine = AVAudioEngine()
        self.audioEngine = engine
        
        // 第三步：配置音频会话（v3: 同声传译会强制内置麦克风）
        try configureAudioSession(mode: mode)
        
        // 第四步：获取输入节点和格式
        let inputNode = engine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)
        
        print("[AudioCapture] 硬件输入格式: sampleRate=\(hwFormat.sampleRate), channels=\(hwFormat.channelCount), format=\(hwFormat)")
        
        // 检查输入格式是否有效
        guard hwFormat.sampleRate > 0 && hwFormat.channelCount > 0 else {
            print("[AudioCapture] 错误: 输入格式无效")
            throw AudioCaptureError.formatCreationFailed
        }
        
        // 第五步：创建目标格式（PCM16, 16kHz, 单声道）
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
        // 同声传译使用稍大的缓冲区（4800帧=300ms@16kHz），减少发送频率
        let bufferSize: AVAudioFrameCount = (mode == .conversation || mode == .outdoor) ? 2400 : 4800
        
        // 第八步：安装音频处理回调
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
        
        if mode == .immersive {
            print("[AudioCapture] 同声传译模式: 使用iPhone内置麦克风拾取环境声音")
        }
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
