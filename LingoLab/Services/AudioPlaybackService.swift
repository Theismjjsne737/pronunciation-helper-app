import AVFoundation
import Combine

/// Wraps AVAudioPlayer for both recorded attempts and bundled native-speaker examples.
@MainActor
final class AudioPlaybackService: NSObject, ObservableObject {

    // MARK: - Published state

    @Published private(set) var isPlaying = false
    @Published private(set) var progress: Double = 0   // 0.0 – 1.0
    @Published private(set) var duration: TimeInterval = 0

    // MARK: - Private

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?

    // MARK: - Playback

    func play(url: URL) throws {
        stop()

        try AudioSessionManager.shared.activate(category: .playback)

        player = try AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        player?.prepareToPlay()
        duration = player?.duration ?? 0
        player?.play()
        isPlaying = true
        startTracking()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        progressTimer?.invalidate()
    }

    func resume() {
        player?.play()
        isPlaying = true
        startTracking()
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        progress = 0
        duration = 0
        progressTimer?.invalidate()
        progressTimer = nil
        AudioSessionManager.shared.deactivate()
    }

    func seek(to fraction: Double) {
        guard let player else { return }
        player.currentTime = player.duration * max(0, min(1, fraction))
        progress = fraction
    }

    // MARK: - Private

    private func startTracking() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    private func tick() {
        guard let player, player.isPlaying else { return }
        progress = player.duration > 0 ? player.currentTime / player.duration : 0
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlaybackService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.progress = 0
            self.progressTimer?.invalidate()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.isPlaying = false
            self.progressTimer?.invalidate()
        }
    }
}
