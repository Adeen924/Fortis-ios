import SwiftUI

struct WorkoutTabView: View {
    @Binding var activeWorkout: WorkoutViewModel?
    @EnvironmentObject private var dataStore: FirebaseDataStore
    private var sessions: [WorkoutSession] { dataStore.workouts }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.romanBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()
                    emblemSection
                    Spacer()
                    statsBanner
                        .padding(.horizontal, 20)
                    Spacer()
                    startButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Emblem
    private var emblemSection: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.romanSurface)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Circle().stroke(
                            LinearGradient.romanGoldGradient,
                            lineWidth: 1.5
                        )
                    )
                    .shadow(color: .romanGold.opacity(0.25), radius: 24, x: 0, y: 8)

                Image(systemName: "shield.fill")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(LinearGradient.romanGoldGradient)
            }

            VStack(spacing: 6) {
                Text("FORTIS")
                    .font(.system(size: 44, weight: .black, design: .serif))
                    .foregroundStyle(LinearGradient.romanGoldGradient)
                    .tracking(10)

                Text("TRAIN HEAVY · GROW STRONGER")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.romanParchmentDim)
                    .tracking(4)

                Text("Fortes Fortuna Adiuvat")
                    .font(.system(size: 14, weight: .light, design: .serif))
                    .italic()
                    .foregroundStyle(.romanGoldDim)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Stats Banner
    private var statsBanner: some View {
        HStack(spacing: 0) {
            statPillar(value: "\(sessions.count)", label: "SESSIONS")
            Rectangle().fill(Color.romanBorder).frame(width: 0.5).padding(.vertical, 12)
            statPillar(value: weeklyCount, label: "THIS WEEK")
            Rectangle().fill(Color.romanBorder).frame(width: 0.5).padding(.vertical, 12)
            statPillar(value: totalVolumeShort, label: "TOTAL VOL")
        }
        .padding(.vertical, 18)
        .romanCard()
    }

    private func statPillar(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(.romanGold)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.romanParchmentDim)
                .tracking(2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Start Button
    private var startButton: some View {
        Button(action: { activeWorkout = WorkoutViewModel() }) {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 17, weight: .bold))
                Text("BEGIN TRAINING")
                    .font(.system(size: 15, weight: .black))
                    .tracking(3)
            }
            .foregroundStyle(Color.romanBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(LinearGradient.romanGoldGradient)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .romanGold.opacity(0.35), radius: 18, x: 0, y: 8)
        }
    }

    // MARK: - Computed
    private var weeklyCount: String {
        let ago = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return "\(sessions.filter { $0.startDate >= ago }.count)"
    }

    private var totalVolumeShort: String {
        let v = sessions.reduce(0.0) { $0 + $1.totalVolume }
        if v >= 1_000_000 { return String(format: "%.1fM", v / 1_000_000) }
        if v >= 1000      { return String(format: "%.1fk", v / 1000) }
        return String(format: "%.0f", v)
    }
}
