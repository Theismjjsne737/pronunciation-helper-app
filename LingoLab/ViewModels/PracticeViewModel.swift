import Foundation
import Combine

// MARK: - Practice Phase

enum PracticePhase {
    case wordEntry
    case preRecord(word: String)
    case recording(word: String)
    case analyzing(word: String)
    case result(word: String, AnalysisResult, URL)
}

// MARK: - ViewModel

@MainActor
final class PracticeViewModel: ObservableObject {

    // MARK: - Published

    @Published private(set) var phase: PracticePhase = .wordEntry
    @Published var wordInput: String = ""
    @Published private(set) var waveformSamples: [Float] = Array(repeating: 0, count: 60)
    @Published private(set) var capturedSamples: [Float] = []
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published var errorMessage: String?
    @Published private(set) var previewingWord: String? = nil

    let tts = TTSService()
    var playback: AudioPlaybackService { playbackService }

    // MARK: - Dependencies

    private let recordingService = AudioRecordingService()
    private let analysisService = SpeechAnalysisService()
    private let playbackService = AudioPlaybackService()

    private var cancellables = Set<AnyCancellable>()
    private var liveSamples: [Float] = Array(repeating: 0, count: 60)
    private var recordedURL: URL?

    // MARK: - Init

    init() {
        bindRecordingService()
    }

    // MARK: - Permissions

    func requestPermissions() async {
        _ = await recordingService.requestPermission()
        _ = await analysisService.requestPermission()
    }

    // MARK: - Library

    func preview(_ word: String) {
        previewingWord = word
        tts.speak(word)
    }

    func select(_ item: PracticeItem) {
        wordInput = item.word
        HapticsService.light()
        phase = .preRecord(word: item.word)
    }

    // MARK: - Word entry

    func startPractice() {
        let word = wordInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        HapticsService.light()
        phase = .preRecord(word: word)
    }

    // MARK: - Native reference

    func speakNative(slowly: Bool = false) {
        guard case .preRecord(let word) = phase else { return }
        HapticsService.light()
        slowly ? tts.speakSlowly(word) : tts.speak(word)
    }

    // MARK: - Recording

    func startRecording() {
        guard case .preRecord(let word) = phase else { return }
        do {
            let url = try recordingService.startRecording()
            recordedURL = url
            liveSamples = Array(repeating: 0, count: 60)
            waveformSamples = liveSamples
            capturedSamples = []
            phase = .recording(word: word)
            HapticsService.medium()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopAndAnalyze() async {
        guard case .recording(let word) = phase else { return }
        recordingService.stopRecording()
        capturedSamples = waveformSamples
        phase = .analyzing(word: word)

        guard let url = recordedURL else {
            phase = .preRecord(word: word)
            return
        }

        do {
            let result = try await analysisService.analyze(recordingURL: url, targetWord: word)
            if result.score >= 0.9      { HapticsService.success() }
            else if result.score >= 0.6 { HapticsService.medium()  }
            else                        { HapticsService.warning()  }
            phase = .result(word: word, result, url)
        } catch {
            phase = .preRecord(word: word)
            errorMessage = "Analysis failed: \(error.localizedDescription)"
        }
    }

    func cancelRecording() {
        recordingService.stopRecording()
        if case .recording(let word) = phase {
            phase = .preRecord(word: word)
        }
        HapticsService.light()
    }

    // MARK: - Results

    func playRecording() {
        guard case .result(_, _, let url) = phase else { return }
        try? playbackService.play(url: url)
        HapticsService.light()
    }

    func tryAgain() {
        if case .result(let word, _, _) = phase {
            phase = .preRecord(word: word)
        }
    }

    func newWord() {
        wordInput = ""
        phase = .wordEntry
    }

    // MARK: - Binding

    private func bindRecordingService() {
        recordingService.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                guard let self else { return }
                self.liveSamples.removeFirst()
                self.liveSamples.append(level)
                self.waveformSamples = self.liveSamples
            }
            .store(in: &cancellables)

        recordingService.$recordingDuration
            .receive(on: DispatchQueue.main)
            .assign(to: &$recordingDuration)

        tts.$isSpeaking
            .receive(on: DispatchQueue.main)
            .sink { [weak self] speaking in
                if !speaking { self?.previewingWord = nil }
            }
            .store(in: &cancellables)
    }
}
