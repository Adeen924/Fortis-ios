import SwiftUI

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataStore: FirebaseDataStore
    let onSelect: (Exercise) -> Void

    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var selectedExercise: Exercise? = nil

    private let favoritesCategory = "Fav"

    private var categories: [String] {
        ["All", favoritesCategory] + Set(dataStore.exercises.map { $0.category }).sorted()
    }

    private var filteredExercises: [Exercise] {
        let baseExercises = selectedCategory == favoritesCategory
            ? favoriteExercises
            : dataStore.exercises

        return baseExercises.filter { ex in
            let matchSearch = searchText.isEmpty
                || ex.name.localizedCaseInsensitiveContains(searchText)
                || ex.primaryMuscles.joined().localizedCaseInsensitiveContains(searchText)
            let matchCat = selectedCategory == nil || selectedCategory == "All" || selectedCategory == favoritesCategory
                || ex.category == selectedCategory
            return matchSearch && matchCat
        }
    }

    private var favoriteExercises: [Exercise] {
        let usage = exerciseUsage()
        return dataStore.exercises
            .filter { exercise in
                usage[exercise.id.uuidString] != nil || usage[exercise.name.normalizedExerciseKey] != nil
            }
            .sorted { lhs, rhs in
                let lhsUsage = usage[lhs.id.uuidString] ?? usage[lhs.name.normalizedExerciseKey]
                let rhsUsage = usage[rhs.id.uuidString] ?? usage[rhs.name.normalizedExerciseKey]

                if lhsUsage?.lastUsed != rhsUsage?.lastUsed {
                    return (lhsUsage?.lastUsed ?? .distantPast) > (rhsUsage?.lastUsed ?? .distantPast)
                }

                if lhsUsage?.count != rhsUsage?.count {
                    return (lhsUsage?.count ?? 0) > (rhsUsage?.count ?? 0)
                }

                return lhs.name < rhs.name
            }
    }

    private func exerciseUsage() -> [String: ExerciseUsage] {
        var usage: [String: ExerciseUsage] = [:]

        for session in dataStore.workouts {
            let usedAt = session.endDate ?? session.startDate
            for workoutExercise in session.workoutExercises where workoutExercise.sets.contains(where: { $0.isCompleted }) {
                let keys = [
                    workoutExercise.exerciseID.uuidString,
                    workoutExercise.exerciseName.normalizedExerciseKey
                ]

                for key in keys {
                    var current = usage[key] ?? ExerciseUsage(count: 0, lastUsed: .distantPast)
                    current.count += 1
                    current.lastUsed = max(current.lastUsed, usedAt)
                    usage[key] = current
                }
            }
        }

        return usage
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
                            Image(systemName: dataStore.lastError == nil ? "dumbbell" : "exclamationmark.triangle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.romanGoldDim)
                            Text(emptyStateTitle)
                                .foregroundStyle(.romanParchmentDim)
                            if let message = dataStore.lastError {
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.romanCrimson)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
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

    private var emptyStateTitle: String {
        if dataStore.lastError != nil { return "Unable to load exercises" }
        if selectedCategory == favoritesCategory { return "No completed exercises yet" }
        if searchText.isEmpty && selectedCategory == nil {
            return dataStore.hasLoadedExercises ? "No exercises in catalog" : "Loading exercise catalog"
        }
        return "No exercises found"
    }
}

private struct ExerciseUsage {
    var count: Int
    var lastUsed: Date
}

private extension String {
    var normalizedExerciseKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.romanParchmentDim)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onConfirm) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add to Workout")
                        }
                    }
                    .foregroundStyle(.romanGold)
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
