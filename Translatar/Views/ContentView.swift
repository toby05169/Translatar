// ContentView.swift
// Translatar - AI实时翻译耳机应用
//
// 应用主界面
// 包含语言选择、翻译控制按钮、实时字幕显示和翻译历史

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: TranslationViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景渐变
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "0F0F1A"),
                        Color(hex: "1A1A2E"),
                        Color(hex: "16213E")
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 顶部语言选择区域
                    LanguageSelectorView()
                        .padding(.top, 8)
                    
                    // 实时翻译显示区域
                    TranslationDisplayView()
                        .padding(.top, 16)
                    
                    Spacer()
                    
                    // 中央控制按钮
                    TranslationControlButton()
                        .padding(.bottom, 20)
                    
                    // 翻译历史列表
                    TranslationHistoryView()
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Translatar")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.white.opacity(0.8))
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
}

// MARK: - 语言选择器

struct LanguageSelectorView: View {
    @EnvironmentObject var viewModel: TranslationViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // 源语言选择
            LanguagePickerButton(
                label: "对方说",
                language: $viewModel.config.sourceLanguage
            )
            
            // 交换按钮
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
            
            // 目标语言选择
            LanguagePickerButton(
                label: "翻译成",
                language: $viewModel.config.targetLanguage
            )
        }
        .padding(.horizontal, 20)
    }
}

/// 语言选择按钮组件
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
                Text(viewModel.connectionState.displayText)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
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
                AudioWaveView(level: viewModel.audioLevel)
                    .frame(height: 40)
                    .padding(.horizontal, 24)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentTranslatedText)
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentTranscript)
    }
    
    private var statusColor: Color {
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
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [.cyan.opacity(0.6), .cyan],
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
        Button {
            viewModel.toggleTranslation()
        } label: {
            ZStack {
                // 外圈脉冲动画（翻译中时显示）
                if viewModel.connectionState.isActive {
                    Circle()
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 2)
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
                    .fill(
                        viewModel.connectionState.isActive
                            ? LinearGradient(colors: [.red.opacity(0.8), .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [.cyan.opacity(0.8), .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 90, height: 90)
                    .shadow(color: viewModel.connectionState.isActive ? .red.opacity(0.4) : .cyan.opacity(0.4), radius: 20)
                
                // 按钮图标
                VStack(spacing: 4) {
                    Image(systemName: viewModel.connectionState.isActive ? "stop.fill" : "ear.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                    Text(viewModel.connectionState.isActive ? "停止" : "开始翻译")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .onChange(of: viewModel.connectionState.isActive) { _, isActive in
            isPulsing = isActive
        }
    }
}

// MARK: - 翻译历史列表

struct TranslationHistoryView: View {
    @EnvironmentObject var viewModel: TranslationViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
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
            
            // 历史记录列表
            ScrollView {
                LazyVStack(spacing: 8) {
                    if viewModel.translationHistory.isEmpty {
                        Text("开始翻译后，记录将显示在这里")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.3))
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

/// 翻译记录卡片
struct TranslationEntryCard: View {
    let entry: TranslationEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 时间和语言标签
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
            
            // 原文
            Text(entry.originalText)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(2)
            
            // 翻译
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

// MARK: - 预览

#Preview {
    ContentView()
        .environmentObject(TranslationViewModel())
}
