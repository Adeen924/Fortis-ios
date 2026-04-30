import SwiftUI
import SwiftData

@main
struct FortisApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(
                for: Exercise.self, WorkoutSession.self, ExerciseSet.self, WorkoutExercise.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
        let container = modelContainer
        Task { @MainActor in
            ExerciseService.seedIfNeeded(context: container.mainContext)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
        }
    }
}
