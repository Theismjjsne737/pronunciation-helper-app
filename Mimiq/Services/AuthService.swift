import AuthenticationServices
import Foundation

enum AuthError: LocalizedError {
    case credentialCastFailed
    case missingUserID
    case cancelled

    var errorDescription: String? {
        switch self {
        case .credentialCastFailed: return "Sign in failed. Please try again."
        case .missingUserID:        return "Could not retrieve your Apple ID."
        case .cancelled:            return nil
        }
    }
}

// MARK: - AuthService

/// Handles credential processing and Keychain persistence for Sign in with Apple.
/// The auth sheet is owned by SignInWithAppleButton in SwiftUI — no controller needed here.
@MainActor
final class AuthService {

    static let shared = AuthService()

    // MARK: - Process SwiftUI button result

    func processAuthorization(_ authorization: ASAuthorization) throws -> User {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential
        else { throw AuthError.credentialCastFailed }

        guard !credential.user.isEmpty else { throw AuthError.missingUserID }

        let fullName: String? = [
            credential.fullName?.givenName,
            credential.fullName?.familyName,
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
        .nilIfEmpty

        let user = User(appleUserID: credential.user, fullName: fullName)
        persist(user)
        return user
    }

    // MARK: - Restore session on launch

    func restoreSession() async -> User? {
        guard let userID = KeychainService.read(.appleUserID) else { return nil }

        let state = try? await ASAuthorizationAppleIDProvider()
            .credentialState(forUserID: userID)

        switch state {
        case .authorized:
            return User(
                appleUserID: userID,
                fullName: KeychainService.read(.appleFullName)
            )
        case .revoked, .notFound:
            signOut()
            return nil
        default:
            return nil
        }
    }

    // MARK: - Sign out

    func signOut() {
        KeychainService.delete(.appleUserID)
        KeychainService.delete(.appleFullName)
    }

    // MARK: - Private

    private func persist(_ user: User) {
        KeychainService.write(user.appleUserID, for: .appleUserID)
        if let name = user.fullName {
            KeychainService.write(name, for: .appleFullName)
        }
    }
}

// MARK: - String helper

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
