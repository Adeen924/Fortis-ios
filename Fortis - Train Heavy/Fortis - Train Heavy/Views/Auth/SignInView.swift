import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(AuthManager.self) private var authManager
    @EnvironmentObject private var dataStore: FirebaseDataStore
    @Environment(\.dismiss) private var dismiss

    @State private var identifier  = ""
    @State private var password    = ""
    @State private var isLoading   = false
    @State private var errorText: String? = nil
    @State private var showingForgotPassword = false
    @State private var showingProfileCompletion = false
    @State private var appleFirstName = ""
    @State private var appleLastName = ""
    @State private var appleEmail: String? = nil
    @State private var currentNonce: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.romanBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Brand mark
                        VStack(spacing: 10) {
                            Image(systemName: "shield.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(LinearGradient.romanGoldGradient)
                                .padding(.top, 20)
                            Text("WELCOME BACK")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(4)
                                .foregroundStyle(.romanParchmentDim)
                            Text("Sign in to continue your legacy")
                                .font(.subheadline)
                                .foregroundStyle(.romanParchmentDim)
                        }

                        VStack(spacing: 14) {
                            TextField("Email address", text: $identifier)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.subheadline)
                                .foregroundStyle(.romanParchment)
                                .padding(16)
                                .background(Color.romanSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.romanBorder, lineWidth: 0.5))

                            SecureField("Password", text: $password)
                                .font(.subheadline)
                                .foregroundStyle(.romanParchment)
                                .padding(16)
                                .background(Color.romanSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.romanBorder, lineWidth: 0.5))

                            Button(action: { showingForgotPassword = true }) {
                                Text("Forgot password?")
                                    .font(.caption.bold())
                                    .foregroundStyle(.romanGoldDim)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }

                        if let error = errorText {
                            Label(error, systemImage: "exclamationmark.circle")
                                .font(.caption.bold())
                                .foregroundStyle(.romanCrimson)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                            let nonce = AuthManager.randomNonceString()
                            currentNonce = nonce
                            request.nonce = AuthManager.sha256(nonce)
                        } onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        // Sign In Button
                        Button(action: attemptSignIn) {
                            HStack(spacing: 8) {
                                if isLoading {
                                    ProgressView().tint(.romanBackground)
                                } else {
                                    Text("SIGN IN")
                                        .font(.system(size: 14, weight: .black))
                                        .tracking(3)
                                }
                            }
                            .foregroundStyle(.romanBackground)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(LinearGradient.romanGoldGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .romanGold.opacity(0.3), radius: 12, x: 0, y: 6)
                        }
                        .disabled(isLoading)

                        // Create account link
                        Button(action: dismiss.callAsFunction) {
                            HStack(spacing: 4) {
                                Text("Don't have an account?")
                                    .foregroundStyle(.romanParchmentDim)
                                Text("Create one")
                                    .foregroundStyle(.romanGold)
                                    .bold()
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: dismiss.callAsFunction) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundStyle(.romanParchmentDim)
                    }
                }
            }
            .alert("Reset Password", isPresented: $showingForgotPassword) {
                Button("OK") {}
            } message: {
                Text("Password reset requires a backend integration. Please contact support or re-create your account.")
            }
            .sheet(isPresented: $showingProfileCompletion) {
                SocialProfileCompletionView(firstName: appleFirstName, lastName: appleLastName, email: appleEmail)
                    .environment(authManager)
            }
            .onChange(of: authManager.isAuthenticated) { authenticated in
                if authenticated {
                    showingProfileCompletion = false
                }
            }
            .onChange(of: authManager.needsProfileCompletion) { needsCompletion in
                if !needsCompletion {
                    showingProfileCompletion = false
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = currentNonce else { return }
            appleFirstName = credential.fullName?.givenName ?? ""
            appleLastName = credential.fullName?.familyName ?? ""
            appleEmail = credential.email
            Task {
                do {
                    _ = try await authManager.signInWithApple(credential: credential, nonce: nonce)
                    showingProfileCompletion = true
                } catch {
                    errorText = error.localizedDescription
                }
            }
        case .failure:
            errorText = "Apple Sign In failed. Please try again."
        }
    }

    private func attemptSignIn() {
        errorText = nil
        let email = identifier.trimmingCharacters(in: .whitespaces)
        guard !email.isEmpty else { errorText = "Enter your email."; return }
        guard email.contains("@"), email.contains(".") else { errorText = "Enter a valid email address."; return }
        guard password.count >= 8 else { errorText = "Password must be at least 8 characters."; return }

        isLoading = true
        Task {
            do {
                let userId = try await authManager.signInWithEmail(
                    email: email,
                    password: password
                )

                guard try await dataStore.profileExists(userId: userId) else {
                    authManager.signOut()
                    errorText = "No Fortis profile was found for this email. Create an account first."
                    isLoading = false
                    return
                }

                authManager.completeSignIn(userID: userId)
            } catch {
                authManager.signOut()
                errorText = error.localizedDescription
            }
            isLoading = false
        }
    }
}
