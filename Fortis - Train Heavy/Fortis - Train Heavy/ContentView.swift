import SwiftUI

struct ContentView: View {
    @State private var activeWorkout: WorkoutViewModel?
    @State private var restoredDraftOnce = false

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
            activeWorkout = WorkoutViewModel.restoredDraft().map(WorkoutViewModel.init(draft:)) ?? WorkoutViewModel()
        })
        .fullScreenCover(item: $activeWorkout) { workout in
            ActiveWorkoutView(viewModel: workout) {
                activeWorkout = nil
            }
        }
        .task {
            guard !restoredDraftOnce else { return }
            restoredDraftOnce = true
            if let draft = WorkoutViewModel.restoredDraft() {
                activeWorkout = WorkoutViewModel(draft: draft)
            }
        }
    }
}

#Preview {
    ContentView()
}
