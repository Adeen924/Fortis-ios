import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \WorkoutSession.startDate, order: .reverse) private var sessions: [WorkoutSession]
    @State private var selectedSession: WorkoutSession?

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Workouts Yet",
                        systemImage: "clock.badge.questionmark",
                        description: Text("Complete your first workout to see your history.")
                    )
                } else {
                    List {
                        // Group by month
                        ForEach(groupedSessions.keys.sorted(by: >), id: \.self) { monthKey in
                            Section(header: Text(monthKey).textCase(nil)) {
                                ForEach(groupedSessions[monthKey] ?? []) { session in
                                    Button {
                                        selectedSession = session
                                    } label: {
                                        HistoryRow(session: session)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("History")
            .sheet(item: $selectedSession) { session in
                WorkoutSummaryView(session: session) {
                    selectedSession = nil
                }
            }
        }
    }

    private var groupedSessions: [String: [WorkoutSession]] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return Dictionary(grouping: sessions) { formatter.string(from: $0.startDate) }
    }
}

struct HistoryRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 12) {
            // Date block
            VStack(spacing: 2) {
                Text(dayString)
                    .font(.title3.bold())
                    .foregroundStyle(.orange)
                Text(weekdayString)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .font(.subheadline.bold())
                HStack(spacing: 8) {
                    Label(durationFormatted, systemImage: "clock")
                    Label(volumeFormatted, systemImage: "scalemass")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Text(musclesString)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var dayString: String {
        let f = DateFormatter(); f.dateFormat = "d"
        return f.string(from: session.startDate)
    }

    private var weekdayString: String {
        let f = DateFormatter(); f.dateFormat = "EEE"
        return f.string(from: session.startDate).uppercased()
    }

    private var durationFormatted: String {
        let d = Int(session.duration)
        let m = d / 60
        if m < 60 { return "\(m)m" }
        return "\(m / 60)h \(m % 60)m"
    }

    private var volumeFormatted: String {
        let v = session.totalVolume
        if v >= 1000 { return String(format: "%.1fk lbs", v / 1000) }
        return String(format: "%.0f lbs", v)
    }

    private var musclesString: String {
        let muscles = Set(session.workoutExercises.flatMap { $0.primaryMuscles })
        return muscles.sorted().joined(separator: " · ")
    }
}
