import SwiftUI
import SwiftData

struct SettingsView: View {

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Query(filter: #Predicate<AccentProfile> { _ in true }) private var profiles: [AccentProfile]
    @ObservedObject private var subs   = SubscriptionManager.shared
    @ObservedObject private var notifs = NotificationService.shared
    @AppStorage("practiceLanguage") private var practiceLanguage = SupportedLanguage.default.rawValue

    @State private var showResetAlert = false
    @State private var showPaywall    = false

    private var profile: AccentProfile? { profiles.first }

    private let bg       = Color(red: 0.06, green: 0.06, blue: 0.10)
    private let rowBg    = Color(red: 0.10, green: 0.10, blue: 0.16)
    private let violet   = Color(red: 0.53, green: 0.39, blue: 0.98)
    private let offWhite = Color(red: 0.94, green: 0.93, blue: 0.98)
    private let muted    = Color(red: 0.55, green: 0.53, blue: 0.65)
    private let sep      = Color.white.opacity(0.07)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    profileRow
                    if !subs.hasActiveSubscription { upgradeRow }

                    section("PREFERENCES") {
                        settingRow(icon: "globe", color: .blue, label: "Practice Language") {
                            Picker("", selection: $practiceLanguage) {
                                ForEach(SupportedLanguage.allCases) { lang in
                                    Text("\(lang.flag) \(lang.displayName)").tag(lang.rawValue)
                                }
                            }
                            .labelsHidden()
                            .tint(muted)
                        }
                        separator
                        notificationRow
                    }

                    section("ACCOUNT") {
                        settingRow(
                            icon: subs.hasActiveSubscription ? "checkmark.seal.fill" : "sparkles",
                            color: subs.hasActiveSubscription ? .green : violet,
                            label: subs.hasActiveSubscription ? "Premium" : "Free Plan"
                        ) {
                            Text(subs.subscriptionStatusLabel).font(.system(size: 13)).foregroundStyle(muted)
                        }
                        separator
                        Button { Task { await subs.restorePurchases() } } label: {
                            settingRow(icon: "arrow.clockwise", color: .orange, label: "Restore Purchases") {
                                if subs.restoreSuccess { Image(systemName: "checkmark").foregroundStyle(.green) }
                            }
                        }
                        if subs.hasActiveSubscription, let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            separator
                            Link(destination: url) {
                                settingRow(icon: "creditcard", color: .purple, label: "Manage Subscription") {
                                    Image(systemName: "chevron.right").foregroundStyle(muted)
                                }
                            }
                        }
                    }

                    section("ACCENT PROFILE") {
                        if let p = profile {
                            settingRow(icon: "textformat.abc", color: .teal, label: "Words Practised") {
                                Text("\(p.totalPracticeWords)").foregroundStyle(muted)
                            }
                            separator
                            settingRow(icon: "waveform", color: violet, label: "Phoneme Patterns") {
                                Text("\(p.phonemePatterns.count)").foregroundStyle(muted)
                            }
                            separator
                            Button { showResetAlert = true } label: {
                                settingRow(icon: "arrow.counterclockwise", color: .red, label: "Reset Profile") {
                                    Image(systemName: "chevron.right").foregroundStyle(muted)
                                }
                            }
                        }
                    }

                    Button { authViewModel.signOut() } label: {
                        Text("Sign Out")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(rowBg)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
                .padding(.top, 8)
            }
            .background(bg.ignoresSafeArea())
            .preferredColorScheme(.dark)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .alert("Reset Accent Profile?", isPresented: $showResetAlert) {
                Button("Reset", role: .destructive) {
                    profile?.phonemePatterns = []
                    profile?.totalPracticeWords = 0
                    profile?.totalSessions = 0
                    try? modelContext.save()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Clears learned phoneme patterns. Chat history is kept.")
            }
        }
    }

    // MARK: - Profile row

    private var profileRow: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(violet.opacity(0.2)).frame(width: 56, height: 56)
                Text(initials).font(.system(size: 22, weight: .bold)).foregroundStyle(violet)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(authViewModel.currentUser?.fullName ?? "Pronce User")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(offWhite)
                if let email = authViewModel.currentUser?.email {
                    Text(email).font(.system(size: 13)).foregroundStyle(muted)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var initials: String {
        let name = authViewModel.currentUser?.fullName ?? "M"
        return name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined()
    }

    // MARK: - Upgrade banner

    private var upgradeRow: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill").foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Upgrade to Premium")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(offWhite)
                    Text("Unlock unlimited words")
                        .font(.system(size: 12)).foregroundStyle(muted)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(muted)
            }
            .padding(16)
            .background(violet.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(violet.opacity(0.3), lineWidth: 1))
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Notification row

    @ViewBuilder
    private var notificationRow: some View {
        switch notifs.authorizationStatus {
        case .notDetermined:
            Button { Task { await notifs.requestPermission() } } label: {
                settingRow(icon: "bell.badge.fill", color: .orange, label: "Enable Reminders") {
                    Image(systemName: "chevron.right").foregroundStyle(muted)
                }
            }
        case .denied:
            settingRow(icon: "bell.slash", color: .gray, label: "Notifications Off") {
                Button("Enable") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 13, weight: .medium)).foregroundStyle(violet)
            }
        default:
            settingRow(icon: "bell.fill", color: .orange, label: "Daily Reminder") {
                Toggle("", isOn: $notifs.reminderEnabled).tint(violet).labelsHidden()
            }
        }
    }

    // MARK: - Primitives

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(muted)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            VStack(spacing: 0) { content() }
                .background(rowBg)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
        }
    }

    private func settingRow<T: View>(icon: String, color: Color, label: String, @ViewBuilder trailing: () -> T) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.18)).frame(width: 34, height: 34)
                Image(systemName: icon).font(.system(size: 15)).foregroundStyle(color)
            }
            Text(label).font(.system(size: 15)).foregroundStyle(offWhite)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var separator: some View {
        Rectangle().fill(sep).frame(height: 1).padding(.leading, 64)
    }
}
