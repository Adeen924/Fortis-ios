import Foundation

final class Exercise: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var category: String          // e.g. "Chest", "Back", "Legs"
    var equipmentType: String     // e.g. "Barbell", "Dumbbell", "Machine", "Bodyweight", "Cable"
    var primaryMuscles: [String]
    var secondaryMuscles: [String]
    var instructions: String
    var mediaImageName: String?
    var mediaVideoName: String?
    var isCustom: Bool

    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        equipmentType: String,
        primaryMuscles: [String],
        secondaryMuscles: [String] = [],
        instructions: String = "",
        mediaImageName: String? = nil,
        mediaVideoName: String? = nil,
        isCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.equipmentType = equipmentType
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.instructions = instructions
        self.mediaImageName = mediaImageName
        self.mediaVideoName = mediaVideoName
        self.isCustom = isCustom
    }

    static func == (lhs: Exercise, rhs: Exercise) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Muscle Group Enum
enum MuscleGroup: String, CaseIterable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case legs = "Legs"
    case glutes = "Glutes"
    case core = "Core"
    case calves = "Calves"
    case forearms = "Forearms"

    var color: String {
        switch self {
        case .chest:      return "muscle_chest"
        case .back:       return "muscle_back"
        case .shoulders:  return "muscle_shoulders"
        case .biceps:     return "muscle_biceps"
        case .triceps:    return "muscle_triceps"
        case .legs:       return "muscle_legs"
        case .glutes:     return "muscle_glutes"
        case .core:       return "muscle_core"
        case .calves:     return "muscle_calves"
        case .forearms:   return "muscle_forearms"
        }
    }
}

// MARK: - Equipment Type Enum
enum EquipmentType: String, CaseIterable {
    case barbell = "Barbell"
    case dumbbell = "Dumbbell"
    case machine = "Machine"
    case cable = "Cable"
    case bodyweight = "Bodyweight"
    case ezBar = "EZ Bar"
    case kettlebell = "Kettlebell"
    case smith = "Smith Machine"
    case bands = "Resistance Bands"

    var icon: String {
        switch self {
        case .barbell:    return "figure.strengthtraining.traditional"
        case .dumbbell:   return "dumbbell"
        case .machine:    return "gearshape"
        case .cable:      return "arrow.up.and.down"
        case .bodyweight: return "figure.gymnastics"
        case .ezBar:      return "minus.forwardslash.plus"
        case .kettlebell: return "circle.and.line.horizontal"
        case .smith:      return "line.3.horizontal"
        case .bands:      return "arrow.left.and.right"
        }
    }
}
