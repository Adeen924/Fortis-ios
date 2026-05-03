import SwiftUI
import Combine

@Observable
final class WorkoutViewModel: Identifiable {
    let id = UUID()
    static let draftStorageKey = "fortis.active_workout_draft"

    // MARK: - State
    var workoutName: String = "Morning Workout" { didSet { saveDraft() } }
    var startTime: Date = Date() { didSet { saveDraft() } }
    var workoutExercises: [WorkoutExerciseEntry] = [] { didSet { saveDraft() } }
    var displayedSeconds: Int = 0  // for UI updates only
    var isFinished: Bool = false

    private var displayTimer: AnyCancellable?
    private var isRestoringDraft = false

    // MARK: - Computed elapsed time (based on actual Date difference, survives backgrounding)
    var elapsedSeconds: Int {
        Int(Date().timeIntervalSince(startTime))
    }

    // MARK: - Init
    init() {
        startTime = Date()
        startDisplayTimer()
    }

    init(draft: WorkoutDraft) {
        isRestoringDraft = true
        workoutName = draft.workoutName
        startTime = draft.startTime
        workoutExercises = draft.workoutExercises
        isRestoringDraft = false
        startDisplayTimer()
        saveDraft()
    }

    // MARK: - Timer
    private func startDisplayTimer() {
        displayTimer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.displayedSeconds = self.elapsedSeconds
            }
    }

    func stopTimer() {
        displayTimer?.cancel()
        displayTimer = nil
    }

    // MARK: - Exercise Management
    func addExercise(_ exercise: Exercise, bodyWeightLbs: Double? = nil) {
        let entry = WorkoutExerciseEntry(exercise: exercise, order: workoutExercises.count, bodyWeightLbs: bodyWeightLbs)
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
        let nextNumber = (workoutExercises[idx].sets.map { $0.setNumber }.max() ?? 0) + 1
        let newSetWeight = workoutExercises[idx].isBodyweight ? (workoutExercises[idx].bodyWeightLbs ?? 0) : 0
        if workoutExercises[idx].isUnilateral {
            let leftSet = SetEntry(
                setNumber: nextNumber,
                reps: 0,
                weight: newSetWeight,
                side: .left
            )
            let rightSet = SetEntry(
                setNumber: nextNumber,
                reps: 0,
                weight: newSetWeight,
                side: .right
            )
            workoutExercises[idx].sets.append(contentsOf: [leftSet, rightSet])
        } else {
            let newSet = SetEntry(
                setNumber: nextNumber,
                reps: 0,
                weight: newSetWeight
            )
            workoutExercises[idx].sets.append(newSet)
        }
    }

    func addRedoSet(to exerciseEntry: WorkoutExerciseEntry, from setID: UUID) {
        guard let idx = workoutExercises.firstIndex(where: { $0.id == exerciseEntry.id }),
              let sourceSet = workoutExercises[idx].sets.first(where: { $0.id == setID }) else { return }
        let nextNumber = (workoutExercises[idx].sets.map { $0.setNumber }.max() ?? 0) + 1
        let newSet = SetEntry(
            setNumber: nextNumber,
            reps: sourceSet.reps,
            weight: sourceSet.weight,
            side: sourceSet.side
        )
        workoutExercises[idx].sets.append(newSet)
    }

    func removeLastSet(from exerciseEntry: WorkoutExerciseEntry) {
        guard let idx = workoutExercises.firstIndex(where: { $0.id == exerciseEntry.id }),
              !workoutExercises[idx].sets.isEmpty else { return }

        if workoutExercises[idx].isUnilateral, workoutExercises[idx].sets.count >= 2 {
            let last = workoutExercises[idx].sets[workoutExercises[idx].sets.count - 1]
            let previous = workoutExercises[idx].sets[workoutExercises[idx].sets.count - 2]
            if last.setNumber == previous.setNumber {
                workoutExercises[idx].sets.removeLast(2)
            } else {
                workoutExercises[idx].sets.removeLast()
            }
        } else {
            workoutExercises[idx].sets.removeLast()
        }

        if workoutExercises[idx].isUnilateral {
            var renumbered: [SetEntry] = []
            var nextNumber = 1
            var chunk: [SetEntry] = []
            for set in workoutExercises[idx].sets {
                chunk.append(set)
                if chunk.count == 2 || set.side == nil {
                    for var item in chunk {
                        item.setNumber = nextNumber
                        renumbered.append(item)
                    }
                    chunk.removeAll()
                    nextNumber += 1
                }
            }
            workoutExercises[idx].sets = renumbered
        } else {
            for (s, _) in workoutExercises[idx].sets.enumerated() {
                workoutExercises[idx].sets[s].setNumber = s + 1
            }
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

    func setUnilateral(for exerciseEntry: WorkoutExerciseEntry, enabled: Bool) {
        guard let idx = workoutExercises.firstIndex(where: { $0.id == exerciseEntry.id }) else { return }
        var entry = workoutExercises[idx]

        if enabled && !entry.isUnilateral {
            var newSets: [SetEntry] = []
            if entry.sets.isEmpty {
                let startWeight = entry.bodyWeightLbs ?? 0
                newSets = [
                    SetEntry(setNumber: 1, reps: 0, weight: startWeight, side: .left),
                    SetEntry(setNumber: 1, reps: 0, weight: startWeight, side: .right)
                ]
            } else {
                let groupedSets = Dictionary(grouping: entry.sets, by: { $0.setNumber })
                for number in groupedSets.keys.sorted() {
                    let currentSets = groupedSets[number]!
                    let reps = currentSets.first?.reps ?? 0
                    let weight = currentSets.first?.weight ?? (entry.bodyWeightLbs ?? 0)
                    newSets.append(SetEntry(setNumber: number, reps: reps, weight: weight, side: .left))
                    newSets.append(SetEntry(setNumber: number, reps: reps, weight: weight, side: .right))
                }
            }
            entry.sets = newSets
            entry.isUnilateral = true
        } else if !enabled && entry.isUnilateral {
            var condensed: [SetEntry] = []
            let grouped = Dictionary(grouping: entry.sets, by: { $0.setNumber })
            for number in grouped.keys.sorted() {
                let group = grouped[number]!
                let representative = group.first(where: { $0.side == .left }) ?? group.first!
                condensed.append(SetEntry(setNumber: number, reps: representative.reps, weight: representative.weight))
            }
            entry.sets = condensed
            entry.isUnilateral = false
        }

        workoutExercises[idx] = entry
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

    var totalWorkoutVolume: Double {
        workoutExercises.flatMap { $0.sets }.reduce(0) { $0 + $1.volume }
    }

    var totalSets: Int {
        workoutExercises.flatMap { $0.sets }.count
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
    func finishWorkout() -> WorkoutSession {
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

    func saveDraft() {
        guard !isRestoringDraft, !isFinished else { return }
        guard !workoutExercises.isEmpty || workoutName != "Morning Workout" else {
            clearDraft()
            return
        }

        let draft = WorkoutDraft(
            workoutName: workoutName,
            startTime: startTime,
            workoutExercises: workoutExercises
        )

        if let data = try? JSONEncoder.fortisDraftEncoder.encode(draft) {
            UserDefaults.standard.set(data, forKey: Self.draftStorageKey)
        }
    }

    func clearDraft() {
        UserDefaults.standard.removeObject(forKey: Self.draftStorageKey)
    }

    static func restoredDraft() -> WorkoutDraft? {
        guard let data = UserDefaults.standard.data(forKey: draftStorageKey) else { return nil }
        return try? JSONDecoder.fortisDraftDecoder.decode(WorkoutDraft.self, from: data)
    }
}

struct WorkoutDraft: Codable {
    var workoutName: String
    var startTime: Date
    var workoutExercises: [WorkoutExerciseEntry]
}

// MARK: - Entry structs (in-memory, before saving)
struct WorkoutExerciseEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var exerciseID: UUID
    var exerciseName: String
    var exerciseCategory: String
    var primaryMuscles: [String]
    var secondaryMuscles: [String]
    var order: Int
    var sets: [SetEntry] = []
    var isUnilateral: Bool = false
    var bodyWeightLbs: Double? = nil

    init(exercise: Exercise, order: Int, bodyWeightLbs: Double? = nil) {
        self.exerciseID = exercise.id
        self.exerciseName = exercise.name
        self.exerciseCategory = exercise.category
        self.primaryMuscles = exercise.primaryMuscles
        self.secondaryMuscles = exercise.secondaryMuscles
        self.order = order
        self.bodyWeightLbs = bodyWeightLbs
        if bodyWeightLbs != nil {
            let defaultWeight = bodyWeightLbs ?? 0
            self.sets = [SetEntry(setNumber: 1, reps: 0, weight: defaultWeight)]
        }
    }

    var isBodyweight: Bool { bodyWeightLbs != nil }

    var totalVolume: Double {
        sets.filter { $0.isCompleted }.reduce(0) { $0 + $1.volume }
    }
    var completedSets: Int { sets.filter { $0.isCompleted }.count }
}

enum ExerciseSide: String, Codable {
    case left = "Left"
    case right = "Right"
}

struct SetEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var setNumber: Int
    var reps: Int
    var weight: Double
    var side: ExerciseSide? = nil
    var isWarmup: Bool = false
    var isCompleted: Bool = false
    var completedAt: Date?

    var volume: Double { weight * Double(reps) }
}

private extension JSONEncoder {
    static var fortisDraftEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var fortisDraftDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
