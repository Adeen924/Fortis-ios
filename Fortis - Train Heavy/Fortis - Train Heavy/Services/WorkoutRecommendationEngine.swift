import Foundation
import SwiftData

@MainActor
final class WorkoutRecommendationEngine {
    
    // MARK: - Main Recommendation Method
    static func recommendWorkout(
        for muscleGroup: String,
        userProfile: UserProfile?,
        workoutHistory: [WorkoutSession],
        availableExercises: [Exercise],
        context: ModelContext
    ) -> SuggestedWorkout? {
        
        // Filter exercises for the target muscle group
        let targetExercises = availableExercises.filter { exercise in
            exercise.primaryMuscles.contains(where: { $0.lowercased() == muscleGroup.lowercased() })
        }
        
        guard !targetExercises.isEmpty else { return nil }
        
        // Analyze user profile and history
        let userGoals = userProfile?.goals ?? []
        let exerciseFrequency = analyzeExerciseFrequency(from: workoutHistory)
        let userLevel = estimateUserLevel(from: workoutHistory)
        
        // Select diverse exercises for the target muscle group
        let selectedExercises = selectDiverseExercises(
            from: targetExercises,
            count: 5,
            level: userLevel,
            goals: userGoals,
            frequency: exerciseFrequency
        )
        
        // Create recommendations with intelligent rep/set ranges
        let recommendations = selectedExercises.map { exercise in
            createRecommendation(
                for: exercise,
                muscleGroup: muscleGroup,
                userLevel: userLevel,
                goals: userGoals
            )
        }
        
        guard !recommendations.isEmpty else { return nil }
        
        // Determine difficulty and duration
        let difficulty = determineDifficulty(for: userLevel, goals: userGoals)
        let estimatedDuration = estimateWorkoutDuration(for: recommendations.count)
        
        return SuggestedWorkout(
            targetMuscleGroup: muscleGroup,
            exercises: recommendations,
            estimatedDuration: estimatedDuration,
            difficulty: difficulty,
            description: generateDescription(for: muscleGroup, goals: userGoals)
        )
    }
    
    // MARK: - Exercise Selection Logic
    private static func selectDiverseExercises(
        from exercises: [Exercise],
        count: Int,
        level: UserLevel,
        goals: [String],
        frequency: [String: Int]
    ) -> [Exercise] {
        // Prioritize exercises by:
        // 1. Equipment diversity (don't pick all dumbbells)
        // 2. Frequency (avoid exercises they do too often)
        // 3. Difficulty match (match their level)
        // 4. Alignment with goals
        
        var selected: [Exercise] = []
        var usedEquipment: Set<String> = []
        
        let sortedExercises = exercises.sorted { ex1, ex2 in
            let freqScore1 = frequency[ex1.name.lowercased()] ?? 0
            let freqScore2 = frequency[ex2.name.lowercased()] ?? 0
            
            // Prefer less frequently done exercises
            if freqScore1 != freqScore2 {
                return freqScore1 < freqScore2
            }
            
            // Prefer equipment diversity
            let equip1Used = usedEquipment.contains(ex1.equipmentType)
            let equip2Used = usedEquipment.contains(ex2.equipmentType)
            if equip1Used != equip2Used {
                return !equip1Used
            }
            
            // Prefer exercises that match user goals
            let goalMatch1 = exerciseGoalAlignment(ex1, goals: goals)
            let goalMatch2 = exerciseGoalAlignment(ex2, goals: goals)
            return goalMatch1 > goalMatch2
        }
        
        for exercise in sortedExercises {
            if selected.count >= count { break }
            if !usedEquipment.contains(exercise.equipmentType) || selected.count < count - 1 {
                selected.append(exercise)
                usedEquipment.insert(exercise.equipmentType)
            }
        }
        
        return selected.count >= count ? Array(selected.prefix(count)) : selected
    }
    
    // MARK: - Recommendation Creation
    private static func createRecommendation(
        for exercise: Exercise,
        muscleGroup: String,
        userLevel: UserLevel,
        goals: [String]
    ) -> RecommendedExercise {
        let (sets, reps, intensity) = determineRepsAndSets(
            for: exercise,
            level: userLevel,
            goals: goals
        )
        
        let reason = generateRecommendationReason(
            for: exercise,
            muscleGroup: muscleGroup,
            goals: goals
        )
        
        return RecommendedExercise(
            exercise: exercise,
            recommendedSets: sets,
            recommendedReps: reps,
            reason: reason,
            intensity: intensity
        )
    }
    
    // MARK: - Rep/Set Intelligence
    private static func determineRepsAndSets(
        for exercise: Exercise,
        level: UserLevel,
        goals: [String]
    ) -> (sets: Int, reps: String, intensity: RecommendedExercise.ExerciseIntensity) {
        let hasStrengthGoal = goals.contains(where: { $0.lowercased().contains("strength") })
        let hasSizeGoal = goals.contains(where: { $0.lowercased().contains("hypertrophy") || $0.lowercased().contains("muscle") })
        let hasEnduranceGoal = goals.contains(where: { $0.lowercased().contains("endurance") })
        
        // Exercise classification
        let isIsolation = exercise.secondaryMuscles.isEmpty || exercise.secondaryMuscles.count < 2
        let isCompound = !isIsolation
        
        // Determine intensity and rep range
        if hasStrengthGoal && isCompound {
            let sets = level == .beginner ? 3 : (level == .intermediate ? 4 : 5)
            return (sets, "3-5", .high)
        } else if hasEnduranceGoal {
            let sets = level == .beginner ? 2 : 3
            return (sets, "15-20", .low)
        } else if hasSizeGoal || (isIsolation && !hasStrengthGoal) {
            let sets = level == .beginner ? 3 : 4
            return (sets, "8-12", .moderate)
        } else {
            // Default balanced approach
            let sets = level == .beginner ? 3 : 4
            return (sets, "8-12", .moderate)
        }
    }
    
    // MARK: - User Level Analysis
    private static func estimateUserLevel(from history: [WorkoutSession]) -> UserLevel {
        guard !history.isEmpty else { return .beginner }
        
        let sessionsCount = history.count
        let averageVolume = history.map { $0.totalVolume }.reduce(0, +) / Double(history.count)
        let averageExerciseCount = history.map { $0.workoutExercises.count }.reduce(0, +) / history.count
        
        if sessionsCount < 10 || averageExerciseCount < 4 {
            return .beginner
        } else if sessionsCount < 40 && averageVolume < 10000 {
            return .intermediate
        } else {
            return .advanced
        }
    }
    
    enum UserLevel {
        case beginner
        case intermediate
        case advanced
    }
    
    // MARK: - Frequency Analysis
    private static func analyzeExerciseFrequency(from history: [WorkoutSession]) -> [String: Int] {
        var frequency: [String: Int] = [:]
        for session in history {
            for exercise in session.workoutExercises {
                let key = exercise.exerciseName.lowercased()
                frequency[key, default: 0] += 1
            }
        }
        return frequency
    }
    
    // MARK: - Goal Alignment
    private static func exerciseGoalAlignment(_ exercise: Exercise, goals: [String]) -> Int {
        var score = 0
        let exerciseName = exercise.name.lowercased()
        
        for goal in goals {
            let goalLower = goal.lowercased()
            if goalLower.contains("strength") && (exercise.equipmentType == "Barbell" || exercise.equipmentType == "Smith Machine") {
                score += 2
            }
            if goalLower.contains("hypertrophy") || goalLower.contains("muscle") {
                score += 1
            }
            if goalLower.contains("endurance") && exercise.name.count > 5 {
                score += 1
            }
        }
        return score
    }
    
    // MARK: - Difficulty Determination
    private static func determineDifficulty(
        for level: UserLevel,
        goals: [String]
    ) -> SuggestedWorkout.WorkoutDifficulty {
        if level == .advanced || goals.contains(where: { $0.lowercased().contains("strength") }) {
            return .advanced
        } else if level == .intermediate {
            return .intermediate
        } else {
            return .beginner
        }
    }
    
    // MARK: - Duration Estimation
    private static func estimateWorkoutDuration(for exerciseCount: Int) -> Int {
        // ~8-10 minutes per exercise including warm-up
        return max(30, exerciseCount * 8)
    }
    
    // MARK: - Text Generation
    private static func generateRecommendationReason(
        for exercise: Exercise,
        muscleGroup: String,
        goals: [String]
    ) -> String {
        if goals.contains(where: { $0.lowercased().contains("strength") }) {
            return "Compound movement for \(muscleGroup) strength"
        } else if goals.contains(where: { $0.lowercased().contains("hypertrophy") }) {
            return "Effective for \(muscleGroup) muscle growth"
        } else {
            return "Great for targeting \(muscleGroup)"
        }
    }
    
    private static func generateDescription(for muscleGroup: String, goals: [String]) -> String {
        if goals.contains(where: { $0.lowercased().contains("strength") }) {
            return "Strength-focused \(muscleGroup) workout designed to build power and maximize muscle tension."
        } else if goals.contains(where: { $0.lowercased().contains("hypertrophy") }) {
            return "\(muscleGroup) hypertrophy workout optimized for muscle growth through moderate to high rep ranges."
        } else {
            return "Balanced \(muscleGroup) workout for overall development and fitness."
        }
    }
}
