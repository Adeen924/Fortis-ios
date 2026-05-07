import AuthenticationServices
import CryptoKit
import FirebaseAuth
import Foundation
import Security
import UIKit

@Observable
final class AuthManager {
    var isAuthenticated = false
    var currentUserID: String?
    var needsProfileCompletion = false
    var pendingSocialFirstName = ""
    var pendingSocialLastName = ""
    var pendingSocialEmail: String? = nil
    var pendingSocialAuthProvider = "apple"

    private var authHandle: AuthStateDidChangeListenerHandle?
    @ObservationIgnored private var _googleAuthSession: ASWebAuthenticationSession?
    @ObservationIgnored private var _googleContextProvider: GoogleSignInContextProvider?
    @ObservationIgnored private var phoneSignUpInProgress = false
    @ObservationIgnored private let phoneAuthUIDelegate = PhoneAuthUIDelegate()

    func startSessionListener() async {
        if let cached = Auth.auth().currentUser {
            do {
                try await cached.reload()
                self.currentUserID = cached.uid
                self.isAuthenticated = true
            } catch {
                signOut()
            }
        }

        guard authHandle == nil else { return }
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            // While phone sign-up is in progress the user is already authenticated
            // in Firebase but hasn't saved a profile yet. Hold the app on WelcomeView
            // by keeping needsProfileCompletion = true until finishPhoneSignUp is called.
            if let user, self.phoneSignUpInProgress {
                self.currentUserID = user.uid
                self.isAuthenticated = true
                self.needsProfileCompletion = true
                return
            }
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
        return result.user.uid
    }

    @MainActor
    func sendPhoneVerification(phoneNumber: String) async throws -> String {
        try await PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: phoneAuthUIDelegate)
    }

    func signInWithPhone(verificationID: String, code: String, isSignUp: Bool = false) async throws -> String {
        if isSignUp { phoneSignUpInProgress = true }
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: code
        )
        let result = try await Auth.auth().signIn(with: credential)
        return result.user.uid
    }

    func finishPhoneSignUp(userID: String) {
        phoneSignUpInProgress = false
        completeSignIn(userID: userID)
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

        let firstName = credential.fullName?.givenName ?? ""
        let lastName = credential.fullName?.familyName ?? ""
        let email = credential.email
        beginSocialOnboarding(
            userID: result.user.uid,
            firstName: firstName,
            lastName: lastName,
            email: email,
            authProvider: "apple"
        )
        return result.user.uid
    }

    @MainActor
    func signInWithGoogle(presentationAnchor: ASPresentationAnchor) async throws -> String {
        let clientID = "445557254761-d7g6qak0r7hgenao0qfq09nrtiobic6b.apps.googleusercontent.com"
        let redirectScheme = "com.googleusercontent.apps.445557254761-d7g6qak0r7hgenao0qfq09nrtiobic6b"
        let redirectURI = redirectScheme + ":/"

        let codeVerifier = Self.randomNonceString(length: 64)
        let codeChallenge = Self.sha256Base64URLEncoded(codeVerifier)
        let state = Self.randomNonceString(length: 32)

        var authComps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        authComps.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
        ]

        let contextProvider = GoogleSignInContextProvider(anchor: presentationAnchor)

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authComps.url!, callbackURLScheme: redirectScheme) { url, error in
                if let error { continuation.resume(throwing: error) }
                else if let url { continuation.resume(returning: url) }
                else { continuation.resume(throwing: NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Authentication failed."])) }
            }
            session.presentationContextProvider = contextProvider
            session.prefersEphemeralWebBrowserSession = false
            self._googleAuthSession = session
            self._googleContextProvider = contextProvider
            session.start()
        }
        _googleAuthSession = nil
        _googleContextProvider = nil

        guard let callbackComps = URLComponents(url: callbackURL, resolvingAgainstBaseURL: true),
              let code = callbackComps.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw NSError(domain: "GoogleSignIn", code: -2, userInfo: [NSLocalizedDescriptionKey: "Sign-in was cancelled or failed."])
        }

        let (idToken, accessToken) = try await exchangeGoogleAuthCode(
            code: code, codeVerifier: codeVerifier, clientID: clientID, redirectURI: redirectURI
        )

        let payload = Self.decodeJWTPayload(idToken)
        let firstName = payload?["given_name"] as? String ?? ""
        let lastName = payload?["family_name"] as? String ?? ""
        let email = payload?["email"] as? String

        let googleCredential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        let result = try await Auth.auth().signIn(with: googleCredential)
        beginSocialOnboarding(
            userID: result.user.uid,
            firstName: firstName,
            lastName: lastName,
            email: email,
            authProvider: "google"
        )
        return result.user.uid
    }

    private func exchangeGoogleAuthCode(
        code: String, codeVerifier: String, clientID: String, redirectURI: String
    ) async throws -> (idToken: String, accessToken: String) {
        let url = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var formComps = URLComponents()
        formComps.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "code_verifier", value: codeVerifier),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
        ]
        request.httpBody = formComps.query?.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idToken = json["id_token"] as? String,
              let accessToken = json["access_token"] as? String else {
            let errorMsg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error_description"] as? String
            throw NSError(domain: "GoogleSignIn", code: -3, userInfo: [NSLocalizedDescriptionKey: errorMsg ?? "Failed to obtain Google tokens."])
        }
        return (idToken, accessToken)
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

    static func sha256Base64URLEncoded(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hash = SHA256.hash(data: inputData)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func decodeJWTPayload(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    func completeSignIn(userID: String) {
        currentUserID = userID
        isAuthenticated = true
        needsProfileCompletion = false
    }

    func beginSocialOnboarding(
        userID: String,
        firstName: String = "",
        lastName: String = "",
        email: String? = nil,
        authProvider: String = "apple"
    ) {
        currentUserID = userID
        needsProfileCompletion = true
        pendingSocialFirstName = firstName
        pendingSocialLastName = lastName
        pendingSocialEmail = email
        pendingSocialAuthProvider = authProvider
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
        guard let user = Auth.auth().currentUser else { return }
        try await user.delete()
        signOut()
    }
}

private class GoogleSignInContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    let anchor: ASPresentationAnchor
    init(anchor: ASPresentationAnchor) { self.anchor = anchor }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { anchor }
}

private class PhoneAuthUIDelegate: NSObject, AuthUIDelegate {
    @MainActor
    func present(_ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
        guard let topVC = topViewController() else { completion?(); return }
        topVC.present(viewControllerToPresent, animated: animated, completion: completion)
    }

    @MainActor
    func dismiss(animated: Bool, completion: (() -> Void)? = nil) {
        guard let topVC = topViewController() else { completion?(); return }
        topVC.dismiss(animated: animated, completion: completion)
    }

    @MainActor
    private func topViewController() -> UIViewController? {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController
        else { return nil }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
