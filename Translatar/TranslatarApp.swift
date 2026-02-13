// TranslatarApp.swift
// Translatar - AI实时翻译耳机应用
//
// 应用程序入口文件（第三阶段完整版）
// 集成引导页、订阅服务、TabView导航

import SwiftUI

@main
struct TranslatarApp: App {
    @StateObject private var translationVM = TranslationViewModel()
    @StateObject private var subscriptionService = SubscriptionService()
    @AppStorage("has_completed_onboarding") private var hasCompletedOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainTabView()
                    .environmentObject(translationVM)
                    .environmentObject(subscriptionService)
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
    }
}

// MARK: - 主Tab导航

struct MainTabView: View {
    @EnvironmentObject var translationVM: TranslationViewModel
    @EnvironmentObject var subscriptionService: SubscriptionService
    @State private var selectedTab = 0
    @State private var showPaywall = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 翻译主页
            ContentView()
                .tabItem {
                    Image(systemName: "waveform.and.mic")
                    Text("翻译")
                }
                .tag(0)
            
            // 翻译历史
            HistoryView()
                .tabItem {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("记录")
                }
                .tag(1)
            
            // 设置
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("设置")
                }
                .tag(2)
        }
        .tint(.cyan)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(subscriptionService)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showPaywall)) { _ in
            showPaywall = true
        }
    }
}

// MARK: - 通知扩展

extension Notification.Name {
    static let showPaywall = Notification.Name("showPaywall")
}
