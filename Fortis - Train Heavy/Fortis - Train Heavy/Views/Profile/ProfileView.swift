import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query(sort: \WorkoutSession.startDate, order: .reverse) private var sessions: [WorkoutSession]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.romanBackground.ignoresSafeArea()
                List {
                    Section {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.romanSurface)
                                    .frame(width: 64, height: 64)
                                    .overlay(Circle().stroke(LinearGradient.romanGoldGradient, lineWidth: 1.5))
                                Text("F")
                                    .font(.system(size: 28, weight: .black, design: .serif))
                                    .foregroundStyle(LinearGradient.romanGoldGradient)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Athlete")
                                    .font(.title3.bold())
                                    .foregroundStyle(.romanParchment)
                                Text("Fortis — Train Heavy")
                                    .font(.caption)
                                    .foregroundStyle(.romanParchmentDim)
                            }
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Color.romanSurface)
                    }

                    Section {
                        ProfileStatRow(label: "Total Sessions",    value: "\(sessions.count)")
                        ProfileStatRow(label: "Total Volume",      value: totalVolumeFormatted)
                        ProfileStatRow(label: "Exercises Logged",  value: "\(totalExercises)")
                    } header: {
                        sectionHeader("YOUR LEGACY")
                    }
                    .listRowBackground(Color.romanSurface)
                    .listRowSeparatorTint(Color.romanBorder)

                    Section {
                        settingsRow(label: "Notifications",       icon: "bell.fill")
                        settingsRow(label: "Units (lbs / kg)",    icon: "scalemass.fill")
                        settingsRow(label: "Apple Health",        icon: "heart.fill")
                        settingsRow(label: "Apple Watch",         icon: "applewatch")
                    } header: {
                        sectionHeader("SETTINGS")
                    }
                    .listRowBackground(Color.romanSurface)
                    .listRowSeparatorTint(Color.romanBorder)

                    Section {
                        Text("Full profile, social features, and advanced settings arrive in Phase 4.")
                            .font(.caption)
                            .foregroundStyle(.romanParchmentDim)
                            .listRowBackground(Color.romanSurface)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("PROFILE")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(3)
            .foregroundStyle(.romanParchmentDim)
    }

    private func settingsRow(label: String, icon: String) -> some View {
        Label(label, systemImage: icon)
            .foregroundStyle(.romanParchment)
    }

    private var totalVolumeFormatted: String {
        let v = sessions.reduce(0.0) { $0 + $1.totalVolume }
        if v >= 1_000_000 { return String(format: "%.1fM lbs", v / 1_000_000) }
        if v >= 1000      { return String(format: "%.1fk lbs", v / 1000) }
        return String(format: "%.0f lbs", v)
    }

    private var totalExercises: Int { sessions.flatMap { $0.workoutExercises }.count }
}

struct ProfileStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.romanParchment)
            Spacer()
            Text(value).foregroundStyle(.romanGold).bold()
        }
    }
}
