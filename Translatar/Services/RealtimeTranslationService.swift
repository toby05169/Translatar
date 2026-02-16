// RealtimeTranslationService.swift
// Translatar - AI实时翻译耳机应用
//
// Gemini Live API 翻译服务（v13 - 移除同声传译模式）
//
// v13 修改说明（2026-02-15）：
// 【核心改动：移除同声传译（Immersive）模式】
// - 移除所有同声传译相关逻辑（定时分段、activityStart/End、静音帧等）
// - 仅保留对话模式和户外模式
//
// 保留功能：
// - 上下文窗口压缩（无限时长会话）
// - 会话恢复机制（10分钟连接重置）
// - 双向互译（对话模式）
// - 回声循环防护（对话模式和户外模式）

import Foundation
import Combine

/// 翻译服务协议
protocol RealtimeTranslationServiceProtocol {
    var translatedAudioPublisher: AnyPublisher<Data, Never> { get }
    var translatedTextPublisher: AnyPublisher<String, Never> { get }
    var transcriptPublisher: AnyPublisher<String, Never> { get }
    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> { get }
    
    func connect(config: TranslationConfig, mode: TranslationMode, isPro: Bool) async throws
    func sendAudio(data: Data)
    func disconnect()
}

/// Gemini Live API 翻译服务实现
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
    
    /// 实时转录发布者（边说边出字）
    private let liveTranscriptSubject = PassthroughSubject<String, Never>()
    var liveTranscriptPublisher: AnyPublisher<String, Never> {
        liveTranscriptSubject.eraseToAnyPublisher()
    }
    
    private let connectionStateSubject = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - 属性
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var currentConfig: TranslationConfig?
    private var currentMode: TranslationMode = .conversation
    private var isConnected = false
    private var isSetupComplete = false
    private var isDisconnecting = false
    private var isPro = false
    
    /// Gemini Live API WebSocket 端点
    private let apiBaseURL = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"
    
    /// Gemini 模型名称
    private let geminiModel = "models/gemini-2.5-flash-native-audio-preview-12-2025"
    
    /// 累积的输入转录文本
    private var accumulatedInputTranscript = ""
    /// 累积的输出转录文本
    private var accumulatedOutputTranscript = ""
    
    // MARK: - 回声循环防护
    
    /// 是否正在播放模型输出的音频（此时暂停发送麦克风数据）
    private var isModelOutputting = false
    
    /// 恢复音频发送的延迟任务
    private var resumeAudioTask: Task<Void, Never>?
    
    // MARK: - 会话恢复
    
    /// 上一次的会话恢复句柄（用于重连时恢复会话）
    private var sessionResumptionHandle: String?
    
    // MARK: - 自动重连
    
    private var reconnectCount = 0
    private let maxReconnectAttempts = 5
    private var reconnectTask: Task<Void, Never>?
    
    // MARK: - 连接管理
    
    func connect(config: TranslationConfig, mode: TranslationMode = .conversation, isPro: Bool = false) async throws {
        currentConfig = config
        currentMode = mode
        self.isPro = isPro
        isSetupComplete = false
        isDisconnecting = false
        isModelOutputting = false
        reconnectCount = 0
        sessionResumptionHandle = nil
        
        try await establishConnection(config: config, mode: mode)
    }
    
    private func establishConnection(config: TranslationConfig, mode: TranslationMode) async throws {
        connectionStateSubject.send(.connecting)
        
        guard let apiKey = getAPIKey() else {
            connectionStateSubject.send(.error(NSLocalizedString("error.noApiKey.short", comment: "")))
            throw TranslationError.missingAPIKey
        }
        
        guard let url = URL(string: "\(apiBaseURL)?key=\(apiKey)") else {
            throw TranslationError.invalidURL
        }
        
        let request = URLRequest(url: url)
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.urlSession = session
        self.webSocketTask = session.webSocketTask(with: request)
        
        webSocketTask?.resume()
        startReceivingMessages()
        
        try await Task.sleep(nanoseconds: 500_000_000)
        try await sendSetupMessage(config: config, mode: mode)
        
        for _ in 0..<50 {
            if isSetupComplete { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        if !isSetupComplete {
            print("[GeminiAPI] 警告: 未收到 setupComplete，但继续尝试")
        }
        
        isConnected = true
        connectionStateSubject.send(.connected)
        
        print("[GeminiAPI] 已连接 - \(config.sourceLanguage.englishName) ↔ \(config.targetLanguage.englishName) (双向互译)")
    }
    
    // MARK: - Setup 消息
    
    private func sendSetupMessage(config: TranslationConfig, mode: TranslationMode) async throws {
        let translationPrompt = buildTranslationPrompt(config: config, mode: mode)
        let vadConfig = buildVADConfig(mode: mode)
        
        var setupContent: [String: Any] = [
            "model": geminiModel,
            "generationConfig": [
                "responseModalities": ["AUDIO"],
                "temperature": 0.0,
                "thinkingConfig": [
                    "thinkingBudget": 0
                ],
                "speechConfig": [
                    "voiceConfig": [
                        "prebuiltVoiceConfig": [
                            "voiceName": "Kore"
                        ]
                    ]
                ]
            ] as [String: Any],
            "systemInstruction": [
                "parts": [
                    ["text": translationPrompt]
                ]
            ],
            "realtimeInputConfig": [
                "automaticActivityDetection": vadConfig
            ],
            "inputAudioTranscription": [String: Any](),
            "outputAudioTranscription": [String: Any]()
        ]
        
        // 上下文窗口压缩（启用滑动窗口，允许无限时长会话）
        setupContent["contextWindowCompression"] = [
            "slidingWindow": [String: Any]()
        ]
        
        // 会话恢复（处理10分钟连接重置）
        var sessionResumptionConfig: [String: Any] = [String: Any]()
        if let handle = sessionResumptionHandle {
            sessionResumptionConfig["handle"] = handle
            print("[GeminiAPI] 使用会话恢复句柄重连")
        }
        setupContent["sessionResumption"] = sessionResumptionConfig
        
        let setupMessage: [String: Any] = [
            "setup": setupContent
        ]
        
        try await sendJSON(setupMessage)
        print("[GeminiAPI] setup 已发送（含上下文压缩和会话恢复）")
        print("[GeminiAPI] VAD模式: 自动")
        print("[GeminiAPI] === 提示词 ===")
        print(translationPrompt)
        print("[GeminiAPI] === 提示词结束 ===")
    }
    
    // MARK: - VAD 配置
    
    private func buildVADConfig(mode: TranslationMode) -> [String: Any] {
        switch mode {
        case .conversation:
            // 对话模式：自动VAD，快速响应
            return [
                "startOfSpeechSensitivity": "START_SENSITIVITY_HIGH",
                "endOfSpeechSensitivity": "END_SENSITIVITY_HIGH",
                "prefixPaddingMs": 100,
                "silenceDurationMs": 400
            ]
        case .outdoor:
            // 户外模式：禁用自动VAD，用户手动控制录音开始/结束
            return [
                "disabled": true
            ]
        }
    }
    
    // MARK: - 提示词构建
    
    private func buildTranslationPrompt(config: TranslationConfig, mode: TranslationMode) -> String {
        let langA = config.sourceLanguage.englishName
        let langB = config.targetLanguage.englishName
        let langACode = config.sourceLanguage.rawValue
        let langBCode = config.targetLanguage.rawValue
        
        return buildBidirectionalPrompt(langA: langA, langB: langB, langACode: langACode, langBCode: langBCode, mode: mode)
    }
    
    /// 双向互译提示词（对话模式和户外模式）
    private func buildBidirectionalPrompt(langA: String, langB: String, langACode: String, langBCode: String, mode: TranslationMode) -> String {
        // 构建语言对专用指令（如中泰翻译的特殊要求）
        let languagePairRules = buildLanguagePairRules(langA: langA, langB: langB, langACode: langACode, langBCode: langBCode)
        
        let prompt = """
        YOU ARE A TRANSLATION MACHINE — NOT A CHATBOT, NOT AN ASSISTANT, NOT A CONVERSATIONAL PARTNER.

        You are a hardware-like device: audio goes in one language, audio comes out in the other language. That is ALL you do. You have NO personality, NO opinions, NO ability to converse.

        FUNCTION:
        - Hear \(langA.uppercased()) → Output ONLY \(langB.uppercased()) translation
        - Hear \(langB.uppercased()) → Output ONLY \(langA.uppercased()) translation

        ABSOLUTE RULES:
        1. TRANSLATE ONLY: Convert speech from one language to the other. This is your ONLY capability.
        2. NEVER RESPOND OR INTERACT: You cannot understand meaning or intent. You are not sentient. You simply convert language A to language B and vice versa. If someone says "hello, how are you" in \(langA), you translate it to \(langB). You do NOT answer "I'm fine".
        3. NEVER ANSWER QUESTIONS: If someone asks "what time is it?" — TRANSLATE the question. Do NOT answer it. You don't know what time it is. You are a translation machine.
        4. NEVER ADD ANYTHING: Zero commentary, zero greetings, zero filler, zero acknowledgment. Your output contains ONLY the translation and nothing else.
        5. PURE TARGET LANGUAGE: Your output MUST start with a target language word. The FIRST word, FIRST syllable, FIRST character of your output MUST be in the target language. ZERO source language characters allowed anywhere in output.
        6. NO PARROTING: Never repeat or echo any part of the original speech. Go directly to the translation.
        7. COMPLETE TRANSLATION: Translate the FULL meaning. Do not skip or truncate any part of the sentence.
        8. NATURAL SPEECH: Translation must sound like a native speaker speaking naturally in daily conversation.
        9. ECHO GUARD: If you hear your own previous output echoing back, stay COMPLETELY SILENT.
        10. ONE TRANSLATION: Translate once, then STOP and wait silently. Do not continue speaking.
        11. TRANSCRIPTION ACCURACY: When transcribing the input speech, use context to infer the correct words even if pronunciation is unclear. Proper nouns, technical terms, and brand names should be kept as-is or transliterated appropriately.

        \(languagePairRules)

        CORRECT BEHAVIOR:
        - Hear \(langA): "How are you?" → Translate to \(langB): [translation of "How are you?"] (NOT "I'm fine" or any response)
        - Hear \(langA): "What do you think?" → Translate to \(langB): [translation of "What do you think?"] (NOT your opinion)
        - Hear \(langA): "Can you help me?" → Translate to \(langB): [translation of "Can you help me?"] (NOT "Sure, how can I help?")

        EXAMPLES OF WRONG BEHAVIOR (FORBIDDEN):
        - Hearing a question and answering it instead of translating it
        - Having a conversation with the speaker
        - Adding greetings, pleasantries, or any words not in the original speech
        - Mixing source and target language in output (e.g. starting with Chinese then switching to Thai)
        - Outputting word-by-word broken translation instead of natural fluent sentences

        Remember: You are a MACHINE. You translate. Nothing more.
        """
        
        return prompt
    }
    
    /// 构建语言对专用规则（针对特定语言组合的优化指令）
    private func buildLanguagePairRules(langA: String, langB: String, langACode: String, langBCode: String) -> String {
        let langCodes = Set([langACode, langBCode])
        
        // 中泰翻译专用规则
        if langCodes.contains("zh") && langCodes.contains("th") {
            return """
            CHINESE-THAI SPECIFIC RULES:
            - When translating Chinese to Thai: Output MUST be 100% Thai script (ภาษาไทย). NOT A SINGLE Chinese character (汉字) is allowed in the output.
            - When translating Thai to Chinese: Output MUST be 100% Simplified Chinese (简体中文). NOT A SINGLE Thai character is allowed in the output.
            - Thai output MUST be written as natural connected Thai text WITHOUT extra spaces between words. Thai is written continuously like "สวัสดีครับวันนี้อากาศดีมาก" NOT "สวัสดี ครับ วัน นี้ อากาศ ดี มาก".
            - Translate idiomatically, not word-by-word. Capture the full meaning in natural Thai/Chinese.
            - FORBIDDEN: "如果在 มัน อยู่" (mixing Chinese and Thai)
            - FORBIDDEN: "钥匙 อยู่ที่ประตู" (mixing Chinese and Thai)
            - FORBIDDEN: "สวัสดี ครับ วัน นี้" (spaces between Thai words)
            - CORRECT: "กุญแจอยู่ที่ประตูของคุณ" (pure Thai, no spaces)
            - CORRECT: "钥匙在你的门那里" (pure Chinese)
            """
        }
        
        // 中日翻译专用规则
        if langCodes.contains("zh") && langCodes.contains("ja") {
            return """
            CHINESE-JAPANESE SPECIFIC RULES:
            - When translating Chinese to Japanese: Use natural Japanese with appropriate kanji, hiragana, and katakana.
            - When translating Japanese to Chinese: Output MUST be Simplified Chinese (简体中文).
            - Do NOT confuse Chinese hanzi with Japanese kanji — translate the meaning, not the characters.
            """
        }
        
        // 其他语言对：通用规则
        return """
        LANGUAGE PURITY REMINDER:
        - \(langA) input → 100% \(langB) output (zero \(langA) characters)
        - \(langB) input → 100% \(langA) output (zero \(langB) characters)
        """
    }
    
    // MARK: - 音频数据传输
    
    /// 发送音频数据到 Gemini Live API
    func sendAudio(data: Data) {
        guard isConnected else { return }
        
        // 回声防护：模型输出时暂停发送麦克风数据
        if isModelOutputting { return }
        
        // 户外模式下，只有在手动录音状态时才发送音频
        if currentMode == .outdoor && !isManualRecording { return }
        
        let base64Audio = data.base64EncodedString()
        
        let audioMessage: [String: Any] = [
            "realtimeInput": [
                "audio": [
                    "data": base64Audio,
                    "mimeType": "audio/pcm;rate=16000"
                ]
            ]
        ]
        
        Task {
            try? await sendJSON(audioMessage)
        }
    }
    
    // MARK: - 户外模式手动控制
    
    /// 是否正在手动录音（户外模式专用）
    private var isManualRecording = false
    
    /// 开始手动录音（户外模式：用户按下按钮时调用）
    func startManualRecording() {
        guard isConnected, currentMode == .outdoor else { return }
        isManualRecording = true
        isModelOutputting = false
        resumeAudioTask?.cancel()
        
        let startMessage: [String: Any] = [
            "realtimeInput": [
                "activityStart": [String: Any]()
            ]
        ]
        Task {
            try? await sendJSON(startMessage)
        }
        print("[GeminiAPI] 户外模式：开始手动录音")
    }
    
    /// 停止手动录音（户外模式：用户松开按钮时调用）
    func stopManualRecording() {
        guard currentMode == .outdoor else { return }
        isManualRecording = false
        
        let endMessage: [String: Any] = [
            "realtimeInput": [
                "activityEnd": [String: Any]()
            ]
        ]
        Task {
            try? await sendJSON(endMessage)
        }
        print("[GeminiAPI] 户外模式：停止手动录音")
    }
    
    /// 断开连接
    func disconnect() {
        isDisconnecting = true
        isConnected = false
        isSetupComplete = false
        isModelOutputting = false
        isManualRecording = false
        accumulatedInputTranscript = ""
        accumulatedOutputTranscript = ""
        resumeAudioTask?.cancel()
        resumeAudioTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        connectionStateSubject.send(.disconnected)
        print("[GeminiAPI] 已断开连接")
    }
    
    // MARK: - 自动重连（支持会话恢复）
    
    private func attemptReconnect() {
        guard !isDisconnecting,
              reconnectCount < maxReconnectAttempts,
              let config = currentConfig else {
            if reconnectCount >= maxReconnectAttempts {
                print("[GeminiAPI] 已达到最大重连次数(\(maxReconnectAttempts))，停止重连")
                connectionStateSubject.send(.error("连接已断开，请重新开始"))
                sessionResumptionHandle = nil
            }
            return
        }
        
        reconnectCount += 1
        let delay = min(pow(2.0, Double(reconnectCount)), 10.0)
        
        print("[GeminiAPI] 将在 \(delay)s 后第 \(reconnectCount)/\(maxReconnectAttempts) 次重连...")
        if sessionResumptionHandle != nil {
            print("[GeminiAPI] 将使用会话恢复句柄")
        }
        connectionStateSubject.send(.connecting)
        
        reconnectTask = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled, !isDisconnecting else { return }
                
                webSocketTask?.cancel(with: .goingAway, reason: nil)
                webSocketTask = nil
                urlSession?.invalidateAndCancel()
                urlSession = nil
                isSetupComplete = false
                isModelOutputting = false
                
                try await establishConnection(config: config, mode: currentMode)
                reconnectCount = 0
                print("[GeminiAPI] 重连成功！")
            } catch {
                if !Task.isCancelled {
                    print("[GeminiAPI] 重连失败: \(error.localizedDescription)")
                    attemptReconnect()
                }
            }
        }
    }
    
    // MARK: - WebSocket 消息处理
    
    private func startReceivingMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.startReceivingMessages()
            case .failure(let error):
                print("[GeminiAPI] 接收消息错误: \(error.localizedDescription)")
                if !self.isDisconnecting {
                    self.isConnected = false
                    self.connectionStateSubject.send(.error(error.localizedDescription))
                    self.attemptReconnect()
                }
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            handleGeminiMessage(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                handleGeminiMessage(text)
            }
        @unknown default:
            break
        }
    }
    
    private func handleGeminiMessage(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        if json["setupComplete"] != nil {
            isSetupComplete = true
            print("[GeminiAPI] setup 完成，翻译引擎就绪")
            return
        }
        
        // 处理会话恢复更新
        if let sessionResumptionUpdate = json["sessionResumptionUpdate"] as? [String: Any] {
            handleSessionResumptionUpdate(sessionResumptionUpdate)
            return
        }
        
        // 处理GoAway消息（服务器即将断开连接的预警）
        if let goAway = json["goAway"] as? [String: Any] {
            handleGoAway(goAway)
            return
        }
        
        if let serverContent = json["serverContent"] as? [String: Any] {
            handleServerContent(serverContent)
            return
        }
        
        if json["toolCall"] != nil { return }
    }
    
    // MARK: - 会话恢复处理
    
    private func handleSessionResumptionUpdate(_ update: [String: Any]) {
        if let newHandle = update["newHandle"] as? String, !newHandle.isEmpty {
            sessionResumptionHandle = newHandle
            let resumable = update["resumable"] as? Bool ?? false
            print("[GeminiAPI] 收到会话恢复句柄 (可恢复: \(resumable))")
        }
    }
    
    private func handleGoAway(_ goAway: [String: Any]) {
        let timeLeft = goAway["timeLeft"] as? String ?? "未知"
        print("[GeminiAPI] 收到GoAway消息，剩余时间: \(timeLeft)")
        print("[GeminiAPI] 服务器即将断开连接，准备使用会话恢复重连...")
    }
    
    /// 处理 serverContent 消息
    private func handleServerContent(_ content: [String: Any]) {
        
        // 调试：打印serverContent的所有顶层key
        let contentKeys = content.keys.sorted().joined(separator: ", ")
        print("[GeminiAPI] serverContent keys: [\(contentKeys)]")
        
        // 处理输入转录（实时显示，边说边出字）
        if let inputTranscription = content["inputTranscription"] as? [String: Any],
           let text = inputTranscription["text"] as? String, !text.isEmpty {
            let simplifiedText = convertToSimplifiedChinese(text)
            accumulatedInputTranscript += simplifiedText
            // 实时发送累积的原文，让UI立即更新
            liveTranscriptSubject.send(accumulatedInputTranscript)
            print("[GeminiAPI] 输入转录: \(simplifiedText)")
        }
        
        // 处理输出转录
        if let outputTranscription = content["outputTranscription"] as? [String: Any],
           let text = outputTranscription["text"] as? String, !text.isEmpty {
            // 后处理：清理泰文多余空格、移除混入的源语言字符
            let cleanedText = postProcessTranslation(text)
            accumulatedOutputTranscript += cleanedText
            translatedTextSubject.send(cleanedText)
            print("[GeminiAPI] 输出转录: \(cleanedText)")
        }
        
        // 处理模型输出（音频）
        if let modelTurn = content["modelTurn"] as? [String: Any] {
            let turnKeys = modelTurn.keys.sorted().joined(separator: ", ")
            print("[GeminiAPI] modelTurn keys: [\(turnKeys)]")
            
            if let parts = modelTurn["parts"] as? [[String: Any]] {
                for (idx, part) in parts.enumerated() {
                    let partKeys = part.keys.sorted().joined(separator: ", ")
                    print("[GeminiAPI] part[\(idx)] keys: [\(partKeys)]")
                    
                    if let inlineData = part["inlineData"] as? [String: Any],
                       let base64Data = inlineData["data"] as? String,
                       let audioData = Data(base64Encoded: base64Data) {
                        
                        print("[GeminiAPI] 收到音频: \(audioData.count)字节")
                        
                        // 回声防护
                        if !isModelOutputting {
                            isModelOutputting = true
                            resumeAudioTask?.cancel()
                            print("[GeminiAPI] 模型输出中，暂停麦克风")
                        }
                        
                        translatedAudioSubject.send(audioData)
                        connectionStateSubject.send(.translating)
                    }
                    
                    if let text = part["text"] as? String, !text.isEmpty {
                        translatedTextSubject.send(text)
                        accumulatedOutputTranscript += text
                    }
                }
            } else {
                print("[GeminiAPI] modelTurn 没有 parts")
            }
        }
        
        // 处理被打断
        if let interrupted = content["interrupted"] as? Bool, interrupted {
            print("[GeminiAPI] 翻译被打断")
            isModelOutputting = false
            resumeAudioTask?.cancel()
            connectionStateSubject.send(.connected)
        }
        
        // 处理回合结束
        if let turnComplete = content["turnComplete"] as? Bool, turnComplete {
            print("[GeminiAPI] 回合结束")
            
            if !accumulatedInputTranscript.isEmpty {
                transcriptSubject.send(accumulatedInputTranscript)
                print("[GeminiAPI] 原文: \(accumulatedInputTranscript)")
            }
            if !accumulatedOutputTranscript.isEmpty {
                print("[GeminiAPI] 译文: \(accumulatedOutputTranscript)")
            }
            
            accumulatedInputTranscript = ""
            accumulatedOutputTranscript = ""
            
            // 回声防护恢复逻辑
            resumeAudioTask?.cancel()
            resumeAudioTask = Task {
                do {
                    try await Task.sleep(nanoseconds: 800_000_000)
                    guard !Task.isCancelled else { return }
                    self.isModelOutputting = false
                    print("[GeminiAPI] 恢复麦克风")
                } catch {}
            }
            
            connectionStateSubject.send(.connected)
        }
    }
    
    // MARK: - 工具方法
    
    /// 翻译输出后处理：清理泰文多余空格、移除混入的源语言字符
    private func postProcessTranslation(_ text: String) -> String {
        guard let config = currentConfig else { return text }
        var result = text
        
        let langCodes = Set([config.sourceLanguage.rawValue, config.targetLanguage.rawValue])
        
        // 中泰翻译专用后处理
        if langCodes.contains("zh") && langCodes.contains("th") {
            // 检测输出主要是泰文还是中文
            let thaiCount = result.unicodeScalars.filter { isThai($0) }.count
            let cjkCount = result.unicodeScalars.filter { isCJK($0) }.count
            
            if thaiCount > cjkCount {
                // 输出主要是泰文：移除混入的中文字符，清理泰文词间多余空格
                result = String(result.unicodeScalars.filter { !isCJK($0) })
                // 清理泰文字符之间的多余空格（保留数字、英文之间的空格）
                result = cleanThaiSpaces(result)
            } else if cjkCount > thaiCount {
                // 输出主要是中文：移除混入的泰文字符
                result = String(result.unicodeScalars.filter { !isThai($0) })
                // 确保输出是简体中文
                result = convertToSimplifiedChinese(result)
            }
        }
        
        // 清理多余空格（连续多个空格变一个）
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        result = result.trimmingCharacters(in: .whitespaces)
        
        return result
    }
    
    /// 清理泰文文本中的多余空格
    /// 泰文是连写文字，词与词之间不加空格
    private func cleanThaiSpaces(_ text: String) -> String {
        var result = ""
        let chars = Array(text)
        
        for i in 0..<chars.count {
            let char = chars[i]
            if char == " " {
                // 检查空格前后是否都是泰文字符，如果是则跳过空格
                let prevIsThai = i > 0 && chars[i-1].unicodeScalars.allSatisfy { isThai($0) }
                let nextIsThai = i < chars.count - 1 && chars[i+1].unicodeScalars.allSatisfy { isThai($0) }
                if prevIsThai && nextIsThai {
                    continue // 跳过泰文词间空格
                }
                // 检查空格前是泰文、后是标点，或前是标点、后是泰文
                let prevIsThaiOrPunct = i > 0 && (chars[i-1].unicodeScalars.allSatisfy { isThai($0) } || chars[i-1].isPunctuation)
                let nextIsThaiOrPunct = i < chars.count - 1 && (chars[i+1].unicodeScalars.allSatisfy { isThai($0) } || chars[i+1].isPunctuation)
                if prevIsThaiOrPunct && nextIsThaiOrPunct {
                    continue
                }
            }
            result.append(char)
        }
        return result
    }
    
    /// 判断是否是泰文字符 (U+0E00 ~ U+0E7F)
    private func isThai(_ scalar: Unicode.Scalar) -> Bool {
        return scalar.value >= 0x0E00 && scalar.value <= 0x0E7F
    }
    
    /// 判断是否是CJK中文字符
    private func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        return (v >= 0x4E00 && v <= 0x9FFF) ||   // CJK统一汉字
               (v >= 0x3400 && v <= 0x4DBF) ||   // CJK扩展A
               (v >= 0xF900 && v <= 0xFAFF)      // CJK兼容汉字
    }
    
    /// 繁体中文转简体中文（使用iOS内置CFStringTransform）
    private func convertToSimplifiedChinese(_ text: String) -> String {
        let mutableString = NSMutableString(string: text)
        CFStringTransform(mutableString, nil, "Traditional-Simplified" as CFString, false)
        return mutableString as String
    }
    
    private func sendJSON(_ dict: [String: Any]) async throws {
        guard let task = webSocketTask else {
            print("[GeminiAPI] Socket未连接")
            return
        }
        
        let data = try JSONSerialization.data(withJSONObject: dict)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw TranslationError.encodingFailed
        }
        if dict["setup"] != nil {
            print("[GeminiAPI] 发送 setup: \(jsonString.prefix(500))...")
        }
        try await task.send(.string(jsonString))
    }
    
    private func getAPIKey() -> String? {
        if let key = UserDefaults.standard.string(forKey: "gemini_api_key"), !key.isEmpty {
            return key
        }
        if let key = UserDefaults.standard.string(forKey: "openai_api_key"), !key.isEmpty {
            return key
        }
        if let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !key.isEmpty {
            return key
        }
        return nil
    }
    
    deinit {
        disconnect()
    }
}

// MARK: - URLSessionWebSocketDelegate

extension RealtimeTranslationService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("[GeminiAPI] WebSocket 连接已打开")
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonStr = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "无"
        print("[GeminiAPI] WebSocket 关闭，代码: \(closeCode.rawValue), 原因: \(reasonStr)")
        
        if !isDisconnecting && isConnected {
            if sessionResumptionHandle != nil {
                print("[GeminiAPI] 连接重置（可能是10分钟限制），使用会话恢复重连...")
            } else {
                print("[GeminiAPI] 意外断连，准备重连...")
            }
            isConnected = false
            attemptReconnect()
        } else {
            connectionStateSubject.send(.disconnected)
        }
    }
}

// MARK: - 错误定义

enum TranslationError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case connectionFailed
    case encodingFailed
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return NSLocalizedString("error.noApiKey", comment: "")
        case .invalidURL:
            return NSLocalizedString("error.invalidUrl", comment: "")
        case .connectionFailed:
            return NSLocalizedString("error.connectionFailed", comment: "")
        case .encodingFailed:
            return NSLocalizedString("error.encodingFailed", comment: "")
        }
    }
}
