import SwiftUI
import SwiftData

struct HistoryView: View {
    @EnvironmentObject private var appSettings: AppSettings
    @Query(sort: \WorkoutSession.startDate, order: .reverse) private var sessions: [WorkoutSession]
    @State private var selectedSession: WorkoutSession?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.romanBackground.ignoresSafeArea()
                Group {
                    if sessions.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "scroll.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.romanGoldDim)
                            Text("NO SESSIONS YET")
                                .font(.system(size: 12, weight: .bold))
                                .tracking(3)
                                .foregroundStyle(.romanParchment)
                            Text("Complete your first workout to begin your legacy.")
                                .font(.subheadline)
                                .foregroundStyle(.romanParchmentDim)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        List {
                            ForEach(groupedSessions.keys.sorted(by: >), id: \.self) { monthKey in
                                Section {
                                    ForEach(groupedSessions[monthKey] ?? []) { session in
                                        Button { selectedSession = session } label: {
                                            HistoryRow(session: session)
                                        }
                                        .buttonStyle(.plain)
                                        .listRowBackground(Color.romanSurface)
                                        .listRowSeparatorTint(Color.romanBorder)
                                    }
                                } header: {
                                    Text(monthKey.uppercased())
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(3)
                                        .foregroundStyle(.romanParchmentDim)
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("HISTORY")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(item: $selectedSession) { session in
                WorkoutSummaryView(session: session) { selectedSession = nil }
            }
        }
    }

    private var groupedSessions: [String: [WorkoutSession]] {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return Dictionary(grouping: sessions) { f.string(from: $0.startDate) }
    }
}

struct HistoryRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(dayString)
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(.romanGold)
                Text(weekdayString)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.romanParchmentDim)
            }
            .frame(width: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.romanParchment)
                HStack(spacing: 10) {
                    Label(durationFormatted, systemImage: "clock")
                    Label(volumeFormatted, systemImage: "scalemass")
                }
                .font(.caption)
                .foregroundStyle(.romanParchmentDim)
                Text(musclesString)
                    .font(.caption)
                    .foregroundStyle(.romanGoldDim)
                    .lineLimit(1)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.romanBorder)
        }
        .padding(.vertical, 4)
    }

    private var dayString: String      { let f = DateFormatter(); f.dateFormat = "d";   return f.string(from: session.startDate) }
    private var weekdayString: String  { let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: session.startDate).uppercased() }

    private var durationFormatted: String {
        let m = Int(session.duration) / 60
        return m < 60 ? "\(m)m" : "\(m / 60)h \(m % 60)m"
    }

    private var volumeFormatted: String {
        let v = session.totalVolume
        let converted = appSettings.weightUnit == .kg ? v * 0.45359237 : v
        let symbol = appSettings.weightUnit.symbol
        if abs(converted) >= 1000 { return String(format: "%.1fk %@", converted / 1000, symbol) }
        return String(format: "%.0f %@", converted, symbol)
    }

    private var musclesString: String {
        Set(session.workoutExercises.flatMap { $0.primaryMuscles }).sorted().joined(separator: " · ")
    }
}
