import StoreKit
import Foundation
import UIKit

/// Triggers App Store review prompts at high-value moments. One prompt per app version max.
@MainActor
final class ReviewService {

    static let shared = ReviewService()
    private init() {}

    private enum Key {
        static let lastReviewedVersion = "review_last_prompted_version"
        static let goodScoreCount      = "review_good_score_count"
    }

    // MARK: - Trigger points

    /// Call after each attempt. Prompts after 3 scores ≥ 80%.
    func recordGoodScore(_ score: Double) {
        guard score >= 0.8 else { return }
        let count = UserDefaults.standard.integer(forKey: Key.goodScoreCount) + 1
        UserDefaults.standard.set(count, forKey: Key.goodScoreCount)
        if count == 3 { requestReview() }
    }

    func recordLevelUp() {
        requestReview()
    }

    func recordStreakMilestone(_ streak: Int) {
        guard [3, 7, 14, 30].contains(streak) else { return }
        requestReview()
    }

    // MARK: - Internal

    private func requestReview() {
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        guard UserDefaults.standard.string(forKey: Key.lastReviewedVersion) != current else { return }
        UserDefaults.standard.set(current, forKey: Key.lastReviewedVersion)

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }

        AppStore.requestReview(in: scene)
    }
}
