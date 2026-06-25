import StoreKit
import Foundation

// MARK: - Subscription tier

enum SubscriptionTier: String, CaseIterable, Identifiable {
    case monthly = "com.rhearao.Pronce.monthly"
    case yearly  = "com.rhearao.Pronce.yearly"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly:  return "Yearly"
        }
    }

    var billingDescription: String {
        switch self {
        case .monthly: return "Billed monthly, cancel anytime"
        case .yearly:  return "$8.33/month • Save 44%"
        }
    }

    var isBestValue: Bool { self == .yearly }

    /// Shown as a coloured pill on the plan card. nil = no badge.
    var savingsBadge: String? {
        switch self {
        case .yearly:  return "SAVE 44%"
        case .monthly: return nil
        }
    }

    init?(productID: String) { self.init(rawValue: productID) }
}

// MARK: - Purchase result (for UI feedback)

enum PurchaseResult {
    case success
    case pending    // Ask to Buy / parental approval
    case cancelled
    case failed(String)
}

// MARK: - SubscriptionManager

/// Single source of truth for StoreKit 2 subscription state and the free-tier word counter.
@MainActor
final class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()

    // MARK: - Published state

    @Published private(set) var hasActiveSubscription = false
    @Published private(set) var currentTier: SubscriptionTier?
    @Published private(set) var renewalDate: Date?
    @Published private(set) var products: [Product] = []
    @Published var isPurchasing = false
    @Published var purchaseError: String?
    @Published var restoreSuccess = false

    // MARK: - Constants

    static let productIDs: [String] = SubscriptionTier.allCases.map(\.rawValue)
    static let freeWordLimit = 5
    private static let wordsKey = "pronce_free_words_v1"

    // MARK: - Free-tier word counter

    @Published private(set) var uniqueWordCount: Int = 0

    var wordsRemaining: Int { max(0, Self.freeWordLimit - uniqueWordCount) }
    var hasUsedAllFreeWords: Bool { uniqueWordCount >= Self.freeWordLimit }

    func hasSeenWord(_ word: String) -> Bool { storedWords().contains(canonical(word)) }

    func markWordSeen(_ word: String) {
        var words = storedWords()
        let key = canonical(word)
        guard !words.contains(key) else { return }
        words.insert(key)
        saveWords(words)
        uniqueWordCount = words.count
    }

    private func storedWords() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.wordsKey) ?? [])
    }

    private func saveWords(_ words: Set<String>) {
        UserDefaults.standard.set(Array(words), forKey: Self.wordsKey)
    }

    private func canonical(_ word: String) -> String {
        word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private

    private var transactionListener: Task<Void, Never>?

    // MARK: - Init / deinit

    private init() {
        uniqueWordCount = storedWords().count
        transactionListener = startTransactionListener()
    }

    deinit { transactionListener?.cancel() }

    // MARK: - Launch check

    /// Call once on app launch to refresh subscription status.
    func initialise() async {
        async let productsTask: () = loadProducts()
        async let statusTask: () = refreshStatus()
        _ = await (productsTask, statusTask)
    }

    // MARK: - Subscription status

    func refreshStatus() async {
        var found = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result,
                  tx.revocationDate == nil,
                  SubscriptionTier(productID: tx.productID) != nil else { continue }
            hasActiveSubscription = true
            currentTier = SubscriptionTier(productID: tx.productID)
            renewalDate = tx.expirationDate
            found = true
            break
        }
        if !found {
            hasActiveSubscription = false
            currentTier = nil
            renewalDate = nil
        }
    }

    // MARK: - Products

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: Self.productIDs)
            // Sort: yearly first (higher price = better value featured first)
            products = loaded.sorted { $0.price > $1.price }
        } catch {
            purchaseError = "Couldn't load products: \(error.localizedDescription)"
        }
    }

    func product(for tier: SubscriptionTier) -> Product? {
        for prod in products {
            if prod.id == tier.rawValue {
                return prod
            }
        }
        return nil
    }

    // MARK: - Purchase

    @discardableResult
    func purchase(_ product: Product) async -> PurchaseResult {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let tx) = verification else {
                    let msg = "Purchase verification failed."
                    purchaseError = msg
                    return .failed(msg)
                }
                await tx.finish()
                await refreshStatus()
                return .success

            case .pending:
                return .pending

            case .userCancelled:
                return .cancelled

            @unknown default:
                return .cancelled
            }
        } catch {
            purchaseError = error.localizedDescription
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        isPurchasing = true
        restoreSuccess = false
        defer { isPurchasing = false }

        do {
            try await AppStore.sync()
            await refreshStatus()
            restoreSuccess = hasActiveSubscription
            if !hasActiveSubscription {
                purchaseError = "No active subscription found to restore."
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Transaction listener (handles renewals, refunds, etc.)

    private func startTransactionListener() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let tx) = result else { continue }
                await tx.finish()
                await self?.refreshStatus()
            }
        }
    }

    var canAccessPro: Bool { hasActiveSubscription || !hasUsedAllFreeWords }

    // Test support only — resets in-memory counter to match UserDefaults state
    func resetWordCounterForTesting() {
        uniqueWordCount = storedWords().count
    }

    // MARK: - Computed helpers

    var subscriptionStatusLabel: String {
        if hasActiveSubscription { return currentTier?.displayName.appending(" Plan") ?? "Active" }
        return "\(wordsRemaining) free word\(wordsRemaining == 1 ? "" : "s") remaining"
    }
}
