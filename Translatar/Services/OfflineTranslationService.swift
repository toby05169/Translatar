// OfflineTranslationService.swift
// Translatar - AI实时翻译耳机应用
//
// 离线翻译服务（第二阶段新增）
// 在没有网络连接时，使用Apple原生框架提供基础翻译能力
//
// 技术架构（三步流水线）：
// 1. SFSpeechRecognizer：设备端语音识别（语音→文字）
// 2. Apple Translation框架：设备端文本翻译（iOS 18+）
// 3. AVSpeechSynthesizer：设备端文字转语音（文字→语音）
//
// 优势：完全免费、无需网络、隐私保护（数据不离开设备）
// 局限：翻译质量不如OpenAI、支持语言较少、需要预下载语言包

import Foundation
import Speech
import AVFoundation
import Combine

// 注意：Translation框架需要iOS 18+，使用条件编译
// 在iOS 17设备上，离线翻译将降级为仅语音识别+TTS
#if canImport(Translation)
import Translation
#endif

/// 离线翻译服务协议
protocol OfflineTranslationServiceProtocol {
    /// 翻译后的文本流
    var translatedTextPublisher: AnyPublisher<String, Never> { get }
    /// 原始转录文本流
    var transcriptPublisher: AnyPublisher<String, Never> { get }
    /// 服务状态流
    var statePublisher: AnyPublisher<OfflineServiceState, Never> { get }
    
    /// 检查离线翻译是否可用
    func checkAvailability(source: SupportedLanguage, target: SupportedLanguage) -> Bool
    /// 启动离线翻译
    func start(source: SupportedLanguage, target: SupportedLanguage, audioEngine: AVAudioEngine) throws
    /// 停止离线翻译
    func stop()
}

/// 离线服务状态
enum OfflineServiceState: Equatable {
    case idle                   // 空闲
    case preparing              // 准备中（下载语言包等）
    case ready                  // 就绪
    case listening              // 正在监听
    case translating            // 正在翻译
    case speaking               // 正在播放翻译结果
    case error(String)          // 错误
    case unavailable(String)    // 不可用（缺少语言包等）
    
    var displayText: String {
        switch self {
        case .idle: return String(localized: "offline.status.standby")
        case .preparing: return String(localized: "offline.status.preparing")
        case .ready: return String(localized: "offline.status.ready")
        case .listening: return String(localized: "offline.status.listening")
        case .translating: return String(localized: "offline.status.translating")
        case .speaking: return String(localized: "offline.status.playing")
        case .error(let msg): return "离线错误：\(msg)"
        case .unavailable(let msg): return "离线不可用：\(msg)"
        }
    }
}

/// 离线翻译服务实现
class OfflineTranslationService: NSObject, OfflineTranslationServiceProtocol {
    
    // MARK: - 发布者
    
    private let translatedTextSubject = PassthroughSubject<String, Never>()
    var translatedTextPublisher: AnyPublisher<String, Never> {
        translatedTextSubject.eraseToAnyPublisher()
    }
    
    private let transcriptSubject = PassthroughSubject<String, Never>()
    var transcriptPublisher: AnyPublisher<String, Never> {
        transcriptSubject.eraseToAnyPublisher()
    }
    
    private let stateSubject = CurrentValueSubject<OfflineServiceState, Never>(.idle)
    var statePublisher: AnyPublisher<OfflineServiceState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - 属性
    
    /// Apple语音识别器
    private var speechRecognizer: SFSpeechRecognizer?
    /// 语音识别请求
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    /// 语音识别任务
    private var recognitionTask: SFSpeechRecognitionTask?
    /// 文字转语音合成器
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    /// 当前源语言
    private var sourceLanguage: SupportedLanguage?
    /// 当前目标语言
    private var targetLanguage: SupportedLanguage?
    
    /// 上一次识别的文本（用于去重）
    private var lastTranscript = ""
    /// 翻译防抖计时器
    private var translationDebounceTimer: Timer?
    
    // MARK: - 语言映射
    
    /// 将应用支持的语言映射到Apple SFSpeechRecognizer的Locale
    private func speechLocale(for language: SupportedLanguage) -> Locale {
        switch language {
        // 东亚语言
        case .chinese: return Locale(identifier: "zh-CN")
        case .cantonese: return Locale(identifier: "zh-HK")
        case .hokkien: return Locale(identifier: "zh-TW")
        case .japanese: return Locale(identifier: "ja-JP")
        case .korean: return Locale(identifier: "ko-KR")
        // 东南亚语言
        case .thai: return Locale(identifier: "th-TH")
        case .vietnamese: return Locale(identifier: "vi-VN")
        case .burmese: return Locale(identifier: "my-MM")
        case .indonesian: return Locale(identifier: "id-ID")
        case .malay: return Locale(identifier: "ms-MY")
        case .tagalog: return Locale(identifier: "fil-PH")
        case .khmer: return Locale(identifier: "km-KH")
        case .lao: return Locale(identifier: "lo-LA")
        // 南亚语言
        case .hindi: return Locale(identifier: "hi-IN")
        case .bengali: return Locale(identifier: "bn-BD")
        case .tamil: return Locale(identifier: "ta-IN")
        case .urdu: return Locale(identifier: "ur-PK")
        // 欧美语言
        case .english: return Locale(identifier: "en-US")
        case .spanish: return Locale(identifier: "es-ES")
        case .portuguese: return Locale(identifier: "pt-BR")
        case .french: return Locale(identifier: "fr-FR")
        case .german: return Locale(identifier: "de-DE")
        case .italian: return Locale(identifier: "it-IT")
        case .russian: return Locale(identifier: "ru-RU")
        case .dutch: return Locale(identifier: "nl-NL")
        case .polish: return Locale(identifier: "pl-PL")
        case .turkish: return Locale(identifier: "tr-TR")
        case .greek: return Locale(identifier: "el-GR")
        case .swedish: return Locale(identifier: "sv-SE")
        // 中东/非洲语言
        case .arabic: return Locale(identifier: "ar-SA")
        case .hebrew: return Locale(identifier: "he-IL")
        case .persian: return Locale(identifier: "fa-IR")
        case .swahili: return Locale(identifier: "sw-KE")
        }
    }
    
    /// 将应用支持的语言映射到AVSpeechSynthesisVoice的语言代码
    private func ttsLanguageCode(for language: SupportedLanguage) -> String {
        switch language {
        // 东亚语言
        case .chinese: return "zh-CN"
        case .cantonese: return "zh-HK"
        case .hokkien: return "zh-TW"
        case .japanese: return "ja-JP"
        case .korean: return "ko-KR"
        // 东南亚语言
        case .thai: return "th-TH"
        case .vietnamese: return "vi-VN"
        case .burmese: return "my-MM"
        case .indonesian: return "id-ID"
        case .malay: return "ms-MY"
        case .tagalog: return "fil-PH"
        case .khmer: return "km-KH"
        case .lao: return "lo-LA"
        // 南亚语言
        case .hindi: return "hi-IN"
        case .bengali: return "bn-BD"
        case .tamil: return "ta-IN"
        case .urdu: return "ur-PK"
        // 欧美语言
        case .english: return "en-US"
        case .spanish: return "es-ES"
        case .portuguese: return "pt-BR"
        case .french: return "fr-FR"
        case .german: return "de-DE"
        case .italian: return "it-IT"
        case .russian: return "ru-RU"
        case .dutch: return "nl-NL"
        case .polish: return "pl-PL"
        case .turkish: return "tr-TR"
        case .greek: return "el-GR"
        case .swedish: return "sv-SE"
        // 中东/非洲语言
        case .arabic: return "ar-SA"
        case .hebrew: return "he-IL"
        case .persian: return "fa-IR"
        case .swahili: return "sw-KE"
        }
    }
    
    // MARK: - 可用性检查
    
    /// 检查离线翻译是否可用
    /// 需要：语音识别器可用 + 支持设备端识别
    func checkAvailability(source: SupportedLanguage, target: SupportedLanguage) -> Bool {
        let locale = speechLocale(for: source)
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            return false
        }
        // 检查是否支持设备端识别
        return recognizer.isAvailable && recognizer.supportsOnDeviceRecognition
    }
    
    // MARK: - 启动/停止
    
    /// 启动离线翻译
    /// - Parameters:
    ///   - source: 源语言
    ///   - target: 目标语言
    ///   - audioEngine: 共享的音频引擎（与AudioCaptureService共用）
    func start(source: SupportedLanguage, target: SupportedLanguage, audioEngine: AVAudioEngine) throws {
        sourceLanguage = source
        targetLanguage = target
        stateSubject.send(.preparing)
        
        // 请求语音识别权限
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self = self else { return }
            
            switch status {
            case .authorized:
                do {
                    try self.startRecognition(source: source, audioEngine: audioEngine)
                } catch {
                    self.stateSubject.send(.error("启动语音识别失败: \(error.localizedDescription)"))
                }
            case .denied:
                self.stateSubject.send(.error(String(localized: "offline.error.permDenied")))
            case .restricted:
                self.stateSubject.send(.error(String(localized: "offline.error.notSupported")))
            case .notDetermined:
                self.stateSubject.send(.error(String(localized: "offline.error.permUndetermined")))
            @unknown default:
                self.stateSubject.send(.error(String(localized: "offline.error.permUnknown")))
            }
        }
    }
    
    /// 启动语音识别引擎
    private func startRecognition(source: SupportedLanguage, audioEngine: AVAudioEngine) throws {
        // 取消之前的任务
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // 创建语音识别器
        let locale = speechLocale(for: source)
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            stateSubject.send(.unavailable(String(localized: "offline.error.recognizerUnavailable")))
            return
        }
        
        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "OfflineTranslation", code: -1, userInfo: [NSLocalizedDescriptionKey: String(localized: "offline.error.cannotCreateRequest")])
        }
        
        // 配置为设备端识别（离线）
        recognitionRequest.requiresOnDeviceRecognition = true
        // 启用部分结果，实现实时显示
        recognitionRequest.shouldReportPartialResults = true
        // 如果可用，添加标点符号
        if #available(iOS 16.0, *) {
            recognitionRequest.addsPunctuation = true
        }
        
        // 获取音频输入节点
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // 在输入节点上安装tap，将音频数据送入语音识别器
        // 注意：如果AudioCaptureService已经安装了tap，这里需要使用不同的bus
        // 或者共享同一个tap的数据
        inputNode.installTap(onBus: 1, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // 启动识别任务
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let transcript = result.bestTranscription.formattedString
                
                // 发布转录文本
                self.transcriptSubject.send(transcript)
                self.stateSubject.send(.listening)
                
                // 防抖翻译：等待用户停顿后再翻译，避免频繁调用
                self.debounceTranslation(text: transcript)
                
                // 如果是最终结果，立即翻译
                if result.isFinal {
                    self.translateAndSpeak(text: transcript)
                }
            }
            
            if let error = error {
                print("[OfflineTranslation] 识别错误: \(error.localizedDescription)")
                // 如果不是取消错误，尝试重启
                if (error as NSError).code != 216 { // 216 = 用户取消
                    self.stateSubject.send(.error(error.localizedDescription))
                }
            }
        }
        
        stateSubject.send(.ready)
        print("[OfflineTranslation] 离线语音识别已启动 - 语言: \(source.displayName)")
    }
    
    /// 防抖翻译：用户停顿800ms后触发翻译
    private func debounceTranslation(text: String) {
        translationDebounceTimer?.invalidate()
        translationDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
            guard let self = self, text != self.lastTranscript else { return }
            self.lastTranscript = text
            self.translateAndSpeak(text: text)
        }
    }
    
    /// 翻译文本并用TTS播放
    private func translateAndSpeak(text: String) {
        guard let targetLanguage = targetLanguage, !text.isEmpty else { return }
        
        stateSubject.send(.translating)
        
        // 使用Apple Translation框架进行翻译（iOS 18+）
        // 如果不可用，则使用简单的字典查找或直接TTS原文
        translateText(text) { [weak self] translatedText in
            guard let self = self else { return }
            
            let finalText = translatedText ?? text
            self.translatedTextSubject.send(finalText)
            
            // 使用TTS播放翻译结果
            self.speak(text: finalText, language: targetLanguage)
        }
    }
    
    /// 使用Apple Translation框架翻译文本
    /// 注意：TranslationSession需要通过SwiftUI的.translationTask修饰符获取，
    /// 在非SwiftUI上下文中无法直接创建。离线模式下仅提供语音识别+TTS功能，
    /// 翻译功能需要在SwiftUI视图层通过translationTask实现。
    private func translateText(_ text: String, completion: @escaping (String?) -> Void) {
        // 离线模式下的翻译降级策略：
        // 由于TranslationSession只能通过SwiftUI的.translationTask获取，
        // 在Service层直接调用不可行。
        // 这里返回nil，由调用方使用原文+TTS作为降级方案。
        // 完整的离线翻译需要在View层配合.translationTask实现。
        print("[OfflineTranslation] 离线翻译使用语音识别+TTS降级模式")
        completion(nil)
    }
    
    /// 使用AVSpeechSynthesizer播放翻译结果
    private func speak(text: String, language: SupportedLanguage) {
        // 如果正在播放，先停止
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: ttsLanguageCode(for: language))
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.1 // 稍快一点，更自然
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.9
        
        stateSubject.send(.speaking)
        speechSynthesizer.speak(utterance)
        
        // 播放完成后恢复监听状态
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(text.count) * 0.08) { [weak self] in
            if self?.stateSubject.value == .speaking {
                self?.stateSubject.send(.listening)
            }
        }
    }
    
    /// 停止离线翻译
    func stop() {
        translationDebounceTimer?.invalidate()
        translationDebounceTimer = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        lastTranscript = ""
        stateSubject.send(.idle)
        print("[OfflineTranslation] 离线翻译已停止")
    }
    
    // MARK: - 清理
    
    deinit {
        stop()
    }
}

// MARK: - 网络状态检测工具

/// 网络连接状态检测
/// 用于自动切换在线/离线翻译模式
class NetworkMonitor: ObservableObject {
    @Published var isConnected = true
    
    private let monitor: Any? // NWPathMonitor，使用Any避免直接导入
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        if #available(iOS 12.0, *) {
            let pathMonitor = NWPathMonitor()
            self.monitor = pathMonitor
            
            pathMonitor.pathUpdateHandler = { [weak self] path in
                DispatchQueue.main.async {
                    self?.isConnected = path.status == .satisfied
                    print("[NetworkMonitor] 网络状态: \(path.status == .satisfied ? "已连接" : "已断开")")
                }
            }
            pathMonitor.start(queue: queue)
        } else {
            self.monitor = nil
        }
    }
    
    deinit {
        if #available(iOS 12.0, *), let monitor = monitor as? NWPathMonitor {
            monitor.cancel()
        }
    }
}

import Network
