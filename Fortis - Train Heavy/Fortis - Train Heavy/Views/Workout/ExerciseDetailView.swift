import AVKit
import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise
    let recommendation: RecommendedExercise?
    
    var body: some View {
        ZStack {
            Color.romanBackground.ignoresSafeArea()

            ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Exercise Header
                        headerSection

                        // Media Demonstration
                        mediaSection
                        
                        // Muscle Map
                        muscleMapSection
                        
                        // Exercise Details
                        detailsSection
                        
                        // Instructions
                        if !exercise.instructions.isEmpty {
                            instructionsSection
                        }
                        
                        // Recommendation Info (if provided)
                        if let rec = recommendation {
                            recommendationSection(rec)
                        }
                    }
                    .padding()
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.category.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(.romanGoldDim)
                    
                    Text(exercise.name)
                        .font(.title2.bold())
                        .foregroundStyle(.romanParchment)
                }
                Spacer()
            }
            
            HStack(spacing: 8) {
                Label(exercise.equipmentType, systemImage: "wrench.and.hammer")
                    .font(.caption)
                    .foregroundStyle(.romanGold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.romanSurface)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Media Section
    private var mediaSection: some View {
        Group {
            if let imageName = exercise.mediaImageName,
               !imageName.isEmpty,
               UIImage(named: imageName) != nil {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 280)
                    .clipped()
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.romanBorder, lineWidth: 0.5))
            } else if let videoName = exercise.mediaVideoName,
                      let url = Bundle.main.url(forResource: videoName, withExtension: nil) {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.romanBorder, lineWidth: 0.5))
            } else {
                ZStack {
                    Color.romanSurface
                    VStack(spacing: 10) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.romanGoldDim)
                        Text("No media available")
                            .font(.caption)
                            .foregroundStyle(.romanParchmentDim)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.romanBorder, lineWidth: 0.5))
            }
        }
    }

    // MARK: - Muscle Map Section
    private var muscleMapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MUSCLES TARGETED")
                .font(.system(size: 10, weight: .bold))
                .tracking(3)
                .foregroundStyle(.romanParchmentDim)
            
            MuscleMapView(
                primaryMuscles: exercise.primaryMuscles,
                secondaryMuscles: exercise.secondaryMuscles
            )
        }
    }

    // MARK: - Details Section
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EXERCISE DETAILS")
                .font(.system(size: 10, weight: .bold))
                .tracking(3)
                .foregroundStyle(.romanParchmentDim)
            
            VStack(alignment: .leading, spacing: 10) {
                // Primary Muscles
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PRIMARY MUSCLES")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(.romanGoldDim)
                        
                        ForEach(exercise.primaryMuscles, id: \.self) { muscle in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.romanGold)
                                    .frame(width: 4, height: 4)
                                Text(muscle)
                                    .font(.caption)
                                    .foregroundStyle(.romanParchment)
                            }
                        }
                    }
                    Spacer()
                }
                
                if !exercise.secondaryMuscles.isEmpty {
                    Divider()
                        .background(Color.romanBorder)
                    
                    // Secondary Muscles
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("SECONDARY MUSCLES")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(.romanGoldDim)
                            
                            ForEach(exercise.secondaryMuscles, id: \.self) { muscle in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.romanGold.opacity(0.5))
                                        .frame(width: 4, height: 4)
                                    Text(muscle)
                                        .font(.caption)
                                        .foregroundStyle(.romanParchmentDim)
                                }
                            }
                        }
                        Spacer()
                    }
                }
            }
            .padding(12)
            .romanCard()
        }
    }

    // MARK: - Instructions Section
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HOW TO PERFORM")
                .font(.system(size: 10, weight: .bold))
                .tracking(3)
                .foregroundStyle(.romanParchmentDim)
            
            Text(exercise.instructions)
                .font(.caption)
                .foregroundStyle(.romanParchment)
                .lineSpacing(4)
                .padding(12)
                .romanCard()
        }
    }

    // MARK: - Recommendation Section
    private func recommendationSection(_ recommendation: RecommendedExercise) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECOMMENDED FOR THIS WORKOUT")
                .font(.system(size: 10, weight: .bold))
                .tracking(3)
                .foregroundStyle(.romanParchmentDim)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SETS")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(.romanParchmentDim)
                        Text("\(recommendation.recommendedSets)")
                            .font(.title2.bold())
                            .foregroundStyle(.romanGold)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("REPS")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(.romanParchmentDim)
                        Text(recommendation.recommendedReps)
                            .font(.title2.bold())
                            .foregroundStyle(.romanGold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("INTENSITY")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(.romanParchmentDim)
                        Label(intensityLabel(recommendation.intensity), systemImage: intensityIcon(recommendation.intensity))
                            .font(.caption.bold())
                            .foregroundStyle(intensityColor(recommendation.intensity))
                    }
                }
                
                Divider()
                    .background(Color.romanBorder)
                
                Text(recommendation.reason)
                    .font(.caption)
                    .foregroundStyle(.romanParchmentDim)
            }
            .padding(12)
            .romanCard()
        }
    }

    private func intensityLabel(_ intensity: RecommendedExercise.ExerciseIntensity) -> String {
        switch intensity {
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        }
    }

    private func intensityIcon(_ intensity: RecommendedExercise.ExerciseIntensity) -> String {
        switch intensity {
        case .low: return "arrow.down"
        case .moderate: return "minus"
        case .high: return "arrow.up"
        }
    }

    private func intensityColor(_ intensity: RecommendedExercise.ExerciseIntensity) -> Color {
        switch intensity {
        case .low: return .romanParchmentDim
        case .moderate: return .romanGold
        case .high: return .romanCrimson
        }
    }
}

#Preview {
    let testExercise = Exercise(
        name: "Barbell Bench Press",
        category: "Chest",
        equipmentType: "Barbell",
        primaryMuscles: ["Chest"],
        secondaryMuscles: ["Triceps", "Shoulders"],
        instructions: "Lie on a flat bench with feet firmly on the ground. Grip the barbell slightly wider than shoulder-width. Lower the bar to your chest in a controlled manner, then press upward explosively. Keep your shoulder blades retracted throughout the movement."
    )
    
    let testRecommendation = RecommendedExercise(
        exercise: testExercise,
        recommendedSets: 4,
        recommendedReps: "6-8",
        reason: "Compound movement for chest strength",
        intensity: .high
    )
    
    return ExerciseDetailView(exercise: testExercise, recommendation: testRecommendation)
        .preferredColorScheme(.dark)
}
