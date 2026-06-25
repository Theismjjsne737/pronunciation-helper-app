import SwiftUI
import SwiftData
import Speech
import AVFoundation

/// First-run setup. Guides the user through language selection, notification opt-in,
/// and surfaces how to add an API key if they don't have one yet.
struct OnboardingView: View {

    let profile: AccentProfile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedLanguage: String? = nil
    @State private var selectedChallenges: Set<String> = []
    @State private var page = 0

    @StateObject private var notifs  = NotificationService.shared
    @StateObject private var recorder = AudioRecordingService()
    @State private var notifRequested = false

    // Sentence assessment
    @State private var sentenceIdx = 0
    @State private var sentenceStep: SentenceStep = .ready
    @State private var collectedResults: [(expected: String, heard: String)] = []
    @State private var activeRecordingURL: URL? = nil

    private let profileService = AccentProfileService()

    private enum SentenceStep: Equatable {
        case ready, recording, transcribing, reviewing(String)
    }

    private let assessmentSentences = [
        "The weather there was rather warm today.",
        "I very rarely feel worried about flying.",
        "Have you heard her voice before?",
        "She thinks this is the right thing to do.",
        "Three brown wolves drove through the forest.",
    ]

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
                sentenceAssessmentPage.tag(2)
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

    // MARK: - Mascot helper

    private func mascotImage(_ name: String, fallback: String = "PronceParrot") -> some View {
        let imageName = UIImage(named: name) != nil ? name : fallback
        return Image(imageName)
            .resizable()
            .scaledToFit()
            .frame(width: 160, height: 160)
    }

    // MARK: - Page 0: Welcome

    private var welcomePage: some View {
        VStack(spacing: 28) {
            Spacer()

            mascotImage("PronceHello")

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

    // MARK: - Page 2: Sentence Assessment

    private var sentenceAssessmentPage: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    let mascotName: String = {
                        switch sentenceStep {
                        case .recording:     return "PronceListening"
                        case .transcribing:  return "PronceAnalyzing"
                        default:             return "PronceHello"
                        }
                    }()

                    mascotImage(mascotName)
                        .animation(.spring(duration: 0.4), value: mascotName)

                    VStack(spacing: 8) {
                        Text("Quick accent check")
                            .font(.title2.weight(.bold))
                        Text("Read each sentence aloud. Takes about 30 seconds.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 4)

                    HStack(spacing: 8) {
                        ForEach(0..<assessmentSentences.count, id: \.self) { i in
                            Circle()
                                .fill(i < collectedResults.count ? Color.indigo : Color(.systemGray4))
                                .frame(width: 8, height: 8)
                                .animation(.spring(duration: 0.3), value: collectedResults.count)
                        }
                    }

                    if sentenceIdx < assessmentSentences.count {
                        sentenceCard(assessmentSentences[sentenceIdx])
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            Button("Skip – learn organically instead") {
                withAnimation { page = 3 }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.vertical, 20)
        }
    }

    @ViewBuilder
    private func sentenceCard(_ sentence: String) -> some View {
        VStack(spacing: 20) {
            Text(sentence)
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))

            switch sentenceStep {
            case .ready:
                Button {
                    Task { await startSentenceRecording() }
                } label: {
                    Label("Tap to record", systemImage: "mic.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.indigo.gradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

            case .recording:
                VStack(spacing: 12) {
                    Button { stopAndTranscribe() } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "stop.circle.fill")
                            Text("Recording… tap to stop").font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red.gradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray5))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.indigo.opacity(0.7))
                                .frame(width: geo.size.width * CGFloat(recorder.audioLevel))
                                .animation(.linear(duration: 0.05), value: recorder.audioLevel)
                        }
                    }
                    .frame(height: 8)
                }

            case .transcribing:
                HStack(spacing: 10) {
                    ProgressView().scaleEffect(0.85)
                    Text("Listening…").font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)

            case .reviewing(let transcript):
                VStack(spacing: 14) {
                    VStack(spacing: 4) {
                        Text("I heard:").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                        Text(transcript.isEmpty ? "(unclear — try again)" : transcript)
                            .font(.subheadline)
                            .foregroundStyle(transcript.isEmpty ? .secondary : .primary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    HStack(spacing: 12) {
                        Button("Re-record") { sentenceStep = .ready }
                            .buttonStyle(.bordered).tint(.secondary)
                        Button("Next →") {
                            collectedResults.append((sentence, transcript))
                            advanceSentence()
                        }
                        .buttonStyle(.borderedProminent).tint(.indigo)
                    }
                }
            }
        }
    }

    // MARK: - Sentence recording helpers

    private func startSentenceRecording() async {
        guard await recorder.requestPermission() else { return }
        do {
            activeRecordingURL = try recorder.startRecording()
            sentenceStep = .recording
        } catch {
            sentenceStep = .ready
        }
    }

    private func stopAndTranscribe() {
        recorder.stopRecording()
        sentenceStep = .transcribing
        guard let url = activeRecordingURL else { sentenceStep = .reviewing(""); return }
        Task {
            let transcript = await transcribeFile(url: url)
            sentenceStep = .reviewing(transcript)
        }
    }

    private func transcribeFile(url: URL) async -> String {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else { return "" }
        let granted = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
        guard granted else { return "" }
        let request = SFSpeechURLRecognitionRequest(url: url)
        return await withCheckedContinuation { cont in
            var done = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !done else { return }
                if let r = result, r.isFinal { done = true; cont.resume(returning: r.bestTranscription.formattedString) }
                else if error != nil { done = true; cont.resume(returning: "") }
            }
        }
    }

    private func advanceSentence() {
        let next = sentenceIdx + 1
        if next >= assessmentSentences.count {
            let detected = profileService.detectSentenceChallenges(
                expected: collectedResults.map(\.expected),
                transcriptions: collectedResults.map(\.heard)
            )
            if !detected.isEmpty { selectedChallenges = Set(detected) }
            withAnimation { page = 3 }
        } else {
            sentenceIdx = next
            sentenceStep = .ready
        }
    }

    // MARK: - Page 3: Notifications

    private var notificationPage: some View {
        VStack(spacing: 28) {
            Spacer()

            mascotImage("PronceWave")

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

            mascotImage("PronceCelebrate")

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
