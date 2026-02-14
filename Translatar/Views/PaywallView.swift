// PaywallView.swift
// Translatar - AI实时翻译耳机应用
//
// 付费墙视图
// 展示订阅方案，引导用户升级
// 符合App Store审核要求：清楚显示价格、时长、试用期、续订条款

import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var showSuccessAnimation = false
    
    var body: some View {
        ZStack {
            // 背景
            backgroundView
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // 关闭按钮
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // 头部
                    headerSection
                    
                    // 功能对比
                    featureComparisonSection
                    
                    // 订阅方案卡片
                    subscriptionCardsSection
                    
                    // 购买按钮
                    purchaseButton
                    
                    // 恢复购买 + 条款
                    footerSection
                }
                .padding(.bottom, 32)
            }
            
            // 购买成功动画
            if showSuccessAnimation {
                successOverlay
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // 默认选中年度方案（性价比最高）
            selectedProduct = subscriptionService.products.last
        }
    }
    
    // MARK: - 头部区域
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.cyan.opacity(0.2), .indigo.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Text(String(localized: "paywall.title"))
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(String(localized: "paywall.subtitle"))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - 功能对比
    
    private var featureComparisonSection: some View {
        VStack(spacing: 12) {
            FeatureRow(icon: "infinity", text: String(localized: "paywall.feature.unlimited"), isFree: false, isPro: true)
            FeatureRow(icon: "ear.fill", text: String(localized: "paywall.feature.immersive"), isFree: false, isPro: true)
            FeatureRow(icon: "waveform.badge.minus", text: String(localized: "paywall.feature.noise"), isFree: false, isPro: true)
            FeatureRow(icon: "wifi.slash", text: String(localized: "paywall.feature.offline"), isFree: false, isPro: true)
            FeatureRow(icon: "person.2.fill", text: String(localized: "paywall.feature.conversation"), isFree: true, isPro: true)
            FeatureRow(icon: "captions.bubble", text: String(localized: "paywall.feature.bilingual"), isFree: true, isPro: true)
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - 订阅方案卡片
    
    private var subscriptionCardsSection: some View {
        VStack(spacing: 12) {
            ForEach(subscriptionService.products) { product in
                SubscriptionCard(
                    product: product,
                    isSelected: selectedProduct?.id == product.id,
                    isYearly: product.id.contains("yearly")
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedProduct = product
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - 购买按钮
    
    private var purchaseButton: some View {
        VStack(spacing: 8) {
            Button {
                guard let product = selectedProduct else { return }
                Task {
                    isPurchasing = true
                    let success = await subscriptionService.purchase(product)
                    isPurchasing = false
                    if success {
                        withAnimation(.spring(response: 0.5)) {
                            showSuccessAnimation = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            dismiss()
                        }
                    }
                }
            } label: {
                HStack {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(String(localized: "paywall.trial.start"))
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.cyan, .indigo],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: .cyan.opacity(0.3), radius: 16, y: 8)
            }
            .disabled(selectedProduct == nil || isPurchasing)
            .padding(.horizontal, 24)
            
            // 续订说明（App Store审核要求）
            if let product = selectedProduct {
                Text(String(localized: "paywall.trial.note.prefix") + "\(product.displayPrice)/" + (product.id.contains("yearly") ? String(localized: "paywall.yearly") : String(localized: "paywall.monthly"))自动续订。可随时在设置中取消。")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }
    
    // MARK: - 底部（恢复购买 + 条款）
    
    private var footerSection: some View {
        VStack(spacing: 12) {
            // 恢复购买按钮
            Button {
                Task {
                    await subscriptionService.restorePurchases()
                }
            } label: {
                Text(String(localized: "paywall.restore"))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            // 条款链接（App Store审核要求）
            HStack(spacing: 16) {
                Link(String(localized: "paywall.terms"), destination: URL(string: "https://translatar.app/terms")!)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.3))
                
                Text("·")
                    .foregroundColor(.white.opacity(0.2))
                
                Link(String(localized: "paywall.privacy"), destination: URL(string: "https://translatar.app/privacy")!)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.3))
            }
            
            // 订阅说明（App Store审核要求）
            Text(String(localized: "paywall.terms.detail"))
                .font(.caption2)
                .foregroundColor(.white.opacity(0.2))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    // MARK: - 购买成功动画
    
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
                
                Text(String(localized: "paywall.success.title"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(String(localized: "paywall.success.subtitle"))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
            .transition(.scale.combined(with: .opacity))
        }
    }
    
    // MARK: - 背景
    
    private var backgroundView: some View {
        ZStack {
            Color(hex: "0A0A14")
            
            // 装饰光晕
            Circle()
                .fill(Color.cyan.opacity(0.06))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -80, y: -100)
            
            Circle()
                .fill(Color.indigo.opacity(0.06))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(x: 100, y: 300)
        }
    }
}

// MARK: - 功能对比行

struct FeatureRow: View {
    let icon: String
    let text: String
    let isFree: Bool
    let isPro: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.cyan)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            // 免费版
            Image(systemName: isFree ? "checkmark.circle.fill" : "xmark.circle")
                .font(.subheadline)
                .foregroundColor(isFree ? .green.opacity(0.6) : .red.opacity(0.3))
                .frame(width: 30)
            
            // Pro版
            Image(systemName: isPro ? "checkmark.circle.fill" : "xmark.circle")
                .font(.subheadline)
                .foregroundColor(isPro ? .green : .red.opacity(0.3))
                .frame(width: 30)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 订阅方案卡片

struct SubscriptionCard: View {
    let product: Product
    let isSelected: Bool
    let isYearly: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // 选中指示器
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.cyan : Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.cyan)
                            .frame(width: 14, height: 14)
                    }
                }
                
                // 方案信息
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(product.displayName)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if isYearly {
                            Text(String(localized: "paywall.recommended"))
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [.orange, .red],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                        }
                    }
                    
                    Text(isYearly ? "7天免费试用 · 之后\(product.displayPrice)/年" : "7天免费试用 · 之后\(product.displayPrice)/月")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                // 价格
                VStack(alignment: .trailing, spacing: 0) {
                    Text(product.displayPrice)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? .cyan : .white.opacity(0.6))
                    Text(isYearly ? String(localized: "paywall.per.year") : String(localized: "paywall.per.month"))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isSelected ? 0.1 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.cyan.opacity(0.5) : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(SubscriptionService())
}
