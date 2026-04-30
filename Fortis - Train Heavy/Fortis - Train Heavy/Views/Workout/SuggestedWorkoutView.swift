import SwiftUI
import SwiftData

struct SuggestedWorkoutView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.showWorkout) private var showWorkout
    @EnvironmentObject private var appSettings: AppSettings
    @Query private var profiles: [UserProfile]
    let suggestedWorkout: SuggestedWorkout
    let onDismiss: () -> Void
    
    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.romanBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        headerSection
                        
                        // Exercises List
                        exercisesSection
                        
                        // Start Button
                        startButton
                    }
                    .padding()
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("SUGGESTED WORKOUT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { onDismiss() }
                        .foregroundStyle(.romanGold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestedWorkout.targetMuscleGroup.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(.romanGoldDim)
                    
                    Text("AI-Recommended Workout")
                        .font(.title2.bold())
                        .foregroundStyle(.romanParchment)
                    
                    Text(suggestedWorkout.description)
                        .font(.caption)
                        .foregroundStyle(.romanParchmentDim)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 8) {
                    Image(systemName: suggestedWorkout.difficulty.icon)
                        .font(.title)
                        .foregroundStyle(.romanGold)
                    
                    Text(difficultyText)
                        .font(.caption.bold())
                        .foregroundStyle(.romanParchment)
                    
                    Text("\(suggestedWorkout.estimatedDuration) min")
                        .font(.caption)
                        .foregroundStyle(.romanParchmentDim)
                }
                .frame(width: 60)
            }
            .padding(12)
            .romanCard()
        }
    }

    // MARK: - Exercises Section
    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECOMMENDED EXERCISES")
                .font(.system(size: 10, weight: .bold))
                .tracking(3)
                .foregroundStyle(.romanParchmentDim)
            
            VStack(spacing: 10) {
                ForEach(suggestedWorkout.exercises) { recommendation in
                    NavigationLink(destination: ExerciseDetailView(exercise: recommendation.exercise, recommendation: recommendation)) {
                        ExerciseRecommendationCard(recommendation: recommendation)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Start Button
    private var startButton: some View {
        Button(action: {
            // TODO: Create a workout session with these recommended exercises
            showWorkout()
        }) {
            HStack {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("START WORKOUT")
                    .font(.system(size: 13, weight: .black))
                    .tracking(2)
            }
            .foregroundStyle(.romanBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(LinearGradient.romanGoldGradient)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.top, 8)
    }

    private var difficultyText: String {
        switch suggestedWorkout.difficulty {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }
}

// MARK: - Exercise Recommendation Card
struct ExerciseRecommendationCard: View {
    let recommendation: RecommendedExercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Exercise Name and Reason
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.exercise.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.romanParchment)
                
                Text(recommendation.reason)
                    .font(.caption)
                    .foregroundStyle(.romanGoldDim)
            }
            
            // Equipment and Category
            HStack(spacing: 12) {
                Label(recommendation.exercise.equipmentType, systemImage: "wrench.and.hammer")
                    .font(.caption)
                    .foregroundStyle(.romanParchmentDim)
                
                Label(recommendation.exercise.category, systemImage: "tag")
                    .font(.caption)
                    .foregroundStyle(.romanParchmentDim)
            }
            
            Divider()
                .background(Color.romanBorder)
            
            // Recommended Sets and Reps
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SETS")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.romanParchmentDim)
                    
                    Text("\(recommendation.recommendedSets)")
                        .font(.title3.bold())
                        .foregroundStyle(.romanGold)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("REPS")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.romanParchmentDim)
                    
                    Text(recommendation.recommendedReps)
                        .font(.title3.bold())
                        .foregroundStyle(.romanGold)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("INTENSITY")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.romanParchmentDim)
                    
                    Label(intensityLabel, systemImage: intensityIcon)
                        .font(.caption.bold())
                        .foregroundStyle(intensityColor)
                }
            }
            
            // Description
            if !recommendation.exercise.instructions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HOW TO PERFORM")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.romanParchmentDim)
                    
                    Text(truncatedInstructions)
                        .font(.caption)
                        .foregroundStyle(.romanParchment)
                        .lineLimit(3)
                }
            }
        }
        .padding(12)
        .romanCard()
    }

    private var intensityLabel: String {
        switch recommendation.intensity {
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        }
    }

    private var intensityIcon: String {
        switch recommendation.intensity {
        case .low: return "arrow.down"
        case .moderate: return "minus"
        case .high: return "arrow.up"
        }
    }

    private var intensityColor: Color {
        switch recommendation.intensity {
        case .low: return .romanParchmentDim
        case .moderate: return .romanGold
        case .high: return .romanCrimson
        }
    }

    private var truncatedInstructions: String {
        let shortened = recommendation.exercise.instructions
            .split(separator: ".")
            .first
            .map { String($0) } ?? recommendation.exercise.instructions
        return shortened.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Preview
#Preview {
    let testExercise = Exercise(
        name: "Barbell Bench Press",
        category: "Chest",
        equipmentType: "Barbell",
        primaryMuscles: ["Chest"],
        secondaryMuscles: ["Triceps", "Shoulders"],
        instructions: "Lie on a flat bench with the barbell at chest level. Press upward explosively."
    )
    
    let testRecommendation = RecommendedExercise(
        exercise: testExercise,
        recommendedSets: 4,
        recommendedReps: "6-8",
        reason: "Compound movement for Chest strength",
        intensity: .high
    )
    
    let testWorkout = SuggestedWorkout(
        targetMuscleGroup: "Chest",
        exercises: [testRecommendation],
        estimatedDuration: 40,
        difficulty: .intermediate,
        description: "Strength-focused chest workout designed to build power and maximize muscle tension."
    )
    
    return SuggestedWorkoutView(suggestedWorkout: testWorkout, onDismiss: {})
        .preferredColorScheme(.dark)
}
