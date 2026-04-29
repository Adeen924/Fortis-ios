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
            // Seed exercises on first launch
            Task { @MainActor in
                ExerciseService.seedIfNeeded(context: modelContainer.mainContext)
            }
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
        }
    }
}
