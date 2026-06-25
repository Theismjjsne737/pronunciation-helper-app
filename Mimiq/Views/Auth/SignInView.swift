import AuthenticationServices
import SwiftUI

struct SignInView: View {

    @EnvironmentObject private var vm: AuthViewModel
    @State private var showEmailForm = false
    @FocusState private var focused: Field?

    private enum Field { case email, password }

    private let bg       = Color(red: 0.06, green: 0.06, blue: 0.10)
    private let card     = Color(red: 0.10, green: 0.10, blue: 0.16)
    private let violet   = Color(red: 0.53, green: 0.39, blue: 0.98)
    private let offWhite = Color(red: 0.94, green: 0.93, blue: 0.98)
    private let muted    = Color(red: 0.55, green: 0.53, blue: 0.65)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Logo
                    VStack(spacing: 16) {
                        Image("PronceParrot")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 110, height: 128)
                            .padding(.top, 72)

                        Text("Pronce")
                            .font(.system(size: 36, weight: .bold, design: .serif))
                            .foregroundStyle(offWhite)

                        Text("Say it right. Every time.")
                            .font(.system(size: 15))
                            .foregroundStyle(muted)
                    }

                    Spacer().frame(height: 56)

                    VStack(spacing: 14) {
                        // Apple
                        SignInWithAppleButton(vm.isSignUp ? .signUp : .signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            Task { await vm.handleSignInResult(result) }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        // Google
                        Button {
                            Task { await vm.signInWithGoogle() }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "globe")
                                    .font(.system(size: 18, weight: .medium))
                                Text("Continue with Google")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(offWhite)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // Divider
                        HStack {
                            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                            Text("or")
                                .font(.system(size: 12))
                                .foregroundStyle(muted)
                                .padding(.horizontal, 12)
                            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                        }

                        // Email
                        if showEmailForm {
                            emailForm
                        } else {
                            Button {
                                withAnimation(.spring(duration: 0.35)) { showEmailForm = true }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "envelope")
                                        .font(.system(size: 16, weight: .medium))
                                    Text("Continue with Email")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundStyle(offWhite)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(card)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }

                        if let error = vm.errorMessage {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundStyle(.red.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 28)

                    Spacer().frame(height: 40)

                    Text("By continuing you agree to our Terms & Privacy Policy.")
                        .font(.system(size: 11))
                        .foregroundStyle(muted.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 48)
                }
            }

            if vm.isLoading {
                Color.black.opacity(0.4).ignoresSafeArea()
                ProgressView().tint(violet)
            }
        }
    }

    @ViewBuilder
    private var emailForm: some View {
        VStack(spacing: 12) {
            TextField("", text: $vm.emailInput, prompt: Text("Email").foregroundStyle(muted))
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textContentType(.emailAddress)
                .focused($focused, equals: .email)
                .foregroundStyle(offWhite)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(card)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(focused == .email ? violet.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))

            SecureField("", text: $vm.passwordInput, prompt: Text("Password").foregroundStyle(muted))
                .textContentType(vm.isSignUp ? .newPassword : .password)
                .focused($focused, equals: .password)
                .foregroundStyle(offWhite)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(card)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(focused == .password ? violet.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))

            Button {
                focused = nil
                Task { await vm.submitEmail() }
            } label: {
                Group {
                    if vm.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(vm.isSignUp ? "Create Account" : "Sign In")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(violet)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button {
                vm.errorMessage = nil
                withAnimation { vm.isSignUp.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Text(vm.isSignUp ? "Already have an account?" : "Don't have an account?")
                        .foregroundStyle(muted)
                    Text(vm.isSignUp ? "Sign in" : "Sign up")
                        .foregroundStyle(violet)
                }
                .font(.system(size: 13))
            }
        }
    }
}
