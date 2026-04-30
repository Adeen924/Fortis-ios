import Foundation
import Supabase
import SwiftData

// MARK: - SupabaseService

final class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    // UUID of the currently authenticated Supabase user, nil when signed out.
    private(set) var currentUserId: UUID?

    private init() {
        let (url, key) = Self.loadConfig()
        client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }

    // MARK: - Config loading

    private static func loadConfig() -> (URL, String) {
        guard
            let path    = Bundle.main.path(forResource: "Config", ofType: "plist"),
            let dict    = NSDictionary(contentsOfFile: path),
            let rawURL  = dict["SupabaseURL"]      as? String,
            let anonKey = dict["SupabaseAnonKey"]  as? String
        else {
            fatalError("Config.plist missing or malformed — add SupabaseURL and SupabaseAnonKey")
        }
        // The SDK needs the project base URL (no /rest/v1/ suffix)
        let base = rawURL.replacingOccurrences(of: "/rest/v1/", with: "")
        guard let url = URL(string: base) else {
            fatalError("SupabaseURL in Config.plist is not a valid URL: \(rawURL)")
        }
        return (url, anonKey)
    }

    // MARK: - Session

    /// Checks for an existing Supabase session and returns the user ID if valid.
    func restoreSession() async -> UUID? {
        do {
            let session = try await client.auth.session
            currentUserId = session.user.id
            return session.user.id
        } catch {
            currentUserId = nil
            return nil
        }
    }

    // MARK: - Auth

    func signUpWithEmail(email: String, password: String) async throws -> UUID {
        let response = try await client.auth.signUp(email: email, password: password)
        let uid = response.user.id
        currentUserId = uid
        return uid
    }

    func signInWithEmail(email: String, password: String) async throws -> UUID {
        let session = try await client.auth.signIn(email: email, password: password)
        let uid = session.user.id
        currentUserId = uid
        return uid
    }

    func signOut() async throws {
        try await client.auth.signOut()
        currentUserId = nil
    }

    // MARK: - Profile

    func createProfile(userId: UUID, username: String, fullName: String) async throws {
        let payload = ProfileInsert(id: userId, username: username, fullName: fullName)
        try await client.from("profiles").insert(payload).execute()
    }

    func fetchProfile(userId: UUID) async throws -> ProfileRow {
        let rows: [ProfileRow] = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        guard let profile = rows.first else {
            throw FortisError.notFound("Profile for user \(userId)")
        }
        return profile
    }

    // MARK: - Workout sync

    /// Upserts a WorkoutSession and all its exercises/sets to Supabase.
    func syncWorkoutSession(_ session: WorkoutSession) async throws {
        guard let uid = currentUserId else { throw FortisError.notAuthenticated }

        // 1. Upsert session header
        let sessionRow = WorkoutSessionInsert(session: session, userId: uid)
        try await client.from("workout_sessions").upsert(sessionRow).execute()

        // 2. Upsert each exercise
        for workoutExercise in session.workoutExercises {
            let exRow = WorkoutExerciseInsert(exercise: workoutExercise, sessionId: session.id)
            try await client.from("workout_exercises").upsert(exRow).execute()

            // 3. Upsert each set
            let setRows = workoutExercise.sets.map {
                ExerciseSetInsert(set: $0, workoutExerciseId: workoutExercise.id)
            }
            if !setRows.isEmpty {
                try await client.from("exercise_sets").upsert(setRows).execute()
            }
        }

        markSynced(sessionId: session.id)
    }

    /// Fetches up to 50 recent workout sessions from the user's friends.
    func fetchFriendWorkouts(userId: UUID) async throws -> [FriendWorkoutRow] {
        let rows: [FriendWorkoutRow] = try await client
            .from("workout_sessions")
            .select("id, name, start_date, duration, user_id, profiles(username, full_name)")
            .neq("user_id", value: userId.uuidString)
            .order("start_date", ascending: false)
            .limit(50)
            .execute()
            .value
        return rows
    }

    func sendFriendRequest(toUserId: UUID) async throws {
        guard let uid = currentUserId else { throw FortisError.notAuthenticated }
        let payload = FriendRequestInsert(fromUserId: uid, toUserId: toUserId)
        try await client.from("friend_requests").insert(payload).execute()
    }

    // MARK: - Pending sync (offline queue)

    private let pendingSyncKey = "fortis.pending_sync_ids"

    func markPendingSync(sessionId: UUID) {
        var ids = pendingSyncIds
        ids.insert(sessionId.uuidString)
        UserDefaults.standard.set(Array(ids), forKey: pendingSyncKey)
    }

    func syncPendingSessions(context: ModelContext) async {
        let ids = pendingSyncIds
        guard !ids.isEmpty, currentUserId != nil else { return }

        for idString in ids {
            guard let uuid = UUID(uuidString: idString) else { continue }
            let descriptor = FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.id == uuid }
            )
            if let session = try? context.fetch(descriptor).first {
                try? await syncWorkoutSession(session)
            }
        }
    }

    private var pendingSyncIds: Set<String> {
        let arr = UserDefaults.standard.stringArray(forKey: pendingSyncKey) ?? []
        return Set(arr)
    }

    private func markSynced(sessionId: UUID) {
        var ids = pendingSyncIds
        ids.remove(sessionId.uuidString)
        UserDefaults.standard.set(Array(ids), forKey: pendingSyncKey)
    }
}

// MARK: - Error

enum FortisError: LocalizedError {
    case notAuthenticated
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:   return "You must be signed in to perform this action."
        case .notFound(let msg):  return "\(msg) not found."
        }
    }
}

// MARK: - Codable payloads  (camelCase Swift ↔ snake_case Postgres via CodingKeys)

private struct ProfileInsert: Encodable {
    let id: UUID
    let username: String
    let fullName: String

    enum CodingKeys: String, CodingKey {
        case id, username
        case fullName = "full_name"
    }
}

struct ProfileRow: Decodable {
    let id: UUID
    let username: String
    let fullName: String?
    let avatarUrl: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, username
        case fullName  = "full_name"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }
}

private struct WorkoutSessionInsert: Encodable {
    let id: UUID
    let userId: UUID
    let name: String
    let startDate: Date
    let endDate: Date?
    let duration: Double
    let notes: String

    enum CodingKeys: String, CodingKey {
        case id, name, duration, notes
        case userId    = "user_id"
        case startDate = "start_date"
        case endDate   = "end_date"
    }

    init(session: WorkoutSession, userId: UUID) {
        self.id        = session.id
        self.userId    = userId
        self.name      = session.name
        self.startDate = session.startDate
        self.endDate   = session.endDate
        self.duration  = session.duration
        self.notes     = session.notes
    }
}

private struct WorkoutExerciseInsert: Encodable {
    let id: UUID
    let sessionId: UUID
    let exerciseName: String
    let exerciseCategory: String
    let primaryMuscles: [String]
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId       = "session_id"
        case exerciseName    = "exercise_name"
        case exerciseCategory = "exercise_category"
        case primaryMuscles  = "primary_muscles"
        case sortOrder       = "sort_order"
    }

    init(exercise: WorkoutExercise, sessionId: UUID) {
        self.id               = exercise.id
        self.sessionId        = sessionId
        self.exerciseName     = exercise.exerciseName
        self.exerciseCategory = exercise.exerciseCategory
        self.primaryMuscles   = exercise.primaryMuscles
        self.sortOrder        = exercise.order
    }
}

private struct ExerciseSetInsert: Encodable {
    let id: UUID
    let workoutExerciseId: UUID
    let setNumber: Int
    let reps: Int
    let weight: Double
    let isWarmup: Bool
    let isCompleted: Bool
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, reps, weight
        case workoutExerciseId = "workout_exercise_id"
        case setNumber         = "set_number"
        case isWarmup          = "is_warmup"
        case isCompleted       = "is_completed"
        case completedAt       = "completed_at"
    }

    init(set: ExerciseSet, workoutExerciseId: UUID) {
        self.id                 = set.id
        self.workoutExerciseId  = workoutExerciseId
        self.setNumber          = set.setNumber
        self.reps               = set.reps
        self.weight             = set.weight
        self.isWarmup           = set.isWarmup
        self.isCompleted        = set.isCompleted
        self.completedAt        = set.completedAt
    }
}

private struct FriendRequestInsert: Encodable {
    let fromUserId: UUID
    let toUserId: UUID

    enum CodingKeys: String, CodingKey {
        case fromUserId = "from_user_id"
        case toUserId   = "to_user_id"
    }
}

struct FriendWorkoutRow: Decodable {
    let id: UUID
    let name: String
    let startDate: Date
    let duration: Double
    let userId: UUID
    let profile: FriendProfile?

    enum CodingKeys: String, CodingKey {
        case id, name, duration
        case startDate = "start_date"
        case userId    = "user_id"
        case profile   = "profiles"
    }
}

struct FriendProfile: Decodable {
    let username: String
    let fullName: String?

    enum CodingKeys: String, CodingKey {
        case username
        case fullName = "full_name"
    }
}
