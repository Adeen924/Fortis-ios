import SwiftUI
import SwiftData

@main
struct FortisApp: App {
    let modelContainer: ModelContainer
    @StateObject private var appSettings = AppSettings.shared
    @State private var authManager      = AuthManager()
    @State private var isCheckingSession = true   // show splash while validating JWT

    init() {
        func makeContainer() throws -> ModelContainer {
            try ModelContainer(
                for: Exercise.self,
                     WorkoutSession.self,
                     ExerciseSet.self,
                     WorkoutExercise.self,
                     UserProfile.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
        }

        do {
            modelContainer = try makeContainer()
        } catch {
            Self.removeDefaultStore()
            do {
                modelContainer = try makeContainer()
            } catch {
                fatalError("Failed to initialize ModelContainer after reset: \(error)")
            }
        }

        let container = modelContainer
        Task.detached(priority: .utility) {
            let context = ModelContext(container)
            await ExerciseService.seedIfNeeded(context: context)
        }
    }

    private static func removeDefaultStore() {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let store = dir.appendingPathComponent("default.store")
        for f in [store, store.appendingPathExtension("-shm"), store.appendingPathExtension("-wal")] {
            try? FileManager.default.removeItem(at: f)
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isCheckingSession {
                    // ── Splash while the Supabase JWT is validated ──
                    ZStack {
                        Color(red: 0.11, green: 0.07, blue: 0)   // romanBackground
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            Image(systemName: "shield.fill")
                                .font(.system(size: 56, weight: .bold))
                                .foregroundStyle(Color(red: 0.83, green: 0.57, blue: 0.04))
                            ProgressView()
                                .tint(Color(red: 0.83, green: 0.57, blue: 0.04))
                        }
                    }
                } else if authManager.isAuthenticated {
                    ContentView()
                } else {
                    WelcomeView()
                }
            }
            .modelContainer(modelContainer)
            .environment(authManager)
            .environmentObject(appSettings)
            .animation(.easeInOut(duration: 0.35), value: isCheckingSession)
            .animation(.easeInOut(duration: 0.4),  value: authManager.isAuthenticated)
            // ── Session validation on launch ──────────────────────────────────
            .task {
                await validateSession()
            }
            // ── Auto-sync when connectivity is restored ───────────────────────
            .onChange(of: NetworkMonitor.shared.isConnected) { oldValue, newValue in
                if !oldValue && newValue && authManager.isAuthenticated {
                    let ctx = modelContainer.mainContext
                    Task {
                        await SupabaseService.shared.syncPendingSessions(context: ctx)
                    }
                }
            }
        }
    }

    // MARK: - Session validation

    private func validateSession() async {
        if let userId = await SupabaseService.shared.restoreSession() {
            // Valid Supabase session — make sure AuthManager reflects it
            if !authManager.isAuthenticated {
                authManager.completeSignIn(userID: userId.uuidString)
            }
        } else {
            // No valid session — force sign-out so stale UserDefaults don't lie
            if authManager.isAuthenticated {
                authManager.signOut()
            }
        }
        isCheckingSession = false
    }
}
