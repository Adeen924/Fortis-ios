import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query(sort: \WorkoutSession.startDate, order: .reverse) private var sessions: [WorkoutSession]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 64, height: 64)
                            Text("F")
                                .font(.title.bold())
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Athlete")
                                .font(.title3.bold())
                            Text("Joined today")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Stats") {
                    ProfileStatRow(label: "Total Workouts", value: "\(sessions.count)")
                    ProfileStatRow(label: "Total Volume", value: totalVolumeFormatted)
                    ProfileStatRow(label: "Exercises Logged", value: "\(totalExercises)")
                }

                Section("Settings") {
                    Label("Notifications", systemImage: "bell.fill")
                    Label("Units (lbs / kg)", systemImage: "scalemass.fill")
                    Label("Connect Apple Health", systemImage: "heart.fill")
                    Label("Sync with Apple Watch", systemImage: "applewatch")
                }

                Section {
                    Text("More settings and full profile coming in Phase 4.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Profile")
        }
    }

    private var totalVolumeFormatted: String {
        let v = sessions.reduce(0) { $0 + $1.totalVolume }
        if v >= 1_000_000 { return String(format: "%.1fM lbs", v / 1_000_000) }
        if v >= 1000      { return String(format: "%.1fk lbs", v / 1000) }
        return String(format: "%.0f lbs", v)
    }

    private var totalExercises: Int {
        sessions.flatMap { $0.workoutExercises }.count
    }
}

struct ProfileStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.orange)
                .bold()
        }
    }
}
