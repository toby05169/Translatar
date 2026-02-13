// TranslationViewModel.swift
// Translatar - AI实时翻译耳机应用
//
// 核心ViewModel
// 连接音频捕获、翻译服务和UI界面的桥梁
// 管理整个翻译流程的状态和生命周期

import Foundation
import Combine
import SwiftUI

/// 翻译核心ViewModel
/// 使用 @MainActor 确保所有UI相关的状态更新都在主线程执行
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
    
    // MARK: - 服务层
    
    /// 音频捕获服务
    private let audioCaptureService: AudioCaptureService
    /// 翻译服务
    private let translationService: RealtimeTranslationService
    /// 音频播放服务
    private let audioPlaybackService: AudioPlaybackService
    
    /// Combine订阅管理
    private var cancellables = Set<AnyCancellable>()
    
    /// 累积的翻译文本（用于逐字拼接显示）
    private var accumulatedTranslatedText = ""
    /// 累积的转录文本
    private var accumulatedTranscript = ""
    
    // MARK: - 初始化
    
    init() {
        self.audioCaptureService = AudioCaptureService()
        self.translationService = RealtimeTranslationService()
        self.audioPlaybackService = AudioPlaybackService()
        
        // 从UserDefaults恢复API密钥
        self.apiKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
        
        // 设置数据绑定
        setupBindings()
    }
    
    /// 设置服务层与UI层之间的数据绑定
    private func setupBindings() {
        // 绑定音频数据流：音频捕获 → 翻译服务
        audioCaptureService.audioDataPublisher
            .sink { [weak self] audioData in
                self?.translationService.sendAudio(data: audioData)
            }
            .store(in: &cancellables)
        
        // 绑定翻译音频流：翻译服务 → 音频播放
        translationService.translatedAudioPublisher
            .sink { [weak self] audioData in
                self?.audioPlaybackService.enqueueAudio(data: audioData)
            }
            .store(in: &cancellables)
        
        // 绑定翻译文本流：翻译服务 → UI显示
        translationService.translatedTextPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self = self else { return }
                self.accumulatedTranslatedText += text
                self.currentTranslatedText = self.accumulatedTranslatedText
            }
            .store(in: &cancellables)
        
        // 绑定原文转录流：翻译服务 → UI显示
        translationService.transcriptPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self = self else { return }
                // 收到完整转录时，保存到历史记录并重置累积文本
                self.currentTranscript = text
                
                // 如果有翻译文本，创建历史记录条目
                if !self.accumulatedTranslatedText.isEmpty {
                    let entry = TranslationEntry(
                        timestamp: Date(),
                        originalText: text,
                        translatedText: self.accumulatedTranslatedText,
                        sourceLanguage: self.config.sourceLanguage,
                        targetLanguage: self.config.targetLanguage
                    )
                    self.translationHistory.insert(entry, at: 0)
                    
                    // 限制历史记录数量
                    if self.translationHistory.count > 50 {
                        self.translationHistory.removeLast()
                    }
                }
                
                // 重置累积文本，准备接收下一段翻译
                self.accumulatedTranslatedText = ""
            }
            .store(in: &cancellables)
        
        // 绑定连接状态流
        translationService.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = state
            }
            .store(in: &cancellables)
        
        // 绑定音频电平流
        audioCaptureService.audioLevelPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.audioLevel = level
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 用户操作
    
    /// 开始翻译
    /// 这是用户点击"开始翻译"按钮时调用的方法
    func startTranslation() {
        // 检查API密钥是否已配置
        guard !apiKey.isEmpty else {
            errorMessage = "请先在设置中配置您的OpenAI API密钥"
            showError = true
            showSettings = true
            return
        }
        
        // 保存API密钥到UserDefaults
        UserDefaults.standard.set(apiKey, forKey: "openai_api_key")
        
        // 重置状态
        currentTranslatedText = ""
        currentTranscript = ""
        accumulatedTranslatedText = ""
        accumulatedTranscript = ""
        
        Task {
            do {
                // 第一步：连接翻译服务
                try await translationService.connect(config: config)
                
                // 第二步：启动音频捕获
                try audioCaptureService.startCapture()
                
                print("[ViewModel] 翻译已启动: \(config.sourceLanguage.displayName) → \(config.targetLanguage.displayName)")
                
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                connectionState = .error(error.localizedDescription)
                print("[ViewModel] 启动翻译失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 停止翻译
    func stopTranslation() {
        audioCaptureService.stopCapture()
        translationService.disconnect()
        audioPlaybackService.stopPlayback()
        connectionState = .disconnected
        audioLevel = 0.0
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
    
    /// 交换源语言和目标语言
    func swapLanguages() {
        let temp = config.sourceLanguage
        config.sourceLanguage = config.targetLanguage
        config.targetLanguage = temp
        
        // 如果正在翻译中，需要重新连接
        if connectionState.isActive {
            stopTranslation()
            // 短暂延迟后重新启动
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
}
