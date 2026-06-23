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
        let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        return envKey
    }()

    // MARK: - Supabase

    /// Supabase project URL, e.g. "https://abcdefgh.supabase.co"
    /// Set SUPABASE_URL in your .xcconfig / build settings.
    static let supabaseURL: String = {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
    }()

    /// Supabase anon (public) key — safe to ship; RLS enforces row-level access.
    /// Set SUPABASE_ANON_KEY in your .xcconfig / build settings.
    static let supabaseAnonKey: String = {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""
    }()
}
