import Foundation
import SwiftUI

/// XP + levelling system. Earns XP per pronunciation attempt; higher scores earn bonus XP.
/// Level formula: level = floor(sqrt(totalXP / 50)), so each level costs progressively more.
@MainActor
final class GamificationService: ObservableObject {

    static let shared = GamificationService()

    @Published private(set) var totalXP: Int = 0
    @Published private(set) var level: Int = 0
    @Published private(set) var levelTitle: String = ""
    @Published private(set) var xpToNextLevel: Int = 50
    @Published private(set) var xpInCurrentLevel: Int = 0
    @Published private(set) var levelProgress: Double = 0
    /// Non-nil for one cycle when the user levels up — used to trigger celebration UI.
    @Published var levelUpEvent: Int? = nil

    private enum Key {
        static let totalXP = "gamification_total_xp_v1"
    }

    private init() { load() }

    // MARK: - Award XP

    /// Call after each pronunciation attempt. Score is 0.0–1.0.
    func award(score: Double) {
        let base = 10
        let bonus: Int
        switch score {
        case 0.95...: bonus = 15
        case 0.85...: bonus = 8
        case 0.70...: bonus = 3
        default:      bonus = 0
        }
        let previousLevel = level
        totalXP += base + bonus
        UserDefaults.standard.set(totalXP, forKey: Key.totalXP)
        recompute()
        if level > previousLevel {
            levelUpEvent = level
            ReviewService.shared.recordLevelUp()
        }
    }

    // MARK: - Level computation
    // Level n requires n² × 50 total XP. Level = floor(sqrt(xp / 50)).

    private func recompute() {
        let newLevel = Int(sqrt(Double(totalXP) / 50.0))
        level = newLevel
        levelTitle = titles[min(newLevel, titles.count - 1)]
        let currentFloor = newLevel * newLevel * 50
        let nextFloor    = (newLevel + 1) * (newLevel + 1) * 50
        let span         = nextFloor - currentFloor
        xpInCurrentLevel = totalXP - currentFloor
        xpToNextLevel    = span
        levelProgress    = Double(xpInCurrentLevel) / Double(span)
    }

    private func load() {
        totalXP = UserDefaults.standard.integer(forKey: Key.totalXP)
        recompute()
    }

    private let titles: [String] = [
        "Newcomer", "Listener", "Mimic", "Learner", "Practitioner",
        "Speaker", "Communicator", "Articulator", "Fluent", "Polished",
        "Eloquent", "Refined", "Proficient", "Expert", "Master"
    ]
}
