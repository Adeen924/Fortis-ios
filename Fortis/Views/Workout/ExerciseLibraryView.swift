import SwiftUI
import SwiftData

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    let onSelect: (Exercise) -> Void

    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var selectedExercise: Exercise? = nil

    private var categories: [String] {
        let cats = Set(allExercises.map { $0.category })
        return ["All"] + cats.sorted()
    }

    private var filteredExercises: [Exercise] {
        allExercises.filter { exercise in
            let matchesSearch = searchText.isEmpty ||
                exercise.name.localizedCaseInsensitiveContains(searchText) ||
                exercise.primaryMuscles.joined().localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == nil || selectedCategory == "All" ||
                exercise.category == selectedCategory
            return matchesSearch && matchesCategory
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { cat in
                            CategoryChip(
                                title: cat,
                                isSelected: (cat == "All" && selectedCategory == nil) || selectedCategory == cat
                            ) {
                                selectedCategory = cat == "All" ? nil : cat
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                Divider()

                // Exercise list
                if filteredExercises.isEmpty {
                    ContentUnavailableView("No Exercises Found", systemImage: "magnifyingglass",
                                          description: Text("Try a different search or category."))
                } else {
                    List(filteredExercises) { exercise in
                        ExercisePickerRow(exercise: exercise) {
                            selectedExercise = exercise
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search exercises or muscles")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $selectedExercise) { exercise in
                ExerciseDetailConfirmView(exercise: exercise) {
                    onSelect(exercise)
                    selectedExercise = nil
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Category Chip
struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.orange : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Exercise Picker Row
struct ExercisePickerRow: View {
    let exercise: Exercise
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Category icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(categoryColor(exercise.category).opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: categoryIcon(exercise.category))
                        .font(.system(size: 18))
                        .foregroundStyle(categoryColor(exercise.category))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    HStack(spacing: 4) {
                        Text(exercise.equipmentType)
                        Text("·")
                        Text(exercise.primaryMuscles.joined(separator: ", "))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    func categoryColor(_ cat: String) -> Color {
        switch cat {
        case "Chest":     return .red
        case "Back":      return .blue
        case "Shoulders": return .purple
        case "Biceps":    return .orange
        case "Triceps":   return .yellow
        case "Legs":      return .green
        case "Glutes":    return .pink
        case "Core":      return .teal
        default:          return .gray
        }
    }

    func categoryIcon(_ cat: String) -> String {
        switch cat {
        case "Chest":     return "heart.fill"
        case "Back":      return "arrow.up.and.down"
        case "Shoulders": return "arrow.left.and.right"
        case "Biceps":    return "hand.raised.fill"
        case "Triceps":   return "hand.raised.fingers.spread"
        case "Legs":      return "figure.walk"
        case "Glutes":    return "figure.run"
        case "Core":      return "circle.grid.cross"
        default:          return "dumbbell"
        }
    }
}

// MARK: - Exercise Detail Confirm (muscle diagram confirmation)
struct ExerciseDetailConfirmView: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Muscle diagram placeholder (Phase 2 will have real SVG)
                    MuscleHighlightView(primaryMuscles: exercise.primaryMuscles,
                                       secondaryMuscles: exercise.secondaryMuscles)

                    // Info
                    VStack(alignment: .leading, spacing: 16) {
                        infoRow(label: "Category", value: exercise.category)
                        infoRow(label: "Equipment", value: exercise.equipmentType)
                        infoRow(label: "Primary Muscles", value: exercise.primaryMuscles.joined(separator: ", "))
                        if !exercise.secondaryMuscles.isEmpty {
                            infoRow(label: "Secondary Muscles", value: exercise.secondaryMuscles.joined(separator: ", "))
                        }
                        if !exercise.instructions.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Instructions")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                Text(exercise.instructions)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)

                    // Add to Workout button
                    Button(action: onConfirm) {
                        Label("Add to Workout", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.subheadline)
        }
    }
}

// MARK: - Muscle Highlight View (schematic, Phase 2 replaces with real diagram)
struct MuscleHighlightView: View {
    let primaryMuscles: [String]
    let secondaryMuscles: [String]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .frame(height: 200)
                .padding(.horizontal)

            VStack(spacing: 12) {
                Image(systemName: "figure.stand")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary.opacity(0.4))

                VStack(spacing: 4) {
                    if !primaryMuscles.isEmpty {
                        Label(primaryMuscles.joined(separator: ", "), systemImage: "circle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                    }
                    if !secondaryMuscles.isEmpty {
                        Label(secondaryMuscles.joined(separator: ", "), systemImage: "circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
