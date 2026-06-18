import UIKit

/// Lightweight wrapper around UIKit haptic generators.
/// All methods are safe to call from any thread.
enum HapticsService {

    // MARK: - Impact

    static func light()   { impact(.light) }
    static func medium()  { impact(.medium) }
    static func heavy()   { impact(.heavy) }
    static func soft()    { impact(.soft) }
    static func rigid()   { impact(.rigid) }

    // MARK: - Notification

    static func success() { notification(.success) }
    static func warning() { notification(.warning) }
    static func error()   { notification(.error) }

    // MARK: - Selection

    static func selection() {
        DispatchQueue.main.async {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    // MARK: - Private

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        DispatchQueue.main.async {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }

    private static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        DispatchQueue.main.async {
            UINotificationFeedbackGenerator().notificationOccurred(type)
        }
    }
}
