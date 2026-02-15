// ContentView.swift
// Translatar - AI实时翻译耳机应用
//
// 应用主界面（v13 - 移除同声传译模式）
// 精美UI + 订阅检查 + 免费额度提示 + 动效升级 + 多语言本地化

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: TranslationViewModel
    @EnvironmentObject var subscriptionService: SubscriptionService
    @State private var showPaywall = false
    
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
                    
                    // 免费额度提示（仅免费用户显示）
                    if subscriptionService.currentSubscription == .free {
                        FreeQuotaBanner(
                            remainingSeconds: subscriptionService.remainingFreeSeconds,
                            totalSeconds: subscriptionService.freeQuotaSeconds
                        ) {
                            showPaywall = true
                        }
                        .padding(.top, 8)
                        .padding(.horizontal, 20)
                    }
                    
                    if viewModel.translationMode == .outdoor {
                        // === 户外模式布局 ===
                        
                        // 语言选择器（紧凑版）
                        LanguageSelectorView()
                            .padding(.top, 8)
                        
                        // 开始/停止按钮（户外模式需要先连接）
                        if !viewModel.connectionState.isActive {
                            TranslationControlButton()
                                .padding(.vertical, 12)
                        } else {
                            // 小型停止按钮
                            HStack {
                                Spacer()
                                Button {
                                    viewModel.toggleTranslation()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "stop.fill")
                                            .font(.caption)
                                        Text(NSLocalizedString("button.stop", comment: ""))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule().fill(Color.red.opacity(0.15))
                                    )
                                }
                                Spacer()
                            }
                            .padding(.top, 4)
                        }
                        
                        // 按住说话界面（占据剩余空间）
                        OutdoorModeView()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                        
                    } else {
                        // === 对话模式布局 ===
                        
                        // 顶部语言选择区域
                        LanguageSelectorView()
                            .padding(.top, 12)
                        
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
                        
                        // 翻译历史预览
                        TranslationHistoryPreview()
                    }
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
                        
                        // 会员标识
                        if subscriptionService.currentSubscription != .free {
                            Text("PRO")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.yellow)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [.yellow.opacity(0.3), .orange.opacity(0.3)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                        }
                        
                        // 离线模式标识
                        if viewModel.isOfflineMode {
                            Text(NSLocalizedString("common.offline.badge", comment: ""))
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
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(subscriptionService)
            }
            .alert(NSLocalizedString("common.alert.title", comment: ""), isPresented: $viewModel.showError) {
                Button(NSLocalizedString("common.alert.ok", comment: ""), role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? NSLocalizedString("common.alert.unknown.error", comment: ""))
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
            case .outdoor:
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "0F0F1A"),
                        Color(hex: "1A0F2E"),
                        Color(hex: "0F1A2E")
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
}

// MARK: - 免费额度提示条

struct FreeQuotaBanner: View {
    let remainingSeconds: Int
    let totalSeconds: Int
    let onUpgrade: () -> Void
    
    private var progress: Double {
        Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }
    
    private var remainingMinutes: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // 进度环
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 3)
                    .frame(width: 32, height: 32)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        progress > 0.8 ? Color.red : Color.cyan,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(-90))
                Image(systemName: "clock")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("quota.remaining", comment: ""))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                Text(remainingMinutes)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(progress > 0.8 ? .red : .white)
            }
            
            Spacer()
            
            Button {
                onUpgrade()
            } label: {
                Text(NSLocalizedString("quota.upgrade", comment: ""))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.cyan, .indigo],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
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
                                  ? (mode == .outdoor ? Color.purple.opacity(0.4)
                                     : Color.cyan.opacity(0.3))
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
            StatusChip(
                icon: viewModel.isNetworkConnected ? "wifi" : "wifi.slash",
                text: viewModel.isNetworkConnected
                    ? NSLocalizedString("status.online", comment: "")
                    : NSLocalizedString("status.offline", comment: ""),
                color: viewModel.isNetworkConnected ? .green : .orange
            )
            
            StatusChip(
                icon: "waveform.badge.minus",
                text: viewModel.isNoiseSuppressionEnabled
                    ? NSLocalizedString("status.noise.on", comment: "")
                    : NSLocalizedString("status.noise.off", comment: ""),
                color: viewModel.isNoiseSuppressionEnabled ? .cyan : .gray
            )
            
            StatusChip(
                icon: viewModel.translationMode.iconName,
                text: viewModel.translationMode == .outdoor
                    ? NSLocalizedString("status.outdoor", comment: "")
                    : NSLocalizedString("status.chatting", comment: ""),
                color: viewModel.translationMode == .outdoor ? .purple : .cyan
            )
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

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
                label: NSLocalizedString("lang.source", comment: ""),
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
                label: NSLocalizedString("lang.target", comment: ""),
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
                // 按地区分组显示语言，方便用户查找
                ForEach(LanguageGroup.allCases, id: \.rawValue) { group in
                    Section(header: Text(group.displayName)) {
                        ForEach(group.languages) { lang in
                            Button {
                                language = lang
                            } label: {
                                HStack {
                                    Text("\(lang.flag) \(lang.localizedName)")
                                    Spacer()
                                    if lang == language {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(language.flag)
                        .font(.title2)
                    Text(language.localizedName)
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 14)
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
            }
            .padding(.horizontal, 24)
            
            // 原文显示
            if !viewModel.currentTranscript.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("display.original", comment: ""))
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
                    Text(NSLocalizedString("display.translated", comment: ""))
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
                    accentColor: viewModel.translationMode == .outdoor ? .purple : .cyan
                )
                .frame(height: 40)
                .padding(.horizontal, 24)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentTranslatedText)
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentTranscript)
    }
    
    private var statusText: String {
        if viewModel.isOfflineMode {
            return viewModel.offlineState.displayText
        }
        return viewModel.connectionState.displayText
    }
    
    private var statusColor: Color {
        if viewModel.isOfflineMode { return .orange }
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
    @EnvironmentObject var subscriptionService: SubscriptionService
    @State private var isPulsing = false
    
    var body: some View {
        VStack(spacing: 8) {
            Button {
                // 检查免费额度
                if subscriptionService.currentSubscription == .free &&
                   !subscriptionService.canUseTranslation &&
                   !viewModel.connectionState.isActive {
                    NotificationCenter.default.post(name: .showPaywall, object: nil)
                    return
                }
                // 同步PRO状态到ViewModel，用于选择翻译模型
                viewModel.isPro = subscriptionService.currentSubscription != .free
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
            
            Text(viewModel.translationMode.description)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.35))
        }
        .onChange(of: viewModel.connectionState.isActive) { _, isActive in
            isPulsing = isActive
        }
    }
    
    private var buttonIcon: String {
        if viewModel.connectionState.isActive { return "stop.fill" }
        switch viewModel.translationMode {
        case .outdoor: return "figure.walk"
        case .conversation: return "mic.fill"
        }
    }
    
    private var buttonText: String {
        if viewModel.connectionState.isActive {
            return NSLocalizedString("button.stop", comment: "")
        }
        switch viewModel.translationMode {
        case .outdoor: return NSLocalizedString("button.start.outdoor", comment: "")
        case .conversation: return NSLocalizedString("button.start.translate", comment: "")
        }
    }
    
    private var pulseColor: Color {
        switch viewModel.translationMode {
        case .outdoor: return .purple
        case .conversation: return .cyan
        }
    }
    
    private var buttonGradient: LinearGradient {
        if viewModel.connectionState.isActive {
            return LinearGradient(colors: [.red.opacity(0.8), .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        switch viewModel.translationMode {
        case .outdoor:
            return LinearGradient(colors: [.purple.opacity(0.8), .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .conversation:
            return LinearGradient(colors: [.cyan.opacity(0.8), .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private var buttonShadowColor: Color {
        if viewModel.connectionState.isActive { return .red.opacity(0.4) }
        switch viewModel.translationMode {
        case .outdoor: return .purple.opacity(0.4)
        case .conversation: return .cyan.opacity(0.4)
        }
    }
}

// MARK: - 翻译历史预览（首页底部简化版）

struct TranslationHistoryPreview: View {
    @EnvironmentObject var viewModel: TranslationViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(NSLocalizedString("history.recent", comment: ""))
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    if viewModel.translationHistory.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: viewModel.translationMode == .outdoor
                                  ? "hand.tap.fill"
                                  : "bubble.left.and.bubble.right")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.15))
                            Text(viewModel.translationMode == .outdoor
                                 ? NSLocalizedString("history.empty.outdoor", comment: "")
                                 : NSLocalizedString("history.empty.conversation", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .padding(.top, 30)
                    } else {
                        ForEach(viewModel.translationHistory.prefix(5)) { entry in
                            TranslationEntryCard(entry: entry)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(maxHeight: 220)
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
                Text("\(entry.sourceLanguage.flag) \(entry.sourceLanguage.localizedName)")
                Text("→")
                    .foregroundColor(.white.opacity(0.3))
                Text("\(entry.targetLanguage.flag) \(entry.targetLanguage.localizedName)")
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
        .environmentObject(SubscriptionService())
}
