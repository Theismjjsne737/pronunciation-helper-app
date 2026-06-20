import AVFoundation
import Combine

/// Wraps AVSpeechSynthesizer to pronounce any word or phrase on demand.
/// Used to give users a "hear the word" reference before they record.
@MainActor
final class TTSService: NSObject, ObservableObject {

    @Published private(set) var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()

    // Available English voice options
    enum Rate: Float {
        case slow   = 0.30   // Exaggerated clarity for learning
        case normal = 0.45   // Natural pace
    }

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Public API

    /// Speak `text` at the given rate using the device's en-US voice.
    func speak(_ text: String, rate: Rate = .normal) {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate.rawValue
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = 0.1

        // Prefer a high-quality en-US voice if available
        utterance.voice = preferredVoice()

        synthesizer.speak(utterance)
        isSpeaking = true
    }

    /// Speak `text` at a slower rate — useful for demonstration.
    func speakSlowly(_ text: String) {
        speak(text, rate: .slow)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    // MARK: - Private

    private func preferredVoice() -> AVSpeechSynthesisVoice? {
        let lang = UserDefaults.standard.string(forKey: "practiceLanguage") ?? "en-US"
        let voices = AVSpeechSynthesisVoice.speechVoices()
        if let enhanced = voices.first(where: {
            $0.language.hasPrefix(lang) && $0.quality == .enhanced
        }) { return enhanced }
        return AVSpeechSynthesisVoice(language: lang)
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TTSService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in self.isSpeaking = false }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
