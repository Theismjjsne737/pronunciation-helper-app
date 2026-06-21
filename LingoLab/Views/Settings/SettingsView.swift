import SwiftUI
import SwiftData

struct SettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<AccentProfile> { _ in true }) private var profiles: [AccentProfile]
    @ObservedObject private var subs = SubscriptionManager.shared
    @ObservedObject private var notifs = NotificationService.shared
    @AppStorage("practiceLanguage") private var practiceLanguage = SupportedLanguage.default.rawValue

    @State private var showResetAlert = false
    @State private var showPaywall = false

    private var profile: AccentProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            List {
                subscriptionSection
                notificationSection
                languageSection
                accentSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
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

    // MARK: - Subscription

    private var subscriptionSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: subs.hasActiveSubscription ? "checkmark.seal.fill" : "sparkles")
                    .font(.title2)
                    .foregroundStyle(subs.hasActiveSubscription ? .green : .indigo)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(subs.hasActiveSubscription ? "Premium" : "Free Plan")
                        .font(.subheadline.weight(.semibold))
                    Text(subs.subscriptionStatusLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)

            if subs.hasActiveSubscription {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    Link(destination: url) {
                        Label("Manage Subscription", systemImage: "arrow.up.right.square")
                            .font(.subheadline)
                    }
                }
            } else {
                // Free word counter bar
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Free words used")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(subs.uniqueWordCount) / \(SubscriptionManager.freeWordLimit)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(subs.hasUsedAllFreeWords ? .red : .primary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(.systemFill))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(subs.hasUsedAllFreeWords ? Color.red : Color.indigo)
                                .frame(
                                    width: geo.size.width * min(1, Double(subs.uniqueWordCount) / Double(SubscriptionManager.freeWordLimit)),
                                    height: 6
                                )
                                .animation(.easeOut, value: subs.uniqueWordCount)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.vertical, 4)

                Button {
                    showPaywall = true
                } label: {
                    Label("Upgrade to Premium", systemImage: "crown.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.indigo.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
            }
        } header: {
            Text("Subscription")
        }
    }

    // MARK: - Notifications

    private var notificationSection: some View {
        Section {
            switch notifs.authorizationStatus {
            case .notDetermined:
                Button {
                    Task { await notifs.requestPermission() }
                } label: {
                    Label("Enable Daily Reminders", systemImage: "bell.badge.fill")
                        .foregroundStyle(.orange)
                        .font(.subheadline)
                }

            case .denied:
                HStack {
                    Label("Notifications blocked", systemImage: "bell.slash")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.indigo)
                }

            default:
                Toggle(isOn: $notifs.reminderEnabled) {
                    Label("Daily reminder", systemImage: "bell.fill")
                        .font(.subheadline)
                }
                .tint(.indigo)

                if notifs.reminderEnabled {
                    Picker(selection: $notifs.reminderHour) {
                        ForEach([7, 8, 9, 10, 12, 17, 18, 19, 20, 21], id: \.self) { hour in
                            Text(hourLabel(hour)).tag(hour)
                        }
                    } label: {
                        Label("Reminder time", systemImage: "clock")
                            .font(.subheadline)
                    }
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("A daily nudge helps build a consistent practice habit.")
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour; comps.minute = 0
        let date = Calendar.current.date(from: comps) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    // MARK: - Language

    private var languageSection: some View {
        Section {
            Picker(selection: $practiceLanguage) {
                ForEach(SupportedLanguage.allCases) { lang in
                    HStack(spacing: 8) {
                        Text(lang.flag)
                        Text(lang.displayName)
                    }
                    .tag(lang.rawValue)
                }
            } label: {
                Label("Practice language", systemImage: "globe")
                    .font(.subheadline)
            }
        } header: {
            Text("Language")
        } footer: {
            Text("Sets the language used for pronunciation scoring and native audio reference.")
        }
    }

    // MARK: - Accent Profile

    private var accentSection: some View {
        Section {
            if let p = profile {
                LabeledContent("Native language", value: p.languageLabel)
                    .font(.subheadline)
                LabeledContent("Words practised", value: "\(p.totalPracticeWords)")
                    .font(.subheadline)
                LabeledContent("Coach sessions", value: "\(p.totalSessions)")
                    .font(.subheadline)
                LabeledContent("Phoneme patterns", value: "\(p.phonemePatterns.count)")
                    .font(.subheadline)
                Button("Reset accent profile…", role: .destructive) {
                    showResetAlert = true
                }
                .font(.subheadline)
            }
        } header: {
            Text("Accent Profile")
        } footer: {
            Text("The coach learns your accent over time. Resetting clears learned patterns but keeps your chat history.")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Mimiq", value: "1.0.0")
                .font(.subheadline)
            LabeledContent("Speech", value: "Apple Speech Framework")
                .font(.subheadline)
            LabeledContent("TTS", value: "AVSpeechSynthesizer")
                .font(.subheadline)
        }
    }
}
