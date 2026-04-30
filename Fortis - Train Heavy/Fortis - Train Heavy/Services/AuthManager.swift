import SwiftUI
import SwiftData
import AuthenticationServices

@Observable
final class AuthManager {
    var isAuthenticated: Bool
    var currentUserID: String?
    var needsProfileCompletion: Bool  // true after social sign-in, before profile is saved

    private let defaults = UserDefaults.standard

    init() {
        isAuthenticated      = defaults.bool(forKey: "fortis_isAuthenticated")
        currentUserID        = defaults.string(forKey: "fortis_userID")
        needsProfileCompletion = false
    }

    func completeSignIn(userID: String) {
        currentUserID   = userID
        isAuthenticated = true
        needsProfileCompletion = false
        defaults.set(true,   forKey: "fortis_isAuthenticated")
        defaults.set(userID, forKey: "fortis_userID")
    }

    func beginSocialOnboarding(userID: String) {
        currentUserID = userID
        needsProfileCompletion = true
    }

    func signOut() {
        currentUserID   = nil
        isAuthenticated = false
        needsProfileCompletion = false
        defaults.removeObject(forKey: "fortis_isAuthenticated")
        defaults.removeObject(forKey: "fortis_userID")
    }
}
