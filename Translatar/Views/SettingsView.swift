// SettingsView.swift
// Translatar - AI实时翻译耳机应用
//
// 设置页面（第二阶段增强版）
// 新增：降噪设置、自动离线切换、离线语言包提示

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: TranslationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var tempAPIKey: String = ""
    @State private var showAPIKey: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0F0F1A")
                    .ignoresSafeArea()
                
                List {
                    // API密钥配置
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("OpenAI API 密钥")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                            
                            HStack {
                                if showAPIKey {
                                    TextField("sk-...", text: $tempAPIKey)
                                        .textContentType(.password)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                } else {
                                    SecureField("sk-...", text: $tempAPIKey)
                                        .textContentType(.password)
                                        .autocorrectionDisabled()
                                }
                                
                                Button {
                                    showAPIKey.toggle()
                                } label: {
                                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                        .foregroundColor(.cyan)
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.08))
                            )
                            
                            Text("您的API密钥仅保存在本地设备上，不会上传到任何服务器。")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    } header: {
                        Text("账号配置")
                            .foregroundColor(.cyan)
                    }
                    
                    // 翻译模式选择
                    Section {
                        ForEach(TranslationMode.allCases) { mode in
                            Button {
                                withAnimation {
                                    viewModel.switchMode(mode)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: mode.iconName)
                                        .foregroundColor(mode == .immersive ? .indigo : .cyan)
                                        .frame(width: 30)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mode.displayName)
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                        Text(mode.description)
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                    
                                    Spacer()
                                    
                                    if viewModel.translationMode == mode {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.cyan)
                                    }
                                }
                            }
                            .listRowBackground(Color.white.opacity(0.05))
                        }
                    } header: {
                        Text("翻译模式")
                            .foregroundColor(.cyan)
                    } footer: {
                        Text("对话模式适合面对面交流；沉浸模式适合机场广播、车站播报等环境音翻译，会持续监听周围声音。")
                            .foregroundColor(.white.opacity(0.3))
                    }
                    
                    // 音频与降噪设置
                    Section {
                        // 降噪开关
                        HStack {
                            Image(systemName: "waveform.badge.minus")
                                .foregroundColor(.cyan)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("AI降噪")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                Text("Apple Voice Processing 降噪技术")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $viewModel.isNoiseSuppressionEnabled)
                                .tint(.cyan)
                                .onChange(of: viewModel.isNoiseSuppressionEnabled) { _, newValue in
                                    UserDefaults.standard.set(newValue, forKey: "noise_suppression")
                                }
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                        
                    } header: {
                        Text("音频设置")
                            .foregroundColor(.cyan)
                    } footer: {
                        Text("降噪功能使用Apple原生Voice Processing技术，包含回声消除、噪声抑制和自动增益控制。在嘈杂环境中建议开启。")
                            .foregroundColor(.white.opacity(0.3))
                    }
                    
                    // 离线翻译设置
                    Section {
                        // 自动离线切换
                        HStack {
                            Image(systemName: "wifi.exclamationmark")
                                .foregroundColor(.orange)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("自动离线切换")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                Text("网络断开时自动切换到离线翻译")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $viewModel.autoOfflineSwitch)
                                .tint(.orange)
                                .onChange(of: viewModel.autoOfflineSwitch) { _, newValue in
                                    UserDefaults.standard.set(newValue, forKey: "auto_offline_switch")
                                }
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                        
                        // 离线语言包提示
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "arrow.down.circle")
                                    .foregroundColor(.orange)
                                    .frame(width: 30)
                                Text("离线语言包")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                            
                            Text("离线翻译使用Apple原生语音识别和翻译框架，需要预先下载语言包：")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.4))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("• 语音识别：设置 → 通用 → 键盘 → 听写语言")
                                Text("• 翻译引擎：设置 → 通用 → 翻译 → 下载语言（iOS 18+）")
                            }
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.35))
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                        
                    } header: {
                        Text("离线翻译")
                            .foregroundColor(.orange)
                    } footer: {
                        Text("离线模式使用Apple设备端AI，完全免费且保护隐私。翻译质量略低于在线模式，但在无网络环境下非常实用。")
                            .foregroundColor(.white.opacity(0.3))
                    }
                    
                    // 关于
                    Section {
                        HStack {
                            Text("版本")
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text("2.0.0 (Phase 2)")
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                        
                        HStack {
                            Text("在线翻译引擎")
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text("OpenAI Realtime API")
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                        
                        HStack {
                            Text("离线翻译引擎")
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text("Apple Speech + Translation")
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                        
                        HStack {
                            Text("降噪技术")
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text("Apple Voice Processing")
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    } header: {
                        Text("关于")
                            .foregroundColor(.cyan)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        if !tempAPIKey.isEmpty {
                            viewModel.saveAPIKey(tempAPIKey)
                        }
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                }
            }
            .onAppear {
                tempAPIKey = viewModel.apiKey
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SettingsView()
        .environmentObject(TranslationViewModel())
}
