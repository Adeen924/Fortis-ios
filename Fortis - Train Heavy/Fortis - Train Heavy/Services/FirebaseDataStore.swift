import Combine
import FirebaseFirestore
import Foundation

@MainActor
final class FirebaseDataStore: ObservableObject {
    @Published private(set) var profile: UserProfile?
    @Published private(set) var workouts: [WorkoutSession] = []
    @Published private(set) var exercises: [Exercise] = []
    @Published private(set) var isLoading = false
    @Published var lastError: String?

    private var profileListener: ListenerRegistration?
    private var workoutListener: ListenerRegistration?
    private var exerciseListener: ListenerRegistration?
    private var activeUserId: String?

    deinit {
        profileListener?.remove()
        workoutListener?.remove()
        exerciseListener?.remove()
    }

    func start(for userId: String?) {
        guard activeUserId != userId else { return }
        stop()
        activeUserId = userId
        loadExercises()

        guard let userId else {
            profile = nil
            workouts = []
            return
        }

        listenForProfile(userId: userId)
        listenForWorkouts(userId: userId)
    }

    func stop() {
        profileListener?.remove()
        workoutListener?.remove()
        profileListener = nil
        workoutListener = nil
        activeUserId = nil
    }

    func saveProfile(_ profile: UserProfile, userId: String) async throws {
        profile.firebaseUID = userId
        profile.contactIdentifier = profile.contactIdentifier ?? profile.email ?? profile.phoneNumber
        try await FirebaseService.db
            .collection(FirebaseService.usersCollection)
            .document(userId)
            .setData(profile.firestoreData, merge: true)
    }

    func saveWorkout(_ session: WorkoutSession, userId: String? = nil) async throws {
        let uid = userId ?? activeUserId
        guard let uid else { throw FirebaseDataError.notAuthenticated }
        try await FirebaseService.db
            .collection(FirebaseService.usersCollection)
            .document(uid)
            .collection(FirebaseService.workoutsCollection)
            .document(session.id.uuidString)
            .setData(session.firestoreData, merge: true)
    }

    func deleteAllUserData(userId: String) async throws {
        let userRef = FirebaseService.db.collection(FirebaseService.usersCollection).document(userId)
        let workoutDocs = try await userRef.collection(FirebaseService.workoutsCollection).getDocuments().documents
        for doc in workoutDocs {
            try await doc.reference.delete()
        }
        try await userRef.delete()
    }

    func publishBundledExercisesToFirebase() async throws {
        let batch = FirebaseService.db.batch()
        for exercise in ExerciseService.loadFromBundle() {
            let ref = FirebaseService.db
                .collection(FirebaseService.exercisesCollection)
                .document(exercise.id.uuidString)
            batch.setData(exercise.firestoreData, forDocument: ref, merge: true)
        }
        try await batch.commit()
    }

    private func loadExercises() {
        guard exerciseListener == nil else { return }
        exercises = []

        exerciseListener = FirebaseService.db
            .collection(FirebaseService.exercisesCollection)
            .order(by: "name")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.lastError = error.localizedDescription
                        return
                    }
                    self.exercises = snapshot?.documents.compactMap {
                        Exercise(firestoreData: $0.data(), documentId: $0.documentID)
                    } ?? []
                }
            }
    }

    private func listenForProfile(userId: String) {
        profileListener = FirebaseService.db
            .collection(FirebaseService.usersCollection)
            .document(userId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.lastError = error.localizedDescription
                        return
                    }
                    self.profile = snapshot.flatMap { UserProfile(firestoreData: $0.data() ?? [:], documentId: $0.documentID) }
                }
            }
    }

    private func listenForWorkouts(userId: String) {
        workoutListener = FirebaseService.db
            .collection(FirebaseService.usersCollection)
            .document(userId)
            .collection(FirebaseService.workoutsCollection)
            .order(by: "startDate", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.lastError = error.localizedDescription
                        return
                    }
                    self.workouts = snapshot?.documents.compactMap {
                        WorkoutSession(firestoreData: $0.data(), documentId: $0.documentID)
                    } ?? []
                }
            }
    }
}

private extension UserProfile {
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id.uuidString,
            "firstName": firstName,
            "lastName": lastName,
            "username": username,
            "age": age,
            "heightFeet": heightFeet,
            "heightInches": heightInches,
            "weightLbs": weightLbs,
            "goals": goals,
            "authProvider": authProvider,
            "createdAt": createdAt
        ]
        data["firebaseUID"] = firebaseUID
        data["contactIdentifier"] = contactIdentifier
        data["email"] = email
        data["phoneNumber"] = phoneNumber
        data["gender"] = gender
        return data
    }

    convenience init?(firestoreData data: [String: Any], documentId: String) {
        let id = (data["id"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
        self.init(
            id: id,
            firebaseUID: data["firebaseUID"] as? String ?? documentId,
            firstName: data["firstName"] as? String ?? "",
            lastName: data["lastName"] as? String ?? "",
            username: data["username"] as? String ?? "",
            contactIdentifier: data["contactIdentifier"] as? String,
            email: data["email"] as? String,
            phoneNumber: data["phoneNumber"] as? String,
            age: data["age"] as? Int ?? 18,
            gender: data["gender"] as? String,
            heightFeet: data["heightFeet"] as? Int ?? 5,
            heightInches: data["heightInches"] as? Int ?? 10,
            weightLbs: data["weightLbs"] as? Double ?? 160,
            goals: data["goals"] as? [String] ?? [],
            authProvider: data["authProvider"] as? String ?? "email",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? data["createdAt"] as? Date ?? Date()
        )
    }
}

private extension Exercise {
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "category": category,
            "equipmentType": equipmentType,
            "primaryMuscles": primaryMuscles,
            "secondaryMuscles": secondaryMuscles,
            "instructions": instructions,
            "isCustom": isCustom
        ]
        data["mediaImageName"] = mediaImageName
        data["mediaVideoName"] = mediaVideoName
        return data
    }

    convenience init?(firestoreData data: [String: Any], documentId: String) {
        self.init(
            id: (data["id"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID(uuidString: documentId) ?? UUID(),
            name: data["name"] as? String ?? "",
            category: data["category"] as? String ?? "",
            equipmentType: data["equipmentType"] as? String ?? "",
            primaryMuscles: data["primaryMuscles"] as? [String] ?? [],
            secondaryMuscles: data["secondaryMuscles"] as? [String] ?? [],
            instructions: data["instructions"] as? String ?? "",
            mediaImageName: data["mediaImageName"] as? String,
            mediaVideoName: data["mediaVideoName"] as? String,
            isCustom: data["isCustom"] as? Bool ?? false
        )
    }
}

private extension WorkoutSession {
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "startDate": startDate,
            "duration": duration,
            "notes": notes,
            "totalVolume": totalVolume,
            "totalSets": totalSets,
            "workoutExercises": workoutExercises.map { $0.firestoreData }
        ]
        data["endDate"] = endDate
        return data
    }

    convenience init?(firestoreData data: [String: Any], documentId: String) {
        let exerciseData = data["workoutExercises"] as? [[String: Any]] ?? []
        self.init(
            id: (data["id"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID(uuidString: documentId) ?? UUID(),
            name: data["name"] as? String ?? "",
            startDate: (data["startDate"] as? Timestamp)?.dateValue() ?? data["startDate"] as? Date ?? Date(),
            endDate: (data["endDate"] as? Timestamp)?.dateValue() ?? data["endDate"] as? Date,
            duration: data["duration"] as? TimeInterval ?? 0,
            notes: data["notes"] as? String ?? "",
            workoutExercises: exerciseData.compactMap { WorkoutExercise(firestoreData: $0) }
        )
    }
}

private extension WorkoutExercise {
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id.uuidString,
            "exerciseID": exerciseID.uuidString,
            "exerciseName": exerciseName,
            "exerciseCategory": exerciseCategory,
            "primaryMuscles": primaryMuscles,
            "order": order,
            "sets": sets.map { $0.firestoreData }
        ]
        data["secondaryMuscles"] = secondaryMuscles
        return data
    }

    convenience init?(firestoreData data: [String: Any]) {
        guard let exerciseIDString = data["exerciseID"] as? String,
              let exerciseID = UUID(uuidString: exerciseIDString) else { return nil }

        self.init(
            id: (data["id"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID(),
            exerciseID: exerciseID,
            exerciseName: data["exerciseName"] as? String ?? "",
            exerciseCategory: data["exerciseCategory"] as? String ?? "",
            primaryMuscles: data["primaryMuscles"] as? [String] ?? [],
            secondaryMuscles: data["secondaryMuscles"] as? [String],
            order: data["order"] as? Int ?? 0,
            sets: (data["sets"] as? [[String: Any]] ?? []).compactMap { ExerciseSet(firestoreData: $0) }
        )
    }
}

private extension ExerciseSet {
    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "id": id.uuidString,
            "setNumber": setNumber,
            "reps": reps,
            "weight": weight,
            "isWarmup": isWarmup,
            "isCompleted": isCompleted
        ]
        data["completedAt"] = completedAt
        return data
    }

    convenience init?(firestoreData data: [String: Any]) {
        self.init(
            id: (data["id"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID(),
            setNumber: data["setNumber"] as? Int ?? 0,
            reps: data["reps"] as? Int ?? 0,
            weight: data["weight"] as? Double ?? 0,
            isWarmup: data["isWarmup"] as? Bool ?? false,
            isCompleted: data["isCompleted"] as? Bool ?? false,
            completedAt: (data["completedAt"] as? Timestamp)?.dateValue() ?? data["completedAt"] as? Date
        )
    }
}
