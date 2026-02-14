// OnboardingView.swift
// Translatar - AI实时翻译耳机应用
//
// 首次启动引导页
// 展示应用核心价值，引导用户完成初始设置

import SwiftUI

/// 引导页数据模型
struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let description: String
    let accentColor: Color
}

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "airpodspro",
            title: "戴上耳机",
            subtitle: NSLocalizedString("onboarding.title1", comment: ""),
            description: NSLocalizedString("onboarding.desc1", comment: ""),
            accentColor: .cyan
        ),
        OnboardingPage(
            icon: "waveform.badge.mic",
            title: NSLocalizedString("onboarding.title2", comment: ""),
            subtitle: NSLocalizedString("onboarding.subtitle2", comment: ""),
            description: NSLocalizedString("onboarding.desc2", comment: ""),
            accentColor: .indigo
        ),
        OnboardingPage(
            icon: "ear.trianglebadge.exclamationmark",
            title: NSLocalizedString("onboarding.title3", comment: ""),
            subtitle: NSLocalizedString("onboarding.subtitle3", comment: ""),
            description: NSLocalizedString("onboarding.desc3", comment: ""),
            accentColor: .purple
        ),
        OnboardingPage(
            icon: "shield.checkered",
            title: NSLocalizedString("onboarding.title4", comment: ""),
            subtitle: NSLocalizedString("onboarding.subtitle4", comment: ""),
            description: NSLocalizedString("onboarding.desc4", comment: ""),
            accentColor: .orange
        )
    ]
    
    var body: some View {
        ZStack {
            // 动态背景
            backgroundView
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 跳过按钮
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button(NSLocalizedString("onboarding.skip", comment: "")) {
                            completeOnboarding()
                        }
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.trailing, 24)
                        .padding(.top, 8)
                    }
                }
                
                Spacer()
                
                // 页面内容
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)
                
                // 页面指示器
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? pages[currentPage].accentColor : Color.white.opacity(0.2))
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 32)
                
                // 底部按钮
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        completeOnboarding()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(currentPage < pages.count - 1 ? NSLocalizedString("onboarding.next", comment: "") : NSLocalizedString("onboarding.start", comment: ""))
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if currentPage == pages.count - 1 {
                            Image(systemName: "arrow.right")
                                .font(.headline)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [pages[currentPage].accentColor.opacity(0.8), pages[currentPage].accentColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: pages[currentPage].accentColor.opacity(0.4), radius: 16, y: 8)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    /// 动态背景（根据当前页面变化）
    private var backgroundView: some View {
        ZStack {
            Color(hex: "0A0A14")
            
            // 装饰性光晕
            Circle()
                .fill(pages[currentPage].accentColor.opacity(0.08))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: -50, y: -200)
                .animation(.easeInOut(duration: 0.8), value: currentPage)
            
            Circle()
                .fill(pages[currentPage].accentColor.opacity(0.05))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: 100, y: 200)
                .animation(.easeInOut(duration: 0.8), value: currentPage)
        }
    }
    
    private func completeOnboarding() {
        withAnimation(.easeInOut(duration: 0.3)) {
            hasCompletedOnboarding = true
            UserDefaults.standard.set(true, forKey: "has_completed_onboarding")
        }
    }
}

// MARK: - 单页视图

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // 图标
            ZStack {
                // 光晕背景
                Circle()
                    .fill(page.accentColor.opacity(0.1))
                    .frame(width: 160, height: 160)
                    .blur(radius: 20)
                
                // 图标圆环
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [page.accentColor.opacity(0.6), page.accentColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 120, height: 120)
                
                // 图标
                Image(systemName: page.icon)
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [page.accentColor, page.accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(.bottom, 16)
            
            // 标题
            VStack(spacing: 8) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(page.subtitle)
                    .font(.title3)
                    .foregroundColor(page.accentColor.opacity(0.8))
            }
            
            // 描述
            Text(page.description)
                .font(.body)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)
            
            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
