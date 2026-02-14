// TranslationViewModel.swift
// Translatar - AI实时翻译耳机应用
//
// 核心ViewModel（第二阶段增强版）
// 连接音频捕获、翻译服务和UI界面的桥梁
// 管理整个翻译流程的状态和生命周期
//
// 第二阶段新增能力：
// - 翻译模式切换（对话模式/沉浸模式）
// - AI降噪开关控制
// - 离线翻译自动切换（网络断开时自动降级）
// - 网络状态监测

import Foundation
import Combine
import SwiftUI

/// 翻译核心ViewModel
@MainActor
class TranslationViewModel: ObservableObject {
    
    // MARK: - UI绑定的状态属性
    
    /// 当前连接状态
    @Published var connectionState: ConnectionState = .disconnected
    /// 当前翻译模式
    @Published var translationMode: TranslationMode = .conversation
    /// 翻译配置（源语言和目标语言）
    @Published var config: TranslationConfig = .defaultConfig
    /// 实时翻译文本（逐字显示）
    @Published var currentTranslatedText: String = ""
    /// 原始语音转录文本
    @Published var currentTranscript: String = ""
    /// 翻译历史记录
    @Published var translationHistory: [TranslationEntry] = []
    /// 当前音频电平（用于波形动画）
    @Published var audioLevel: Float = 0.0
    /// 是否显示设置页面
    @Published var showSettings: Bool = false
    /// API密钥（用户在设置中输入）
    @Published var apiKey: String = ""
    /// 错误提示信息
    @Published var errorMessage: String?
    /// 是否显示错误提示
    @Published var showError: Bool = false
    
    // ---- 第二阶段新增状态 ----
    
    /// AI降噪是否启用
    @Published var isNoiseSuppressionEnabled: Bool = true
    /// 是否处于离线模式
    @Published var isOfflineMode: Bool = false
    /// 网络是否连接
    @Published var isNetworkConnected: Bool = true
    /// 离线翻译服务状态
    @Published var offlineState: OfflineServiceState = .idle
    /// 是否自动切换离线模式（网络断开时自动切换）
    @Published var autoOfflineSwitch: Bool = true
    
    // MARK: - 服务层
    
    /// 音频捕获服务
    private let audioCaptureService: AudioCaptureService
    /// 在线翻译服务（OpenAI Realtime API）
    private let translationService: RealtimeTranslationService
    /// 音频播放服务
    private let audioPlaybackService: AudioPlaybackService
    /// 离线翻译服务（Apple原生框架）
    private let offlineTranslationService: OfflineTranslationService
    /// 网络状态监测
    private let networkMonitor: NetworkMonitor
    
    /// Combine订阅管理
    private var cancellables = Set<AnyCancellable>()
    
    /// 累积的翻译文本
    private var accumulatedTranslatedText = ""
    /// 累积的转录文本
    private var accumulatedTranscript = ""
    
    // MARK: - 初始化
    
    init() {
        self.audioCaptureService = AudioCaptureService()
        self.translationService = RealtimeTranslationService()
        self.audioPlaybackService = AudioPlaybackService()
        self.offlineTranslationService = OfflineTranslationService()
        self.networkMonitor = NetworkMonitor()
        
        // 从UserDefaults恢复设置
        self.apiKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
        self.isNoiseSuppressionEnabled = UserDefaults.standard.object(forKey: "noise_suppression") as? Bool ?? true
        self.autoOfflineSwitch = UserDefaults.standard.object(forKey: "auto_offline_switch") as? Bool ?? true
        
        // 恢复上次使用的翻译模式
        if let modeRaw = UserDefaults.standard.string(forKey: "translation_mode"),
           let mode = TranslationMode(rawValue: modeRaw) {
            self.translationMode = mode
        }
        
        // 设置数据绑定
        setupBindings()
        setupNetworkMonitoring()
    }
    
    /// 设置服务层与UI层之间的数据绑定
    private func setupBindings() {
        // ---- 在线翻译数据流 ----
        
        // 音频捕获 → 翻译服务
        audioCaptureService.audioDataPublisher
            .sink { [weak self] audioData in
                guard let self = self, !self.isOfflineMode else { return }
                self.translationService.sendAudio(data: audioData)
            }
            .store(in: &cancellables)
        
        // 翻译音频 → 播放
        translationService.translatedAudioPublisher
            .sink { [weak self] audioData in
                self?.audioPlaybackService.enqueueAudio(data: audioData)
            }
            .store(in: &cancellables)
        
        // 翻译文本 → UI
        translationService.translatedTextPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self = self else { return }
                self.accumulatedTranslatedText += text
                self.currentTranslatedText = self.accumulatedTranslatedText
            }
            .store(in: &cancellables)
        
        // 原文转录 → UI + 历史记录
        translationService.transcriptPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self = self else { return }
                self.currentTranscript = text
                self.addHistoryEntry(original: text, translated: self.accumulatedTranslatedText)
                self.accumulatedTranslatedText = ""
            }
            .store(in: &cancellables)
        
        // 连接状态 → UI
        translationService.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self, !self.isOfflineMode else { return }
                self.connectionState = state
            }
            .store(in: &cancellables)
        
        // 音频电平 → UI
        audioCaptureService.audioLevelPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.audioLevel = level
            }
            .store(in: &cancellables)
        
        // ---- 离线翻译数据流 ----
        
        // 离线翻译文本 → UI
        offlineTranslationService.translatedTextPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self = self, self.isOfflineMode else { return }
                self.currentTranslatedText = text
            }
            .store(in: &cancellables)
        
        // 离线转录 → UI
        offlineTranslationService.transcriptPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self = self, self.isOfflineMode else { return }
                self.currentTranscript = text
            }
            .store(in: &cancellables)
        
        // 离线状态 → UI
        offlineTranslationService.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.offlineState = state
            }
            .store(in: &cancellables)
    }
    
    /// 设置网络状态监测
    private func setupNetworkMonitoring() {
        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                guard let self = self else { return }
                self.isNetworkConnected = connected
                
                // 自动切换离线模式
                if self.autoOfflineSwitch && self.connectionState.isActive {
                    if !connected && !self.isOfflineMode {
                        print("[ViewModel] 网络断开，自动切换到离线模式")
                        self.switchToOfflineMode()
                    } else if connected && self.isOfflineMode {
                        print("[ViewModel] 网络恢复，自动切换到在线模式")
                        self.switchToOnlineMode()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 用户操作
    
    /// 开始翻译
    func startTranslation() {
        // 检查是否需要使用离线模式
        if !isNetworkConnected || isOfflineMode {
            startOfflineTranslation()
            return
        }
        
        // 在线模式：检查API密钥
        guard !apiKey.isEmpty else {
            errorMessage = NSLocalizedString("error.noApiKey", comment: "")
            showError = true
            showSettings = true
            return
        }
        
        // 保存API密钥
        UserDefaults.standard.set(apiKey, forKey: "openai_api_key")
        
        // 重置状态
        resetState()
        
        Task {
            do {
                // 连接翻译服务（传入当前模式）
                try await translationService.connect(config: config, mode: translationMode)
                
                // 启动音频捕获（传入模式和降噪设置）
                try audioCaptureService.startCapture(
                    mode: translationMode,
                    noiseSuppression: isNoiseSuppressionEnabled
                )
                
                print("[ViewModel] 在线翻译已启动: \(config.sourceLanguage.displayName) → \(config.targetLanguage.displayName), 模式: \(translationMode.displayName)")
                
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                connectionState = .error(error.localizedDescription)
            }
        }
    }
    
    /// 启动离线翻译
    private func startOfflineTranslation() {
        // 检查离线翻译可用性
        guard offlineTranslationService.checkAvailability(
            source: config.sourceLanguage,
            target: config.targetLanguage
        ) else {
            errorMessage = NSLocalizedString("error.offlineUnavailable", comment: "")
            showError = true
            return
        }
        
        isOfflineMode = true
        resetState()
        connectionState = .connected
        
        // 离线模式不需要AudioCaptureService的tap，
        // OfflineTranslationService会自己管理音频输入
        // 但我们仍然需要配置音频会话
        do {
            try audioCaptureService.startCapture(
                mode: translationMode,
                noiseSuppression: isNoiseSuppressionEnabled
            )
            // 注意：离线翻译服务需要共享audioEngine，这里简化处理
            // 在实际实现中，可能需要更精细的音频路由管理
            print("[ViewModel] 离线翻译已启动")
        } catch {
            errorMessage = "启动音频捕获失败: \(error.localizedDescription)"
            showError = true
        }
    }
    
    /// 停止翻译
    func stopTranslation() {
        audioCaptureService.stopCapture()
        translationService.disconnect()
        audioPlaybackService.stopPlayback()
        offlineTranslationService.stop()
        
        connectionState = .disconnected
        audioLevel = 0.0
        isOfflineMode = false
        print("[ViewModel] 翻译已停止")
    }
    
    /// 切换翻译状态（开始/停止）
    func toggleTranslation() {
        if connectionState.isActive {
            stopTranslation()
        } else {
            startTranslation()
        }
    }
    
    /// 切换翻译模式
    func switchMode(_ mode: TranslationMode) {
        let wasActive = connectionState.isActive
        
        if wasActive {
            stopTranslation()
        }
        
        translationMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "translation_mode")
        
        if wasActive {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.startTranslation()
            }
        }
    }
    
    /// 切换降噪开关
    func toggleNoiseSuppression() {
        isNoiseSuppressionEnabled.toggle()
        UserDefaults.standard.set(isNoiseSuppressionEnabled, forKey: "noise_suppression")
        
        // 如果正在录制，动态切换降噪
        if audioCaptureService.isRecording {
            audioCaptureService.setNoiseSuppression(enabled: isNoiseSuppressionEnabled)
        }
    }
    
    /// 切换到离线模式
    private func switchToOfflineMode() {
        let wasActive = connectionState.isActive
        if wasActive {
            translationService.disconnect()
        }
        isOfflineMode = true
        if wasActive {
            startOfflineTranslation()
        }
    }
    
    /// 切换到在线模式
    private func switchToOnlineMode() {
        offlineTranslationService.stop()
        isOfflineMode = false
        
        if connectionState.isActive || offlineState == .listening {
            stopTranslation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.startTranslation()
            }
        }
    }
    
    /// 交换源语言和目标语言
    func swapLanguages() {
        let temp = config.sourceLanguage
        config.sourceLanguage = config.targetLanguage
        config.targetLanguage = temp
        
        if connectionState.isActive {
            stopTranslation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.startTranslation()
            }
        }
    }
    
    /// 清空翻译历史
    func clearHistory() {
        translationHistory.removeAll()
        currentTranslatedText = ""
        currentTranscript = ""
    }
    
    /// 保存API密钥
    func saveAPIKey(_ key: String) {
        apiKey = key
        UserDefaults.standard.set(key, forKey: "openai_api_key")
    }
    
    // MARK: - 辅助方法
    
    /// 重置翻译状态
    private func resetState() {
        currentTranslatedText = ""
        currentTranscript = ""
        accumulatedTranslatedText = ""
        accumulatedTranscript = ""
    }
    
    /// 添加翻译历史记录
    private func addHistoryEntry(original: String, translated: String) {
        guard !translated.isEmpty else { return }
        
        let entry = TranslationEntry(
            timestamp: Date(),
            originalText: original,
            translatedText: translated,
            sourceLanguage: config.sourceLanguage,
            targetLanguage: config.targetLanguage
        )
        translationHistory.insert(entry, at: 0)
        
        // 限制历史记录数量
        if translationHistory.count > 100 {
            translationHistory.removeLast()
        }
    }
}
