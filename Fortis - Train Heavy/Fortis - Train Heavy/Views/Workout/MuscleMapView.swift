import SwiftUI
import MuscleMap

struct MuscleMapView: View {
    let primaryMuscles: [String]
    let secondaryMuscles: [String]

    var body: some View {
        HStack(spacing: 20) {
            BodyView(gender: .male, side: .front)
                .bodyStyle(.minimal)
                .applyHighlights()
                .frame(maxWidth: .infinity)

            BodyView(gender: .male, side: .back)
                .bodyStyle(.minimal)
                .applyHighlights()
                .frame(maxWidth: .infinity)
        }
        .frame(height: 320)
        .padding(16)
        .background(Color.romanSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.romanBorder, lineWidth: 0.5))
        .padding(.horizontal)
    }

    private func applyHighlights() -> some ViewModifier {
        return Modifier(primary: primaryMuscles, secondary: secondaryMuscles)
    }

    struct Modifier: ViewModifier {
        let primary: [String]
        let secondary: [String]

        func body(content: Content) -> some View {
            var view = content
            for muscle in primary.compactMap({ mapToMuscle($0) }) {
                view = view.highlight(muscle, color: Color.blue.opacity(0.85))
            }
            for muscle in secondary.compactMap({ mapToMuscle($0) }) {
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
}
