import SwiftUI
import SwiftData

struct AnalyticsView: View {
    @EnvironmentObject private var appSettings: AppSettings
    @Query(sort: \WorkoutSession.startDate, order: .reverse) private var sessions: [WorkoutSession]
    @Query private var profiles: [UserProfile]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.romanBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        muscleGroupStatsSection
                        recommendationsSection
                        progressSection
                    }
                    .padding()
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("ANALYTICS")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Muscle Group Stats
    private var muscleGroupStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("MUSCLE GROUP STATS")
            let stats = muscleGroupStats()
            if stats.isEmpty {
                Text("Complete workouts to see your muscle group statistics.")
                    .font(.caption)
                    .foregroundStyle(.romanParchmentDim)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .romanCard()
            } else {
                VStack(spacing: 8) {
                    ForEach(stats.sorted { $0.value > $1.value }, id: \.key) { muscle, count in
                        HStack {
                            Text(muscle)
                                .font(.subheadline.bold())
                                .foregroundStyle(.romanParchment)
                            Spacer()
                            Text("\(count) workouts")
                                .font(.caption)
                                .foregroundStyle(.romanGold)
                        }
                        .padding(14)
                        .romanCard()
                    }
                }
            }
        }
    }

    // MARK: - Recommendations
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("RECOMMENDATIONS")
            let recommendations = generateRecommendations()
            if recommendations.isEmpty {
                Text("Set goals in your profile to receive personalized recommendations.")
                    .font(.caption)
                    .foregroundStyle(.romanParchmentDim)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .romanCard()
            } else {
                VStack(spacing: 8) {
                    ForEach(recommendations, id: \.self) { rec in
                        Text(rec)
                            .font(.subheadline)
                            .foregroundStyle(.romanParchment)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .romanCard()
                    }
                }
            }
        }
    }

    // MARK: - Progress
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("PROGRESS OVERVIEW")
            let progress = progressStats()
            VStack(spacing: 8) {
                ForEach(progress, id: \.self) { stat in
                    HStack {
                        Text(stat.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(.romanParchment)
                        Spacer()
                        Text(stat.value)
                            .font(.caption)
                            .foregroundStyle(.romanGold)
                    }
                    .padding(14)
                    .romanCard()
                }
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(3)
            .foregroundStyle(.romanParchmentDim)
    }

    private func muscleGroupStats() -> [String: Int] {
        var counts: [String: Int] = [:]
        for session in sessions {
            for workoutEx in session.workoutExercises {
                for muscle in workoutEx.primaryMuscles {
                    counts[muscle, default: 0] += 1
                }
            }
        }
        return counts
    }

    private func generateRecommendations() -> [String] {
        guard let profile = profiles.first else { return [] }
        let stats = muscleGroupStats()
        var recommendations: [String] = []

        if profile.goals.contains("Lose Weight") {
            recommendations.append("Focus on compound movements and cardio to maximize calorie burn.")
            if let leastWorked = stats.min(by: { $0.value < $1.value })?.key {
                recommendations.append("Try adding \(leastWorked) exercises to your routine for balanced training.")
            }
        }

        if profile.goals.contains("Get Stronger") {
            if let leastWorked = stats.min(by: { $0.value < $1.value })?.key {
                recommendations.append("Prioritize \(leastWorked) training - it's been underworked recently.")
            }
            recommendations.append("Increase weights gradually on exercises you've been struggling with.")
        }

        if profile.goals.contains("Build Muscle") {
            recommendations.append("Ensure progressive overload on all muscle groups for optimal growth.")
        }

        if profile.goals.contains("Improve Endurance") {
            recommendations.append("Incorporate higher rep ranges (12-15) for endurance-focused training.")
        }

        return recommendations
    }

    private func progressStats() -> [ProgressStat] {
        let totalWorkouts = sessions.count
        let totalVolume = sessions.reduce(0.0) { $0 + $1.totalVolume }
        let avgVolume = totalWorkouts > 0 ? totalVolume / Double(totalWorkouts) : 0
        let totalExercises = sessions.flatMap { $0.workoutExercises }.count
        let uniqueExercises = Set(sessions.flatMap { $0.workoutExercises.map { $0.exerciseName } }).count

        return [
            ProgressStat(title: "Total Workouts", value: "\(totalWorkouts)"),
            ProgressStat(title: "Total Volume", value: formattedWeight(totalVolume)),
            ProgressStat(title: "Average Volume per Workout", value: formattedWeight(avgVolume)),
            ProgressStat(title: "Total Exercises Performed", value: "\(totalExercises)"),
            ProgressStat(title: "Unique Exercises", value: "\(uniqueExercises)")
        ]
    }

    private func formattedWeight(_ value: Double) -> String {
        let converted = appSettings.weightUnit == .kg ? value * 0.45359237 : value
        let symbol = appSettings.weightUnit.symbol
        if abs(converted) >= 1000 {
            return String(format: "%.1fk %@", converted / 1000, symbol)
        }
        return String(format: "%.0f %@", converted, symbol)
    }
}

struct ProgressStat: Hashable {
    let title: String
    let value: String
}

#Preview {
    AnalyticsView()
}