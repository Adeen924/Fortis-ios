import Foundation

final class UserProfile: Identifiable, Codable, Hashable {
    var id: UUID
    var firebaseUID: String?
    var firstName: String
    var lastName: String
    var username: String
    var contactIdentifier: String?
    var email: String?
    var phoneNumber: String?
    var age: Int
    var gender: String?  // "male" or "female"
    var heightFeet: Int
    var heightInches: Int
    var weightLbs: Double
    var goals: [String]
    var authProvider: String   // "apple", "google", "email", "phone"
    var createdAt: Date
    var photoData: Data?

    var fullName: String { "\(firstName) \(lastName)" }
    var heightFormatted: String { "\(heightFeet)'\(heightInches)\"" }
    var weightFormatted: String { String(format: "%.1f lbs", weightLbs) }

    func weightFormatted(for unit: WeightUnit) -> String {
        let value = unit == .kg ? weightLbs * 0.45359237 : weightLbs
        return String(format: "%.1f %@", value, unit.symbol)
    }

    init(
        id: UUID = UUID(),
        firebaseUID: String? = nil,
        firstName: String = "",
        lastName: String = "",
        username: String = "",
        contactIdentifier: String? = nil,
        email: String? = nil,
        phoneNumber: String? = nil,
        age: Int = 18,
        gender: String? = "male",
        heightFeet: Int = 5,
        heightInches: Int = 10,
        weightLbs: Double = 160,
        goals: [String] = [],
        authProvider: String = "email",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.firebaseUID = firebaseUID
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
        self.contactIdentifier = contactIdentifier
        self.email = email
        self.phoneNumber = phoneNumber
        self.age = age
        self.gender = gender
        self.heightFeet = heightFeet
        self.heightInches = heightInches
        self.weightLbs = weightLbs
        self.goals = goals
        self.authProvider = authProvider
        self.createdAt = createdAt
    }

    static func == (lhs: UserProfile, rhs: UserProfile) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Gym Goals
enum GymGoal: String, CaseIterable, Identifiable {
    case buildMuscle         = "Build Muscle"
    case loseWeight          = "Lose Weight"
    case increaseStrength    = "Increase Strength"
    case improveEndurance    = "Improve Endurance"
    case athleticPerformance = "Athletic Performance"
    case generalFitness      = "General Fitness"
    case competitionPrep     = "Competition Prep"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .buildMuscle:          return "figure.strengthtraining.traditional"
        case .loseWeight:           return "flame.fill"
        case .increaseStrength:     return "bolt.fill"
        case .improveEndurance:     return "figure.run"
        case .athleticPerformance:  return "trophy.fill"
        case .generalFitness:       return "heart.fill"
        case .competitionPrep:      return "medal.fill"
        }
    }
}
