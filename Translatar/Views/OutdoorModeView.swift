// OutdoorModeView.swift
// Translatar - AI实时翻译耳机应用
//
// 户外模式界面（按住说话）
// 专为嘈杂环境设计：公交车、街道、市场等
// 用户按住按钮说话，松开后翻译播放
//
// UI设计：
// - 上半区：用户按钮（语言A）- 用户按住说自己的语言
// - 下半区：对方按钮（语言B）- 对方按住说他们的语言
// - 中间：翻译结果显示区域
// - 翻译通过耳机+扬声器双通道输出

import SwiftUI

// MARK: - 户外模式主视图

struct OutdoorModeView: View {
    @EnvironmentObject var viewModel: TranslationViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // 上半区：用户按钮（语言A）
            OutdoorSpeakButton(
                speaker: .me,
                language: viewModel.config.sourceLanguage,
                label: NSLocalizedString("lang.source", comment: ""),
                gradientColors: [Color(hex: "0891B2"), Color(hex: "06B6D4")],
                isActive: viewModel.isOutdoorRecording && viewModel.currentOutdoorSpeaker == .me
            )
            
            // 中间：翻译结果显示 + 状态
            OutdoorTranslationDisplay()
                .frame(height: 180)
            
            // 下半区：对方按钮（语言B）
            OutdoorSpeakButton(
                speaker: .other,
                language: viewModel.config.targetLanguage,
                label: NSLocalizedString("lang.target", comment: ""),
                gradientColors: [Color(hex: "7C3AED"), Color(hex: "8B5CF6")],
                isActive: viewModel.isOutdoorRecording && viewModel.currentOutdoorSpeaker == .other
            )
        }
    }
}

// MARK: - 按住说话按钮

struct OutdoorSpeakButton: View {
    @EnvironmentObject var viewModel: TranslationViewModel
    
    let speaker: OutdoorSpeaker
    let language: SupportedLanguage
    let label: String
    let gradientColors: [Color]
    let isActive: Bool
    
    @State private var isPressing = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景渐变
                LinearGradient(
                    colors: isActive
                        ? gradientColors.map { $0.opacity(0.9) }
                        : gradientColors.map { $0.opacity(0.3) },
                    startPoint: speaker == .me ? .topLeading : .bottomTrailing,
                    endPoint: speaker == .me ? .bottomTrailing : .topLeading
                )
                
                // 脉冲动画（录音时）
                if isActive {
                    Circle()
                        .fill(gradientColors[0].opacity(0.2))
                        .frame(width: 200, height: 200)
                        .scaleEffect(pulseScale)
                        .animation(
                            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                            value: pulseScale
                        )
                        .onAppear { pulseScale = 1.5 }
                        .onDisappear { pulseScale = 1.0 }
                }
                
                VStack(spacing: 12) {
                    // 语言标识
                    HStack(spacing: 8) {
                        Text(language.flag)
                            .font(.system(size: 32))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(label)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                            Text(language.localizedName)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                    }
                    
                    // 麦克风图标
                    Image(systemName: isActive ? "mic.fill" : "mic")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .symbolEffect(.pulse, isActive: isActive)
                    
                    // 提示文字
                    Text(isActive
                         ? NSLocalizedString("outdoor.recording", comment: "")
                         : NSLocalizedString("outdoor.hold.to.speak", comment: ""))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(isActive ? 1.0 : 0.7))
                    
                    // 音频电平指示器（录音时）
                    if isActive {
                        OutdoorAudioLevelView(
                            level: viewModel.audioLevel,
                            color: gradientColors[1]
                        )
                        .frame(height: 20)
                        .padding(.horizontal, 40)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressing {
                            isPressing = true
                            onPressStart()
                        }
                    }
                    .onEnded { _ in
                        isPressing = false
                        onPressEnd()
                    }
            )
        }
    }
    
    private func onPressStart() {
        // 触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        viewModel.outdoorStartSpeaking(speaker: speaker)
    }
    
    private func onPressEnd() {
        // 触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        viewModel.outdoorStopSpeaking()
    }
}

// MARK: - 户外模式翻译显示区域

struct OutdoorTranslationDisplay: View {
    @EnvironmentObject var viewModel: TranslationViewModel
    
    var body: some View {
        ZStack {
            // 背景
            Color(hex: "0F0F1A")
            
            VStack(spacing: 8) {
                // 连接状态
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    
                    Spacer()
                    
                    // 双通道输出标识
                    if viewModel.connectionState.isActive {
                        HStack(spacing: 4) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.caption2)
                            Text(NSLocalizedString("outdoor.dual.output", comment: ""))
                                .font(.caption2)
                        }
                        .foregroundColor(.orange.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(Color.orange.opacity(0.15))
                        )
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // 翻译结果
                if !viewModel.currentTranslatedText.isEmpty {
                    VStack(spacing: 4) {
                        Text(NSLocalizedString("display.translated", comment: ""))
                            .font(.caption2)
                            .foregroundColor(.cyan.opacity(0.6))
                        Text(viewModel.currentTranslatedText)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.cyan)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                    .padding(.horizontal, 20)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else if !viewModel.currentTranscript.isEmpty {
                    // 原文（等待翻译时显示）
                    VStack(spacing: 4) {
                        Text(NSLocalizedString("display.original", comment: ""))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.4))
                        Text(viewModel.currentTranscript)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 20)
                } else if viewModel.connectionState.isActive {
                    // 等待状态
                    VStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.2))
                        Text(NSLocalizedString("outdoor.hint", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.3))
                            .multilineTextAlignment(.center)
                    }
                } else {
                    // 未连接状态
                    Text(NSLocalizedString("outdoor.not.connected", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.3))
                }
                
                Spacer()
            }
            .padding(.vertical, 12)
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentTranslatedText)
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentTranscript)
    }
    
    private var statusText: String {
        if viewModel.isOutdoorRecording {
            return NSLocalizedString("outdoor.recording", comment: "")
        }
        return viewModel.connectionState.displayText
    }
    
    private var statusColor: Color {
        if viewModel.isOutdoorRecording { return .red }
        switch viewModel.connectionState {
        case .disconnected: return .gray
        case .connecting: return .yellow
        case .connected: return .green
        case .translating: return .cyan
        case .error: return .red
        }
    }
}

// MARK: - 户外模式音频电平指示器

struct OutdoorAudioLevelView: View {
    let level: Float
    let color: Color
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<30, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(for: index))
                    .frame(width: 4, height: barHeight(for: index))
                    .animation(
                        .easeInOut(duration: 0.1)
                            .delay(Double(index) * 0.01),
                        value: level
                    )
            }
        }
    }
    
    private func barColor(for index: Int) -> Color {
        let threshold = Int(Float(30) * level)
        return index < threshold ? color : color.opacity(0.2)
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 3
        let maxAdditional: CGFloat = 17
        let variation = sin(Double(index) * 0.6 + Double(level) * 8) * 0.5 + 0.5
        return baseHeight + maxAdditional * CGFloat(level) * CGFloat(variation)
    }
}

#Preview {
    OutdoorModeView()
        .environmentObject(TranslationViewModel())
}
