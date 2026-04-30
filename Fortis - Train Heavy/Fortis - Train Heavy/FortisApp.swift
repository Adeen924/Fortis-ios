import SwiftUI
import SwiftData

@main
struct FortisApp: App {
    let modelContainer: ModelContainer
    @State private var authManager = AuthManager()

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
            let context = await MainActor.run { ModelContext(container) }
            ExerciseService.seedIfNeeded(context: context)
        }
    }

    private static func removeDefaultStore() {
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let storeURL = appSupportURL.appendingPathComponent("default.store")
        let files = [storeURL, storeURL.appendingPathExtension("-shm"), storeURL.appendingPathExtension("-wal")]
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    ContentView()
                } else {
                    WelcomeView()
                }
            }
            .modelContainer(modelContainer)
            .environment(authManager)
            .animation(.easeInOut(duration: 0.4), value: authManager.isAuthenticated)
        }
    }
}
