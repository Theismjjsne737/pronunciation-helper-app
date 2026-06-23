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
    private var streamGeneration = 0

    // Session-level progress tracking
    private var sessionAttempts = 0
    private var sessionScoreTotal: Double = 0
    // Guarantees retry prompt appears after low-score attempt even if Claude omits [RECORD:] tag
    private var pendingRetryWord: String?

    // MARK: - Init

    init(accentProfile: AccentProfile, modelContext: ModelContext) {
        self.accentProfile = accentProfile
        self.modelContext = modelContext
        bindRecordingService()
    }

    // MARK: - Session start

    func startSession() async {
        accentProfile.totalSessions += 1
        do { try modelContext.save() } catch { assertionFailure("SwiftData save failed: \(error)") }

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

            // Detect patterns early so the result card can display them inline
            let detected = profileService.detectPatterns(target: word, heard: result.transcription)
            let detectedLabels = detected.map { p in p.sub.map { "\(p.phoneme)→\($0)" } ?? "\(p.phoneme) dropped" }

            // Show result card in chat (user side)
            appendAttemptResult(
                word: word,
                transcription: result.transcription,
                score: result.score,
                detectedPatterns: detectedLabels
            )

            // Confetti on excellent score
            if result.score >= 0.90 {
                showConfetti = true
            }

            // Exercise card for low scores with detected patterns
            if result.score < 0.75, let firstPattern = detected.first {
                let tip = profileService.exerciseTip(for: firstPattern.phoneme, profile: accentProfile)
                let drill = profileService.drillWords(for: firstPattern.phoneme)
                appendExerciseCard(phoneme: firstPattern.phoneme, why: tip.why, technique: tip.technique, drillWords: drill)
            }

            // Snapshot top challenge BEFORE updating profile (enables improvement detection)
            let topChallengeBefore = accentProfile.topChallenges.first

            // Update accent profile + streak
            profileService.record(
                targetWord: word,
                transcription: result.transcription,
                score: result.score,
                into: accentProfile
            )
            do { try modelContext.save() } catch { assertionFailure("SwiftData save failed: \(error)") }
            await StreakService.shared.recordPractice()
            await GamificationService.shared.award(score: result.score)

            // Index in Spotlight
            SpotlightService.index(word: word, score: result.score, transcription: result.transcription)

            // Session stats
            sessionAttempts += 1
            sessionScoreTotal += result.score
            let sessionAvg = Int(sessionScoreTotal / Double(sessionAttempts) * 100)
            let sessionLine = sessionAttempts > 1
                ? "\nSession so far: \(sessionAttempts) words, \(sessionAvg)% average."
                : ""

            // Milestone: top challenge improved significantly this attempt
            var milestoneNote = ""
            if let before = topChallengeBefore,
               let after = accentProfile.phonemePatterns.first(where: { $0.phoneme == before.phoneme }),
               after.accuracy - before.accuracy >= 0.15,
               after.accuracy >= 0.75 {
                milestoneNote = "\nMILESTONE: User's '\(before.phoneme)' accuracy just jumped from \(Int(before.accuracy * 100))% to \(Int(after.accuracy * 100))% — celebrate this progress!"
            }

            // Phoneme pattern note for Claude context
            let patternNote = detectedLabels.isEmpty ? "" : "\nDetected pattern: \(detectedLabels.joined(separator: ", "))"

            if result.score < 0.85 { pendingRetryWord = word }

            let ctx = "User recorded '\(word)'. I heard: '\(result.transcription)'. Score: \(result.scorePercentage)%.\(patternNote)\(sessionLine)\(milestoneNote)"
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
        streamGeneration += 1
        let generation = streamGeneration
        streamTask = Task {
            var accumulated = ""
            do {
                for try await chunk in await AnthropicService.shared.streamCompletion(
                    systemPrompt: systemPrompt,
                    messages: history
                ) {
                    guard !Task.isCancelled, generation == streamGeneration else { break }
                    accumulated += chunk
                    streamingText = accumulated
                }
                guard generation == streamGeneration else { return }
                await finalise(accumulated)
            } catch {
                guard generation == streamGeneration else { return }
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
            pendingRetryWord = nil
            let subs = SubscriptionManager.shared
            let isNewWord = !subs.hasSeenWord(word)
            if isNewWord && !subs.hasActiveSubscription && subs.hasUsedAllFreeWords {
                paywallTriggerWord = word
                coachState = .idle
                return
            }
            if isNewWord { subs.markWordSeen(word) }
            coachState = .awaitingAttempt(word: word)
            try? await Task.sleep(for: .milliseconds(400))
            tts.speak(word)
        } else if let retryWord = pendingRetryWord {
            pendingRetryWord = nil
            coachState = .awaitingAttempt(word: retryWord)
            try? await Task.sleep(for: .milliseconds(400))
            tts.speak(retryWord)
        } else {
            coachState = .idle
        }
    }

    // MARK: - Message helpers

    private func appendUser(_ content: String) {
        let msg = ChatMessage(role: .user, kind: .text, content: content, sessionID: sessionID)
        persist(msg)
    }

    private func appendAttemptResult(word: String, transcription: String, score: Double, detectedPatterns: [String] = []) {
        let msg = ChatMessage(
            role: .user,
            kind: .pronunciationResult,
            content: "Recorded \"\(word)\"",
            targetWord: word,
            pronunciationScore: score,
            transcription: transcription,
            detectedPatterns: detectedPatterns,
            sessionID: sessionID
        )
        persist(msg)
    }

    func sendSuggestion(_ word: String) async {
        guard coachState == .idle else { return }
        let text = "How do I say \"\(word)\"?"
        appendUser(text)
        await streamCoachResponse(userMessage: text)
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

    private func appendExerciseCard(phoneme: String, why: String?, technique: String?, drillWords: [String]) {
        struct CardData: Encodable {
            let phoneme: String
            let why: String?
            let technique: String?
            let drillWords: [String]
        }
        let data = CardData(phoneme: phoneme, why: why, technique: technique, drillWords: drillWords)
        let json = (try? JSONEncoder().encode(data)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let msg = ChatMessage(role: .assistant, kind: .exerciseCard, content: json, sessionID: sessionID)
        persist(msg)
    }

    private func persist(_ msg: ChatMessage) {
        modelContext.insert(msg)
        do { try modelContext.save() } catch { assertionFailure("SwiftData save failed: \(error)") }
        messages.append(msg)
    }

    // MARK: - Claude history builder

    /// Converts stored messages into the (role, content) pairs Claude expects.
    /// Pronunciation results are translated to the analytical text format.
    private func buildAPIHistory(appendingUser newMsg: String) -> [(role: String, content: String)] {
        var history: [(role: String, content: String)] = messages
            .suffix(8)
            .filter { $0.kind != .exerciseCard }   // exercise cards are UI-only, not part of Claude's context
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
