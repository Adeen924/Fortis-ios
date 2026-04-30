import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appSettings: AppSettings
    @Bindable var viewModel: WorkoutViewModel
    @Query private var profiles: [UserProfile]
    let onDismiss: () -> Void

    @State private var showingExercisePicker = false

    private var profile: UserProfile? { profiles.first }
    @State private var showingFinishAlert = false
    @State private var showingCancelAlert = false
    @State private var showingRenameSheet = false
    @State private var finishedSession: WorkoutSession?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.romanBackground.ignoresSafeArea()

                Group {
                    if viewModel.workoutExercises.isEmpty {
                        emptyState
                    } else {
                        exerciseList
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
            .safeAreaInset(edge: .bottom) { addExerciseButton }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView { exercise in
                    let bodyWeight = exercise.equipmentType.lowercased().contains("body") ? profile?.weightLbs : nil
                    viewModel.addExercise(exercise, bodyWeightLbs: bodyWeight)
                }
            }
            .sheet(isPresented: $showingRenameSheet) { renameSheet }
            .alert("Finish Workout?", isPresented: $showingFinishAlert) {
                Button("Finish", role: .none) { finishWorkout() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Save \(viewModel.totalCompletedSets) completed sets · \(formattedWeight(viewModel.totalVolume)) total.")
            }
            .alert("Cancel Workout?", isPresented: $showingCancelAlert) {
                Button("Discard", role: .destructive) { onDismiss() }
                Button("Keep Going", role: .cancel) {}
            } message: {
                Text("This workout will not be saved.")
            }
            .fullScreenCover(item: $finishedSession) { session in
                WorkoutSummaryView(session: session, onDismiss: {
                    finishedSession = nil
                    onDismiss()
                })
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel", role: .destructive) { showingCancelAlert = true }
                .foregroundStyle(.romanCrimson)
        }
        ToolbarItem(placement: .principal) {
            Button(action: { showingRenameSheet = true }) {
                VStack(spacing: 2) {
                    timerBadge
                    Text(viewModel.workoutName)
                        .font(.caption2.bold())
                        .foregroundStyle(.romanParchmentDim)
                        .lineLimit(1)
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("FINISH") { showingFinishAlert = true }
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.romanGold)
        }
    }

    // MARK: - Timer Badge
    private var timerBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.green)
                .frame(width: 6, height: 6)
            Text(viewModel.formattedDuration)
                .font(.subheadline.monospacedDigit().bold())
                .foregroundStyle(.romanParchment)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color.romanSurface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.romanBorder, lineWidth: 0.5))
    }

    // MARK: - Rename Sheet
    private var renameSheet: some View {
        NavigationStack {
            ZStack {
                Color.romanBackground.ignoresSafeArea()
                VStack(spacing: 24) {
                    Text("RENAME WORKOUT")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(.romanParchmentDim)

                    TextField("Workout name", text: $viewModel.workoutName)
                        .font(.title3.bold())
                        .foregroundStyle(.romanParchment)
                        .multilineTextAlignment(.center)
                        .padding()
                        .romanCard()
                        .padding(.horizontal)
                }
                .padding(.top, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showingRenameSheet = false }
                        .foregroundStyle(.romanGold)
                        .bold()
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "plus.circle.dashed")
                .font(.system(size: 56))
                .foregroundStyle(.romanGoldDim)
            Text("ADD YOUR FIRST EXERCISE")
                .font(.system(size: 13, weight: .bold))
                .tracking(3)
                .foregroundStyle(.romanParchment)
            Text("Tap below to browse the exercise library.")
                .font(.subheadline)
                .foregroundStyle(.romanParchmentDim)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    // MARK: - Exercise List
    private var exerciseList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(viewModel.workoutExercises) { entry in
                    ExerciseLogCard(entry: entry, viewModel: viewModel) {
                        if let idx = viewModel.workoutExercises.firstIndex(where: { $0.id == entry.id }) {
                            viewModel.removeExercise(at: IndexSet(integer: idx))
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 90)
        }
    }

    // MARK: - Add Exercise Button
    private var addExerciseButton: some View {
        Button { showingExercisePicker = true } label: {
            Label("ADD EXERCISE", systemImage: "plus")
                .font(.system(size: 13, weight: .black))
                .tracking(2)
                .foregroundStyle(.romanBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LinearGradient.romanGoldGradient)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
    }

    private func finishWorkout() {
        let session = viewModel.finishWorkout(context: modelContext)
        finishedSession = session
    }

    private func formattedWeight(_ value: Double) -> String {
        let converted = appSettings.weightUnit == .kg ? value * 0.45359237 : value
        let symbol = appSettings.weightUnit.symbol
        if abs(converted) >= 1_000_000 { return String(format: "%.1fM %@", converted / 1_000_000, symbol) }
        if abs(converted) >= 1_000 { return String(format: "%.1fk %@", converted / 1_000, symbol) }
        return String(format: "%.0f %@", converted, symbol)
    }
}

// MARK: - Exercise Log Card
struct ExerciseLogCard: View {
    @EnvironmentObject private var appSettings: AppSettings
    let entry: WorkoutExerciseEntry
    @Bindable var viewModel: WorkoutViewModel
    let onDelete: () -> Void

    @State private var showingDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.exerciseName)
                        .font(.subheadline.bold())
                        .foregroundStyle(.romanParchment)
                    HStack(spacing: 4) {
                        Text(entry.exerciseCategory.uppercased())
                            .tracking(1)
                        Text("·")
                        Text(entry.primaryMuscles.joined(separator: ", "))
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.romanParchmentDim)
                }
                Spacer()
                if entry.totalVolume > 0 {
                    Text(formattedWeight(entry.totalVolume))
                        .font(.caption.bold())
                        .foregroundStyle(.romanGold)
                        .padding(.trailing, 4)
                }
                Button(action: { showingDeleteConfirm = true }) {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(.romanParchmentDim)
                        .frame(width: 28, height: 28)
                        .background(Color.romanSurfaceHigh)
                        .clipShape(Circle())
                }
            }
            .padding(14)

            Toggle(isOn: Binding(
                get: { entry.isUnilateral },
                set: { viewModel.setUnilateral(for: entry, enabled: $0) }
            )) {
                Text("Unilateral")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.romanParchment)
            }
            .toggleStyle(SwitchToggleStyle(tint: .romanGold))
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

            Rectangle().fill(Color.romanBorder).frame(height: 0.5).padding(.horizontal, 14)

            // Sets header
            HStack {
                Text("SET").frame(width: 36, alignment: .leading)
                Text(appSettings.weightUnit.symbol.uppercased()).frame(maxWidth: .infinity)
                Text("REPS").frame(maxWidth: .infinity)
                Text("").frame(width: 44)
            }
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.romanParchmentDim)
            .tracking(2)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            ForEach(entry.sets) { set in
                SetRow(
                    set: set,
                    onRedo: { viewModel.addRedoSet(to: entry, from: set.id) },
                    onUpdate: { reps, weight in
                        viewModel.updateSet(in: entry, setID: set.id, reps: reps, weight: weight)
                    }
                )
            }

            HStack(spacing: 12) {
                Button {
                    viewModel.addSet(to: entry)
                } label: {
                    Label("Add Set", systemImage: "plus")
                        .font(.subheadline.bold())
                        .foregroundStyle(.romanGold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.romanSurfaceHigh)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Button {
                    viewModel.removeLastSet(from: entry)
                } label: {
                    Label("Remove Set", systemImage: "minus")
                        .font(.subheadline.bold())
                        .foregroundStyle(.romanCrimson)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.romanSurfaceHigh)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(entry.sets.isEmpty)
                .opacity(entry.sets.isEmpty ? 0.5 : 1)
            }
            .padding(.top, 4)
        }
        .romanCard()
        .confirmationDialog("Remove \(entry.exerciseName)?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Remove Exercise", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func formattedWeight(_ value: Double) -> String {
        let converted = appSettings.weightUnit == .kg ? value * 0.45359237 : value
        let symbol = appSettings.weightUnit.symbol
        if abs(converted) >= 1_000_000 { return String(format: "%.1fM %@", converted / 1_000_000, symbol) }
        if abs(converted) >= 1_000 { return String(format: "%.1fk %@", converted / 1_000, symbol) }
        return String(format: "%.0f %@", converted, symbol)
    }
}

// MARK: - Set Row
struct SetRow: View {
    @EnvironmentObject private var appSettings: AppSettings
    let set: SetEntry
    let onRedo: () -> Void
    let onUpdate: (Int, Double) -> Void

    @State private var repsText: String
    @State private var weightText: String

    init(set: SetEntry, onRedo: @escaping () -> Void, onUpdate: @escaping (Int, Double) -> Void) {
        self.set = set
        self.onRedo = onRedo
        self.onUpdate = onUpdate
        _repsText   = State(initialValue: set.reps > 0   ? "\(set.reps)"                      : "")
        _weightText = State(initialValue: set.weight > 0 ? String(format: "%.1f", set.weight) : "")
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(set.setNumber)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.romanParchmentDim)
                if let side = set.side {
                    Text(side.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.romanGoldDim)
                }
            }
            .frame(width: 36, alignment: .leading)

            TextField("0", text: $weightText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.romanParchment)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Color.romanSurfaceHigh)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .onChange(of: weightText) { new in
                    if let displayWeight = Double(new), let storedWeight = storedWeight(from: displayWeight) {
                        onUpdate(Int(repsText) ?? set.reps, storedWeight)
                    }
                }

            TextField("0", text: $repsText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.romanParchment)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Color.romanSurfaceHigh)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .onChange(of: repsText) { new in
                    if let r = Int(new) {
                        let displayWeight = Double(weightText) ?? (appSettings.weightUnit == .kg ? set.weight * 0.45359237 : set.weight)
                        onUpdate(r, storedWeight(from: displayWeight) ?? set.weight)
                    }
                }

            Button(action: onRedo) {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
                    .foregroundStyle(.romanGold)
            }
            .frame(width: 44)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(set.isCompleted ? Color.romanGoldDim.opacity(0.12) : Color.clear)
        .animation(.easeInOut(duration: 0.15), value: set.isCompleted)
        .onAppear { if set.weight > 0 { weightText = formattedDisplayWeight() } }
        .onChange(of: appSettings.weightUnit) {
            if set.weight > 0 { weightText = formattedDisplayWeight() }
        }
    }

    private func formattedDisplayWeight() -> String {
        let display = appSettings.weightUnit == .kg ? set.weight * 0.45359237 : set.weight
        return String(format: "%.1f", display)
    }

    private func storedWeight(from displayWeight: Double) -> Double? {
        let stored = appSettings.weightUnit == .kg ? displayWeight / 0.45359237 : displayWeight
        return stored
    }
}
