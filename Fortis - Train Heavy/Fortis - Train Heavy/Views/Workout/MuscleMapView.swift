import SwiftUI
import MuscleMap

struct MuscleMapView: View {
    let primaryMuscles: [String]
    let secondaryMuscles: [String]

    @EnvironmentObject private var dataStore: FirebaseDataStore

    private var userGender: BodyGender {
        (dataStore.profile?.gender ?? "male") == "female" ? .female : .male
    }

    var body: some View {
        HStack(spacing: 20) {
            highlightedBodyView(side: .front)
                .frame(maxWidth: .infinity)

            highlightedBodyView(side: .back)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 320)
        .padding(16)
        .background(Color.romanSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.romanBorder, lineWidth: 0.5))
        .padding(.horizontal)
    }

    private func highlightedBodyView(side: BodySide) -> some View {
        var view = BodyView(gender: userGender, side: side).bodyStyle(.minimal)
        for muscle in primaryMuscles.compactMap({ mapToMuscle($0) }) {
            view = view.highlight(muscle, color: Color.blue.opacity(0.85))
        }
        for muscle in secondaryMuscles.compactMap({ mapToMuscle($0) }) {
            view = view.highlight(muscle, color: Color.blue.opacity(0.45))
        }
        return view
    }

    private func mapToMuscle(_ name: String) -> Muscle? {
        switch name.lowercased() {
        case "chest": return .chest
        case "shoulders": return .deltoids
        case "biceps": return .biceps
        case "triceps": return .triceps
        case "forearms": return .forearm
        case "core": return .obliques
        case "abs": return .abs
        case "quads": return .quadriceps
        case "glutes": return .gluteal
        case "hamstrings": return .hamstring
        case "calves": return .calves
        case "back": return .upperBack
        case "lats": return .upperBack
        case "lower back": return .lowerBack
        case "traps": return .trapezius
        default: return nil
        }
    }
}
