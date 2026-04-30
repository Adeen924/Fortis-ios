import SwiftUI

struct ContentView: View {
    @State private var activeWorkout: WorkoutViewModel?
    @State private var showingWorkoutSheet = false

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            WorkoutTabView(activeWorkout: $activeWorkout, showingWorkoutSheet: $showingWorkoutSheet)
                .tabItem { Label("Workout", systemImage: "dumbbell.fill") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.fill") }

            SocialView()
                .tabItem { Label("Social", systemImage: "person.2.fill") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .environment(\.showWorkout, {
            activeWorkout = WorkoutViewModel()
            showingWorkoutSheet = true
        })
        .fullScreenCover(isPresented: $showingWorkoutSheet) {
            if let workout = activeWorkout {
                ActiveWorkoutView(viewModel: workout) {
                    showingWorkoutSheet = false
                    activeWorkout = nil
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
