import AppIntents
import Foundation

// MARK: - Start Practice Session

struct StartPracticeIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Pronunciation Practice"
    static var description = IntentDescription("Open Mimiq and start a coaching session with your AI pronunciation coach.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - Check My Streak

struct CheckStreakIntent: AppIntent {
    static var title: LocalizedStringResource = "Check My Practice Streak"
    static var description = IntentDescription("See your current pronunciation practice streak in Mimiq.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let streak = StreakService.shared.currentStreak
        let dialog: IntentDialog = streak > 0
            ? "Your current Mimiq streak is \(streak) day\(streak == 1 ? "" : "s"). Keep it going!"
            : "You don't have an active streak yet. Open Mimiq to start practising!"
        return .result(dialog: dialog)
    }
}

// MARK: - App Shortcuts (appear in Spotlight + Siri suggestions)

struct LingoLabShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartPracticeIntent(),
            phrases: [
                "Start \(.applicationName)",
                "Open \(.applicationName)",
                "Practice pronunciation with \(.applicationName)",
                "Practise with \(.applicationName)"
            ],
            shortTitle: "Practice",
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: CheckStreakIntent(),
            phrases: [
                "Check my \(.applicationName) streak",
                "How's my \(.applicationName) streak?"
            ],
            shortTitle: "My Streak",
            systemImageName: "flame.fill"
        )
    }
}
