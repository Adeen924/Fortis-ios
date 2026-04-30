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
        ["All"] + Set(allExercises.map { $0.category }).sorted()
    }

    private var filteredExercises: [Exercise] {
        allExercises.filter { ex in
            let matchSearch = searchText.isEmpty
                || ex.name.localizedCaseInsensitiveContains(searchText)
                || ex.primaryMuscles.joined().localizedCaseInsensitiveContains(searchText)
            let matchCat = selectedCategory == nil || selectedCategory == "All"
                || ex.category == selectedCategory
            return matchSearch && matchCat
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.romanBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Category chips
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
                        .padding(.vertical, 10)
                    }

                    Rectangle().fill(Color.romanBorder).frame(height: 0.5)

                    if filteredExercises.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 36))
                                .foregroundStyle(.romanGoldDim)
                            Text("No exercises found")
                                .foregroundStyle(.romanParchmentDim)
                            Spacer()
                        }
                    } else {
                        List(filteredExercises) { exercise in
                            ExercisePickerRow(exercise: exercise) {
                                selectedExercise = exercise
                            }
                            .listRowBackground(Color.romanSurface)
                            .listRowSeparatorTint(Color.romanBorder)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("ADD EXERCISE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search exercises or muscles")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.romanParchmentDim)
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
        .preferredColorScheme(.dark)
    }
}

// MARK: - Category Chip
struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.romanGold : Color.romanSurface)
                .foregroundStyle(isSelected ? Color.romanBackground : Color.romanParchmentDim)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.clear : Color.romanBorder, lineWidth: 0.5))
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
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(categoryColor(exercise.category).opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: categoryIcon(exercise.category))
                        .font(.system(size: 18))
                        .foregroundStyle(categoryColor(exercise.category))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.romanParchment)
                    HStack(spacing: 4) {
                        Text(exercise.equipmentType)
                        Text("·")
                        Text(exercise.primaryMuscles.joined(separator: ", "))
                    }
                    .font(.caption)
                    .foregroundStyle(.romanParchmentDim)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.romanBorder)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    func categoryColor(_ cat: String) -> Color {
        switch cat {
        case "Chest":     return .romanCrimson
        case "Back":      return Color(red: 0.3, green: 0.5, blue: 0.9)
        case "Shoulders": return Color(red: 0.6, green: 0.3, blue: 0.8)
        case "Biceps":    return .romanGold
        case "Triceps":   return .romanBronze
        case "Legs":      return Color(red: 0.3, green: 0.7, blue: 0.4)
        case "Glutes":    return Color(red: 0.9, green: 0.4, blue: 0.6)
        case "Core":      return Color(red: 0.2, green: 0.7, blue: 0.7)
        default:          return .romanParchmentDim
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

// MARK: - Exercise Detail Confirm
struct ExerciseDetailConfirmView: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.romanBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        MuscleMapView(
                            primaryMuscles: exercise.primaryMuscles,
                            secondaryMuscles: exercise.secondaryMuscles
                        )

                        VStack(alignment: .leading, spacing: 14) {
                            infoRow(label: "CATEGORY",         value: exercise.category)
                            infoRow(label: "EQUIPMENT",        value: exercise.equipmentType)
                            infoRow(label: "PRIMARY MUSCLES",  value: exercise.primaryMuscles.joined(separator: ", "))
                            if !exercise.secondaryMuscles.isEmpty {
                                infoRow(label: "SECONDARY MUSCLES", value: exercise.secondaryMuscles.joined(separator: ", "))
                            }
                            if !exercise.instructions.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("INSTRUCTIONS")
                                        .font(.system(size: 9, weight: .bold))
                                        .tracking(2)
                                        .foregroundStyle(.romanParchmentDim)
                                    Text(exercise.instructions)
                                        .font(.subheadline)
                                        .foregroundStyle(.romanParchment)
                                }
                            }
                        }
                        .padding(16)
                        .romanCard()
                        .padding(.horizontal)

                        Button(action: onConfirm) {
                            Label("Add to Workout", systemImage: "plus.circle.fill")
                                .font(.system(size: 14, weight: .black))
                                .tracking(1)
                                .foregroundStyle(.romanBackground)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(LinearGradient.romanGoldGradient)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.romanParchmentDim)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(2)
                .foregroundStyle(.romanParchmentDim)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.romanParchment)
        }
    }
}

// MARK: - Muscle Highlight View
struct MuscleHighlightView: View {
    let primaryMuscles: [String]
    let secondaryMuscles: [String]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.romanSurface)
                .frame(height: 180)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.romanBorder, lineWidth: 0.5))
                .padding(.horizontal)

            VStack(spacing: 10) {
                Image(systemName: "figure.stand")
                    .font(.system(size: 56))
                    .foregroundStyle(.romanSurfaceHigh)

                VStack(spacing: 4) {
                    if !primaryMuscles.isEmpty {
                        Label(primaryMuscles.joined(separator: ", "), systemImage: "circle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.romanGold)
                    }
                    if !secondaryMuscles.isEmpty {
                        Label(secondaryMuscles.joined(separator: ", "), systemImage: "circle")
                            .font(.caption)
                            .foregroundStyle(.romanParchmentDim)
                    }
                }
            }
        }
    }
}
