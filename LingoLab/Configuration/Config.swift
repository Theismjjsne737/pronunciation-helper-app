import Foundation

/// App-level configuration. Set these before shipping.
/// Use xcconfig / build settings to inject secrets — never hardcode in git.
enum Config {

    // MARK: - Backend

    /// Your deployed Vercel backend URL, e.g. "https://lingolab-api.vercel.app"
    /// When empty the app falls back to calling Anthropic directly (dev only).
    static let backendURL: String = {
        Bundle.main.object(forInfoDictionaryKey: "LINGOLAB_BACKEND_URL") as? String ?? ""
    }()

    /// Shared secret between the iOS app and the backend API.
    /// Must match APP_SECRET in your Vercel environment variables.
    static let appSecret: String = {
        Bundle.main.object(forInfoDictionaryKey: "LINGOLAB_APP_SECRET") as? String ?? ""
    }()

    // MARK: - Direct API key (dev fallback only — do NOT ship with a real key)

    /// Only used when backendURL is empty (local development).
    static let anthropicAPIKey: String = {
        if let key = Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String,
           !key.isEmpty, key != "$(ANTHROPIC_API_KEY)" { return key }
        return ""
    }()
}
