import SwiftUI
import SwiftData
import PhotosUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutSession.startDate, order: .reverse) private var sessions: [WorkoutSession]
    @Query private var profiles: [UserProfile]
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAccountAlert = false
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.romanBackground.ignoresSafeArea()
                List {
                    // Header
                    Section {
                        HStack(spacing: 16) {
                            ZStack {
                                if let profile = profile, let photoData = profile.photoData, let uiImage = UIImage(data: photoData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 68, height: 68)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(LinearGradient.romanGoldGradient, lineWidth: 1.5))
                                } else {
                                    Circle()
                                        .fill(Color.romanSurface)
                                        .frame(width: 68, height: 68)
                                        .overlay(Circle().stroke(LinearGradient.romanGoldGradient, lineWidth: 1.5))
                                    Text(initials)
                                        .font(.system(size: 26, weight: .black, design: .serif))
                                        .foregroundStyle(LinearGradient.romanGoldGradient)
                                }
                            }
                            .onTapGesture {
                                showingPhotoPicker = true
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile?.fullName ?? "Athlete")
                                    .font(.title3.bold())
                                    .foregroundStyle(.romanParchment)
                                if let username = profile?.username, !username.isEmpty {
                                    Text("@\(username)")
                                        .font(.subheadline)
                                        .foregroundStyle(.romanGoldDim)
                                }
                                Text("Member since \(joinDate)")
                                    .font(.caption)
                                    .foregroundStyle(.romanParchmentDim)
                            }
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Color.romanSurface)
                    }

                    // Physical stats from profile
                    if let p = profile {
                        Section {
                            profileRow(label: "Age",    value: "\(p.age) yrs")
                            profileRow(label: "Height", value: p.heightFormatted)
                            profileRow(label: "Weight", value: p.weightFormatted)
                            if !p.goals.isEmpty {
                                profileRow(label: "Goals", value: p.goals.joined(separator: ", "))
                            }
                        } header: { sectionHeader("YOUR STATS") }
                        .listRowBackground(Color.romanSurface)
                        .listRowSeparatorTint(Color.romanBorder)
                    }

                    // Training legacy
                    Section {
                        profileRow(label: "Total Sessions",   value: "\(sessions.count)")
                        profileRow(label: "Total Volume",     value: totalVolumeFormatted)
                        profileRow(label: "Exercises Logged", value: "\(totalExercises)")
                    } header: { sectionHeader("YOUR LEGACY") }
                    .listRowBackground(Color.romanSurface)
                    .listRowSeparatorTint(Color.romanBorder)

                    // Settings
                    Section {
                        settingsRow("Notifications",        icon: "bell.fill")
                        settingsRow("Units (lbs / kg)",     icon: "scalemass.fill")
                        settingsRow("Apple Health",         icon: "heart.fill")
                        settingsRow("Apple Watch",          icon: "applewatch")
                    } header: { sectionHeader("SETTINGS") }
                    .listRowBackground(Color.romanSurface)
                    .listRowSeparatorTint(Color.romanBorder)

                    // Sign Out
                    Section {
                        Button(role: .destructive, action: { showingSignOutAlert = true }) {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundStyle(.romanCrimson)
                        }
                        .listRowBackground(Color.romanSurface)
                        
                        Button(role: .destructive, action: { showingDeleteAccountAlert = true }) {
                            Label("Delete Account", systemImage: "trash.fill")
                                .foregroundStyle(.romanCrimson)
                        }
                        .listRowBackground(Color.romanSurface)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("PROFILE")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("Sign Out?", isPresented: $showingSignOutAlert) {
                Button("Sign Out", role: .destructive) { authManager.signOut() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You will need to sign in again to access your workouts.")
            }
            .alert("Delete Account?", isPresented: $showingDeleteAccountAlert) {
                Button("Delete Account", role: .destructive) { deleteAccount() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your data, including workouts, exercises, and profile information. This action cannot be undone.")
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared())
            .onChange(of: selectedPhotoItem) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self), let profile = profile {
                        profile.photoData = data
                        try? context.save()
                    }
                }
            }
        }
    }

    private func deleteAccount() {
        // Delete all user data
        do {
            try context.delete(model: UserProfile.self)
            try context.delete(model: WorkoutSession.self)
            try context.delete(model: WorkoutExercise.self)
            try context.delete(model: ExerciseSet.self)
            // Note: Exercises are seeded, so don't delete them
            try context.save()
        } catch {
            print("Error deleting data: \(error)")
        }
        authManager.signOut()
    }

    // MARK: - Helpers
    private var initials: String {
        guard let p = profile else { return "F" }
        let f = p.firstName.prefix(1).uppercased()
        let l = p.lastName.prefix(1).uppercased()
        return f + l
    }

    private var joinDate: String {
        guard let p = profile else { return "today" }
        let f = DateFormatter(); f.dateStyle = .medium
        return f.string(from: p.createdAt)
    }

    private var totalVolumeFormatted: String {
        let v = sessions.reduce(0.0) { $0 + $1.totalVolume }
        if v >= 1_000_000 { return String(format: "%.1fM lbs", v / 1_000_000) }
        if v >= 1000      { return String(format: "%.1fk lbs", v / 1000) }
        return String(format: "%.0f lbs", v)
    }

    private var totalExercises: Int { sessions.flatMap { $0.workoutExercises }.count }

    private func sectionHeader(_ text: String) -> some View {
        Text(text).font(.system(size: 9, weight: .bold)).tracking(3).foregroundStyle(.romanParchmentDim)
    }

    private func profileRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.romanParchment)
            Spacer()
            Text(value).foregroundStyle(.romanGold).bold()
        }
    }

    private func settingsRow(_ label: String, icon: String) -> some View {
        Label(label, systemImage: icon).foregroundStyle(.romanParchment)
    }
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
