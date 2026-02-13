// ContentView.swift
// Translatar - AI实时翻译耳机应用
//
// 应用主界面（第二阶段增强版）
// 新增：模式切换、降噪开关、离线状态指示、沉浸模式专属UI

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: TranslationViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景渐变（根据模式变化）
                backgroundGradient
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.5), value: viewModel.translationMode)
                
                VStack(spacing: 0) {
                    // 模式切换标签栏
                    ModeSwitcherView()
                        .padding(.top, 4)
                    
                    // 顶部语言选择区域
                    LanguageSelectorView()
                        .padding(.top, 8)
                    
                    // 状态栏（降噪、离线、网络）
                    StatusBarView()
                        .padding(.top, 8)
                    
                    // 实时翻译显示区域
                    TranslationDisplayView()
                        .padding(.top, 12)
                    
                    Spacer()
                    
                    // 中央控制按钮
                    TranslationControlButton()
                        .padding(.bottom, 16)
                    
                    // 翻译历史列表
                    TranslationHistoryView()
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Text("Translatar")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        // 离线模式标识
                        if viewModel.isOfflineMode {
                            Text("离线")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(Color.orange.opacity(0.2))
                                )
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // 降噪开关
                        Button {
                            viewModel.toggleNoiseSuppression()
                        } label: {
                            Image(systemName: viewModel.isNoiseSuppressionEnabled
                                  ? "waveform.circle.fill"
                                  : "waveform.circle")
                                .foregroundColor(viewModel.isNoiseSuppressionEnabled ? .cyan : .white.opacity(0.4))
                                .font(.title3)
                        }
                        
                        // 设置按钮
                        Button {
                            viewModel.showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showSettings) {
                SettingsView()
                    .environmentObject(viewModel)
            }
            .alert("提示", isPresented: $viewModel.showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "发生未知错误")
            }
        }
        .preferredColorScheme(.dark)
    }
    
    /// 根据翻译模式切换背景渐变
    private var backgroundGradient: some View {
        Group {
            switch viewModel.translationMode {
            case .conversation:
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "0F0F1A"),
                        Color(hex: "1A1A2E"),
                        Color(hex: "16213E")
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            case .immersive:
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "0A1628"),
                        Color(hex: "0D2137"),
                        Color(hex: "0F2B46")
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
}

// MARK: - 模式切换器

struct ModeSwitcherView: View {
    @EnvironmentObject var viewModel: TranslationViewModel
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(TranslationMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.switchMode(mode)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.iconName)
                            .font(.subheadline)
                        Text(mode.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(viewModel.translationMode == mode ? .white : .white.opacity(0.4))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(viewModel.translationMode == mode
                                  ? (mode == .immersive ? Color.indigo.opacity(0.5) : Color.cyan.opacity(0.3))
                                  : Color.clear)
                    )
                }
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
        )
    }
}

// MARK: - 状态栏

struct StatusBarView: View {
    @EnvironmentObject var viewModel: TranslationViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // 网络状态
            StatusChip(
                icon: viewModel.isNetworkConnected ? "wifi" : "wifi.slash",
                text: viewModel.isNetworkConnected ? "在线" : "离线",
                color: viewModel.isNetworkConnected ? .green : .orange
            )
            
            // 降噪状态
            StatusChip(
                icon: "waveform.badge.minus",
                text: viewModel.isNoiseSuppressionEnabled ? "降噪开" : "降噪关",
                color: viewModel.isNoiseSuppressionEnabled ? .cyan : .gray
            )
            
            // 模式说明
            StatusChip(
                icon: viewModel.translationMode.iconName,
                text: viewModel.translationMode == .immersive ? "环境监听" : "对话翻译",
                color: viewModel.translationMode == .immersive ? .indigo : .cyan
            )
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

/// 状态标签组件
struct StatusChip: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 10))
        }
        .foregroundColor(color.opacity(0.8))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - 语言选择器

struct LanguageSelectorView: View {
    @EnvironmentObject var viewModel: TranslationViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            LanguagePickerButton(
                label: "对方说",
                language: $viewModel.config.sourceLanguage
            )
            
            Button {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.swapLanguages()
                }
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.title3)
                    .foregroundColor(.cyan)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(Color.cyan.opacity(0.15))
                    )
            }
            
            LanguagePickerButton(
                label: "翻译成",
                language: $viewModel.config.targetLanguage
            )
        }
        .padding(.horizontal, 20)
    }
}

struct LanguagePickerButton: View {
    let label: String
    @Binding var language: SupportedLanguage
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
            
            Menu {
                ForEach(SupportedLanguage.allCases) { lang in
                    Button {
                        language = lang
                    } label: {
                        HStack {
                            Text(lang.flag)
                            Text(lang.chineseName)
                            if lang == language {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(language.flag)
                        .font(.title2)
                    Text(language.chineseName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 翻译显示区域

struct TranslationDisplayView: View {
    @EnvironmentObject var viewModel: TranslationViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            // 状态指示器
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                
                // 沉浸模式下显示持续监听提示
                if viewModel.translationMode == .immersive && viewModel.connectionState.isActive {
                    HStack(spacing: 4) {
                        Image(systemName: "ear.trianglebadge.exclamationmark")
                            .font(.caption2)
                        Text("持续监听中")
                            .font(.caption2)
                    }
                    .foregroundColor(.indigo.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(Color.indigo.opacity(0.15))
                    )
                }
            }
            .padding(.horizontal, 24)
            
            // 原文显示
            if !viewModel.currentTranscript.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("原文")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                    Text(viewModel.currentTranscript)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 24)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // 翻译结果显示
            if !viewModel.currentTranslatedText.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("翻译")
                        .font(.caption2)
                        .foregroundColor(.cyan.opacity(0.6))
                    Text(viewModel.currentTranslatedText)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.cyan)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 24)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            // 音频波形动画
            if viewModel.connectionState.isActive {
                AudioWaveView(
                    level: viewModel.audioLevel,
                    accentColor: viewModel.translationMode == .immersive ? .indigo : .cyan
                )
                .frame(height: 40)
                .padding(.horizontal, 24)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentTranslatedText)
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentTranscript)
    }
    
    /// 状态文本（区分在线/离线）
    private var statusText: String {
        if viewModel.isOfflineMode {
            return viewModel.offlineState.displayText
        }
        return viewModel.connectionState.displayText
    }
    
    private var statusColor: Color {
        if viewModel.isOfflineMode {
            return .orange
        }
        switch viewModel.connectionState {
        case .disconnected: return .gray
        case .connecting: return .yellow
        case .connected: return .green
        case .translating: return .cyan
        case .error: return .red
        }
    }
}

// MARK: - 音频波形动画

struct AudioWaveView: View {
    let level: Float
    var accentColor: Color = .cyan
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.6), accentColor],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: barHeight(for: index))
                    .animation(
                        .easeInOut(duration: 0.15)
                            .delay(Double(index) * 0.02),
                        value: level
                    )
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 4
        let maxAdditional: CGFloat = 32
        let variation = sin(Double(index) * 0.5 + Double(level) * 10) * 0.5 + 0.5
        return baseHeight + maxAdditional * CGFloat(level) * CGFloat(variation)
    }
}

// MARK: - 翻译控制按钮

struct TranslationControlButton: View {
    @EnvironmentObject var viewModel: TranslationViewModel
    @State private var isPulsing = false
    
    var body: some View {
        VStack(spacing: 8) {
            Button {
                viewModel.toggleTranslation()
            } label: {
                ZStack {
                    // 外圈脉冲动画
                    if viewModel.connectionState.isActive {
                        Circle()
                            .stroke(pulseColor.opacity(0.3), lineWidth: 2)
                            .frame(width: 120, height: 120)
                            .scaleEffect(isPulsing ? 1.3 : 1.0)
                            .opacity(isPulsing ? 0 : 0.8)
                            .animation(
                                .easeInOut(duration: 1.5).repeatForever(autoreverses: false),
                                value: isPulsing
                            )
                    }
                    
                    // 主按钮
                    Circle()
                        .fill(buttonGradient)
                        .frame(width: 90, height: 90)
                        .shadow(color: buttonShadowColor, radius: 20)
                    
                    // 按钮图标
                    VStack(spacing: 4) {
                        Image(systemName: buttonIcon)
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                        Text(buttonText)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
            
            // 模式描述
            Text(viewModel.translationMode.description)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.35))
        }
        .onChange(of: viewModel.connectionState.isActive) { _, isActive in
            isPulsing = isActive
        }
    }
    
    private var buttonIcon: String {
        if viewModel.connectionState.isActive {
            return "stop.fill"
        }
        return viewModel.translationMode == .immersive ? "ear.fill" : "mic.fill"
    }
    
    private var buttonText: String {
        if viewModel.connectionState.isActive {
            return "停止"
        }
        return viewModel.translationMode == .immersive ? "开始监听" : "开始翻译"
    }
    
    private var pulseColor: Color {
        viewModel.translationMode == .immersive ? .indigo : .cyan
    }
    
    private var buttonGradient: LinearGradient {
        if viewModel.connectionState.isActive {
            return LinearGradient(colors: [.red.opacity(0.8), .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        if viewModel.translationMode == .immersive {
            return LinearGradient(colors: [.indigo.opacity(0.8), .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return LinearGradient(colors: [.cyan.opacity(0.8), .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    private var buttonShadowColor: Color {
        if viewModel.connectionState.isActive { return .red.opacity(0.4) }
        if viewModel.translationMode == .immersive { return .indigo.opacity(0.4) }
        return .cyan.opacity(0.4)
    }
}

// MARK: - 翻译历史列表

struct TranslationHistoryView: View {
    @EnvironmentObject var viewModel: TranslationViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("翻译记录")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                if !viewModel.translationHistory.isEmpty {
                    Button("清空") {
                        viewModel.clearHistory()
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    if viewModel.translationHistory.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: viewModel.translationMode == .immersive
                                  ? "antenna.radiowaves.left.and.right"
                                  : "bubble.left.and.bubble.right")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.15))
                            Text(viewModel.translationMode == .immersive
                                 ? "开始监听后，环境音翻译将显示在这里"
                                 : "开始翻译后，对话记录将显示在这里")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .padding(.top, 30)
                    } else {
                        ForEach(viewModel.translationHistory) { entry in
                            TranslationEntryCard(entry: entry)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(maxHeight: 250)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

struct TranslationEntryCard: View {
    let entry: TranslationEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.sourceLanguage.flag)
                Text("→")
                    .foregroundColor(.white.opacity(0.3))
                Text(entry.targetLanguage.flag)
                Spacer()
                Text(entry.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.3))
            }
            .font(.caption)
            
            Text(entry.originalText)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(2)
            
            Text(entry.translatedText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.cyan.opacity(0.9))
                .lineLimit(2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
    }
}

// MARK: - 颜色扩展

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(TranslationViewModel())
}
