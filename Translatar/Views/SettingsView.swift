// SettingsView.swift
// Translatar - AI实时翻译耳机应用
//
// 设置页面（第三阶段完整版）
// 包含：订阅管理、API配置、翻译模式、降噪设置、离线翻译、关于

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: TranslationViewModel
    @EnvironmentObject var subscriptionService: SubscriptionService
    @State private var tempAPIKey: String = ""
    @State private var showAPIKey: Bool = false
    @State private var showPaywall: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0F0F1A")
                    .ignoresSafeArea()
                
                List {
                    // 订阅状态
                    subscriptionSection
                    
                    // API密钥配置
                    apiKeySection
                    
                    // 翻译模式
                    translationModeSection
                    
                    // 音频设置
                    audioSection
                    
                    // 离线翻译
                    offlineSection
                    
                    // 关于
                    aboutSection
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(NSLocalizedString("settings.title", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(subscriptionService)
            }
            .onAppear {
                tempAPIKey = viewModel.apiKey
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - 订阅状态
    
    private var subscriptionSection: some View {
        Section {
            // 当前方案
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            subscriptionService.currentSubscription == .free
                            ? AnyShapeStyle(Color.white.opacity(0.1))
                            : AnyShapeStyle(LinearGradient(colors: [.cyan.opacity(0.3), .indigo.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: subscriptionService.currentSubscription == .free ? "person.fill" : "crown.fill")
                        .font(.title3)
                        .foregroundColor(subscriptionService.currentSubscription == .free ? .white.opacity(0.6) : .yellow)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(subscriptionService.currentSubscription.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if let expDate = subscriptionService.expirationDate {
                        Text(NSLocalizedString("settings.expiry", comment: "") + "：\(expDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                    } else {
                        Text(subscriptionService.currentSubscription == .free ? NSLocalizedString("settings.freeLimit", comment: "") : NSLocalizedString("settings.allUnlocked", comment: ""))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                
                Spacer()
                
                if subscriptionService.currentSubscription == .free {
                    Button {
                        showPaywall = true
                    } label: {
                        Text(NSLocalizedString("settings.upgrade", comment: ""))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
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
            }
            .listRowBackground(Color.white.opacity(0.05))
            
            // 恢复购买
            Button {
                Task {
                    await subscriptionService.restorePurchases()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.cyan)
                    Text(NSLocalizedString("settings.restore", comment: ""))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .listRowBackground(Color.white.opacity(0.05))
            
            // 管理订阅
            if subscriptionService.currentSubscription != .free {
                Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                    HStack {
                        Image(systemName: "creditcard")
                            .foregroundColor(.cyan)
                        Text(NSLocalizedString("settings.manageSubscription", comment: ""))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
                .listRowBackground(Color.white.opacity(0.05))
            }
        } header: {
            Text(NSLocalizedString("settings.section.subscription", comment: ""))
                .foregroundColor(.cyan)
        }
    }
    
    // MARK: - API密钥
    
    private var apiKeySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("settings.apiKey.title", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                
                HStack {
                    if showAPIKey {
                        TextField("AIza...", text: $tempAPIKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } else {
                        SecureField("AIza...", text: $tempAPIKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                    }
                    
                    Button { showAPIKey.toggle() } label: {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                            .foregroundColor(.cyan)
                    }
                    
                    Button {
                        if !tempAPIKey.isEmpty {
                            viewModel.saveAPIKey(tempAPIKey)
                        }
                    } label: {
                        Text(NSLocalizedString("settings.save", comment: ""))
                            .font(.caption)
                            .foregroundColor(.cyan)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.08))
                )
                
                Text(NSLocalizedString("settings.apiKey.note", comment: ""))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.3))
            }
            .listRowBackground(Color.white.opacity(0.05))
        } header: {
            Text(NSLocalizedString("settings.section.account", comment: ""))
                .foregroundColor(.cyan)
        }
    }
    
    // MARK: - 翻译模式
    
    private var translationModeSection: some View {
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
                            HStack {
                                Text(mode.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                
                                if mode == .immersive && subscriptionService.currentSubscription == .free {
                                    Text("PRO")
                                        .font(.system(size: 8))
                                        .fontWeight(.bold)
                                        .foregroundColor(.yellow)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(Color.yellow.opacity(0.2)))
                                }
                            }
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
            Text(NSLocalizedString("settings.section.translationMode", comment: ""))
                .foregroundColor(.cyan)
        }
    }
    
    // MARK: - 音频设置
    
    private var audioSection: some View {
        Section {
            HStack {
                Image(systemName: "waveform.badge.minus")
                    .foregroundColor(.cyan)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("settings.noiseSuppression", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Text(NSLocalizedString("settings.noiseSuppression.desc", comment: ""))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
                
                Spacer()
                
                Toggle("", isOn: $viewModel.isNoiseSuppressionEnabled)
                    .tint(.cyan)
            }
            .listRowBackground(Color.white.opacity(0.05))
        } header: {
            Text(NSLocalizedString("settings.section.audio", comment: ""))
                .foregroundColor(.cyan)
        } footer: {
            Text(NSLocalizedString("settings.noiseSuppression.footer", comment: ""))
                .foregroundColor(.white.opacity(0.3))
        }
    }
    
    // MARK: - 离线翻译
    
    private var offlineSection: some View {
        Section {
            HStack {
                Image(systemName: "wifi.exclamationmark")
                    .foregroundColor(.orange)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("settings.autoOffline", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Text(NSLocalizedString("settings.autoOffline.desc", comment: ""))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
                
                Spacer()
                
                Toggle("", isOn: $viewModel.autoOfflineSwitch)
                    .tint(.orange)
            }
            .listRowBackground(Color.white.opacity(0.05))
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.orange)
                        .frame(width: 30)
                    Text(NSLocalizedString("settings.offlinePack", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("settings.offline.speech.hint", value: "• 语音识别：设置 → 通用 → 键盘 → 听写语言", comment: ""))
                    Text(NSLocalizedString("settings.offline.translate.hint", value: "• 翻译引擎：设置 → 通用 → 翻译 → 下载语言（iOS 18+）", comment: ""))
                }
                .font(.caption2)
                .foregroundColor(.white.opacity(0.35))
            }
            .listRowBackground(Color.white.opacity(0.05))
        } header: {
            Text(NSLocalizedString("settings.section.offline", comment: ""))
                .foregroundColor(.orange)
        }
    }
    
    // MARK: - 关于
    
    private var aboutSection: some View {
        Section {
            HStack {
                Text(NSLocalizedString("settings.version", comment: ""))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("3.0.0")
                    .foregroundColor(.white.opacity(0.3))
            }
            .listRowBackground(Color.white.opacity(0.05))
            
            HStack {
                Text(NSLocalizedString("settings.onlineEngine", comment: ""))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("Gemini Realtime API")
                    .foregroundColor(.white.opacity(0.3))
            }
            .listRowBackground(Color.white.opacity(0.05))
            
            HStack {
                Text(NSLocalizedString("settings.offlineEngine", comment: ""))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("Apple Speech + Translation")
                    .foregroundColor(.white.opacity(0.3))
            }
            .listRowBackground(Color.white.opacity(0.05))
            
            // 隐私政策
            Link(destination: URL(string: "https://translatar.app/privacy")!) {
                HStack {
                    Text(NSLocalizedString("settings.privacy", comment: ""))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .listRowBackground(Color.white.opacity(0.05))
            
            // 使用条款
            Link(destination: URL(string: "https://translatar.app/terms")!) {
                HStack {
                    Text(NSLocalizedString("settings.terms", comment: ""))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .listRowBackground(Color.white.opacity(0.05))
            
            // 反馈
            Link(destination: URL(string: "mailto:support@translatar.app")!) {
                HStack {
                    Text(NSLocalizedString("settings.feedback", comment: ""))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Image(systemName: "envelope")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .listRowBackground(Color.white.opacity(0.05))
        } header: {
            Text(NSLocalizedString("settings.section.about", comment: ""))
                .foregroundColor(.cyan)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(TranslationViewModel())
        .environmentObject(SubscriptionService())
}
