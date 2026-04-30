import SwiftUI
import MuscleMap

struct MuscleMapView: View {
    let primaryMuscles: [String]
    let secondaryMuscles: [String]

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
        var view = BodyView(gender: .male, side: side).bodyStyle(.minimal)
        for muscle in primaryMuscles.compactMap({ mapToMuscle($0) }) {
            view = view.highlight(muscle, color: Color.blue.opacity(0.85))
        }
        for muscle in secondaryMuscles.compactMap({ mapToMuscle($0) }) {
            view = view.highlight(muscle, color: Color.blue.opacity(0.45))
        }
        return view
    }
}
