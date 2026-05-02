import Foundation

// MARK: - Recommended Exercise
struct RecommendedExercise: Identifiable {
    let id: UUID = UUID()
    let exercise: Exercise
    let recommendedSets: Int
    let recommendedReps: String  // e.g. "8-12", "12-15", "3-5"
    let reason: String            // Why this exercise was recommended
    let intensity: ExerciseIntensity
    
    enum ExerciseIntensity {
        case low      // High reps, low weight
        case moderate // Moderate reps and weight
        case high     // Low reps, high weight
        
        var description: String {
            switch self {
            case .low: return "Higher reps, focus on muscle activation"
            case .moderate: return "Balanced approach for strength and growth"
            case .high: return "Lower reps, focus on strength"
            }
        }
    }
}

// MARK: - Suggested Workout
struct SuggestedWorkout: Identifiable {
    let id: UUID = UUID()
    let targetMuscleGroup: String
    let exercises: [RecommendedExercise]
    let estimatedDuration: Int  // in minutes
    let difficulty: WorkoutDifficulty
    let description: String
    
    enum WorkoutDifficulty {
        case beginner
        case intermediate
        case advanced
        
        var icon: String {
            switch self {
            case .beginner: return "1.circle"
            case .intermediate: return "2.circle"
            case .advanced: return "3.circle"
            }
        }
    }
}
