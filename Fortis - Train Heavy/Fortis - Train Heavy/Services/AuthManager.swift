import AuthenticationServices
import CryptoKit
import FirebaseAuth
import Foundation
import Security

@Observable
final class AuthManager {
    var isAuthenticated = false
    var currentUserID: String?
    var needsProfileCompletion = false

    private var authHandle: AuthStateDidChangeListenerHandle?

    func startSessionListener() {
        guard authHandle == nil else { return }
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            self.currentUserID = user?.uid
            self.isAuthenticated = user != nil
            if user == nil {
                self.needsProfileCompletion = false
            }
        }
    }

    func signUpWithEmail(email: String, password: String) async throws -> String {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        completeSignIn(userID: result.user.uid)
        return result.user.uid
    }

    func signInWithEmail(email: String, password: String) async throws -> String {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        completeSignIn(userID: result.user.uid)
        return result.user.uid
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, nonce: String) async throws -> String {
        guard let tokenData = credential.identityToken,
              let tokenString = String(data: tokenData, encoding: .utf8) else {
            throw FirebaseDataError.invalidData("Unable to read Apple identity token.")
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        let result = try await Auth.auth().signIn(with: firebaseCredential)
        beginSocialOnboarding(userID: result.user.uid)
        return result.user.uid
    }

    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(status)")
            }

            randoms.forEach { random in
                if remainingLength == 0 { return }
                if Int(random) < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.map { String(format: "%02x", $0) }.joined()
    }

    func completeSignIn(userID: String) {
        currentUserID = userID
        isAuthenticated = true
        needsProfileCompletion = false
    }

    func beginSocialOnboarding(userID: String) {
        currentUserID = userID
        needsProfileCompletion = true
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("Firebase sign out failed: \(error)")
        }
        currentUserID = nil
        isAuthenticated = false
        needsProfileCompletion = false
    }

    func deleteCurrentAuthUser() async throws {
        try await Auth.auth().currentUser?.delete()
        currentUserID = nil
        isAuthenticated = false
        needsProfileCompletion = false
    }
}
