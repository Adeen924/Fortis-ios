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
        // ── Base muscles ──────────────────────────────────────────
        case "abs":                             return .abs
        case "biceps":                          return .biceps
        case "calves":                          return .calves
        case "chest":                           return .chest
        case "deltoids", "shoulders":           return .deltoids
        case "feet":                            return .feet
        case "forearm", "forearms":             return .forearm
        case "gluteal", "glutes":               return .gluteal
        case "hamstring", "hamstrings":         return .hamstring
        case "hands":                           return .hands
        case "head":                            return .head
        case "knees":                           return .knees
        case "lower back":                      return .lowerBack
        case "obliques":                        return .obliques
        case "quadriceps", "quads":             return .quadriceps
        case "rhomboids":                       return .rhomboids
        case "rotator cuff":                    return .rotatorCuff
        case "serratus":                        return .serratus
        case "tibialis":                        return .tibialis
        case "trapezius", "traps":              return .trapezius
        case "triceps":                         return .triceps
        case "upper back", "back", "lats":      return .upperBack
        // ── Sub-groups ────────────────────────────────────────────
        case "upper chest":                     return .upperChest
        case "lower chest":                     return .lowerChest
        case "upper abs":                       return .upperAbs
        case "lower abs":                       return .lowerAbs
        case "inner quad":                      return .innerQuad
        case "outer quad":                      return .outerQuad
        case "hip flexors":                     return .hipFlexors
        case "front deltoid":                   return .frontDeltoid
        case "rear deltoid":                    return .rearDeltoid
        case "upper trapezius":                 return .upperTrapezius
        case "lower trapezius":                 return .lowerTrapezius
        case "ankles":                          return .ankles
        case "adductors":                       return .adductors
        case "neck":                            return .neck
        default:                                return nil
        }
    }
}
