// RealtimeTranslationService.swift
// Translatar - AI实时翻译耳机应用
//
// OpenAI Realtime API 翻译服务
// 负责通过WebSocket与OpenAI Realtime API建立连接，
// 发送音频数据并接收翻译后的音频和文本结果
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
    func connect(config: TranslationConfig) async throws
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
    /// 是否已连接
    private var isConnected = false
    
    /// API配置
    /// 注意：在生产环境中，API密钥应通过后端代理服务获取，不应硬编码在客户端
    private let apiBaseURL = "wss://api.openai.com/v1/realtime"
    private let model = "gpt-4o-realtime-preview"
    
    // MARK: - 连接管理
    
    /// 连接到OpenAI Realtime API
    /// - Parameter config: 翻译配置（源语言和目标语言）
    func connect(config: TranslationConfig) async throws {
        currentConfig = config
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
        try await Task.sleep(nanoseconds: 500_000_000) // 等待0.5秒确保连接建立
        try await configureSession(config: config)
        
        isConnected = true
        connectionStateSubject.send(.connected)
        print("[RealtimeAPI] 已连接到翻译服务")
    }
    
    /// 配置翻译会话
    /// 发送session.update事件，设置翻译指令和音频格式
    private func configureSession(config: TranslationConfig) async throws {
        // 构建翻译提示词
        // 这是控制翻译质量的核心，指导模型如何进行翻译
        let translationPrompt = buildTranslationPrompt(config: config)
        
        // 会话配置事件
        let sessionConfig: [String: Any] = [
            "type": "session.update",
            "session": [
                // 使用模型的音频能力
                "modalities": ["text", "audio"],
                // 翻译指令
                "instructions": translationPrompt,
                // 输入音频格式：PCM16
                "input_audio_format": "pcm16",
                // 输出音频格式：PCM16
                "output_audio_format": "pcm16",
                // 输出语音：选择自然的声音
                "voice": "shimmer",
                // 启用服务端VAD（语音活动检测）
                // 这样API会自动检测用户何时开始和停止说话
                "turn_detection": [
                    "type": "server_vad",
                    "threshold": 0.5,           // VAD灵敏度阈值
                    "prefix_padding_ms": 300,    // 语音开始前的填充时间
                    "silence_duration_ms": 500   // 静音多久后认为说话结束
                ],
                // 启用输入音频转录（用于显示原文字幕）
                "input_audio_transcription": [
                    "model": "whisper-1"
                ]
            ]
        ]
        
        try await sendJSON(sessionConfig)
        print("[RealtimeAPI] 会话配置已发送")
    }
    
    /// 构建翻译提示词
    /// 这是产品差异化的关键 - 高质量、自然的翻译指令
    private func buildTranslationPrompt(config: TranslationConfig) -> String {
        return """
        You are a real-time language translator. Your ONLY job is to translate speech.
        
        CRITICAL RULES:
        1. You are translating FROM \(config.sourceLanguage.englishName) TO \(config.targetLanguage.englishName).
        2. ONLY output the translation. Do NOT add any commentary, explanation, or response to the content.
        3. Preserve the speaker's tone, emotion, and intent as much as possible.
        4. If the speech is a question, translate it as a question. If it's a statement, translate it as a statement.
        5. For proper nouns (names, places, brands), keep them in their original form or use the standard translation in \(config.targetLanguage.englishName).
        6. If you cannot understand the speech clearly, translate what you can and indicate uncertainty naturally.
        7. Translate naturally and idiomatically - avoid word-for-word literal translation.
        8. Match the formality level of the original speech.
        
        You are like a professional simultaneous interpreter. Just translate, nothing else.
        """
    }
    
    // MARK: - 音频数据传输
    
    /// 发送音频数据到API
    /// - Parameter data: PCM16格式的音频数据
    func sendAudio(data: Data) {
        guard isConnected else { return }
        
        // 将音频数据编码为Base64
        let base64Audio = data.base64EncodedString()
        
        // 构建音频追加事件
        let audioEvent: [String: Any] = [
            "type": "input_audio_buffer.append",
            "audio": base64Audio
        ]
        
        // 异步发送
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
                // 继续接收下一条消息
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
        // 会话创建成功
        case "session.created":
            print("[RealtimeAPI] 会话已创建")
            
        // 会话配置更新成功
        case "session.updated":
            print("[RealtimeAPI] 会话配置已更新")
            
        // 收到翻译后的音频数据块
        case "response.audio.delta":
            if let delta = json["delta"] as? String,
               let audioData = Data(base64Encoded: delta) {
                translatedAudioSubject.send(audioData)
            }
            connectionStateSubject.send(.translating)
            
        // 翻译后的音频文本（字幕）
        case "response.audio_transcript.delta":
            if let delta = json["delta"] as? String {
                translatedTextSubject.send(delta)
            }
            
        // 翻译完成的完整文本
        case "response.audio_transcript.done":
            if let transcript = json["transcript"] as? String {
                print("[RealtimeAPI] 翻译完成: \(transcript)")
            }
            connectionStateSubject.send(.connected)
            
        // 输入音频的转录结果（原文字幕）
        case "conversation.item.input_audio_transcription.completed":
            if let transcript = json["transcript"] as? String {
                transcriptSubject.send(transcript)
                print("[RealtimeAPI] 原文转录: \(transcript)")
            }
            
        // 语音活动检测：检测到说话开始
        case "input_audio_buffer.speech_started":
            print("[RealtimeAPI] 检测到语音输入")
            connectionStateSubject.send(.translating)
            
        // 语音活动检测：检测到说话结束
        case "input_audio_buffer.speech_stopped":
            print("[RealtimeAPI] 语音输入结束")
            
        // 响应完成
        case "response.done":
            connectionStateSubject.send(.connected)
            
        // 错误处理
        case "error":
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("[RealtimeAPI] API错误: \(message)")
                connectionStateSubject.send(.error(message))
            }
            
        default:
            // 其他事件类型，仅记录日志
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
    /// 优先从UserDefaults读取用户配置的密钥
    /// 也支持从环境变量读取（开发调试用）
    private func getAPIKey() -> String? {
        // 优先从UserDefaults获取（用户在设置页面配置的）
        if let key = UserDefaults.standard.string(forKey: "openai_api_key"), !key.isEmpty {
            return key
        }
        // 其次从环境变量获取（开发调试用）
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
