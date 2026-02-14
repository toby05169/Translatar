// RealtimeTranslationService.swift
// Translatar - AI实时翻译耳机应用
//
// OpenAI Realtime API 翻译服务（第二阶段增强版）
// 负责通过WebSocket与OpenAI Realtime API建立连接，
// 发送音频数据并接收翻译后的音频和文本结果
//
// 第二阶段新增能力：
// - 沉浸模式专用VAD参数（更长的静音容忍，适合广播翻译）
// - 沉浸模式专用翻译提示词（优化广播/公告翻译质量）
// - 模式感知的会话配置
//
// 技术说明：
// - 使用原生URLSessionWebSocketTask进行WebSocket通信
// - 音频数据以Base64编码的PCM16格式传输
// - 支持流式音频输入和输出，实现低延迟翻译
// - 使用VAD（语音活动检测）自动识别说话起止

import Foundation
import Combine

/// 翻译服务协议
protocol RealtimeTranslationServiceProtocol {
    /// 翻译后的音频数据流
    var translatedAudioPublisher: AnyPublisher<Data, Never> { get }
    /// 翻译后的文本流（用于字幕显示）
    var translatedTextPublisher: AnyPublisher<String, Never> { get }
    /// 原始语音的转录文本流
    var transcriptPublisher: AnyPublisher<String, Never> { get }
    /// 连接状态流
    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> { get }
    
    /// 连接到翻译服务
    func connect(config: TranslationConfig, mode: TranslationMode) async throws
    /// 发送音频数据
    func sendAudio(data: Data)
    /// 断开连接
    func disconnect()
}

/// OpenAI Realtime API 翻译服务实现
class RealtimeTranslationService: NSObject, RealtimeTranslationServiceProtocol {
    
    // MARK: - 发布者
    
    private let translatedAudioSubject = PassthroughSubject<Data, Never>()
    var translatedAudioPublisher: AnyPublisher<Data, Never> {
        translatedAudioSubject.eraseToAnyPublisher()
    }
    
    private let translatedTextSubject = PassthroughSubject<String, Never>()
    var translatedTextPublisher: AnyPublisher<String, Never> {
        translatedTextSubject.eraseToAnyPublisher()
    }
    
    private let transcriptSubject = PassthroughSubject<String, Never>()
    var transcriptPublisher: AnyPublisher<String, Never> {
        transcriptSubject.eraseToAnyPublisher()
    }
    
    private let connectionStateSubject = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - 属性
    
    /// WebSocket连接任务
    private var webSocketTask: URLSessionWebSocketTask?
    /// URL会话
    private var urlSession: URLSession?
    /// 当前翻译配置
    private var currentConfig: TranslationConfig?
    /// 当前翻译模式
    private var currentMode: TranslationMode = .conversation
    /// 是否已连接
    private var isConnected = false
    
    /// API配置
    private let apiBaseURL = "wss://api.openai.com/v1/realtime"
    private let model = "gpt-4o-realtime-preview"
    
    // MARK: - 连接管理
    
    /// 连接到OpenAI Realtime API
    /// - Parameters:
    ///   - config: 翻译配置（源语言和目标语言）
    ///   - mode: 翻译模式（对话/沉浸）
    func connect(config: TranslationConfig, mode: TranslationMode = .conversation) async throws {
        currentConfig = config
        currentMode = mode
        connectionStateSubject.send(.connecting)
        
        // 从配置或环境变量获取API密钥
        guard let apiKey = getAPIKey() else {
            connectionStateSubject.send(.error("未配置API密钥"))
            throw TranslationError.missingAPIKey
        }
        
        // 构建WebSocket URL
        guard let url = URL(string: "\(apiBaseURL)?model=\(model)") else {
            throw TranslationError.invalidURL
        }
        
        // 创建WebSocket请求
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")
        
        // 创建URLSession和WebSocket任务
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.urlSession = session
        self.webSocketTask = session.webSocketTask(with: request)
        
        // 开始连接
        webSocketTask?.resume()
        
        // 开始接收消息
        startReceivingMessages()
        
        // 等待连接建立后发送会话配置
        try await Task.sleep(nanoseconds: 500_000_000)
        try await configureSession(config: config, mode: mode)
        
        isConnected = true
        connectionStateSubject.send(.connected)
        print("[RealtimeAPI] 已连接到翻译服务 - 模式: \(mode.displayName)")
    }
    
    /// 配置翻译会话
    /// 根据翻译模式使用不同的VAD参数和提示词
    private func configureSession(config: TranslationConfig, mode: TranslationMode) async throws {
        let translationPrompt = buildTranslationPrompt(config: config, mode: mode)
        let vadConfig = buildVADConfig(mode: mode)
        
        // 会话配置事件
        let sessionConfig: [String: Any] = [
            "type": "session.update",
            "session": [
                "modalities": ["text", "audio"],
                "instructions": translationPrompt,
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm16",
                "voice": "shimmer",
                "turn_detection": vadConfig,
                "input_audio_transcription": [
                    "model": "whisper-1"
                ]
            ]
        ]
        
        try await sendJSON(sessionConfig)
        print("[RealtimeAPI] 会话配置已发送 - 模式: \(mode.displayName)")
    }
    
    /// 根据模式构建不同的VAD（语音活动检测）配置
    /// 这是解决"机场广播翻译"问题的关键参数
    /// 注意：threshold使用NSDecimalNumber避免Double浮点精度问题
    /// （Swift中0.3的Double表示为0.29999...17位小数，超过OpenAI API的16位限制）
    private func buildVADConfig(mode: TranslationMode) -> [String: Any] {
        switch mode {
        case .conversation:
            // 对话模式：快速响应，短静音即认为说话结束
            return [
                "type": "server_vad",
                "threshold": NSDecimalNumber(string: "0.5"),  // 标准灵敏度
                "prefix_padding_ms": 300,    // 语音开始前保留300ms
                "silence_duration_ms": 500   // 静音500ms后认为说话结束
            ]
            
        case .immersive:
            // 沉浸模式：更高灵敏度，更长静音容忍
            // - 降低阈值：更容易捕获远处的广播声音
            // - 增加静音容忍：广播中间可能有短暂停顿，不要过早截断
            // - 增加前缀填充：确保不丢失广播开头的内容
            return [
                "type": "server_vad",
                "threshold": NSDecimalNumber(string: "0.3"),  // 更低的阈值，更灵敏
                "prefix_padding_ms": 500,    // 语音开始前保留500ms
                "silence_duration_ms": 1500  // 静音1.5秒后才认为说话结束（广播可能有停顿）
            ]
        }
    }
    
    /// 构建翻译提示词
    /// 根据模式使用不同的翻译策略
    private func buildTranslationPrompt(config: TranslationConfig, mode: TranslationMode) -> String {
        let basePrompt = """
        You are a real-time language translator. Your ONLY job is to translate speech.
        
        CRITICAL RULES:
        1. You are translating FROM \(config.sourceLanguage.englishName) TO \(config.targetLanguage.englishName).
        2. ONLY output the translation. Do NOT add any commentary, explanation, or response to the content.
        3. Preserve the speaker's tone, emotion, and intent as much as possible.
        4. For proper nouns (names, places, brands), keep them in their original form or use the standard translation in \(config.targetLanguage.englishName).
        5. Translate naturally and idiomatically - avoid word-for-word literal translation.
        6. Match the formality level of the original speech.
        """
        
        switch mode {
        case .conversation:
            return basePrompt + """
            
            CONVERSATION MODE SPECIFIC:
            - You are translating a face-to-face conversation.
            - Keep translations concise and conversational.
            - If the speech is a question, translate it as a question.
            - Respond quickly - prioritize speed over perfection for short phrases.
            
            You are like a professional simultaneous interpreter at a business meeting. Just translate, nothing else.
            """
            
        case .immersive:
            return basePrompt + """
            
            IMMERSIVE/BROADCAST MODE SPECIFIC:
            - You are translating environmental audio such as airport announcements, train station broadcasts, public address systems, or overheard conversations.
            - Pay special attention to:
              * Flight numbers, gate numbers, and boarding information
              * Time references and schedule changes
              * Location names and directions
              * Safety and emergency announcements
              * Names being called out
            - For airport/transit announcements, always include the key actionable information (gate number, flight number, time, action required).
            - If the audio quality is poor or partially unclear, translate what you can confidently understand and mark uncertain parts.
            - Combine fragmented sentences into coherent translations when possible.
            
            You are like a travel companion who helps the user understand everything happening around them. Prioritize accuracy of critical information (numbers, locations, times).
            """
        }
    }
    
    // MARK: - 音频数据传输
    
    /// 发送音频数据到API
    func sendAudio(data: Data) {
        guard isConnected else { return }
        
        let base64Audio = data.base64EncodedString()
        
        let audioEvent: [String: Any] = [
            "type": "input_audio_buffer.append",
            "audio": base64Audio
        ]
        
        Task {
            try? await sendJSON(audioEvent)
        }
    }
    
    /// 断开连接
    func disconnect() {
        isConnected = false
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        connectionStateSubject.send(.disconnected)
        print("[RealtimeAPI] 已断开连接")
    }
    
    // MARK: - WebSocket消息处理
    
    /// 开始循环接收WebSocket消息
    private func startReceivingMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.startReceivingMessages()
                
            case .failure(let error):
                print("[RealtimeAPI] 接收消息错误: \(error.localizedDescription)")
                self.connectionStateSubject.send(.error(error.localizedDescription))
            }
        }
    }
    
    /// 处理接收到的WebSocket消息
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            handleJSONMessage(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                handleJSONMessage(text)
            }
        @unknown default:
            break
        }
    }
    
    /// 解析并处理JSON消息
    private func handleJSONMessage(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }
        
        switch type {
        case "session.created":
            print("[RealtimeAPI] 会话已创建")
            
        case "session.updated":
            print("[RealtimeAPI] 会话配置已更新")
            
        case "response.audio.delta":
            if let delta = json["delta"] as? String,
               let audioData = Data(base64Encoded: delta) {
                translatedAudioSubject.send(audioData)
            }
            connectionStateSubject.send(.translating)
            
        case "response.audio_transcript.delta":
            if let delta = json["delta"] as? String {
                translatedTextSubject.send(delta)
            }
            
        case "response.audio_transcript.done":
            if let transcript = json["transcript"] as? String {
                print("[RealtimeAPI] 翻译完成: \(transcript)")
            }
            connectionStateSubject.send(.connected)
            
        case "conversation.item.input_audio_transcription.completed":
            if let transcript = json["transcript"] as? String {
                transcriptSubject.send(transcript)
                print("[RealtimeAPI] 原文转录: \(transcript)")
            }
            
        case "input_audio_buffer.speech_started":
            print("[RealtimeAPI] 检测到语音输入")
            connectionStateSubject.send(.translating)
            
        case "input_audio_buffer.speech_stopped":
            print("[RealtimeAPI] 语音输入结束")
            
        case "response.done":
            connectionStateSubject.send(.connected)
            
        case "error":
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("[RealtimeAPI] API错误: \(message)")
                connectionStateSubject.send(.error(message))
            }
            
        default:
            break
        }
    }
    
    // MARK: - 工具方法
    
    /// 发送JSON数据到WebSocket
    private func sendJSON(_ dict: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: dict)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw TranslationError.encodingFailed
        }
        try await webSocketTask?.send(.string(jsonString))
    }
    
    /// 获取API密钥
    private func getAPIKey() -> String? {
        if let key = UserDefaults.standard.string(forKey: "openai_api_key"), !key.isEmpty {
            return key
        }
        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty {
            return key
        }
        return nil
    }
    
    // MARK: - 清理
    
    deinit {
        disconnect()
    }
}

// MARK: - URLSessionWebSocketDelegate

extension RealtimeTranslationService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("[RealtimeAPI] WebSocket连接已打开")
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("[RealtimeAPI] WebSocket连接已关闭，代码: \(closeCode)")
        connectionStateSubject.send(.disconnected)
    }
}

// MARK: - 错误定义

/// 翻译服务相关错误
enum TranslationError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case connectionFailed
    case encodingFailed
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "未配置OpenAI API密钥，请在设置中配置"
        case .invalidURL:
            return "API地址无效"
        case .connectionFailed:
            return "连接翻译服务失败"
        case .encodingFailed:
            return "数据编码失败"
        }
    }
}
