import Foundation
import SwiftUI

/// One curated tricky word per day — same word for every user on the same calendar day.
@MainActor
final class DailyChallengeService: ObservableObject {

    static let shared = DailyChallengeService()

    @Published private(set) var todaysWord: String = ""
    @Published private(set) var completedToday: Bool = false

    private init() {
        todaysWord = Self.wordForToday()
        completedToday = Self.isCompletedToday()
    }

    func markCompleted() {
        UserDefaults.standard.set(true, forKey: completionKey)
        completedToday = true
    }

    var completionKey: String {
        "daily_challenge_completed_\(Self.todayISO)"
    }

    static func wordForToday() -> String {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return challengeWords[(day - 1) % challengeWords.count]
    }

    static func isCompletedToday() -> Bool {
        UserDefaults.standard.bool(forKey: "daily_challenge_completed_\(todayISO)")
    }

    static var todayISO: String {
        ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date())).prefix(10).description
    }

    private static let challengeWords: [String] = [
        "Worcestershire", "Nguyen", "quinoa", "colonel", "Joaquin",
        "Siobhan", "chipotle", "February", "hyperbole", "mischievous",
        "espresso", "sherbet", "niche", "pronunciation", "epitome",
        "entrepreneur", "hierarchy", "omniscient", "particularly", "deteriorate",
        "specifically", "comfortable", "temperature", "literally", "library",
        "schedule", "aluminum", "caramel", "pecan", "cache"
    ]
}
