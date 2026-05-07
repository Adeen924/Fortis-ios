import UIKit
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Register for remote notifications so Firebase can receive silent APNs
        // pushes for phone number verification without requiring user permission.
        UIApplication.shared.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        completionHandler(.noData)
    }

    // Handles the reCAPTCHA redirect URL used as a fallback when APNs isn't
    // available (e.g. simulator or APNs certificate not yet uploaded to Firebase).
    func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        if Auth.auth().canHandle(url) {
            return true
        }
        return false
    }
}
