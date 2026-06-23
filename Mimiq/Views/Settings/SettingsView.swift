import SwiftUI
import SwiftData

struct SettingsView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<AccentProfile> { _ in true }) private var profiles: [AccentProfile]
    @ObservedObject private var subs   = SubscriptionManager.shared
    @ObservedObject private var notifs = NotificationService.shared
    @AppStorage("practiceLanguage") private var practiceLanguage = SupportedLanguage.default.rawValue

    @State private var showResetAlert = false
    @State private var showPaywall    = false

    private var profile: AccentProfile? { profiles.first }

    // MARK: - Tokens
    private let navy     = Color(red: 0.027, green: 0.020, blue: 0.059)
    private let violet   = Color(red: 0.482, green: 0.333, blue: 1.0)
    private let lavender = Color(red: 0.773, green: 0.722, blue: 1.0)
    private let offWhite = Color(red: 0.941, green: 0.933, blue: 1.0)
    private let cardBg   = Color.white.opacity(0.04)
    private let border   = Color(red: 0.482, green: 0.333, blue: 1.0).opacity(0.18)

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    subscriptionCard
                    notificationCard
                    languageCard
                    accentCard
                    aboutCard
                }
                .padding(.bottom, 48)
            }
            .background(navy.ignoresSafeArea())
            .preferredColorScheme(.dark)
            .navigationBarHidden(true)
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
                Text("Clears all learned phoneme patterns. Your chat history is kept.")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings")
                .font(.system(size: 42, weight: .bold, design: .serif))
                .foregroundStyle(offWhite)
            Text("Manage your subscription, reminders, and accent profile.")
                .font(.system(size: 13))
                .foregroundStyle(offWhite.opacity(0.58))
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Subscription

    private var subscriptionCard: some View {
        card {
            cardHeader("Subscription")

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(subs.hasActiveSubscription ? Color.green.opacity(0.15) : violet.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: subs.hasActiveSubscription ? "checkmark.seal.fill" : "sparkles")
                        .font(.system(size: 18))
                        .foregroundStyle(subs.hasActiveSubscription ? Color.green : violet)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(subs.hasActiveSubscription ? "Premium" : "Free Plan")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(offWhite)
                    Text(subs.subscriptionStatusLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(offWhite.opacity(0.58))
                }
                Spacer()
                if subs.hasActiveSubscription {
                    Text("Active")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.green.opacity(0.3), lineWidth: 1))
                }
            }

            if subs.hasActiveSubscription {
                divider

                if let date = subs.renewalDate {
                    infoRow(label: "Renews", value: date.formatted(date: .abbreviated, time: .omitted))
                }

                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    Link(destination: url) {
                        rowItem(icon: "arrow.up.right.square", label: "Manage Subscription") {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(offWhite.opacity(0.3))
                        }
                        .foregroundStyle(offWhite)
                    }
                    .padding(.top, 8)
                }

                Button { Task { await subs.restorePurchases() } } label: {
                    rowItem(
                        icon: subs.restoreSuccess ? "checkmark.circle.fill" : "arrow.clockwise",
                        label: subs.restoreSuccess ? "Subscription Restored ✓" : "Restore Purchases"
                    ) { EmptyView() }
                    .foregroundStyle(subs.restoreSuccess ? Color.green : lavender)
                }
                .disabled(subs.isPurchasing)
                .padding(.top, 8)

                Text("To cancel, go to App Store → Settings → Subscriptions.")
                    .font(.system(size: 11))
                    .foregroundStyle(offWhite.opacity(0.35))
                    .padding(.top, 8)

            } else {
                divider

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Free words used")
                            .font(.system(size: 12))
                            .foregroundStyle(offWhite.opacity(0.58))
                        Spacer()
                        Text("\(subs.uniqueWordCount) / \(SubscriptionManager.freeWordLimit)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(subs.hasUsedAllFreeWords ? Color.red : offWhite)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(subs.hasUsedAllFreeWords ? Color.red : violet)
                                .frame(
                                    width: geo.size.width * min(1.0, Double(subs.uniqueWordCount) / Double(SubscriptionManager.freeWordLimit)),
                                    height: 6
                                )
                                .animation(.easeOut, value: subs.uniqueWordCount)
                        }
                    }
                    .frame(height: 6)
                }

                divider

                Button { Task { await subs.restorePurchases() } } label: {
                    rowItem(
                        icon: subs.restoreSuccess ? "checkmark.circle.fill" : "arrow.clockwise",
                        label: subs.restoreSuccess ? "Restored ✓" : "Restore Previous Purchase"
                    ) { EmptyView() }
                    .foregroundStyle(subs.restoreSuccess ? Color.green : offWhite.opacity(0.58))
                }
                .disabled(subs.isPurchasing)
                .padding(.bottom, 12)

                Button { showPaywall = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                        Text("Upgrade to Premium")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [violet, Color(red: 0.35, green: 0.20, blue: 0.90)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    // MARK: - Notifications

    private var notificationCard: some View {
        card {
            cardHeader("Notifications")

            switch notifs.authorizationStatus {
            case .notDetermined:
                Button { Task { await notifs.requestPermission() } } label: {
                    rowItem(icon: "bell.badge.fill", label: "Enable Daily Reminders") {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(offWhite.opacity(0.3))
                    }
                    .foregroundStyle(Color.orange)
                }

            case .denied:
                rowItem(icon: "bell.slash", label: "Notifications blocked") {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(violet)
                }
                .foregroundStyle(offWhite.opacity(0.58))

            default:
                rowItem(icon: "bell.fill", label: "Daily reminder") {
                    Toggle("", isOn: $notifs.reminderEnabled)
                        .tint(violet)
                        .labelsHidden()
                }

                if notifs.reminderEnabled {
                    divider
                    rowItem(icon: "clock", label: "Reminder time") {
                        Picker("", selection: $notifs.reminderHour) {
                            ForEach([7, 8, 9, 10, 12, 17, 18, 19, 20, 21], id: \.self) { h in
                                Text(hourLabel(h)).tag(h)
                            }
                        }
                        .labelsHidden()
                        .tint(lavender)
                    }
                }
            }

            Text("A daily nudge helps build a consistent practice habit.")
                .font(.system(size: 11))
                .foregroundStyle(offWhite.opacity(0.35))
                .padding(.top, 10)
        }
    }

    // MARK: - Language

    private var languageCard: some View {
        card {
            cardHeader("Language")

            rowItem(icon: "globe", label: "Practice language") {
                Picker("", selection: $practiceLanguage) {
                    ForEach(SupportedLanguage.allCases) { lang in
                        HStack(spacing: 6) {
                            Text(lang.flag)
                            Text(lang.displayName)
                        }
                        .tag(lang.rawValue)
                    }
                }
                .labelsHidden()
                .tint(lavender)
            }

            Text("Sets the language for pronunciation scoring and native audio reference.")
                .font(.system(size: 11))
                .foregroundStyle(offWhite.opacity(0.35))
                .padding(.top, 10)
        }
    }

    // MARK: - Accent Profile

    private var accentCard: some View {
        card {
            cardHeader("Accent Profile")

            if let p = profile {
                infoRow(label: "Native language",  value: p.languageLabel)
                divider
                infoRow(label: "Words practised",  value: "\(p.totalPracticeWords)")
                divider
                infoRow(label: "Coach sessions",   value: "\(p.totalSessions)")
                divider
                infoRow(label: "Phoneme patterns", value: "\(p.phonemePatterns.count)")
                divider

                Button("Reset accent profile…") { showResetAlert = true }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.red.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("The coach learns your accent over time. Resetting clears learned patterns but keeps your chat history.")
                    .font(.system(size: 11))
                    .foregroundStyle(offWhite.opacity(0.35))
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - About

    private var aboutCard: some View {
        card {
            cardHeader("About")
            infoRow(label: "Mimiq",   value: "1.0.0")
            divider
            infoRow(label: "Speech",  value: "Apple Speech Framework")
            divider
            infoRow(label: "TTS",     value: "AVSpeechSynthesizer")
        }
    }

    // MARK: - Card primitives

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(20)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(border, lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private func cardHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.0)
            .textCase(.uppercase)
            .foregroundStyle(violet)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 14)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(offWhite.opacity(0.58))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(offWhite)
        }
    }

    private func rowItem<Trailing: View>(
        icon: String,
        label: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(lavender)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(offWhite)
            Spacer()
            trailing()
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
            .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private func hourLabel(_ hour: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour; comps.minute = 0
        let date = Calendar.current.date(from: comps) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}
