// OutdoorModeView.swift
// Translatar - AI实时翻译耳机应用
//
// 户外模式界面（按住说话）
// 专为嘈杂环境设计：公交车、街道、市场等
// 用户按住按钮说话，松开后翻译播放
//
// UI设计：
// - 上方：翻译结果显示区域（占据大部分空间）
// - 底部：左右并排的两个按住说话按钮
//   - 左侧：用户按钮（语言A）
//   - 右侧：对方按钮（语言B）
// - 翻译通过耳机+扬声器双通道输出

import SwiftUI

// MARK: - 户外模式主视图

struct OutdoorModeView: View {
    @EnvironmentObject var viewModel: TranslationViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // 上方：翻译结果显示区域（占据剩余空间）
            OutdoorTranslationDisplay()
            
            // 底部：左右并排的按住说话按钮
            HStack(spacing: 8) {
                // 左侧：用户按钮（语言A）
                OutdoorSpeakButton(
                    speaker: .me,
                    language: viewModel.config.sourceLanguage,
                    label: NSLocalizedString("lang.source", comment: ""),
                    gradientColors: [Color(hex: "0891B2"), Color(hex: "06B6D4")],
                    isActive: viewModel.isOutdoorRecording && viewModel.currentOutdoorSpeaker == .me
                )
                
                // 右侧：对方按钮（语言B）
                OutdoorSpeakButton(
                    speaker: .other,
                    language: viewModel.config.targetLanguage,
                    label: NSLocalizedString("lang.target", comment: ""),
                    gradientColors: [Color(hex: "7C3AED"), Color(hex: "8B5CF6")],
                    isActive: viewModel.isOutdoorRecording && viewModel.currentOutdoorSpeaker == .other
                )
            }
            .frame(height: 160)
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
    }
}

// MARK: - 按住说话按钮（适配左右并排布局）

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
        ZStack {
            // 背景渐变
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: isActive
                            ? gradientColors.map { $0.opacity(0.9) }
                            : gradientColors.map { $0.opacity(0.3) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 脉冲动画（录音时）
            if isActive {
                Circle()
                    .fill(gradientColors[0].opacity(0.2))
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulseScale)
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: pulseScale
                    )
                    .onAppear { pulseScale = 1.4 }
                    .onDisappear { pulseScale = 1.0 }
            }
            
            VStack(spacing: 6) {
                // 语言标识（国旗 + 语言名）
                Text(language.flag)
                    .font(.system(size: 28))
                
                Text(language.localizedName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // 麦克风图标
                Image(systemName: isActive ? "mic.fill" : "mic")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .symbolEffect(.pulse, isActive: isActive)
                
                // 提示文字
                Text(isActive
                     ? NSLocalizedString("outdoor.recording", comment: "")
                     : NSLocalizedString("outdoor.hold.to.speak", comment: ""))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(isActive ? 1.0 : 0.7))
                    .lineLimit(1)
                
                // 音频电平指示器（录音时）
                if isActive {
                    OutdoorAudioLevelView(
                        level: viewModel.audioLevel,
                        color: gradientColors[1]
                    )
                    .frame(height: 12)
                    .padding(.horizontal, 8)
                }
            }
            .padding(.vertical, 8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "0F0F1A").opacity(0.6))
            
            VStack(spacing: 8) {
                // 连接状态栏
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
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                Spacer()
                
                // 翻译结果
                if !viewModel.currentTranslatedText.isEmpty {
                    VStack(spacing: 6) {
                        // 原文（小字）
                        if !viewModel.currentTranscript.isEmpty {
                            Text(viewModel.currentTranscript)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        
                        Text(NSLocalizedString("display.translated", comment: ""))
                            .font(.caption2)
                            .foregroundColor(.cyan.opacity(0.6))
                        Text(viewModel.currentTranslatedText)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.cyan)
                            .multilineTextAlignment(.center)
                            .lineLimit(4)
                    }
                    .padding(.horizontal, 16)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else if !viewModel.currentTranscript.isEmpty {
                    // 原文（等待翻译时显示）
                    VStack(spacing: 4) {
                        Text(NSLocalizedString("display.original", comment: ""))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.4))
                        Text(viewModel.currentTranscript)
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                    .padding(.horizontal, 16)
                } else if viewModel.connectionState.isActive {
                    // 等待状态
                    VStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white.opacity(0.15))
                        Text(NSLocalizedString("outdoor.hint", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.3))
                            .multilineTextAlignment(.center)
                    }
                } else {
                    // 未连接状态
                    VStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.15))
                        Text(NSLocalizedString("outdoor.not.connected", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
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
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(for: index))
                    .frame(width: 3, height: barHeight(for: index))
                    .animation(
                        .easeInOut(duration: 0.1)
                            .delay(Double(index) * 0.01),
                        value: level
                    )
            }
        }
    }
    
    private func barColor(for index: Int) -> Color {
        let threshold = Int(Float(20) * level)
        return index < threshold ? color : color.opacity(0.2)
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 2
        let maxAdditional: CGFloat = 10
        let variation = sin(Double(index) * 0.6 + Double(level) * 8) * 0.5 + 0.5
        return baseHeight + maxAdditional * CGFloat(level) * CGFloat(variation)
    }
}

#Preview {
    OutdoorModeView()
        .environmentObject(TranslationViewModel())
}
