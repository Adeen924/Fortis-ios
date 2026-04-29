import SwiftUI

struct WorkoutSummaryView: View {
    let session: WorkoutSession
    let onDismiss: () -> Void

    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero header
                    summaryHero

                    // Stats grid
                    statsGrid

                    // Exercise breakdown
                    exerciseBreakdown

                    // Body muscle heat map
                    heatMapSection

                    // Share button
                    shareSection
                }
                .padding()
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Workout Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDismiss)
                        .bold()
                }
            }
        }
    }

    // MARK: - Hero
    private var summaryHero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text("Great Work!")
                .font(.title.bold())
            Text(session.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Stats Grid
    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            SummaryStatCard(
                icon: "clock.fill",
                iconColor: .blue,
                label: "Duration",
                value: durationFormatted
            )
            SummaryStatCard(
                icon: "scalemass.fill",
                iconColor: .orange,
                label: "Total Volume",
                value: volumeFormatted
            )
            SummaryStatCard(
                icon: "list.number",
                iconColor: .green,
                label: "Total Sets",
                value: "\(session.totalSets)"
            )
            SummaryStatCard(
                icon: "dumbbell.fill",
                iconColor: .purple,
                label: "Exercises",
                value: "\(session.workoutExercises.count)"
            )
        }
    }

    private var durationFormatted: String {
        let d = Int(session.duration)
        let h = d / 3600
        let m = (d % 3600) / 60
        let s = d % 60
        if h > 0 { return String(format: "%dh %dm", h, m) }
        if m > 0 { return String(format: "%dm %ds", m, s) }
        return "\(s)s"
    }

    private var volumeFormatted: String {
        let v = session.totalVolume
        if v >= 1000 { return String(format: "%.1fk lbs", v / 1000) }
        return String(format: "%.0f lbs", v)
    }

    // MARK: - Exercise Breakdown
    private var exerciseBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercises")
                .font(.headline)

            ForEach(session.workoutExercises.sorted(by: { $0.order < $1.order })) { workoutEx in
                ExerciseSummaryRow(workoutExercise: workoutEx)
            }
        }
    }

    // MARK: - Heat Map
    private var heatMapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Muscles Trained")
                .font(.headline)

            MuscleSummaryHeatMap(session: session)
        }
    }

    // MARK: - Share
    private var shareSection: some View {
        VStack(spacing: 12) {
            Button {
                // Phase 2: share to Instagram / in-app feed
            } label: {
                Label("Share to Feed", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}

// MARK: - Summary Stat Card
struct SummaryStatCard: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.bold())
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Exercise Summary Row
struct ExerciseSummaryRow: View {
    let workoutExercise: WorkoutExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(workoutExercise.exerciseName)
                    .font(.subheadline.bold())
                Spacer()
                Text(volumeFormatted)
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }

            // Sets summary
            ForEach(workoutExercise.sets.sorted(by: { $0.setNumber < $1.setNumber })) { set in
                HStack(spacing: 16) {
                    Text("Set \(set.setNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .leading)
                    Text(String(format: "%.1f lbs", set.weight))
                        .font(.caption.monospacedDigit())
                    Text("×")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(set.reps) reps")
                        .font(.caption.monospacedDigit())
                    Spacer()
                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.caption)
                        .foregroundStyle(set.isCompleted ? .green : .secondary)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var volumeFormatted: String {
        let v = workoutExercise.totalVolume
        if v >= 1000 { return String(format: "%.1fk lbs", v / 1000) }
        return String(format: "%.0f lbs", v)
    }
}

// MARK: - Muscle Heat Map
struct MuscleSummaryHeatMap: View {
    let session: WorkoutSession

    private var trainedMuscles: [String: Int] {
        var counts: [String: Int] = [:]
        for ex in session.workoutExercises {
            for muscle in ex.primaryMuscles {
                counts[muscle, default: 0] += ex.sets.count
            }
        }
        return counts
    }

    var body: some View {
        VStack(spacing: 8) {
            let muscles = trainedMuscles
            let maxCount = muscles.values.max() ?? 1

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(MuscleGroup.allCases, id: \.rawValue) { group in
                    let count = muscles[group.rawValue] ?? 0
                    let intensity = Double(count) / Double(maxCount)

                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(count > 0
                                  ? Color.orange.opacity(0.3 + 0.7 * intensity)
                                  : Color(.tertiarySystemBackground))
                            .frame(height: 40)
                            .overlay(
                                Text(count > 0 ? "\(count)" : "")
                                    .font(.caption.bold())
                                    .foregroundStyle(count > 0 ? .white : .clear)
                            )
                        Text(group.rawValue)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }

            HStack(spacing: 8) {
                Text("Less")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    ForEach([0.2, 0.4, 0.6, 0.8, 1.0], id: \.self) { opacity in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.orange.opacity(opacity))
                            .frame(width: 16, height: 10)
                    }
                }
                Text("More")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
