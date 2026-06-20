import SwiftUI
import SwiftData
import UserNotifications

@main
struct MimiqApp: App {

    let container: ModelContainer

    init() {
        let schema = Schema([ChatMessage.self, AccentProfile.self, SavedWord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("SwiftData container failed to initialise: \(error)")
        }

        // Register Siri shortcuts on every launch
        MimiqShortcuts.updateAppShortcutParameters()
    }

    @StateObject private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .environmentObject(authViewModel)
                .task {
                    // Initialise services in parallel
                    async let auth: ()   = authViewModel.restoreSession()
                    async let subs: ()   = SubscriptionManager.shared.initialise()
                    async let notifs: () = NotificationService.shared.refreshStatus()
                    async let streak: () = StreakService.shared.recordPractice() // no-op if already done today
                    _ = await (auth, subs, notifs, streak)
                }
        }
    }
}
