import SwiftUI
import SwiftData
import UserNotifications

@main
struct PronceApp: App {

    let container: ModelContainer

    init() {
        let schema = Schema([ChatMessage.self, AccentProfile.self, SavedWord.self, PracticeSession.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            do {
                let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                container = try ModelContainer(for: schema, configurations: fallback)
            } catch {
                fatalError("SwiftData failed to initialise even in-memory: \(error)")
            }
        }

        // Register Siri shortcuts on every launch
        PronceShortcuts.updateAppShortcutParameters()
    }

    @StateObject private var authViewModel = AuthViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .environmentObject(authViewModel)
                .task {
                    async let auth: ()   = authViewModel.restoreSession()
                    async let subs: ()   = SubscriptionManager.shared.initialise()
                    async let notifs: () = NotificationService.shared.refreshStatus()
                    async let streak: () = StreakService.shared.recordPractice()
                    _ = await (auth, subs, notifs, streak)

                    if let userID = authViewModel.currentUser?.id {
                        await SupabaseSyncService.shared.pull(userID: userID, into: container.mainContext)
                    }
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .background,
                  let userID = authViewModel.currentUser?.id
            else { return }
            Task {
                let profiles = (try? container.mainContext.fetch(FetchDescriptor<AccentProfile>())) ?? []
                if let profile = profiles.first {
                    await SupabaseSyncService.shared.push(userID: userID, profile: profile)
                }
            }
        }
    }
}
