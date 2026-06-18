import AuthenticationServices
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {

    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: User?
    @Published var errorMessage: String?

    private let authService = AuthService.shared

    // MARK: - Launch restore

    func restoreSession() async {
        currentUser = await authService.restoreSession()
        isAuthenticated = currentUser != nil
    }

    // MARK: - Handle SignInWithAppleButton result

    func handleSignInResult(_ result: Result<ASAuthorization, Error>) async {
        errorMessage = nil
        do {
            let authorization = try result.get()
            let user = try authService.processAuthorization(authorization)
            currentUser = user
            isAuthenticated = true
        } catch AuthError.cancelled {
            // User dismissed sheet — no error shown
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign out

    func signOut() {
        authService.signOut()
        currentUser = nil
        isAuthenticated = false
    }
}
