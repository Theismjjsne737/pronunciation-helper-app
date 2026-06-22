import AVFoundation
import Combine

/// Wraps AVAudioRecorder. Publishes real-time audio levels for waveform rendering.
@MainActor
final class AudioRecordingService: NSObject, ObservableObject {

    // MARK: - Published state

    @Published private(set) var isRecording = false
    @Published private(set) var audioLevel: Float = 0      // 0.0 – 1.0 normalised
    @Published private(set) var recordingDuration: TimeInterval = 0

    // MARK: - Private

    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var durationTimer: Timer?

    // MARK: - Init

    override init() {
        super.init()
        AudioSessionManager.shared.onInterruptionBegan = { [weak self] in
            self?.stopRecording()
        }
    }

    // MARK: - Permissions

    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    // MARK: - Recording lifecycle

    /// Starts recording and returns the URL where audio will be saved.
    func startRecording() throws -> URL {
        let url = makeRecordingURL()
        try ensureRecordingsDirectoryExists(for: url)

        try AudioSessionManager.shared.activate(
            category: .playAndRecord,
            mode: .measurement,
            options: [.defaultToSpeaker, .allowBluetooth]
        )

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()

        isRecording = true
        recordingDuration = 0
        startMetering()
        return url
    }

    /// Stops the current recording. The file at the previously returned URL is complete after this.
    func stopRecording() {
        audioRecorder?.stop()
        stopMetering()
        isRecording = false
        AudioSessionManager.shared.deactivate()
    }

    // MARK: - Helpers

    private func makeRecordingURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Recordings", isDirectory: true)
        return dir.appendingPathComponent("rec_\(UUID().uuidString).m4a")
    }

    private func ensureRecordingsDirectoryExists(for url: URL) throws {
        let dir = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private func startMetering() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateAudioLevel() }
        }
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.recordingDuration += 0.1
            }
        }
    }

    private func stopMetering() {
        levelTimer?.invalidate(); levelTimer = nil
        durationTimer?.invalidate(); durationTimer = nil
        audioLevel = 0
    }

    private func updateAudioLevel() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0) // dB, -160…0
        // Smooth normalisation: map –50…0 dB to 0…1 for a more responsive display
        let clamped = max(-50, min(0, power))
        audioLevel = Float((clamped + 50) / 50)
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecordingService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            self.isRecording = false
            self.stopMetering()
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            self.isRecording = false
            self.stopMetering()
        }
    }
}
