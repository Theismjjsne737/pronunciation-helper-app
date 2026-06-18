import Foundation
import SwiftUI
import SwiftData
import Combine

// MARK: - Coach state machine

enum CoachState: Equatable {
    case idle
    case thinking                       // Waiting for Claude to stream
    case awaitingAttempt(word: String)  // Recording bar is visible
    case recording(word: String)        // Mic is hot
    case analyzing(word: String)        // Transcribing + scoring
}

// MARK: - ViewModel

@MainActor
final class CoachViewModel: ObservableObject {

    // MARK: - Published

    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var coachState: CoachState = .idle
    @Published private(set) var streamingText = ""
    @Published var inputText = ""
    @Published private(set) var waveformSamples: [Float] = Array(repeating: 0, count: 40)
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published var errorMessage: String?
    /// Non-nil when the paywall should be presented. Contains the word that hit the limit.
    @Published var paywallTriggerWord: String? = nil
    /// Set to true after a score ≥ 0.90 to trigger confetti in the view layer.
    @Published var showConfetti = false

    // Expose TTS so views can observe isSpeaking directly
    let tts = TTSService()

    // MARK: - Dependencies

    private let accentProfile: AccentProfile
    private let modelContext: ModelContext
    private let profileService = AccentProfileService()
    private let recordingService = AudioRecordingService()
    private let analysisService = SpeechAnalysisService()

    private var cancellables = Set<AnyCancellable>()
    private var currentRecordingURL: URL?
    private let sessionID = UUID()
    private var streamTask: Task<Void, Never>?

    // MARK: - Init

    init(accentProfile: AccentProfile, modelContext: ModelContext) {
        self.accentProfile = accentProfile
        self.modelContext = modelContext
        bindRecordingService()
    }

    // MARK: - Session start

    func startSession() async {
        accentProfile.totalSessions += 1
        try? modelContext.save()

        // Permissions
        _ = await recordingService.requestPermission()
        _ = await analysisService.requestPermission()

        let welcome = profileService.welcomeMessage(for: accentProfile)
        appendCoach(welcome)
    }

    // MARK: - User sends text

    func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, coachState == .idle else { return }
        inputText = ""
        appendUser(text)
        await streamCoachResponse(userMessage: text)
    }

    // MARK: - TTS: speak the target word

    func speakWord(_ word: String, slowly: Bool = false) {
        slowly ? tts.speakSlowly(word) : tts.speak(word)
    }

    // MARK: - Public state mutations

    /// Resume recording for a word (used after paywall dismissal).
    func resumeRecording(for word: String) {
        coachState = .awaitingAttempt(word: word)
    }

    // MARK: - Recording

    func startRecording() {
        guard case .awaitingAttempt(let word) = coachState else { return }
        do {
            let url = try recordingService.startRecording()
            currentRecordingURL = url
            coachState = .recording(word: word)
            waveformSamples = Array(repeating: 0, count: 40)
            HapticsService.medium()
        } catch {
            HapticsService.error()
            errorMessage = error.localizedDescription
        }
    }

    func stopAndAnalyze() async {
        guard case .recording(let word) = coachState else { return }
        recordingService.stopRecording()
        coachState = .analyzing(word: word)

        guard let url = currentRecordingURL else {
            coachState = .idle; return
        }

        do {
            let result = try await analysisService.analyze(recordingURL: url, targetWord: word)

            // Haptic based on score
            if result.score >= 0.9 { HapticsService.success() }
            else if result.score >= 0.6 { HapticsService.medium() }
            else { HapticsService.warning() }

            // Show result card in chat (user side)
            appendAttemptResult(
                word: word,
                transcription: result.transcription,
                score: result.score
            )

            // Confetti on excellent score
            if result.score >= 0.90 {
                showConfetti = true
            }

            // Update accent profile + streak
            profileService.record(
                targetWord: word,
                transcription: result.transcription,
                score: result.score,
                into: accentProfile
            )
            try? modelContext.save()
            await StreakService.shared.recordPractice()

            // Index in Spotlight
            SpotlightService.index(word: word, score: result.score, transcription: result.transcription)

            // Feed analysis to Claude
            let ctx = "User recorded '\(word)'. I heard: '\(result.transcription)'. Score: \(result.scorePercentage)%."
            await streamCoachResponse(userMessage: ctx)

        } catch {
            coachState = .idle
            HapticsService.error()
            errorMessage = "Couldn't analyse recording: \(error.localizedDescription)"
        }
    }

    func cancelRecording() {
        recordingService.stopRecording()
        currentRecordingURL = nil
        if case .recording(let word) = coachState {
            coachState = .awaitingAttempt(word: word)
        } else {
            coachState = .idle
        }
    }

    // MARK: - Streaming Claude response

    private func streamCoachResponse(userMessage: String) async {
        coachState = .thinking
        streamingText = ""

        let systemPrompt = profileService.buildSystemPrompt(for: accentProfile)
        let history = buildAPIHistory(appendingUser: userMessage)

        streamTask?.cancel()
        streamTask = Task {
            var accumulated = ""
            do {
                for try await chunk in await AnthropicService.shared.streamCompletion(
                    systemPrompt: systemPrompt,
                    messages: history
                ) {
                    guard !Task.isCancelled else { break }
                    accumulated += chunk
                    streamingText = accumulated
                }
                await finalise(accumulated)
            } catch {
                streamingText = ""
                coachState = .idle
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func finalise(_ raw: String) async {
        streamingText = ""

        // Parse [RECORD: word] tag
        let pattern = #"(?m)^\[RECORD:\s*(.+?)\]\s*$"#
        var display = raw
        var targetWord: String?

        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)),
           let range = Range(match.range(at: 1), in: raw) {
            targetWord = String(raw[range]).trimmingCharacters(in: .whitespaces)
            display = regex.stringByReplacingMatches(
                in: display,
                range: NSRange(display.startIndex..., in: display),
                withTemplate: ""
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        appendCoach(display, targetWord: targetWord)

        if let word = targetWord {
            let subs = SubscriptionManager.shared
            let isNewWord = !subs.hasSeenWord(word)

            if isNewWord && !subs.hasActiveSubscription && subs.hasUsedAllFreeWords {
                // Hit the paywall — show it but don't activate the recording widget
                paywallTriggerWord = word
                coachState = .idle
            } else {
                // Mark word seen if new, then let the user record
                if isNewWord { subs.markWordSeen(word) }
                coachState = .awaitingAttempt(word: word)
            }
        } else {
            coachState = .idle
        }
    }

    // MARK: - Message helpers

    private func appendUser(_ content: String) {
        let msg = ChatMessage(role: .user, kind: .text, content: content, sessionID: sessionID)
        persist(msg)
    }

    private func appendAttemptResult(word: String, transcription: String, score: Double) {
        let msg = ChatMessage(
            role: .user,
            kind: .pronunciationResult,
            content: "Recorded \"\(word)\"",
            targetWord: word,
            pronunciationScore: score,
            transcription: transcription,
            sessionID: sessionID
        )
        persist(msg)
    }

    private func appendCoach(_ content: String, targetWord: String? = nil) {
        let kind: MessageKind = targetWord != nil ? .recordingRequest : .text
        let msg = ChatMessage(
            role: .assistant,
            kind: kind,
            content: content,
            targetWord: targetWord,
            sessionID: sessionID
        )
        persist(msg)
    }

    private func persist(_ msg: ChatMessage) {
        modelContext.insert(msg)
        try? modelContext.save()
        messages.append(msg)
    }

    // MARK: - Claude history builder

    /// Converts stored messages into the (role, content) pairs Claude expects.
    /// Pronunciation results are translated to the analytical text format.
    private func buildAPIHistory(appendingUser newMsg: String) -> [(role: String, content: String)] {
        var history: [(role: String, content: String)] = messages
            .suffix(20)
            .map { msg in
                let role = msg.isUser ? "user" : "assistant"
                let content: String = {
                    if msg.kind == .pronunciationResult {
                        return "User recorded '\(msg.targetWord ?? "")'. I heard: '\(msg.transcription ?? "")'. Score: \(Int((msg.pronunciationScore ?? 0) * 100))%."
                    }
                    // Strip any leftover [RECORD:] tags from assistant messages in history
                    return msg.content
                }()
                return (role: role, content: content)
            }
        history.append((role: "user", content: newMsg))
        return history
    }

    // MARK: - Bindings

    private func bindRecordingService() {
        recordingService.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                guard let self else { return }
                waveformSamples.removeFirst()
                waveformSamples.append(level)
            }
            .store(in: &cancellables)

        recordingService.$recordingDuration
            .receive(on: DispatchQueue.main)
            .assign(to: &$recordingDuration)
    }
}
