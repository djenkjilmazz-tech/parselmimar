import Foundation
import StoreKit

@MainActor
class StoreKitService: ObservableObject {
    static let shared = StoreKitService()

    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false

    var isPro: Bool {
        purchasedProductIDs.contains(ProductID.monthlyPro) ||
        purchasedProductIDs.contains(ProductID.yearlyPro) ||
        purchasedProductIDs.contains(ProductID.lifetime)
    }

    // MARK: - Free Tier Daily Calculation Limit

    private static let calcCountKey = "pm_dailyCalcCount"
    private static let calcDateKey  = "pm_lastCalcDate"
    static let freeDailyLimit = 3

    @Published private(set) var dailyCalcCount: Int = 0

    var canCalculate: Bool { isPro || dailyCalcCount < Self.freeDailyLimit }
    var remainingFreeCalcs: Int { isPro ? Int.max : max(0, Self.freeDailyLimit - dailyCalcCount) }

    func recordCalculation() {
        guard !isPro else { return }
        dailyCalcCount = min(dailyCalcCount + 1, Self.freeDailyLimit)
        UserDefaults.standard.set(dailyCalcCount, forKey: Self.calcCountKey)
        UserDefaults.standard.set(Date(), forKey: Self.calcDateKey)
    }

    struct ProductID {
        static let monthlyPro = "com.parselmimar.pro.monthly"
        static let yearlyPro = "com.parselmimar.pro.yearly"
        static let lifetime = "com.parselmimar.pro.lifetime"
        static let singleReport = "com.parselmimar.report.single"

        static let all = [monthlyPro, yearlyPro, lifetime, singleReport]
        static let subscriptions = [monthlyPro, yearlyPro]
    }

    private var transactionListener: Task<Void, Error>?

    private init() {
        // Load today's calculation count from UserDefaults
        let lastDate = UserDefaults.standard.object(forKey: Self.calcDateKey) as? Date ?? .distantPast
        dailyCalcCount = Calendar.current.isDateInToday(lastDate)
            ? UserDefaults.standard.integer(forKey: Self.calcCountKey)
            : 0

        transactionListener = listenForTransactions()
        Task { await loadProducts() }
        Task { await updatePurchasedProducts() }
    }

    deinit {
        transactionListener?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: ProductID.all)
                .sorted { $0.price < $1.price }
        } catch {
            print("Ürünler yüklenemedi: \(error)")
        }
    }

    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updatePurchasedProducts()
            return true
        case .userCancelled:
            return false
        case .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await updatePurchasedProducts()
    }

    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                purchased.insert(transaction.productID)
            }
        }

        purchasedProductIDs = purchased
    }

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                if let transaction = try? self.checkVerified(result) {
                    await transaction.finish()
                    await self.updatePurchasedProducts()
                }
            }
        }
    }
}

enum StoreKitError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification: return "Satın alma doğrulanamadı"
        }
    }
}
