import SwiftUI

struct SignInView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var identifier  = ""  // email or phone
    @State private var password    = ""
    @State private var isLoading   = false
    @State private var errorText: String? = nil
    @State private var showingForgotPassword = false

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
                            TextField("Email or phone number", text: $identifier)
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
        }
        .preferredColorScheme(.dark)
    }

    private func attemptSignIn() {
        errorText = nil
        guard !identifier.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorText = "Enter your email or phone number."; return
        }
        guard password.count >= 8 else {
            errorText = "Password must be at least 8 characters."; return
        }
        isLoading = true

        // Look up matching profile in SwiftData
        let id = identifier.trimmingCharacters(in: .whitespaces).lowercased()
        let descriptor = FetchDescriptor<UserProfile>()
        let profiles = (try? modelContext.fetch(descriptor)) ?? []
        let match = profiles.first { profile in
            (profile.email?.lowercased() == id) ||
            (profile.phoneNumber?.filter { $0.isNumber } == id.filter { $0.isNumber })
        }

        isLoading = false
        if let profile = match {
            authManager.completeSignIn(userID: profile.id.uuidString)
        } else {
            errorText = "No account found with those credentials."
        }
    }
}
