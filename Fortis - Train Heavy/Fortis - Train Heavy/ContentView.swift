import SwiftUI

struct ContentView: View {
    @State private var activeWorkout: WorkoutViewModel?

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            HistoryView()
                .tabItem { Label("History", systemImage: "scroll.fill") }

            AnalyticsView()
                .tabItem { Label("Analytics", systemImage: "chart.bar.fill") }

            SocialView()
                .tabItem { Label("Social", systemImage: "person.2.fill") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "shield.fill") }
        }
        .tint(.romanGold)
        .preferredColorScheme(.dark)
        .environment(\.showWorkout, {
            activeWorkout = WorkoutViewModel()
        })
        .fullScreenCover(item: $activeWorkout) { workout in
            ActiveWorkoutView(viewModel: workout) {
                activeWorkout = nil
            }
        }
    }
}

#Preview {
    ContentView()
}
