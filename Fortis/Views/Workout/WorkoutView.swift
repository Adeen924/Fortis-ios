import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: WorkoutViewModel
    let onDismiss: () -> Void

    @State private var showingExercisePicker = false
    @State private var showingFinishAlert = false
    @State private var showingCancelAlert = false
    @State private var finishedSession: WorkoutSession?
    @State private var showingSummary = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.workoutExercises.isEmpty {
                    emptyState
                } else {
                    exerciseList
                }
            }
            .navigationTitle(viewModel.workoutName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", role: .destructive) {
                        showingCancelAlert = true
                    }
                    .foregroundStyle(.red)
                }
                ToolbarItem(placement: .principal) {
                    timerBadge
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") {
                        showingFinishAlert = true
                    }
                    .bold()
                    .foregroundStyle(.orange)
                }
            }
            .safeAreaInset(edge: .bottom) {
                addExerciseButton
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView { exercise in
                    viewModel.addExercise(exercise)
                }
            }
            .alert("Finish Workout?", isPresented: $showingFinishAlert) {
                Button("Finish", role: .none) { finishWorkout() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your workout will be saved with \(viewModel.totalCompletedSets) completed sets and \(Int(viewModel.totalVolume).formatted()) lbs total volume.")
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
    }

    // MARK: - Timer Badge
    private var timerBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.green)
                .frame(width: 6, height: 6)
            Text(viewModel.formattedDuration)
                .font(.subheadline.monospacedDigit().bold())
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(.secondarySystemBackground))
        .clipShape(Capsule())
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "plus.circle.dashed")
                .font(.system(size: 56))
                .foregroundStyle(.orange.opacity(0.8))
            Text("Add Your First Exercise")
                .font(.title3.bold())
            Text("Tap below to browse and add\nexercises to your workout.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    // MARK: - Exercise List
    private var exerciseList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.workoutExercises) { entry in
                    ExerciseLogCard(entry: entry, viewModel: viewModel)
                }
            }
            .padding()
            .padding(.bottom, 80)
        }
    }

    // MARK: - Add Exercise Button
    private var addExerciseButton: some View {
        Button {
            showingExercisePicker = true
        } label: {
            Label("Add Exercise", systemImage: "plus")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Actions
    private func finishWorkout() {
        let session = viewModel.finishWorkout(context: modelContext)
        finishedSession = session
    }
}

// MARK: - Exercise Log Card
struct ExerciseLogCard: View {
    let entry: WorkoutExerciseEntry
    @Bindable var viewModel: WorkoutViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.exerciseName)
                        .font(.headline)
                    HStack(spacing: 4) {
                        Text(entry.exerciseCategory)
                        Text("·")
                        Text(entry.primaryMuscles.joined(separator: ", "))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if entry.totalVolume > 0 {
                    Text(String(format: "%.0f lbs", entry.totalVolume))
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
            }
            .padding(14)

            Divider().padding(.horizontal, 14)

            // Sets header
            HStack {
                Text("SET").frame(width: 36, alignment: .leading)
                Text("LBS").frame(maxWidth: .infinity)
                Text("REPS").frame(maxWidth: .infinity)
                Text("").frame(width: 44)
            }
            .font(.caption2.bold())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            // Sets
            ForEach(entry.sets) { set in
                SetRow(
                    set: set,
                    onToggle: {
                        viewModel.toggleSetCompleted(in: entry, setID: set.id)
                    },
                    onUpdate: { reps, weight in
                        viewModel.updateSet(in: entry, setID: set.id, reps: reps, weight: weight)
                    }
                )
            }

            // Add Set Button
            Button {
                viewModel.addSet(to: entry)
            } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .padding(.top, 4)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Set Row
struct SetRow: View {
    let set: SetEntry
    let onToggle: () -> Void
    let onUpdate: (Int, Double) -> Void

    @State private var repsText: String
    @State private var weightText: String

    init(set: SetEntry, onToggle: @escaping () -> Void, onUpdate: @escaping (Int, Double) -> Void) {
        self.set = set
        self.onToggle = onToggle
        self.onUpdate = onUpdate
        _repsText = State(initialValue: set.reps > 0 ? "\(set.reps)" : "")
        _weightText = State(initialValue: set.weight > 0 ? String(format: "%.1f", set.weight) : "")
    }

    var body: some View {
        HStack {
            // Set number
            Text("\(set.setNumber)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)

            // Weight
            TextField("0", text: $weightText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.subheadline.monospacedDigit())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onChange(of: weightText) { _, new in
                    if let w = Double(new) { onUpdate(Int(repsText) ?? set.reps, w) }
                }

            // Reps
            TextField("0", text: $repsText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.subheadline.monospacedDigit())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onChange(of: repsText) { _, new in
                    if let r = Int(new) { onUpdate(r, Double(weightText) ?? set.weight) }
                }

            // Complete button
            Button(action: onToggle) {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(set.isCompleted ? .green : .secondary)
            }
            .frame(width: 44)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(set.isCompleted ? Color.green.opacity(0.08) : Color.clear)
        .animation(.easeInOut(duration: 0.15), value: set.isCompleted)
    }
}
