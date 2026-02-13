// SettingsView.swift
// Translatar - AI实时翻译耳机应用
//
// 设置页面
// 用户可以在这里配置API密钥、选择翻译模式和其他偏好设置

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: TranslationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var tempAPIKey: String = ""
    @State private var showAPIKey: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
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
                                viewModel.translationMode = mode
                            } label: {
                                HStack {
                                    Image(systemName: mode.iconName)
                                        .foregroundColor(.cyan)
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
                    }
                    
                    // 关于
                    Section {
                        HStack {
                            Text("版本")
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text("1.0.0 (MVP)")
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                        
                        HStack {
                            Text("翻译引擎")
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text("OpenAI Realtime API")
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
                        // 保存API密钥
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
