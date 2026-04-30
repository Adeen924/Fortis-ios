import SwiftUI
import SwiftData
import UIKit

struct PersonalRecord: Identifiable {
    let id = UUID()
    let exerciseName: String
    let reps: Int
    let weight: Double
    let previousMax: Double
}

struct WorkoutSummaryView: View {
    let session: WorkoutSession
    let onDismiss: () -> Void

    @Query private var profiles: [UserProfile]
    @Query(sort: \WorkoutSession.startDate, order: .reverse) private var pastSessions: [WorkoutSession]

    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

    private var combinedPrimaryMuscles: [String] {
        var muscles = Set<String>()
        for ex in session.workoutExercises {
            muscles.formUnion(ex.primaryMuscles)
        }
        return Array(muscles)
    }

    private var combinedSecondaryMuscles: [String] {
        var muscles = Set<String>()
        for ex in session.workoutExercises {
            muscles.formUnion(ex.secondaryMuscles ?? [])
        }
        return Array(muscles)
    }

    private var personalRecords: [PersonalRecord] {
        var records: [PersonalRecord] = []
        let pastMaxes = getPastMaxes()

        for workoutEx in session.workoutExercises {
            for set in workoutEx.sets where set.isCompleted {
                let key = "\(workoutEx.exerciseID)_\(set.reps)"
                let pastMax = pastMaxes[key] ?? 0
                if set.weight > pastMax {
                    records.append(PersonalRecord(
                        exerciseName: workoutEx.exerciseName,
                        reps: set.reps,
                        weight: set.weight,
                        previousMax: pastMax
                    ))
                }
            }
        }
        return records.sorted { $0.weight > $1.weight }
    }

    private func getPastMaxes() -> [String: Double] {
        var maxes: [String: Double] = [:]
        for pastSession in pastSessions where pastSession.id != session.id {
            for workoutEx in pastSession.workoutExercises {
                for set in workoutEx.sets where set.isCompleted {
                    let key = "\(workoutEx.exerciseID)_\(set.reps)"
                    maxes[key] = max(maxes[key] ?? 0, set.weight)
                }
            }
        }
        return maxes
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.romanBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        summaryHero
                        statsGrid
                        exerciseBreakdown
                        personalRecordsSection
                        shareSection
                    }
                    .padding()
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(session.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("DONE", action: onDismiss)
                        .font(.system(size: 12, weight: .black))
                        .tracking(2)
                        .foregroundStyle(.romanGold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Hero
    private var summaryHero: some View {
        VStack(spacing: 14) {
            Text(session.name)
                .font(.title2.bold())
                .foregroundStyle(.romanParchment)
            MuscleMapView(primaryMuscles: combinedPrimaryMuscles, secondaryMuscles: combinedSecondaryMuscles)
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
        }
        .padding(.top, 8)
    }

    // MARK: - Stats Grid
    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            SummaryStatCard(icon: "clock.fill",      iconColor: .romanGold,    label: "Duration",    value: durationFormatted)
            SummaryStatCard(icon: "scalemass.fill",  iconColor: .romanBronze,  label: "Total Volume", value: volumeFormatted)
            SummaryStatCard(icon: "list.number",     iconColor: .romanGold,    label: "Total Sets",  value: "\(session.totalSets)")
            SummaryStatCard(icon: "dumbbell.fill",   iconColor: .romanCrimson, label: "Exercises",   value: "\(session.workoutExercises.count)")
        }
    }

    private var durationFormatted: String {
        let d = Int(session.duration); let h = d / 3600; let m = (d % 3600) / 60; let s = d % 60
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
            sectionHeader("EXERCISES")
            ForEach(session.workoutExercises.sorted { $0.order < $1.order }) { workoutEx in
                ExerciseSummaryRow(workoutExercise: workoutEx)
            }
        }
    }

    // MARK: - Personal Records
    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("PERSONAL RECORDS")
            if personalRecords.isEmpty {
                Text("No new personal records this session.")
                    .font(.subheadline)
                    .foregroundStyle(.romanParchmentDim)
                    .padding(14)
                    .romanCard()
            } else {
                ForEach(personalRecords) { record in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PR: \(record.exerciseName)")
                                .font(.subheadline.bold())
                                .foregroundStyle(.romanParchment)
                            Text("\(String(format: "%.1f", record.weight)) lbs × \(record.reps) reps")
                                .font(.caption)
                                .foregroundStyle(.romanGold)
                            if record.previousMax > 0 {
                                Text("Previous: \(String(format: "%.1f", record.previousMax)) lbs")
                                    .font(.caption2)
                                    .foregroundStyle(.romanParchmentDim)
                            }
                        }
                        Spacer()
                        Image(systemName: "trophy.fill")
                            .font(.title3)
                            .foregroundStyle(.romanGold)
                    }
                    .padding(14)
                    .romanCard()
                }
            }
        }
    }

    // MARK: - Share
    private var shareSection: some View {
        HStack(spacing: 12) {
            Button {} label: {
                Label("Share to Feed", systemImage: "person.2.fill")
                    .font(.system(size: 12, weight: .black))
                    .tracking(1)
                    .foregroundStyle(.romanBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LinearGradient.romanGoldGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button(action: shareExternally) {
                Label("Share Externally", systemImage: "square.and.arrow.up")
                    .font(.system(size: 12, weight: .black))
                    .tracking(1)
                    .foregroundStyle(.romanBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LinearGradient.romanGoldGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: shareItems)
                .ignoresSafeArea()
        }
    }

    private func shareExternally() {
        var items: [Any] = [shareText]
        if let image = createShareSnapshot() {
            items.insert(image, at: 0)
        }
        shareItems = items
        showShareSheet = true
    }

    private func createShareSnapshot() -> UIImage? {
        let shareCard = WorkoutShareCard(
            title: session.name,
            duration: durationFormatted,
            volume: volumeFormatted,
            exerciseCount: session.workoutExercises.count,
            muscles: combinedPrimaryMuscles,
            primaryMuscles: combinedPrimaryMuscles,
            secondaryMuscles: combinedSecondaryMuscles
        )
        let renderer = ImageRenderer(content: shareCard)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }

    private var shareText: String {
        let muscles = combinedPrimaryMuscles.joined(separator: ", ")
        return "Just completed \(session.name)! 💪\n\nTotal Volume: \(volumeFormatted)\nDuration: \(durationFormatted)\nExercises: \(session.workoutExercises.count)\nMuscles Trained: \(muscles)\n\n#Fortis #Workout #Fitness"
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(3)
            .foregroundStyle(.romanParchmentDim)
    }
}

struct WorkoutShareCard: View {
    let title: String
    let duration: String
    let volume: String
    let exerciseCount: Int
    let muscles: [String]
    let primaryMuscles: [String]
    let secondaryMuscles: [String]

    var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 18) {
                Text(title)
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                MuscleMapView(primaryMuscles: primaryMuscles, secondaryMuscles: secondaryMuscles)
                    .frame(height: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal, 16)

                VStack(spacing: 10) {
                    HStack {
                        ShareStatLabel(title: "Duration", value: duration)
                        ShareStatLabel(title: "Volume", value: volume)
                    }
                    HStack {
                        ShareStatLabel(title: "Exercises", value: "\(exerciseCount)")
                        ShareStatLabel(title: "Muscles", value: muscles.joined(separator: ", "))
                    }
                }
                .padding(.horizontal, 18)

                Text("#Fortis #Workout #Fitness")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 12)
            }
            .padding(20)
        }
        .frame(width: 1080, height: 1620)
    }
}

struct ShareStatLabel: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.romanParchmentDim)
                Text(value)
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(.romanParchment)
            }
            Spacer()
        }
        .padding(14)
        .romanCard()
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
                    .foregroundStyle(.romanParchment)
                Spacer()
                Text(volumeFormatted)
                    .font(.caption.bold())
                    .foregroundStyle(.romanGold)
            }
            ForEach(workoutExercise.sets.sorted { $0.setNumber < $1.setNumber }) { set in
                HStack(spacing: 14) {
                    Text("Set \(set.setNumber)")
                        .font(.caption)
                        .foregroundStyle(.romanParchmentDim)
                        .frame(width: 40, alignment: .leading)
                    Text(String(format: "%.1f lbs", set.weight))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.romanParchment)
                    Text("×")
                        .font(.caption)
                        .foregroundStyle(.romanParchmentDim)
                    Text("\(set.reps) reps")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.romanParchment)
                    Spacer()
                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.caption)
                        .foregroundStyle(set.isCompleted ? .romanGold : .romanParchmentDim)
                }
            }
        }
        .padding(14)
        .romanCard()
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
            for muscle in ex.primaryMuscles { counts[muscle, default: 0] += ex.sets.count }
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
                                  ? Color.romanGold.opacity(0.25 + 0.75 * intensity)
                                  : Color.romanSurfaceHigh)
                            .frame(height: 40)
                            .overlay(
                                Text(count > 0 ? "\(count)" : "")
                                    .font(.caption.bold())
                                    .foregroundStyle(count > 0 ? .romanBackground : .clear)
                            )
                        Text(group.rawValue)
                            .font(.system(size: 8))
                            .foregroundStyle(.romanParchmentDim)
                            .multilineTextAlignment(.center)
                    }
                }
            }

            HStack(spacing: 6) {
                Text("Less").font(.caption2).foregroundStyle(.romanParchmentDim)
                HStack(spacing: 4) {
                    ForEach([0.2, 0.4, 0.6, 0.8, 1.0], id: \.self) { opacity in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.romanGold.opacity(opacity))
                            .frame(width: 16, height: 10)
                    }
                }
                Text("More").font(.caption2).foregroundStyle(.romanParchmentDim)
            }
            .padding(.top, 4)
        }
        .padding(14)
        .romanCard()
    }
}
