// SubscriptionService.swift
// Translatar - AI实时翻译耳机应用
//
// StoreKit 2 订阅管理服务
// 负责：产品加载、购买、恢复购买、订阅状态检查、免费额度管理

import Foundation
import StoreKit

/// 订阅方案定义
enum SubscriptionTier: String, CaseIterable {
    case free = "free"
    case monthly = "com.translatar.app.monthly"
    case yearly = "com.translatar.app.yearly"
    
    var displayName: String {
        switch self {
        case .free: return String(localized: "sub.free")
        case .monthly: return String(localized: "sub.monthly")
        case .yearly: return String(localized: "sub.yearly")
        }
    }
    
    var description: String {
        switch self {
        case .free: return String(localized: "sub.free.desc")
        case .monthly: return String(localized: "sub.monthly.desc")
        case .yearly: return String(localized: "sub.yearly.desc")
        }
    }
    
    var features: [String] {
        switch self {
        case .free:
            return [String(localized: "sub.feature.quota"), String(localized: "sub.feature.conversation"), String(localized: "sub.feature.languages"), String(localized: "sub.feature.bilingual")]
        case .monthly, .yearly:
            return [String(localized: "sub.feature.unlimited"), String(localized: "sub.feature.allModes"), String(localized: "sub.feature.noise"), String(localized: "sub.feature.offline"), String(localized: "sub.feature.export"), String(localized: "sub.feature.support")]
        }
    }
}

/// 订阅服务
@MainActor
class SubscriptionService: ObservableObject {
    
    /// 当前订阅状态
    @Published var currentSubscription: SubscriptionTier = .free
    /// 订阅到期日期
    @Published var expirationDate: Date?
    /// 是否正在加载
    @Published var isLoading: Bool = false
    /// 错误信息
    @Published var errorMessage: String?
    
    /// 今日已使用的免费翻译秒数
    @Published var todayUsedSeconds: Int = 0
    /// 免费额度每日上限（秒）
    let freeQuotaSeconds: Int = 300 // 5分钟
    
    /// 可用的订阅产品
    @Published var products: [Product] = []
    
    /// 产品ID列表
    private let productIDs: Set<String> = [
        "com.translatar.app.monthly",
        "com.translatar.app.yearly"
    ]
    
    /// 交易监听任务
    private var transactionListener: Task<Void, Error>?
    
    // MARK: - 初始化
    
    init() {
        // 启动交易监听
        transactionListener = listenForTransactions()
        
        // 恢复今日使用量
        restoreDailyUsage()
        
        // 检查当前订阅状态
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - 产品加载
    
    /// 从App Store加载订阅产品
    func loadProducts() async {
        isLoading = true
        do {
            let storeProducts = try await Product.products(for: productIDs)
            // 按价格排序：月度在前，年度在后
            products = storeProducts.sorted { $0.price < $1.price }
            print("[订阅] 已加载 \(products.count) 个产品")
        } catch {
            print("[订阅] 加载产品失败: \(error)")
            errorMessage = String(localized: "sub.error.load")
        }
        isLoading = false
    }
    
    // MARK: - 购买
    
    /// 购买订阅
    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // 验证交易
                let transaction = try Self.checkVerified(verification)
                // 更新订阅状态
                await updateSubscriptionStatus(transaction)
                // 完成交易
                await transaction.finish()
                print("[订阅] 购买成功: \(product.displayName)")
                isLoading = false
                return true
                
            case .userCancelled:
                print("[订阅] 用户取消购买")
                isLoading = false
                return false
                
            case .pending:
                print("[订阅] 购买待处理（等待审批）")
                errorMessage = String(localized: "sub.error.pending")
                isLoading = false
                return false
                
            @unknown default:
                isLoading = false
                return false
            }
        } catch {
            print("[订阅] 购买失败: \(error)")
            errorMessage = "购买失败: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    // MARK: - 恢复购买
    
    /// 恢复已有购买
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
            print("[订阅] 恢复购买完成")
        } catch {
            print("[订阅] 恢复购买失败: \(error)")
            errorMessage = "恢复购买失败: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    // MARK: - 订阅状态检查
    
    /// 检查当前订阅状态
    func checkSubscriptionStatus() async {
        var hasActiveSubscription = false
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try Self.checkVerified(result)
                
                if transaction.productType == .autoRenewable {
                    if let expirationDate = transaction.expirationDate,
                       expirationDate > Date() {
                        hasActiveSubscription = true
                        self.expirationDate = expirationDate
                        
                        if let tier = SubscriptionTier(rawValue: transaction.productID) {
                            self.currentSubscription = tier
                        }
                    }
                }
            } catch {
                print("[订阅] 验证交易失败: \(error)")
            }
        }
        
        if !hasActiveSubscription {
            currentSubscription = .free
            expirationDate = nil
        }
    }
    
    // MARK: - 免费额度管理
    
    /// 检查是否可以继续使用（免费版额度检查）
    var canUseTranslation: Bool {
        if currentSubscription != .free { return true }
        return todayUsedSeconds < freeQuotaSeconds
    }
    
    /// 剩余免费秒数
    var remainingFreeSeconds: Int {
        max(0, freeQuotaSeconds - todayUsedSeconds)
    }
    
    /// 记录使用时长
    func recordUsage(seconds: Int) {
        guard currentSubscription == .free else { return }
        todayUsedSeconds += seconds
        saveDailyUsage()
    }
    
    /// 保存今日使用量
    private func saveDailyUsage() {
        let today = Calendar.current.startOfDay(for: Date())
        UserDefaults.standard.set(todayUsedSeconds, forKey: "daily_usage_seconds")
        UserDefaults.standard.set(today.timeIntervalSince1970, forKey: "daily_usage_date")
    }
    
    /// 恢复今日使用量（如果是新的一天则重置）
    private func restoreDailyUsage() {
        let today = Calendar.current.startOfDay(for: Date())
        let savedDate = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: "daily_usage_date"))
        
        if Calendar.current.isDate(today, inSameDayAs: savedDate) {
            todayUsedSeconds = UserDefaults.standard.integer(forKey: "daily_usage_seconds")
        } else {
            // 新的一天，重置额度
            todayUsedSeconds = 0
            saveDailyUsage()
        }
    }
    
    // MARK: - 交易监听
    
    /// 持续监听交易更新
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try Self.checkVerified(result)
                    await self?.updateSubscriptionStatus(transaction)
                    await transaction.finish()
                } catch {
                    print("[订阅] 交易更新验证失败: \(error)")
                }
            }
        }
    }
    
    /// 更新订阅状态
    private func updateSubscriptionStatus(_ transaction: Transaction) async {
        if transaction.productType == .autoRenewable {
            if let expirationDate = transaction.expirationDate,
               expirationDate > Date() {
                self.expirationDate = expirationDate
                if let tier = SubscriptionTier(rawValue: transaction.productID) {
                    self.currentSubscription = tier
                }
            } else if transaction.revocationDate != nil {
                self.currentSubscription = .free
                self.expirationDate = nil
            }
        }
    }
    
    // MARK: - 交易验证（静态方法，避免actor隔离问题）
    
    /// 验证交易签名
    /// 使用nonisolated static方法，使其可以在任何上下文中调用
    nonisolated static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
