import SwiftUI
import SwiftData

/// The primary screen — a full-screen iMessage-style chat with the pronunciation coach.
struct CoachView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<AccentProfile> { _ in true }) private var profiles: [AccentProfile]
    @ObservedObject private var subs    = SubscriptionManager.shared
    @ObservedObject private var streak  = StreakService.shared
    @ObservedObject private var network = NetworkMonitor.shared

    @State private var vm: CoachViewModel?
    @State private var showSettings   = false
    @State private var showOnboarding = false
    @State private var showPaywall    = false

    private var profile: AccentProfile? { profiles.first }

    // MARK: - Body

    // MARK: - Design tokens
    private let navyBg    = Color(red: 0.027, green: 0.020, blue: 0.059)
    private let accent    = Color(red: 0.48,  green: 0.33,  blue: 1.0)
    private let offWhite  = Color(red: 0.941, green: 0.933, blue: 1.0)

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                navyBg.ignoresSafeArea()

                if let vm {
                    chatLayout(vm: vm)
                        .confetti(isActive: Binding(
                            get: { vm.showConfetti },
                            set: { vm.showConfetti = $0 }
                        ))
                } else {
                    loadingState
                }

                if !network.isConnected {
                    VStack {
                        HStack(spacing: 8) {
                            Image(systemName: "wifi.slash")
                            Text("No internet — coach unavailable offline")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(offWhite)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(accent.opacity(0.18))
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(accent.opacity(0.35), lineWidth: 1))
                        .padding(.top, 8)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(duration: 0.3), value: network.isConnected)
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
            .sheet(isPresented: $showSettings,   onDismiss: rebuild) { SettingsView() }
            .sheet(isPresented: $showOnboarding, onDismiss: rebuild) {
                if let p = profile { OnboardingView(profile: p) }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView {
                    if let word = vm?.paywallTriggerWord {
                        vm?.paywallTriggerWord = nil
                        vm?.resumeRecording(for: word)
                    }
                }
            }
            .onChange(of: vm?.paywallTriggerWord) { _, newWord in
                if newWord != nil { showPaywall = true }
            }
            .task { await bootstrap() }
        }
    }

    // MARK: - Chat layout

    private func chatLayout(vm: CoachViewModel) -> some View {
        VStack(spacing: 0) {
            // ── Message list ──────────────────────────────────
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(vm.messages) { msg in
                            MessageBubbleView(message: msg, tts: vm.tts) { word in
                                vm.speakWord(word)
                            }
                            .id(msg.id)
                        }

                        // Streaming / thinking bubble
                        if vm.coachState == .thinking || !vm.streamingText.isEmpty {
                            StreamingBubbleView(text: vm.streamingText)
                                .id("streaming")
                        }

                        Color.clear.frame(height: 4).id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: vm.messages.count)  { _, _ in scrollToBottom(proxy) }
                .onChange(of: vm.streamingText)   { _, _ in scrollToBottom(proxy) }
                .onChange(of: vm.coachState)      { _, _ in scrollToBottom(proxy) }
            }

            // ── Error banner ──────────────────────────────────
            if let err = vm.errorMessage {
                ErrorBannerView(message: err) {
                    HapticsService.light()
                    vm.errorMessage = nil
                }
            }

            // ── Recording bar ─────────────────────────────────
            let isRecordingActive: Bool = {
                switch vm.coachState {
                case .awaitingAttempt, .recording, .analyzing: return true
                default: return false
                }
            }()

            if isRecordingActive {
                RecordingWidget(vm: vm)
            }

            // ── Suggested words (empty state only) ───────────
            if vm.messages.count <= 1 && vm.coachState == .idle {
                SuggestedWordsBar { word in
                    Task { await vm.sendSuggestion(word) }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // ── Text input bar ────────────────────────────────
            InputBar(vm: vm)
        }
        .animation(.spring(duration: 0.3), value: isRecordingBarVisible(vm))
        .animation(.spring(duration: 0.3), value: vm.messages.count)
    }

    // MARK: - Loading placeholder

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.2)
            Text("Starting your coach…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        // Accent / onboarding pill
        ToolbarItem(placement: .topBarLeading) {
            Button { showOnboarding = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "person.crop.circle")
                    Text(profile?.nativeLanguage ?? "Set accent")
                        .font(.caption.weight(.medium))
                }
                .font(.caption)
                .foregroundStyle(.indigo)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.indigo.opacity(0.1))
                .clipShape(Capsule())
            }
            .accessibilityLabel("Edit accent profile")
        }

        // Streak badge
        ToolbarItem(placement: .topBarLeading) {
            StreakBadge(streak: streak.currentStreak, practicedToday: streak.practicedToday)
        }

        // Free-words badge (non-subscribers only)
        if !subs.hasActiveSubscription {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showPaywall = true } label: {
                    FreeWordsBadge(remaining: subs.wordsRemaining)
                }
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("Settings")
        }
    }

    // MARK: - Bootstrap

    private func bootstrap() async {
        if profiles.isEmpty {
            let p = AccentProfile()
            p.onboardingCompleted = true
            modelContext.insert(p)
            try? modelContext.save()
        }

        guard let p = profiles.first else { return }

        let newVM = CoachViewModel(accentProfile: p, modelContext: modelContext)
        vm = newVM
        await newVM.startSession()
    }

    private func rebuild() {
        guard let p = profiles.first else { return }
        let newVM = CoachViewModel(accentProfile: p, modelContext: modelContext)
        vm = newVM
        Task { await newVM.startSession() }
    }

    // MARK: - Helpers

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom") }
    }

    private func isRecordingBarVisible(_ vm: CoachViewModel) -> Bool {
        switch vm.coachState {
        case .awaitingAttempt, .recording, .analyzing: return true
        default: return false
        }
    }
}

// MARK: - Streak badge

struct StreakBadge: View {
    let streak: Int
    let practicedToday: Bool
    @State private var bounce = false

    var body: some View {
        HStack(spacing: 3) {
            Text("🔥")
                .font(.caption)
                .scaleEffect(bounce ? 1.3 : 1.0)
            Text(streak > 0 ? "\(streak)" : "–")
                .font(.caption.weight(.bold))
                .foregroundStyle(streak > 0 ? .orange : .secondary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(streak > 0 ? Color.orange.opacity(0.18) : Color.white.opacity(0.06))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(streak > 0 ? Color.orange.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1))
        .onAppear {
            if streak > 0 {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.5)) { bounce = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { bounce = false }
            }
        }
        .accessibilityLabel("\(streak) day streak")
    }
}

// MARK: - Error banner

private struct ErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.white)
                .lineLimit(2)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.red.gradient)
    }
}

// MARK: - Free words badge

private struct FreeWordsBadge: View {
    let remaining: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: remaining == 0 ? "lock.fill" : "sparkles")
                .font(.caption2)
            Text(remaining == 0 ? "Upgrade" : "\(remaining) free")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.15))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(badgeColor.opacity(0.35), lineWidth: 1))
    }

    private var badgeColor: Color {
        switch remaining {
        case 3...: return .indigo
        case 1...2: return .orange
        default: return .red
        }
    }
}

// MARK: - Suggested words bar

private struct SuggestedWordsBar: View {
    let onSelect: (String) -> Void

    private let suggestions: [(word: String, hint: String)] = [
        ("Worcester", "WUSS-ter"),
        ("Nguyen", "WIN"),
        ("quinoa", "KEEN-wah"),
        ("colonel", "KER-nel"),
        ("Joaquin", "wah-KEEN"),
        ("Siobhan", "shih-VAWN"),
        ("chipotle", "chi-POHT-lay"),
        ("Worcestershire", "WOOS-ter-sheer"),
        ("Maeve", "mayv"),
        ("GIF", "JIF or GIF"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Try a tricky word:")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.42))
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.word) { item in
                        Button {
                            onSelect(item.word)
                        } label: {
                            VStack(spacing: 2) {
                                Text(item.word)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color(red: 0.941, green: 0.933, blue: 1.0))
                                Text("[\(item.hint)]")
                                    .font(.caption2)
                                    .foregroundStyle(Color.white.opacity(0.42))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(red: 0.48, green: 0.33, blue: 1.0).opacity(0.25), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
        .background(Color(red: 0.027, green: 0.020, blue: 0.059))
    }
}
