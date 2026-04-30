import SwiftUI
import SwiftData

@main
struct FortisApp: App {
    let modelContainer: ModelContainer
    @State private var authManager = AuthManager()

    init() {
        do {
            modelContainer = try ModelContainer(
                for: Exercise.self,
                     WorkoutSession.self,
                     ExerciseSet.self,
                     WorkoutExercise.self,
                     UserProfile.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
        let container = modelContainer
        Task.detached(priority: .utility) {
            let context = await MainActor.run { ModelContext(container) }
            ExerciseService.seedIfNeeded(context: context)
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
