import Foundation

final class ExerciseSet: Identifiable, Codable, Hashable {
    var id: UUID
    var setNumber: Int
    var reps: Int
    var weight: Double        // lbs
    var isWarmup: Bool
    var isCompleted: Bool
    var completedAt: Date?

    var volume: Double { weight * Double(reps) }

    init(
        id: UUID = UUID(),
        setNumber: Int,
        reps: Int = 0,
        weight: Double = 0,
        isWarmup: Bool = false,
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.isWarmup = isWarmup
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }

    static func == (lhs: ExerciseSet, rhs: ExerciseSet) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
