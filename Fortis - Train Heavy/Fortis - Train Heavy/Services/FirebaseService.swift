import FirebaseCore
import FirebaseFirestore
import Foundation

enum FirebaseService {
    static let usersCollection = "users"
    static let workoutsCollection = "workouts"
    static let exercisesCollection = "exercise_catalog"

    static var db: Firestore {
        Firestore.firestore()
    }

    static func configure() {
        guard FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()

        let settings = Firestore.firestore().settings
        settings.cacheSettings = MemoryCacheSettings()
        Firestore.firestore().settings = settings
    }
}

enum FirebaseDataError: LocalizedError {
    case notAuthenticated
    case invalidData(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to perform this action."
        case .invalidData(let message):
            return message
        }
    }
}
