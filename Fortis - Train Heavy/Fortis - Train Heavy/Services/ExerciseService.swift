import SwiftData
import Foundation

enum ExerciseService {

    // MARK: - Seed

    static func seedIfNeeded(context: ModelContext) async {
        let descriptor = FetchDescriptor<Exercise>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        let exercises = loadFromBundle()
        exercises.forEach { context.insert($0) }
        try? context.save()
        print("✅ Seeded \(exercises.count) exercises from exercises.json")
    }

    // MARK: - Bundle loading

    static func loadFromBundle() -> [Exercise] {
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json") else {
            assertionFailure("exercises.json not found in bundle — add it to Resources/ExerciseData/")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let records = try JSONDecoder().decode([ExerciseRecord].self, from: data)
            return records.map { $0.toExercise() }
        } catch {
            assertionFailure("Failed to decode exercises.json: \(error)")
            return []
        }
    }

    // MARK: - JSON record (matches exercises.json schema)

    private struct ExerciseRecord: Decodable {
        let name: String
        let category: String
        let equipmentType: String
        let primaryMuscles: [String]
        let secondaryMuscles: [String]
        let instructions: String
        let isCustom: Bool

        func toExercise() -> Exercise {
            Exercise(
                name: name,
                category: category,
                equipmentType: equipmentType,
                primaryMuscles: primaryMuscles,
                secondaryMuscles: secondaryMuscles,
                instructions: instructions,
                isCustom: isCustom
            )
        }
    }
}
