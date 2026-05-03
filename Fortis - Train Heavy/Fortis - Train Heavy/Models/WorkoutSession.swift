import Foundation

final class WorkoutSession: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date?
    var duration: TimeInterval    // seconds
    var notes: String
    var workoutExercises: [WorkoutExercise]

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

    static func == (lhs: WorkoutSession, rhs: WorkoutSession) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - WorkoutExercise (join model: session <-> exercise with sets)
final class WorkoutExercise: Identifiable, Codable, Hashable {
    var id: UUID
    var exerciseID: UUID
    var exerciseName: String
    var exerciseCategory: String
    var primaryMuscles: [String]
    var secondaryMuscles: [String]? = nil
    var order: Int
    var sets: [ExerciseSet]

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
        secondaryMuscles: [String]? = nil,
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

    static func == (lhs: WorkoutExercise, rhs: WorkoutExercise) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
