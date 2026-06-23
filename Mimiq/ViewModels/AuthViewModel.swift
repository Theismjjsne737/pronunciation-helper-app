import AuthenticationServices
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {

    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: User?
    @Published var errorMessage: String?
    @Published var isLoading = false

    // Email form state
    @Published var emailInput = ""
    @Published var passwordInput = ""
    @Published var isSignUp = false

    private let authService = AuthService.shared

    // MARK: - Launch restore

    func restoreSession() async {
        currentUser = await authService.restoreSession()
        isAuthenticated = currentUser != nil
    }

    // MARK: - Apple

    func handleSignInResult(_ result: Result<ASAuthorization, Error>) async {
        errorMessage = nil
        do {
            let authorization = try result.get()
            let user = try authService.processAuthorization(authorization)
            currentUser = user
            isAuthenticated = true
        } catch AuthError.cancelled {
            // no-op
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Google

    func signInWithGoogle() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let user = try await authService.signInWithGoogle()
            currentUser = user
            isAuthenticated = true
        } catch AuthError.cancelled {
            // no-op
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Email / Password

    func submitEmail() async {
        errorMessage = nil
        guard !emailInput.trimmingCharacters(in: .whitespaces).isEmpty,
              !passwordInput.isEmpty else {
            errorMessage = "Enter your email and password."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let user = isSignUp
                ? try await authService.signUpWithEmail(email: emailInput, password: passwordInput)
                : try await authService.signInWithEmail(email: emailInput, password: passwordInput)
            currentUser = user
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign out

    func signOut() {
        authService.signOut()
        currentUser = nil
        isAuthenticated = false
        emailInput = ""
        passwordInput = ""
    }
}
