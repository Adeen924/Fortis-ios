import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.showWorkout) private var showWorkout
    @Query(sort: \WorkoutSession.startDate, order: .reverse) private var sessions: [WorkoutSession]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.romanBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        quickStatsSection
                        startWorkoutCard
                        weeklyMuscleMapSection
                        suggestionsSection
                    }
                    .padding()
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("FORTIS")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Quick Stats
    private var quickStatsSection: some View {
        HStack(spacing: 10) {
            RomanStatCard(title: "THIS WEEK",   value: "\(weeklyWorkoutCount)", unit: "sessions")
            RomanStatCard(title: "VOLUME",      value: weeklyVolumeFormatted,   unit: "lbs")
            RomanStatCard(title: "STREAK",      value: "\(currentStreak)",      unit: "days")
        }
    }

    private var weeklyWorkoutCount: Int {
        sessions.filter { $0.startDate >= currentWeekStart }.count
    }

    private var weeklyVolumeFormatted: String {
        let v = sessions.filter { $0.startDate >= currentWeekStart }.reduce(0.0) { $0 + $1.totalVolume }
        if v >= 1000 { return String(format: "%.1fk", v / 1000) }
        return String(format: "%.0f", v)
    }

    private var currentStreak: Int {
        guard !sessions.isEmpty else { return 0 }
        var streak = 0
        var date = Calendar.current.startOfDay(for: Date())
        for _ in 0..<30 {
            if sessions.contains(where: { Calendar.current.isDate($0.startDate, inSameDayAs: date) }) {
                streak += 1
                date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
            } else { break }
        }
        return streak
    }

    private var sundayCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        return calendar
    }

    private var currentWeekStart: Date {
        sundayCalendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? sundayCalendar.startOfDay(for: Date())
    }

    private var weeklySessions: [WorkoutSession] {
        sessions.filter { $0.startDate >= currentWeekStart }
    }

    private var combinedWeeklyPrimaryMuscles: [String] {
        var muscles = Set<String>()
        for session in weeklySessions {
            for ex in session.workoutExercises {
                muscles.formUnion(ex.primaryMuscles)
            }
        }
        return Array(muscles)
    }

    private var combinedWeeklySecondaryMuscles: [String] {
        var muscles = Set<String>()
        for session in weeklySessions {
            for ex in session.workoutExercises {
                muscles.formUnion(ex.secondaryMuscles ?? [])
            }
        }
        return Array(muscles)
    }

    // MARK: - Start Workout Card
    private var startWorkoutCard: some View {
        Button(action: showWorkout) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BEGIN TRAINING")
                        .font(.system(size: 11, weight: .black))
                        .tracking(3)
                        .foregroundStyle(.romanGoldDim)
                    Text("Start Workout")
                        .font(.title2.bold())
                        .foregroundStyle(.romanParchment)
                    Text("Tap to open a new session")
                        .font(.caption)
                        .foregroundStyle(.romanParchment.opacity(0.6))
                }
                Spacer()
                Image(systemName: "flame.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(LinearGradient.romanGoldGradient)
            }
            .padding(20)
            .background(
                ZStack {
                    Color.romanSurface
                    LinearGradient(
                        colors: [Color.romanGoldDim.opacity(0.15), Color.clear],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.romanGoldDim.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weekly Muscle Map
    private var weeklyMuscleMapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("WEEKLY MUSCLE MAP")
            if weeklySessions.isEmpty {
                Text("Complete a workout to visualize your muscles trained this week.")
                    .font(.caption)
                    .foregroundStyle(.romanParchmentDim)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .romanCard()
            } else {
                MuscleMapView(
                    primaryMuscles: combinedWeeklyPrimaryMuscles,
                    secondaryMuscles: combinedWeeklySecondaryMuscles
                )
                .frame(height: 200)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Suggestions
    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("SUGGESTED")
            let suggestions = muscleGroupSuggestions()
            if suggestions.isEmpty {
                Text("Complete a workout to receive muscle-group suggestions.")
                    .font(.caption)
                    .foregroundStyle(.romanParchmentDim)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .romanCard()
            } else {
                ForEach(suggestions, id: \.self) { muscle in
                    SuggestionCard(muscleGroup: muscle)
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

    private func muscleGroupSuggestions() -> [String] {
        let all = MuscleGroup.allCases.map { $0.rawValue }
        let recent = Set(sessions.prefix(3).flatMap { $0.workoutExercises.flatMap { $0.primaryMuscles } })
        return Array(all.filter { !recent.contains($0) }.prefix(2))
    }
}

// MARK: - Stat Card
struct RomanStatCard: View {
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 8, weight: .bold))
                .tracking(2)
                .foregroundStyle(.romanParchmentDim)
            Text(value)
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(.romanGold)
            Text(unit)
                .font(.system(size: 9))
                .foregroundStyle(.romanParchmentDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .romanCard()
    }
}

// MARK: - Recent Workout Card
struct RecentWorkoutCard: View {
    let session: WorkoutSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.romanParchment)
                Text(session.startDate, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.romanParchmentDim)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(volumeFormatted)
                    .font(.subheadline.bold())
                    .foregroundStyle(.romanGold)
                Text("\(session.totalSets) sets")
                    .font(.caption)
                    .foregroundStyle(.romanParchmentDim)
            }
        }
        .padding(14)
        .romanCard()
    }

    private var volumeFormatted: String {
        let v = session.totalVolume
        if v >= 1000 { return String(format: "%.1fk lbs", v / 1000) }
        return String(format: "%.0f lbs", v)
    }
}

// MARK: - Suggestion Card
struct SuggestionCard: View {
    let muscleGroup: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.up.right.circle.fill")
                .font(.title2)
                .foregroundStyle(.romanGold)
            VStack(alignment: .leading, spacing: 2) {
                Text("Train \(muscleGroup)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.romanParchment)
                Text("Not trained recently")
                    .font(.caption)
                    .foregroundStyle(.romanParchmentDim)
            }
            Spacer()
        }
        .padding(14)
        .romanCard()
    }
}
