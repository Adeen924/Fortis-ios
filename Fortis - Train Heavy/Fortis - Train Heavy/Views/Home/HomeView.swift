import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.showWorkout) private var showWorkout
    @Query(sort: \WorkoutSession.startDate, order: .reverse) private var sessions: [WorkoutSession]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Quick Stats
                    quickStatsSection

                    // Start Workout CTA
                    startWorkoutCard

                    // Recent Workouts
                    if !sessions.isEmpty {
                        recentWorkoutsSection
                    }

                    // Suggestions
                    suggestionsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Fortis")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Quick Stats
    private var quickStatsSection: some View {
        HStack(spacing: 12) {
            StatCard(title: "This Week", value: "\(weeklyWorkoutCount)", unit: "workouts", color: .orange)
            StatCard(title: "Total Volume", value: weeklyVolumeFormatted, unit: "lbs", color: .blue)
            StatCard(title: "Streak", value: "\(currentStreak)", unit: "days", color: .green)
        }
    }

    private var weeklyWorkoutCount: Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return sessions.filter { $0.startDate >= weekAgo }.count
    }

    private var weeklyVolumeFormatted: String {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let volume = sessions.filter { $0.startDate >= weekAgo }.reduce(0) { $0 + $1.totalVolume }
        if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        }
        return String(format: "%.0f", volume)
    }

    private var currentStreak: Int {
        guard !sessions.isEmpty else { return 0 }
        var streak = 0
        var checkDate = Calendar.current.startOfDay(for: Date())
        for _ in 0..<30 {
            let hasWorkout = sessions.contains { Calendar.current.isDate($0.startDate, inSameDayAs: checkDate) }
            if hasWorkout {
                streak += 1
                checkDate = Calendar.current.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else {
                break
            }
        }
        return streak
    }

    // MARK: - Start Workout Card
    private var startWorkoutCard: some View {
        Button(action: showWorkout) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Workout")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("Tap to begin a new session")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Image(systemName: "dumbbell.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(20)
            .background(
                LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent Workouts
    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent")
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(sessions.prefix(3)) { session in
                RecentWorkoutCard(session: session)
            }
        }
    }

    // MARK: - Suggestions
    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested")
                .font(.headline)
                .foregroundStyle(.secondary)

            let suggestions = muscleGroupSuggestions()
            if suggestions.isEmpty {
                Text("Complete a workout to get suggestions")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(suggestions, id: \.self) { muscle in
                    SuggestionCard(muscleGroup: muscle)
                }
            }
        }
    }

    private func muscleGroupSuggestions() -> [String] {
        let allMuscles = MuscleGroup.allCases.map { $0.rawValue }
        let recentMuscles = sessions.prefix(3).flatMap { session in
            session.workoutExercises.flatMap { $0.primaryMuscles }
        }
        let recentSet = Set(recentMuscles)
        let suggestions = allMuscles.filter { !recentSet.contains($0) }
        return Array(suggestions.prefix(2))
    }
}

// MARK: - Supporting Views
struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct RecentWorkoutCard: View {
    let session: WorkoutSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .font(.subheadline.bold())
                Text(session.startDate, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(volumeFormatted)
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)
                Text("\(session.totalSets) sets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var volumeFormatted: String {
        let v = session.totalVolume
        if v >= 1000 { return String(format: "%.1fk lbs", v / 1000) }
        return String(format: "%.0f lbs", v)
    }
}

struct SuggestionCard: View {
    let muscleGroup: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.up.right.circle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Train \(muscleGroup)")
                    .font(.subheadline.bold())
                Text("Not trained recently")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
