import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @EnvironmentObject private var dataStore: FirebaseDataStore
    @EnvironmentObject private var appSettings: AppSettings
    @Environment(\.openURL) private var openURL
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAccountAlert = false
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showingUnitsDialog = false
    @State private var showingURLFailureAlert = false
    @State private var urlFailureMessage = ""
    @State private var isDeletingAccount = false
    @State private var accountDeletionError: String?

    private var profile: UserProfile? { dataStore.profile }
    private var sessions: [WorkoutSession] { dataStore.workouts }

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
                        NavigationLink(destination: NotificationsView()) {
                            settingsRow("Notifications", icon: "bell.fill")
                        }
                        Button(action: { showingUnitsDialog = true }) {
                            settingsRow("Units (\(appSettings.weightUnit.symbol))", icon: "scalemass.fill")
                        }
                        Button(action: openAppleHealth) {
                            settingsRow("Apple Health", icon: "heart.fill")
                        }
                        Button(action: openAppleWatch) {
                            settingsRow("Apple Watch", icon: "applewatch")
                        }
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
                            if isDeletingAccount {
                                HStack {
                                    ProgressView()
                                        .tint(.romanCrimson)
                                    Text("Deleting Account")
                                }
                                .foregroundStyle(.romanCrimson)
                            } else {
                                Label("Delete Account", systemImage: "trash.fill")
                                    .foregroundStyle(.romanCrimson)
                            }
                        }
                        .disabled(isDeletingAccount)
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
            .confirmationDialog("Choose your preferred units", isPresented: $showingUnitsDialog) {
                ForEach(WeightUnit.allCases) { unit in
                    Button(unit.displayName) {
                        appSettings.weightUnit = unit
                    }
                }
            }
            .alert("Unable to open app", isPresented: $showingURLFailureAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(urlFailureMessage)
            }
            .alert("Unable to Delete Account", isPresented: Binding(
                get: { accountDeletionError != nil },
                set: { if !$0 { accountDeletionError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(accountDeletionError ?? "")
            }
            .onChange(of: selectedPhotoItem) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self), let profile = profile {
                        profile.photoData = data
                        if let userId = authManager.currentUserID {
                            try? await dataStore.saveProfile(profile, userId: userId)
                        }
                    }
                }
            }
        }
    }

    private func deleteAccount() {
        Task {
            isDeletingAccount = true
            defer { isDeletingAccount = false }

            do {
                if let userId = authManager.currentUserID {
                    try await dataStore.deleteAllUserData(userId: userId)
                }
                try await authManager.deleteCurrentAuthUser()
            } catch {
                accountDeletionError = error.localizedDescription
            }
        }
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
        return formattedVolume(v)
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

    private func formattedVolume(_ value: Double) -> String {
        let converted = appSettings.weightUnit == .kg ? value * 0.45359237 : value
        let symbol = appSettings.weightUnit.symbol
        if abs(converted) >= 1_000_000 { return String(format: "%.1fM %@", converted / 1_000_000, symbol) }
        if abs(converted) >= 1000      { return String(format: "%.1fk %@", converted / 1000, symbol) }
        return String(format: "%.0f %@", converted, symbol)
    }

    private func settingsRow(_ label: String, icon: String) -> some View {
        Label(label, systemImage: icon).foregroundStyle(.romanParchment)
    }

    private func openAppleHealth() {
        guard let url = URL(string: "x-apple-health://") else { return }
        openURL(url) { accepted in
            if !accepted {
                urlFailureMessage = "Unable to open the Health app."
                showingURLFailureAlert = true
            }
        }
    }

    private func openAppleWatch() {
        guard let url = URL(string: "x-apple-watch://") else { return }
        openURL(url) { accepted in
            if !accepted {
                urlFailureMessage = "Unable to open the Watch app."
                showingURLFailureAlert = true
            }
        }
    }
}

struct NotificationsView: View {
    @AppStorage("fortis_notifications_enabled") private var enabled = true
    @AppStorage("fortis_notifications_daily_summary") private var dailySummary = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Notifications")) {
                    Toggle("Enable Notifications", isOn: $enabled)
                    Toggle("Daily Workout Summary", isOn: $dailySummary)
                        .disabled(!enabled)
                }
            }
            .navigationTitle("Notifications")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
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
