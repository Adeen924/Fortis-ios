import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .home
    @State private var activeWorkout: WorkoutViewModel?
    @State private var showingWorkoutSheet = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(Tab.home)

            WorkoutTabView(activeWorkout: $activeWorkout, showingWorkoutSheet: $showingWorkoutSheet)
                .tabItem {
                    Label("Workout", systemImage: "dumbbell.fill")
                }
                .tag(Tab.workout)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(Tab.history)

            SocialView()
                .tabItem {
                    Label("Social", systemImage: "person.2.fill")
                }
                .tag(Tab.social)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
                .tag(Tab.profile)
        }
        .tint(.orange)
        .environment(\.activeWorkout, activeWorkout)
        .environment(\.showWorkout, {
            selectedTab = .workout
            showingWorkoutSheet = true
        })
        .fullScreenCover(isPresented: $showingWorkoutSheet) {
            if let vm = activeWorkout {
                ActiveWorkoutView(viewModel: vm) {
                    showingWorkoutSheet = false
                    activeWorkout = nil
                }
            }
        }
    }

    enum Tab: Int {
        case home, workout, history, social, profile
    }
}

// MARK: - Environment Keys
struct ActiveWorkoutKey: EnvironmentKey {
    static let defaultValue: WorkoutViewModel? = nil
}

struct ShowWorkoutKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var activeWorkout: WorkoutViewModel? {
        get { self[ActiveWorkoutKey.self] }
        set { self[ActiveWorkoutKey.self] = newValue }
    }
    var showWorkout: () -> Void {
        get { self[ShowWorkoutKey.self] }
        set { self[ShowWorkoutKey.self] = newValue }
    }
}
