import SwiftUI

@main
struct FortisApp: App {
    @StateObject private var appSettings = AppSettings.shared
    @StateObject private var dataStore = FirebaseDataStore()
    @State private var authManager: AuthManager
    @State private var isCheckingSession = true

    init() {
        FirebaseService.configure()
        _authManager = State(initialValue: AuthManager())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isCheckingSession {
                    ZStack {
                        Color.romanBackground.ignoresSafeArea()
                        VStack(spacing: 16) {
                            Image(systemName: "shield.fill")
                                .font(.system(size: 56, weight: .bold))
                                .foregroundStyle(Color.romanGold)
                            ProgressView()
                                .tint(Color.romanGold)
                        }
                    }
                } else if authManager.isAuthenticated && !authManager.needsProfileCompletion {
                    ContentView()
                } else {
                    WelcomeView()
                }
            }
            .environment(authManager)
            .environmentObject(appSettings)
            .environmentObject(dataStore)
            .animation(.easeInOut(duration: 0.35), value: isCheckingSession)
            .animation(.easeInOut(duration: 0.4), value: authManager.isAuthenticated)
            .task {
                await authManager.startSessionListener()
                dataStore.start(for: authManager.currentUserID)
                isCheckingSession = false
            }
            .onChange(of: authManager.currentUserID) { _, newValue in
                dataStore.start(for: newValue)
            }
        }
    }
}
