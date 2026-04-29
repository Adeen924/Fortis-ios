import SwiftUI

struct WorkoutTabView: View {
    @Binding var activeWorkout: WorkoutViewModel?
    @Binding var showingWorkoutSheet: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)

                VStack(spacing: 8) {
                    Text("Ready to Train?")
                        .font(.title.bold())
                    Text("Start a new workout session\nand track your progress.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    startNewWorkout()
                } label: {
                    Label("Start Workout", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)

                Spacer()
            }
            .navigationTitle("Workout")
        }
    }

    private func startNewWorkout() {
        activeWorkout = WorkoutViewModel()
        showingWorkoutSheet = true
    }
}
