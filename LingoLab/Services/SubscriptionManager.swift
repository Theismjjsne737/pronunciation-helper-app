import StoreKit
import Foundation

// MARK: - Subscription tier

enum SubscriptionTier: String, CaseIterable, Identifiable {
    case monthly = "com.yourname.lingolab.monthly"
    case yearly  = "com.yourname.lingolab.yearly"

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
    @Published private(set) var products: [Product] = []
    @Published private(set) var uniqueWordCount: Int = 0
    @Published var isPurchasing = false
    @Published var purchaseError: String?
    @Published var restoreSuccess = false

    // MARK: - Constants

    static let productIDs: [String] = SubscriptionTier.allCases.map(\.rawValue)
    static let freeWordLimit = 5

    // MARK: - Private

    private var transactionListener: Task<Void, Never>?
    private static let wordsKey = "lingolab_practiced_words_v2"

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
            found = true
            break
        }
        if !found {
            hasActiveSubscription = false
            currentTier = nil
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
        Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let tx) = result else { continue }
                if let self { await self.refreshStatus() }
                await tx.finish()
            }
        }
    }

    // MARK: - Word counter

    var wordsRemaining: Int { max(0, Self.freeWordLimit - uniqueWordCount) }
    var hasUsedAllFreeWords: Bool { uniqueWordCount >= Self.freeWordLimit }

    func hasSeenWord(_ word: String) -> Bool {
        storedWords().contains(canonical(word))
    }

    func markWordSeen(_ word: String) {
        var words = storedWords()
        words.insert(canonical(word))
        saveWords(words)
        uniqueWordCount = words.count
    }

    /// Resets the free-word counter (e.g. after a refund or for debug purposes).
    func resetWordCounter() {
        saveWords([])
        uniqueWordCount = 0
    }

    // MARK: - Computed helpers

    var subscriptionStatusLabel: String {
        guard hasActiveSubscription else { return "Free (\(wordsRemaining) word\(wordsRemaining == 1 ? "" : "s") left)" }
        return currentTier?.displayName.appending(" Plan") ?? "Active"
    }

    // MARK: - Private storage

    private func storedWords() -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: Self.wordsKey),
              let array = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(array)
    }

    private func saveWords(_ words: Set<String>) {
        if let data = try? JSONEncoder().encode(Array(words)) {
            UserDefaults.standard.set(data, forKey: Self.wordsKey)
        }
    }

    private func canonical(_ word: String) -> String {
        word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
