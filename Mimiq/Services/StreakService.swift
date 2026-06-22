import Foundation
import SwiftUI

/// Tracks consecutive daily practice streaks and persists them in UserDefaults.
@MainActor
final class StreakService: ObservableObject {

    static let shared = StreakService()

    // MARK: - Published

    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var longestStreak: Int = 0
    @Published private(set) var practicedToday: Bool = false
    @Published private(set) var totalPracticeDays: Int = 0
    @Published private(set) var weekActivity: [Bool] = Array(repeating: false, count: 7) // last 7 days

    // MARK: - Keys

    private enum Key {
        static let currentStreak   = "streak_current"
        static let longestStreak   = "streak_longest"
        static let totalDays       = "streak_total_days"
        static let lastPractice    = "streak_last_date"
        static let history         = "streak_history_v2" // [ISO date string]: Bool
    }

    // MARK: - Init

    private init() { load() }

    // MARK: - Record practice (call after every pronunciation attempt)

    func recordPractice() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        if let last = lastPracticeDate() {
            let lastDay = cal.startOfDay(for: last)

            if lastDay == today {
                practicedToday = true
                return // Already recorded today — don't double-count
            }

            let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
            currentStreak = (lastDay == yesterday) ? currentStreak + 1 : 1
        } else {
            currentStreak = 1
        }

        practicedToday = true
        totalPracticeDays += 1

        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }

        UserDefaults.standard.set(today, forKey: Key.lastPractice)
        markHistoryDate(today)
        save()
        updateWeekActivity()
        ReviewService.shared.recordStreakMilestone(currentStreak)
        let streak = currentStreak
        let practiced = practicedToday
        Task { await NotificationService.shared.scheduleSmartNotifications(currentStreak: streak, practicedToday: practiced) }
    }

    // MARK: - Load / Save

    private func load() {
        currentStreak    = UserDefaults.standard.integer(forKey: Key.currentStreak)
        longestStreak    = UserDefaults.standard.integer(forKey: Key.longestStreak)
        totalPracticeDays = UserDefaults.standard.integer(forKey: Key.totalDays)

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        if let last = lastPracticeDate() {
            let lastDay = cal.startOfDay(for: last)
            practicedToday = lastDay == today

            // Break streak if more than 1 day has passed
            let daysMissed = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if daysMissed > 1 && currentStreak > 0 {
                currentStreak = 0
                save()
            }
        }
        updateWeekActivity()
    }

    private func save() {
        UserDefaults.standard.set(currentStreak,     forKey: Key.currentStreak)
        UserDefaults.standard.set(longestStreak,     forKey: Key.longestStreak)
        UserDefaults.standard.set(totalPracticeDays, forKey: Key.totalDays)
    }

    // MARK: - History tracking (for week dots)

    private func markHistoryDate(_ date: Date) {
        var history = loadHistory()
        history[isoDate(date)] = true
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: Key.history)
        }
    }

    private func loadHistory() -> [String: Bool] {
        guard let data = UserDefaults.standard.data(forKey: Key.history),
              let dict = try? JSONDecoder().decode([String: Bool].self, from: data) else { return [:] }
        return dict
    }

    private func updateWeekActivity() {
        let history = loadHistory()
        let cal = Calendar.current
        weekActivity = (0..<7).reversed().map { daysAgo in
            let date = cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: Date()))!
            return history[isoDate(date)] == true
        }
    }

    private func isoDate(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date).prefix(10).description
    }

    private func lastPracticeDate() -> Date? {
        UserDefaults.standard.object(forKey: Key.lastPractice) as? Date
    }
}
