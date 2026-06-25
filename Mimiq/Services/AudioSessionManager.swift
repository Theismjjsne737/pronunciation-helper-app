import AVFoundation

/// Centralised AVAudioSession manager.
/// All audio services should call activate/deactivate here instead of touching the shared session directly.
@MainActor
final class AudioSessionManager: ObservableObject {

    static let shared = AudioSessionManager()

    // MARK: - Published state

    @Published private(set) var isInterrupted = false
    @Published private(set) var headphonesConnected = false

    // MARK: - Interruption / route callbacks

    var onInterruptionBegan: (() -> Void)?
    var onInterruptionEnded: ((_ shouldResume: Bool) -> Void)?
    var onRouteChanged: ((AVAudioSession.RouteChangeReason) -> Void)?

    // MARK: - Init

    private init() {
        headphonesConnected = Self.detectHeadphones()
        registerNotifications()
    }

    // MARK: - Session lifecycle

    func activate(category: AVAudioSession.Category,
                  mode: AVAudioSession.Mode = .default,
                  options: AVAudioSession.CategoryOptions = []) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(category, mode: mode, options: options)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Notifications

    private func registerNotifications() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()
        center.addObserver(self,
                           selector: #selector(handleInterruption(_:)),
                           name: AVAudioSession.interruptionNotification,
                           object: session)
        center.addObserver(self,
                           selector: #selector(handleRouteChange(_:)),
                           name: AVAudioSession.routeChangeNotification,
                           object: session)
    }

    @objc nonisolated private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeRaw)
        else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            switch type {
            case .began:
                self.isInterrupted = true
                self.onInterruptionBegan?()
            case .ended:
                self.isInterrupted = false
                let optRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                let shouldResume = AVAudioSession.InterruptionOptions(rawValue: optRaw).contains(.shouldResume)
                self.onInterruptionEnded?(shouldResume)
            @unknown default:
                break
            }
        }
    }

    @objc nonisolated private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonRaw = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw)
        else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.headphonesConnected = Self.detectHeadphones()
            self.onRouteChanged?(reason)
        }
    }

    // MARK: - Helpers

    private static func detectHeadphones() -> Bool {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        return outputs.contains {
            [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE].contains($0.portType)
        }
    }
}
