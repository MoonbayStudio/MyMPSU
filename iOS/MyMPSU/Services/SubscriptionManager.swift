import Foundation
import StoreKit
internal import Combine

enum SubscriptionTier: String, CaseIterable, Comparable, Identifiable {
    case none
    case plus
    case premium

    var id: String { rawValue }

    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        lhs.rank < rhs.rank
    }

    private var rank: Int {
        switch self {
        case .none: return 0
        case .plus: return 1
        case .premium: return 2
        }
    }

    var displayName: String {
        switch self {
        case .none: return "Free"
        case .plus: return "MyMPSU Plus"
        case .premium: return "MyMPSU Premium"
        }
    }

    var shortName: String {
        switch self {
        case .none: return "Free"
        case .plus: return "Plus"
        case .premium: return "Premium"
        }
    }
}

enum SubscriptionPeriod: String, CaseIterable, Identifiable {
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly: return "Месяц"
        case .yearly: return "Год"
        }
    }

    var priceSuffix: String {
        switch self {
        case .monthly: return "в месяц"
        case .yearly: return "в год"
        }
    }

    var purchaseSuffix: String {
        switch self {
        case .monthly: return ""
        case .yearly: return " на год"
        }
    }
}

struct SubscriptionPlan: Identifiable, Equatable {
    let tier: SubscriptionTier
    let period: SubscriptionPeriod
    let productID: String
    let displayPrice: String
    let isAvailable: Bool

    var id: String { productID }

    var subtitle: String {
        switch tier {
        case .none:
            return "Базовые возможности"
        case .plus:
            return "Для активного использования"
        case .premium:
            return "Максимум возможностей"
        }
    }

    var benefits: [String] {
        switch tier {
        case .none:
            return [
                "Базовый лимит запросов к Помощнику МПГУ",
                "Стандартные темы",
                "Расписание",
                "Базовые виджеты и Live Activities"
            ]
        case .plus:
            return [
                "Больше запросов к Помощнику МПГУ",
                "Кастомные темы",
                "Поддержка развития приложения"
            ]
        case .premium:
            return [
                "Максимум запросов к Помощнику МПГУ",
                "Все кастомные темы",
                "Ранний доступ к новым функциям"
            ]
        }
    }
}

struct SubscriptionProduct: Identifiable, Equatable {
    let id: String
    let displayPrice: String
    let price: Decimal

    @available(macOS 12.0, *)
    init(product: Product) {
        id = product.id
        displayPrice = product.displayPrice
        price = product.price
    }
}

enum SubscriptionStoreState: Equatable {
    case idle
    case loadingProducts
    case productsLoaded
    case productLoadFailed
    case purchasing
    case purchaseCancelled
    case purchaseFailed
    case purchasePending
    case activePlus
    case activePremium
}

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    static let plusMonthlyProductID = "mympsu.plus.monthly"
    static let plusYearlyProductID = "mympsu.plus.yearly"
    static let premiumMonthlyProductID = "mympsu.premium.monthly"
    static let premiumYearlyProductID = "mympsu.premium.yearly"

    static let productIDs: Set<String> = [
        plusMonthlyProductID,
        plusYearlyProductID,
        premiumMonthlyProductID,
        premiumYearlyProductID
    ]

    @Published private(set) var productsByID: [String: SubscriptionProduct] = [:]
    @Published private(set) var activeTier: SubscriptionTier = .none
    @Published private(set) var activePeriod: SubscriptionPeriod?
    @Published private(set) var state: SubscriptionStoreState = .idle
    @Published private(set) var isLoading = false
    @Published private(set) var isPurchasing = false
    @Published var userMessage: String?

    private var updatesTask: Task<Void, Never>?
    private var storeProductsByID: [String: Any] = [:]

    private init() {
        if #available(macOS 12.0, *) {
            updatesTask = Task { [weak self] in
                for await result in Transaction.updates {
                    guard let self else { return }
                    if case .verified(let transaction) = result {
                        await transaction.finish()
                        await self.refreshEntitlements()
                    }
                }
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var products: [SubscriptionProduct] {
        Self.productIDs.compactMap { productsByID[$0] }
    }

    var hasPremium: Bool { activeTier == .premium }
    var hasPlus: Bool { activeTier == .plus }

    func bootstrap() async {
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        isLoading = true
        state = .loadingProducts
        userMessage = nil

        guard #available(macOS 12.0, *) else {
            storeProductsByID = [:]
            productsByID = [:]
            state = .productLoadFailed
            userMessage = "Подписки недоступны на этой версии macOS."
            isLoading = false
            return
        }

        do {
            let products = try await Product.products(for: Array(Self.productIDs))
            storeProductsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
            productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, SubscriptionProduct(product: $0)) })
            state = .productsLoaded
        } catch {
            storeProductsByID = [:]
            productsByID = [:]
            state = .productLoadFailed
            userMessage = "Не удалось загрузить подписки. Проверьте подключение и попробуйте ещё раз."
        }

        isLoading = false
    }

    func plan(tier: SubscriptionTier, period: SubscriptionPeriod) -> SubscriptionPlan {
        let productID = productID(for: tier, period: period)
        let product = productsByID[productID]
        return SubscriptionPlan(
            tier: tier,
            period: period,
            productID: productID,
            displayPrice: product?.displayPrice ?? "Недоступно",
            isAvailable: product != nil
        )
    }

    func availablePlans(for period: SubscriptionPeriod) -> [SubscriptionPlan] {
        [
            plan(tier: .plus, period: period),
            plan(tier: .premium, period: period)
        ]
    }

    func isYearlyBetterValue(for tier: SubscriptionTier) -> Bool {
        guard
            let monthly = productsByID[productID(for: tier, period: .monthly)],
            let yearly = productsByID[productID(for: tier, period: .yearly)]
        else {
            return false
        }

            let monthlyAnnualPrice = monthly.price * Decimal(12)
            return yearly.price < monthlyAnnualPrice
    }

    func purchase(_ plan: SubscriptionPlan) async {
        guard #available(macOS 12.0, *) else {
            userMessage = "Подписки недоступны на этой версии macOS."
            state = .purchaseFailed
            return
        }

        guard let product = storeProductsByID[plan.productID] as? Product else {
            userMessage = "Этот план сейчас недоступен. Попробуйте позже."
            state = .purchaseFailed
            return
        }

        guard activeTier != .premium else {
            userMessage = "Premium уже активен."
            state = .activePremium
            return
        }

        isPurchasing = true
        state = .purchasing
        userMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                userMessage = "Подписка активирована."
            case .pending:
                state = .purchasePending
                userMessage = "Покупка ожидает подтверждения."
            case .userCancelled:
                state = .purchaseCancelled
                userMessage = "Покупка отменена."
            @unknown default:
                state = .purchaseFailed
                userMessage = "Не удалось завершить покупку. Попробуйте ещё раз."
            }
        } catch {
            state = .purchaseFailed
            userMessage = "Не удалось завершить покупку. Попробуйте ещё раз."
        }

        isPurchasing = false
    }

    func restorePurchases() async {
        userMessage = nil
        isLoading = true

        guard #available(macOS 12.0, *) else {
            userMessage = "Подписки недоступны на этой версии macOS."
            isLoading = false
            return
        }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if activeTier == .none {
                userMessage = "Активных подписок не найдено."
            } else {
                userMessage = "Покупки восстановлены."
            }
        } catch {
            userMessage = "Не удалось восстановить покупки. Попробуйте ещё раз."
        }

        isLoading = false
    }

    func refreshEntitlements() async {
        guard #available(macOS 12.0, *) else {
            activeTier = .none
            activePeriod = nil
            return
        }

        var bestTier: SubscriptionTier = .none
        var bestPeriod: SubscriptionPeriod?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.revocationDate == nil else { continue }
            guard let tier = tier(for: transaction.productID) else { continue }

            if tier > bestTier {
                bestTier = tier
                bestPeriod = period(for: transaction.productID)
            }
        }

        activeTier = bestTier
        activePeriod = bestPeriod

        switch bestTier {
        case .none:
            if state == .activePlus || state == .activePremium {
                state = .productsLoaded
            }
        case .plus:
            state = .activePlus
        case .premium:
            state = .activePremium
        }
    }

    func productID(for tier: SubscriptionTier, period: SubscriptionPeriod) -> String {
        switch (tier, period) {
        case (.plus, .monthly): return Self.plusMonthlyProductID
        case (.plus, .yearly): return Self.plusYearlyProductID
        case (.premium, .monthly): return Self.premiumMonthlyProductID
        case (.premium, .yearly): return Self.premiumYearlyProductID
        case (.none, _): return ""
        }
    }

    func tier(for productID: String) -> SubscriptionTier? {
        switch productID {
        case Self.plusMonthlyProductID, Self.plusYearlyProductID:
            return .plus
        case Self.premiumMonthlyProductID, Self.premiumYearlyProductID:
            return .premium
        default:
            return nil
        }
    }

    func period(for productID: String) -> SubscriptionPeriod? {
        switch productID {
        case Self.plusMonthlyProductID, Self.premiumMonthlyProductID:
            return .monthly
        case Self.plusYearlyProductID, Self.premiumYearlyProductID:
            return .yearly
        default:
            return nil
        }
    }

    @available(macOS 12.0, *)
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

private enum StoreError: Error {
    case failedVerification
}
