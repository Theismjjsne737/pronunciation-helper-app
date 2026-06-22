import UserNotifications
import Foundation

/// Manages local notification permissions and daily practice reminders.
@MainActor
final class NotificationService: ObservableObject {

    static let shared = NotificationService()

    // MARK: - Published

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var reminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(reminderEnabled, forKey: Self.reminderKey)
            if reminderEnabled {
                Task { await scheduleReminder() }
            } else {
                cancelReminder()
            }
        }
    }
    @Published var reminderHour: Int {
        didSet {
            UserDefaults.standard.set(reminderHour, forKey: Self.hourKey)
            if reminderEnabled { Task { await scheduleReminder() } }
        }
    }

    // MARK: - Constants

    static let reminderKey   = "lingolab_reminder_enabled"
    static let hourKey       = "lingolab_reminder_hour"
    static let notifID       = "lingolab.daily_practice"

    // MARK: - Init

    private init() {
        reminderEnabled = UserDefaults.standard.bool(forKey: Self.reminderKey)
        reminderHour    = UserDefaults.standard.object(forKey: Self.hourKey) as? Int ?? 9
        Task { await refreshStatus() }
    }

    // MARK: - Permission request

    /// Call this once during onboarding. Returns true if permission was granted.
    @discardableResult
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshStatus()
            if granted && reminderEnabled {
                await scheduleReminder()
            }
            return granted
        } catch {
            return false
        }
    }

    // MARK: - Status refresh

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - Schedule daily reminder

    func scheduleReminder() async {
        guard authorizationStatus == .authorized else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notifID])

        let content = UNMutableNotificationContent()
        content.title = "Time to practise! 🎙️"
        content.body  = "A quick session keeps your accent progress on track."
        content.sound = .default

        var comps = DateComponents()
        comps.hour   = reminderHour
        comps.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.notifID,
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    // MARK: - Cancel

    func cancelReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.notifID])
    }

    // MARK: - Helpers

    /// Human-readable label for the reminder hour (e.g. "9:00 AM")
    var reminderTimeLabel: String {
        var comps = DateComponents()
        comps.hour   = reminderHour
        comps.minute = 0
        let date = Calendar.current.date(from: comps) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    var isAuthorized: Bool { authorizationStatus == .authorized }
}
