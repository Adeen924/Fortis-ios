import SwiftData
import Foundation

@Model
final class WorkoutSession {
    var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date?
    var duration: TimeInterval    // seconds
    var notes: String
    @Relationship(deleteRule: .cascade) var workoutExercises: [WorkoutExercise]

    var totalVolume: Double {
        workoutExercises.flatMap { $0.sets }.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }

    var totalSets: Int {
        workoutExercises.flatMap { $0.sets }.count
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        startDate: Date = Date(),
        endDate: Date? = nil,
        duration: TimeInterval = 0,
        notes: String = "",
        workoutExercises: [WorkoutExercise] = []
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.notes = notes
        self.workoutExercises = workoutExercises
    }
}

// MARK: - WorkoutExercise (join model: session <-> exercise with sets)
@Model
final class WorkoutExercise {
    var id: UUID
    var exerciseID: UUID
    var exerciseName: String
    var exerciseCategory: String
    var primaryMuscles: [String]
    var secondaryMuscles: [String]
    var order: Int
    @Relationship(deleteRule: .cascade) var sets: [ExerciseSet]

    var totalVolume: Double {
        sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }

    var bestSet: ExerciseSet? {
        sets.max(by: { ($0.weight * Double($0.reps)) < ($1.weight * Double($1.reps)) })
    }

    init(
        id: UUID = UUID(),
        exerciseID: UUID,
        exerciseName: String,
        exerciseCategory: String,
        primaryMuscles: [String],
        secondaryMuscles: [String] = [],
        order: Int = 0,
        sets: [ExerciseSet] = []
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.exerciseCategory = exerciseCategory
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.order = order
        self.sets = sets
    }
}
