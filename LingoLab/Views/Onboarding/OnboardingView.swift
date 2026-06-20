import SwiftUI
import SwiftData

/// First-run setup. Guides the user through language selection, notification opt-in,
/// and surfaces how to add an API key if they don't have one yet.
struct OnboardingView: View {

    let profile: AccentProfile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedLanguage: String? = nil
    @State private var selectedChallenges: Set<String> = []
    @State private var page = 0

    @StateObject private var notifs = NotificationService.shared
    @State private var notifRequested = false

    private let profileService = AccentProfileService()

    private let languages = [
        "Arabic", "French", "German", "Hindi", "Japanese",
        "Korean", "Mandarin", "Portuguese", "Russian", "Spanish",
        "Other",
    ]

    // Pages: 0 Welcome, 1 Language, 2 Assessment, 3 Notifications, 4 Complete
    private let totalPages = 5

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                welcomePage.tag(0)
                languagePage.tag(1)
                assessmentPage.tag(2)
                notificationPage.tag(3)
                completePage.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if page < totalPages - 1 {
                        Button("Skip") { finish() }
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    // MARK: - Page 0: Welcome

    private var welcomePage: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.indigo.opacity(0.15), .purple.opacity(0.1)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "mouth.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 12) {
                Text("Your Personal\nPronunciation Coach")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("Practice any word or name. Get instant AI feedback. Build a streak — and watch your accent improve.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 10) {
                featureRow(icon: "waveform.and.mic", text: "Record & analyze your pronunciation")
                featureRow(icon: "brain.head.profile", text: "AI coach adapts to your accent")
                featureRow(icon: "chart.line.uptrend.xyaxis", text: "Track progress over time")
            }
            .padding(.horizontal, 32)

            Spacer()

            primaryButton("Get Started") { withAnimation { page = 1 } }
        }
        .padding()
    }

    // MARK: - Page 1: Language

    private var languagePage: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("What's your native\nlanguage?")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("This helps the coach understand why certain sounds are tricky for you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                ForEach(languages, id: \.self) { lang in
                    Button {
                        withAnimation(.spring(duration: 0.2)) { selectedLanguage = lang }
                    } label: {
                        Text(lang)
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                selectedLanguage == lang ? Color.indigo : Color(.secondarySystemGroupedBackground)
                            )
                            .foregroundStyle(selectedLanguage == lang ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            primaryButton(selectedLanguage != nil ? "Continue" : "Skip for now") {
                withAnimation { page = 2 }
                // Pre-select language-specific challenges for the assessment page
                if let lang = selectedLanguage, lang != "Other",
                   let group = AccentGroupProfile.groups[lang] {
                    selectedChallenges = Set(group.commonChallenges)
                }
            }
            .opacity(1.0)
        }
        .padding(.top)
    }

    // MARK: - Page 2: Accent Assessment

    private var assessmentChallenges: [String] {
        let universal = ["th", "r", "v", "w", "h", "consonant-cluster", "final-consonants"]
        if let lang = selectedLanguage, lang != "Other",
           let group = AccentGroupProfile.groups[lang] {
            let langSpecific = group.commonChallenges
            return Array((langSpecific + universal.filter { !langSpecific.contains($0) }).prefix(12))
        }
        return universal
    }

    private var assessmentPage: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("Which sounds feel\ntricky?")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("Select all that apply — your coach will focus on these first. You can always change this later.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                ForEach(assessmentChallenges, id: \.self) { phoneme in
                    let selected = selectedChallenges.contains(phoneme)
                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            if selected { selectedChallenges.remove(phoneme) }
                            else { selectedChallenges.insert(phoneme) }
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(phonemeEmoji(phoneme))
                                .font(.title3)
                            Text(phonemeLabel(phoneme))
                                .font(.caption.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selected ? Color.indigo : Color(.secondarySystemGroupedBackground))
                        .foregroundStyle(selected ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selected ? Color.indigo : Color.clear, lineWidth: 1.5)
                        )
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            VStack(spacing: 10) {
                primaryButton(selectedChallenges.isEmpty ? "Skip" : "Continue (\(selectedChallenges.count) selected)") {
                    withAnimation { page = 3 }
                }
            }
        }
        .padding(.top)
    }

    private func phonemeLabel(_ phoneme: String) -> String {
        switch phoneme {
        case "th":               return "\"th\" sound"
        case "r":                return "English R"
        case "l":                return "L vs R"
        case "v":                return "V sound"
        case "w":                return "W sound"
        case "h":                return "H sound"
        case "f":                return "F sound"
        case "p":                return "P vs B"
        case "z":                return "Z sound"
        case "sh":               return "SH sound"
        case "consonant-cluster": return "Consonant clusters"
        case "final-consonants": return "Final consonants"
        case "final-ng":         return "Final -NG"
        case "nasal-vowels":     return "Nasal vowels"
        case "schwa":            return "Schwa (ə)"
        case "tones":            return "Word stress"
        case "retroflex":        return "Retroflex sounds"
        default:                 return phoneme
        }
    }

    private func phonemeEmoji(_ phoneme: String) -> String {
        switch phoneme {
        case "th":               return "👅"
        case "r":                return "🌀"
        case "l", "r-l":        return "↔️"
        case "v":                return "🫦"
        case "w":                return "💋"
        case "h":                return "💨"
        case "f":                return "🦷"
        case "p":                return "💥"
        case "consonant-cluster": return "🔗"
        case "final-consonants", "final-ng": return "🔚"
        case "schwa":            return "🔈"
        case "tones":            return "📊"
        default:                 return "🔤"
        }
    }

    // MARK: - Page 3: Notifications

    private var notificationPage: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 110, height: 110)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 12) {
                Text("Stay on track")
                    .font(.largeTitle.weight(.bold))

                Text("A daily reminder keeps your streak alive. Studies show consistent short sessions beat occasional long ones.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 10) {
                reminderBenefit("Builds lasting muscle memory")
                reminderBenefit("Takes just 2–3 minutes a day")
                reminderBenefit("You can change the time anytime")
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                if notifRequested && notifs.isAuthorized {
                    // Already granted — show confirmation
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Daily reminders enabled!")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.green)
                    }
                    .padding(.vertical, 14)

                    primaryButton("Let's go!") { withAnimation { page = 4 } }

                } else if notifRequested && !notifs.isAuthorized {
                    Text("No worries — you can turn them on in Settings later.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    primaryButton("Continue") { withAnimation { page = 4 } }

                } else {
                    // Not yet requested
                    primaryButton("Enable Daily Reminders 🔔") {
                        Task {
                            notifRequested = true
                            let granted = await notifs.requestPermission()
                            if granted {
                                notifs.reminderEnabled = true
                            }
                        }
                    }

                    Button("Not now") {
                        notifRequested = true
                        withAnimation { page = 4 }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }

    // MARK: - Page 3: Complete

    private var completePage: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 110, height: 110)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.green.gradient)
            }

            VStack(spacing: 12) {
                Text("You're ready!")
                    .font(.largeTitle.weight(.bold))

                if let lang = selectedLanguage {
                    Text("I know \(lang) speakers have specific English patterns. Your coaching will be tailored from day one.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                } else {
                    Text("Start chatting — I'll learn your accent patterns as we practise together.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }

            // Free tier callout
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "gift.fill").foregroundStyle(.indigo)
                    Text("5 free pronunciation sessions included")
                        .font(.subheadline.weight(.semibold))
                }
                Text("No credit card required to get started.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color.indigo.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 32)

            Spacer()

            primaryButton("Start Practising 🎙️", action: finish)
        }
        .padding()
    }

    // MARK: - Shared components

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.indigo.gradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 40)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.indigo)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func reminderBenefit(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.orange)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Finish

    private func finish() {
        if let lang = selectedLanguage, lang != "Other" {
            profile.nativeLanguage = lang
        }
        if !selectedChallenges.isEmpty {
            profileService.seedProfile(
                challenges: Array(selectedChallenges),
                nativeLanguage: selectedLanguage,
                into: profile
            )
        }
        profile.onboardingCompleted = true
        try? modelContext.save()
        dismiss()
    }
}
