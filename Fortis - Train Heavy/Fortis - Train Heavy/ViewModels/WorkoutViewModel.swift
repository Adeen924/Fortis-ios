import SwiftUI
import SwiftData
import Combine

@Observable
final class WorkoutViewModel: Identifiable {
    let id = UUID()
    // MARK: - State
    var workoutName: String = "Morning Workout"
    var startTime: Date = Date()
    var workoutExercises: [WorkoutExerciseEntry] = []
    var elapsedSeconds: Int = 0
    var isFinished: Bool = false

    private var timer: AnyCancellable?

    // MARK: - Init
    init() {
        startTime = Date()
        startTimer()
    }

    // MARK: - Timer
    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.elapsedSeconds += 1
            }
    }

    func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    // MARK: - Exercise Management
    func addExercise(_ exercise: Exercise) {
        let entry = WorkoutExerciseEntry(exercise: exercise, order: workoutExercises.count)
        workoutExercises.append(entry)
    }

    func removeExercise(at offsets: IndexSet) {
        workoutExercises.remove(atOffsets: offsets)
        // Re-number order
        for (i, _) in workoutExercises.enumerated() {
            workoutExercises[i].order = i
        }
    }

    func moveExercise(from source: IndexSet, to destination: Int) {
        workoutExercises.move(fromOffsets: source, toOffset: destination)
        for (i, _) in workoutExercises.enumerated() {
            workoutExercises[i].order = i
        }
    }

    // MARK: - Set Management
    func addSet(to exerciseEntry: WorkoutExerciseEntry) {
        guard let idx = workoutExercises.firstIndex(where: { $0.id == exerciseEntry.id }) else { return }
        let newSet = SetEntry(
            setNumber: workoutExercises[idx].sets.count + 1,
            reps: 0,
            weight: 0
        )
        workoutExercises[idx].sets.append(newSet)
    }

    func addRedoSet(to exerciseEntry: WorkoutExerciseEntry, from setID: UUID) {
        guard let idx = workoutExercises.firstIndex(where: { $0.id == exerciseEntry.id }),
              let sourceSet = workoutExercises[idx].sets.first(where: { $0.id == setID }) else { return }
        let newSet = SetEntry(
            setNumber: workoutExercises[idx].sets.count + 1,
            reps: sourceSet.reps,
            weight: sourceSet.weight
        )
        workoutExercises[idx].sets.append(newSet)
    }

    func removeLastSet(from exerciseEntry: WorkoutExerciseEntry) {
        guard let idx = workoutExercises.firstIndex(where: { $0.id == exerciseEntry.id }),
              !workoutExercises[idx].sets.isEmpty else { return }
        workoutExercises[idx].sets.removeLast()
        // Re-number
        for (s, _) in workoutExercises[idx].sets.enumerated() {
            workoutExercises[idx].sets[s].setNumber = s + 1
        }
    }

    func removeSet(from exerciseEntry: WorkoutExerciseEntry, at offsets: IndexSet) {
        guard let idx = workoutExercises.firstIndex(where: { $0.id == exerciseEntry.id }) else { return }
        workoutExercises[idx].sets.remove(atOffsets: offsets)
        // Re-number
        for (s, _) in workoutExercises[idx].sets.enumerated() {
            workoutExercises[idx].sets[s].setNumber = s + 1
        }
    }

    func updateSet(in exerciseEntry: WorkoutExerciseEntry, setID: UUID, reps: Int? = nil, weight: Double? = nil, completed: Bool? = nil) {
        guard let eIdx = workoutExercises.firstIndex(where: { $0.id == exerciseEntry.id }),
              let sIdx = workoutExercises[eIdx].sets.firstIndex(where: { $0.id == setID }) else { return }
        if let reps   { workoutExercises[eIdx].sets[sIdx].reps = reps }
        if let weight { workoutExercises[eIdx].sets[sIdx].weight = weight }
        if let completed {
            workoutExercises[eIdx].sets[sIdx].isCompleted = completed
            if completed { workoutExercises[eIdx].sets[sIdx].completedAt = Date() }
        }
        // Auto-complete if both reps and weight are set
        let currentReps = reps ?? workoutExercises[eIdx].sets[sIdx].reps
        let currentWeight = weight ?? workoutExercises[eIdx].sets[sIdx].weight
        if currentReps > 0 && currentWeight > 0 && !workoutExercises[eIdx].sets[sIdx].isCompleted {
            workoutExercises[eIdx].sets[sIdx].isCompleted = true
            workoutExercises[eIdx].sets[sIdx].completedAt = Date()
        }
    }

    func toggleSetCompleted(in exerciseEntry: WorkoutExerciseEntry, setID: UUID) {
        guard let eIdx = workoutExercises.firstIndex(where: { $0.id == exerciseEntry.id }),
              let sIdx = workoutExercises[eIdx].sets.firstIndex(where: { $0.id == setID }) else { return }
        let current = workoutExercises[eIdx].sets[sIdx].isCompleted
        updateSet(in: exerciseEntry, setID: setID, completed: !current)
    }

    // MARK: - Computed Properties
    var totalVolume: Double {
        workoutExercises.flatMap { $0.sets }.filter { $0.isCompleted }.reduce(0) { $0 + $1.volume }
    }

    var totalCompletedSets: Int {
        workoutExercises.flatMap { $0.sets }.filter { $0.isCompleted }.count
    }

    var formattedDuration: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Finish & Save
    func finishWorkout(context: ModelContext) -> WorkoutSession {
        stopTimer()
        let session = WorkoutSession(
            name: workoutName.isEmpty ? defaultWorkoutName() : workoutName,
            startDate: startTime,
            endDate: Date(),
            duration: TimeInterval(elapsedSeconds)
        )
        for entry in workoutExercises {
            let workoutEx = WorkoutExercise(
                exerciseID: entry.exerciseID,
                exerciseName: entry.exerciseName,
                exerciseCategory: entry.exerciseCategory,
                primaryMuscles: entry.primaryMuscles,
                secondaryMuscles: entry.secondaryMuscles,
                order: entry.order
            )
            for s in entry.sets {
                let set = ExerciseSet(
                    setNumber: s.setNumber,
                    reps: s.reps,
                    weight: s.weight,
                    isWarmup: s.isWarmup,
                    isCompleted: s.isCompleted,
                    completedAt: s.completedAt
                )
                workoutEx.sets.append(set)
            }
            session.workoutExercises.append(workoutEx)
        }
        context.insert(session)
        try? context.save()
        isFinished = true
        return session
    }

    private func defaultWorkoutName() -> String {
        let hour = Calendar.current.component(.hour, from: startTime)
        switch hour {
        case 5..<12:  return "Morning Workout"
        case 12..<17: return "Afternoon Workout"
        case 17..<21: return "Evening Workout"
        default:      return "Night Workout"
        }
    }
}

// MARK: - Entry structs (in-memory, before saving)
struct WorkoutExerciseEntry: Identifiable {
    var id: UUID = UUID()
    var exerciseID: UUID
    var exerciseName: String
    var exerciseCategory: String
    var primaryMuscles: [String]
    var secondaryMuscles: [String]
    var order: Int
    var sets: [SetEntry] = []

    init(exercise: Exercise, order: Int) {
        self.exerciseID = exercise.id
        self.exerciseName = exercise.name
        self.exerciseCategory = exercise.category
        self.primaryMuscles = exercise.primaryMuscles
        self.secondaryMuscles = exercise.secondaryMuscles
        self.order = order
    }

    var totalVolume: Double {
        sets.filter { $0.isCompleted }.reduce(0) { $0 + $1.volume }
    }
    var completedSets: Int { sets.filter { $0.isCompleted }.count }
}

struct SetEntry: Identifiable {
    var id: UUID = UUID()
    var setNumber: Int
    var reps: Int
    var weight: Double
    var isWarmup: Bool = false
    var isCompleted: Bool = false
    var completedAt: Date?

    var volume: Double { weight * Double(reps) }
}
