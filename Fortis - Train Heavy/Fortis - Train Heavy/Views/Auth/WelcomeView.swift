import SwiftUI
import AuthenticationServices

struct WelcomeView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var showingSignUp   = false
    @State private var showingSignIn   = false
    @State private var googleAlert     = false
    @State private var currentNonce: String?

    var body: some View {
        @Bindable var authManager = authManager
        ZStack {
            Color.romanBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                brandSection
                Spacer()
                authButtonStack
                Spacer(minLength: 20)
                signInFooter
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 28)
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showingSignUp) {
            SignUpView()
                .environment(authManager)
        }
        .fullScreenCover(isPresented: $showingSignIn) {
            SignInView()
                .environment(authManager)
        }
        .sheet(isPresented: $authManager.needsProfileCompletion) {
            SocialProfileCompletionView()
                .environment(authManager)
        }
        .alert("Google Sign-In", isPresented: $googleAlert) {
            Button("OK") {}
        } message: {
            Text("Google Sign-In requires the GoogleSignIn SDK. Add it via File → Add Package Dependencies → https://github.com/google/GoogleSignIn-iOS")
        }
    }

    // MARK: - Brand
    private var brandSection: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.romanSurface)
                    .frame(width: 120, height: 120)
                    .overlay(Circle().stroke(LinearGradient.romanGoldGradient, lineWidth: 1.5))
                    .shadow(color: .romanGold.opacity(0.3), radius: 24, x: 0, y: 8)
                Image(systemName: "shield.fill")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(LinearGradient.romanGoldGradient)
            }

            VStack(spacing: 8) {
                Text("FORTIS")
                    .font(.system(size: 46, weight: .black, design: .serif))
                    .foregroundStyle(LinearGradient.romanGoldGradient)
                    .tracking(10)

                Text("TRAIN HEAVY · GROW STRONGER")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.romanParchmentDim)
                    .tracking(4)

                Text("Forge Your Legacy")
                    .font(.system(size: 16, weight: .light, design: .serif))
                    .italic()
                    .foregroundStyle(.romanGoldDim)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Auth Buttons
    private var authButtonStack: some View {
        VStack(spacing: 14) {
            // Apple Sign In
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

            // Google Sign In (requires SDK — shows guidance alert)
            Button(action: { googleAlert = true }) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(.white).frame(width: 22, height: 22)
                        Text("G")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                    }
                    Text("Continue with Google")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.romanParchment)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.romanSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.romanBorder, lineWidth: 1))
            }

            // Divider
            HStack(spacing: 12) {
                Rectangle().fill(Color.romanBorder).frame(height: 0.5)
                Text("OR").font(.system(size: 11, weight: .bold)).tracking(3).foregroundStyle(.romanParchmentDim)
                Rectangle().fill(Color.romanBorder).frame(height: 0.5)
            }
            .padding(.vertical, 4)

            // Create Account
            Button(action: { showingSignUp = true }) {
                Text("CREATE ACCOUNT")
                    .font(.system(size: 14, weight: .black))
                    .tracking(3)
                    .foregroundStyle(.romanBackground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(LinearGradient.romanGoldGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .romanGold.opacity(0.3), radius: 12, x: 0, y: 6)
            }
        }
    }

    // MARK: - Footer
    private var signInFooter: some View {
        Button(action: { showingSignIn = true }) {
            HStack(spacing: 4) {
                Text("Already have an account?")
                    .foregroundStyle(.romanParchmentDim)
                Text("Sign In")
                    .foregroundStyle(.romanGold)
                    .bold()
            }
            .font(.subheadline)
        }
    }

    // MARK: - Apple Sign In Handler
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = currentNonce else { return }
            Task {
                try? await authManager.signInWithApple(credential: credential, nonce: nonce)
            }
        case .failure:
            break
        }
    }
}
