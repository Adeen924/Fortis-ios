import Foundation

enum ExerciseService {
    static func loadFromBundle() -> [Exercise] {
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json") else {
            assertionFailure("exercises.json not found in bundle. Add it to Resources/ExerciseData/")
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

    private struct ExerciseRecord: Decodable {
        let name: String
        let category: String
        let equipmentType: String
        let primaryMuscles: [String]
        let secondaryMuscles: [String]
        let instructions: String
        let mediaImageName: String?
        let mediaVideoName: String?
        let isCustom: Bool

        func toExercise() -> Exercise {
            Exercise(
                name: name,
                category: category,
                equipmentType: equipmentType,
                primaryMuscles: primaryMuscles,
                secondaryMuscles: secondaryMuscles,
                instructions: instructions,
                mediaImageName: mediaImageName,
                mediaVideoName: mediaVideoName,
                isCustom: isCustom
            )
        }
    }
}
