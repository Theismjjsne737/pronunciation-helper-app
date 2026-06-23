import AuthenticationServices
import Foundation

enum AuthError: LocalizedError {
    case credentialCastFailed
    case missingUserID
    case cancelled
    case supabaseNotConfigured
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .credentialCastFailed:  return "Sign in failed. Please try again."
        case .missingUserID:         return "Could not retrieve your Apple ID."
        case .cancelled:             return nil
        case .supabaseNotConfigured: return "Auth service not configured."
        case .networkError(let msg): return msg
        }
    }
}

// MARK: - Supabase shapes

private struct SupabaseAuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let user: SupabaseUser
    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

private struct SupabaseUser: Decodable {
    let id: String
    let email: String?
}

private struct SupabaseErrorResponse: Decodable {
    let message: String?
    let msg: String?
    var text: String { message ?? msg ?? "Authentication failed." }
}

// MARK: - AuthService

@MainActor
final class AuthService {

    static let shared = AuthService()

    // MARK: - Apple (native)

    func processAuthorization(_ authorization: ASAuthorization) throws -> User {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential
        else { throw AuthError.credentialCastFailed }
        guard !credential.user.isEmpty else { throw AuthError.missingUserID }

        let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ").nilIfEmpty

        KeychainService.write(credential.user, for: .appleUserID)
        if let name = fullName { KeychainService.write(name, for: .appleFullName) }
        KeychainService.write(AuthProvider.apple.rawValue, for: .userProvider)
        return User(appleUserID: credential.user, fullName: fullName)
    }

    // MARK: - Email / password (Supabase REST)

    func signInWithEmail(email: String, password: String) async throws -> User {
        let r = try await supabaseAuth(path: "/token?grant_type=password",
                                       body: ["email": email, "password": password])
        return persist(r, provider: .email)
    }

    func signUpWithEmail(email: String, password: String) async throws -> User {
        let r = try await supabaseAuth(path: "/signup",
                                       body: ["email": email, "password": password])
        return persist(r, provider: .email)
    }

    // MARK: - Google (Supabase OAuth via ASWebAuthenticationSession)

    func signInWithGoogle() async throws -> User {
        guard !Config.supabaseURL.isEmpty, !Config.supabaseAnonKey.isEmpty
        else { throw AuthError.supabaseNotConfigured }

        let authURL = URL(string: "\(Config.supabaseURL)/auth/v1/authorize?provider=google&redirect_to=mimiq://auth-callback")!

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "mimiq"
            ) { url, error in
                if let err = error as? ASWebAuthenticationSessionError, err.code == .canceledLogin {
                    continuation.resume(throwing: AuthError.cancelled); return
                }
                guard let url else {
                    continuation.resume(throwing: AuthError.networkError("OAuth callback missing.")); return
                }
                var params: [String: String] = [:]
                (url.fragment ?? "").split(separator: "&").forEach { pair in
                    let kv = pair.split(separator: "=", maxSplits: 1)
                    if kv.count == 2 { params[String(kv[0])] = String(kv[1]) }
                }
                guard let accessToken  = params["access_token"],
                      let refreshToken = params["refresh_token"] else {
                    continuation.resume(throwing: AuthError.networkError("Tokens missing in OAuth response.")); return
                }
                KeychainService.write(accessToken,                   for: .authToken)
                KeychainService.write(refreshToken,                  for: .refreshToken)
                KeychainService.write(AuthProvider.google.rawValue,  for: .userProvider)
                let user = User(id: UUID().uuidString, provider: .google, email: nil, accessToken: accessToken)
                continuation.resume(returning: user)
            }
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    // MARK: - Restore session on launch

    func restoreSession() async -> User? {
        let providerRaw = KeychainService.read(.userProvider) ?? AuthProvider.apple.rawValue
        let provider = AuthProvider(rawValue: providerRaw) ?? .apple

        switch provider {
        case .apple:
            guard let uid = KeychainService.read(.appleUserID) else { return nil }
            let state = try? await ASAuthorizationAppleIDProvider().credentialState(forUserID: uid)
            guard state == .authorized else { signOut(); return nil }
            return User(appleUserID: uid, fullName: KeychainService.read(.appleFullName))

        case .google, .email:
            guard let token = KeychainService.read(.authToken),
                  let uid   = KeychainService.read(.supabaseUserID) else { return nil }
            return User(id: uid, provider: provider,
                        email: KeychainService.read(.userEmail), accessToken: token)
        }
    }

    // MARK: - Sign out

    func signOut() {
        KeychainService.delete(.appleUserID)
        KeychainService.delete(.appleFullName)
        KeychainService.delete(.authToken)
        KeychainService.delete(.refreshToken)
        KeychainService.delete(.userEmail)
        KeychainService.delete(.userProvider)
        KeychainService.delete(.supabaseUserID)
    }

    // MARK: - Supabase REST helper

    private func supabaseAuth(path: String, body: [String: String]) async throws -> SupabaseAuthResponse {
        guard !Config.supabaseURL.isEmpty, !Config.supabaseAnonKey.isEmpty
        else { throw AuthError.supabaseNotConfigured }

        var req = URLRequest(url: URL(string: "\(Config.supabaseURL)/auth/v1\(path)")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            let msg = (try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data))?.text
                   ?? "Request failed (\(http.statusCode))."
            throw AuthError.networkError(msg)
        }
        return try JSONDecoder().decode(SupabaseAuthResponse.self, from: data)
    }

    private func persist(_ r: SupabaseAuthResponse, provider: AuthProvider) -> User {
        KeychainService.write(r.accessToken,       for: .authToken)
        KeychainService.write(r.refreshToken,      for: .refreshToken)
        KeychainService.write(r.user.id,           for: .supabaseUserID)
        if let email = r.user.email { KeychainService.write(email, for: .userEmail) }
        KeychainService.write(provider.rawValue,   for: .userProvider)
        return User(id: r.user.id, provider: provider, email: r.user.email, accessToken: r.accessToken)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
