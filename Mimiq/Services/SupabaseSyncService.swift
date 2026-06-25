import Foundation
import SwiftData

// MARK: - Supabase SQL migration (run once in Supabase SQL editor)
//
// CREATE TABLE accent_profiles (
//   id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
//   user_id              TEXT        NOT NULL UNIQUE,
//   native_language      TEXT,
//   phoneme_patterns     JSONB       NOT NULL DEFAULT '[]',
//   progress_history     JSONB       NOT NULL DEFAULT '[]',
//   total_practice_words INT         NOT NULL DEFAULT 0,
//   total_sessions       INT         NOT NULL DEFAULT 0,
//   onboarding_completed BOOL        NOT NULL DEFAULT FALSE,
//   created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
//   last_updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
// );
// ALTER TABLE accent_profiles ENABLE ROW LEVEL SECURITY;
// ⚠️  SECURITY: open policy below allows any anon caller to read/write any row.
// Before production: exchange the Sign in with Apple token for a Supabase JWT, then replace with:
// CREATE POLICY "own_row" ON accent_profiles
//   FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
// Dev-only open policy (remove before shipping):
// CREATE POLICY "anon_own_row" ON accent_profiles
//   FOR ALL USING (true) WITH CHECK (true);

// MARK: - DTO

private struct AccentProfileDTO: Codable {
    var userID: String
    var nativeLanguage: String?
    var phonemePatterns: [PhonemePattern]
    var progressHistory: [PhonemeProgressEntry]
    var totalPracticeWords: Int
    var totalSessions: Int
    var onboardingCompleted: Bool
    var createdAt: Date
    var lastUpdatedAt: Date

    init(userID: String, profile: AccentProfile) {
        self.userID              = userID
        self.nativeLanguage      = profile.nativeLanguage
        self.phonemePatterns     = profile.phonemePatterns
        self.progressHistory     = profile.progressHistory
        self.totalPracticeWords  = profile.totalPracticeWords
        self.totalSessions       = profile.totalSessions
        self.onboardingCompleted = profile.onboardingCompleted
        self.createdAt           = profile.createdAt
        self.lastUpdatedAt       = profile.lastUpdatedAt
    }

    enum CodingKeys: String, CodingKey {
        case userID              = "user_id"
        case nativeLanguage      = "native_language"
        case phonemePatterns     = "phoneme_patterns"
        case progressHistory     = "progress_history"
        case totalPracticeWords  = "total_practice_words"
        case totalSessions       = "total_sessions"
        case onboardingCompleted = "onboarding_completed"
        case createdAt           = "created_at"
        case lastUpdatedAt       = "last_updated_at"
    }
}

// MARK: - Service

/// URLSession-based Supabase sync — no SPM dependency required.
/// Pull on launch (remote wins if newer), push when app backgrounds.
@MainActor
final class SupabaseSyncService: ObservableObject {

    static let shared = SupabaseSyncService()

    @Published private(set) var isSyncing  = false
    @Published private(set) var lastSyncAt: Date?
    @Published private(set) var syncError:  String?

    private var baseURL:    String { Config.supabaseURL }
    private var anonKey:    String { Config.supabaseAnonKey }
    private var configured: Bool   { !baseURL.isEmpty && !anonKey.isEmpty }

    // MARK: - Pull (app launch — remote wins if newer)

    func pull(userID: String, into context: ModelContext) async {
        guard configured else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            guard let dto = try await fetchRemote(userID: userID) else { return }
            let profile = localProfile(in: context)
            guard dto.lastUpdatedAt > profile.lastUpdatedAt else { return }
            apply(dto, to: profile)
            try? context.save()
            lastSyncAt = Date()
        } catch {
            syncError = error.localizedDescription
        }
    }

    // MARK: - Push (background / post-session)

    func push(userID: String, profile: AccentProfile) async {
        guard configured else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await upsertRemote(userID: userID, profile: profile)
            lastSyncAt = Date()
            syncError  = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    // MARK: - REST: GET

    private func fetchRemote(userID: String) async throws -> AccentProfileDTO? {
        let safe = userID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? userID
        guard let url = URL(string: "\(baseURL)/rest/v1/accent_profiles?user_id=eq.\(safe)&limit=1")
        else { return nil }

        var req = URLRequest(url: url)
        req.setValue(anonKey,             forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json",  forHTTPHeaderField: "Accept")

        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder.supabase.decode([AccentProfileDTO].self, from: data).first
    }

    // MARK: - REST: POST upsert

    private func upsertRemote(userID: String, profile: AccentProfile) async throws {
        guard let url = URL(string: "\(baseURL)/rest/v1/accent_profiles") else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(anonKey,                       forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(anonKey)",            forHTTPHeaderField: "Authorization")
        req.setValue("application/json",             forHTTPHeaderField: "Content-Type")
        req.setValue("resolution=merge-duplicates",  forHTTPHeaderField: "Prefer")
        req.httpBody = try JSONEncoder.supabase.encode(AccentProfileDTO(userID: userID, profile: profile))

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode)
        else { throw URLError(.badServerResponse) }
    }

    // MARK: - SwiftData helpers

    private func localProfile(in context: ModelContext) -> AccentProfile {
        if let p = (try? context.fetch(FetchDescriptor<AccentProfile>()))?.first { return p }
        let p = AccentProfile()
        context.insert(p)
        return p
    }

    private func apply(_ dto: AccentProfileDTO, to profile: AccentProfile) {
        profile.nativeLanguage      = dto.nativeLanguage
        profile.phonemePatterns     = dto.phonemePatterns
        profile.progressHistory     = dto.progressHistory
        profile.totalPracticeWords  = dto.totalPracticeWords
        profile.totalSessions       = dto.totalSessions
        profile.onboardingCompleted = dto.onboardingCompleted
        profile.lastUpdatedAt       = dto.lastUpdatedAt
    }
}

// MARK: - Encoder / Decoder

private extension JSONEncoder {
    static let supabase: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

private extension JSONDecoder {
    static let supabase: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
