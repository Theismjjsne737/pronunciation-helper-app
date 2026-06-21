import Speech
import AVFoundation
import SwiftUI

/// Real-time speech-to-text for the chat input bar.
/// Uses SFSpeechRecognizer with an AVAudioEngine tap — no file saved.
@MainActor
final class VoiceInputService: ObservableObject {

    @Published private(set) var transcript = ""
    @Published private(set) var isListening = false
    @Published var errorMessage: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private let audioEngine = AVAudioEngine()

    // MARK: - Toggle

    func toggle() async {
        isListening ? stop() : await start()
    }

    // MARK: - Start

    func start() async {
        guard !isListening else { return }

        // Request permission
        let authorized = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        guard authorized else {
            errorMessage = "Speech recognition not authorized."
            return
        }

        do {
            transcript = ""
            isListening = true
            HapticsService.light()

            try AudioSessionManager.shared.activate(category: .record, mode: .measurement, options: .duckOthers)

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let request = recognitionRequest else { stop(); return }
            request.shouldReportPartialResults = true

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)

            recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    if let result {
                        self?.transcript = result.bestTranscription.formattedString
                    }
                    if error != nil || result?.isFinal == true {
                        self?.stop()
                    }
                }
            }

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

        } catch {
            errorMessage = "Couldn't start listening: \(error.localizedDescription)"
            stop()
        }
    }

    // MARK: - Stop

    func stop() {
        guard isListening else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        AudioSessionManager.shared.deactivate()
        HapticsService.light()
    }

    /// Returns the transcript and clears it.
    func consume() -> String {
        defer { transcript = "" }
        return transcript
    }
}
