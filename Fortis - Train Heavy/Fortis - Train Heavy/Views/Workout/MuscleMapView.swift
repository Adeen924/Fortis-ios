import SwiftUI

struct MuscleMapView: View {
    let primaryMuscles: [String]
    let secondaryMuscles: [String]

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Image("MuscleAnatomyChart")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)

                GeometryReader { geometry in
                    Canvas { ctx, size in
                        drawHighlights(ctx: &ctx, size: size)
                    }
                    .allowsHitTesting(false)
                }
            }
            .frame(height: 320)

            HStack(spacing: 20) {
                legendItem(color: Color.blue.opacity(0.85), label: "Primary")
                legendItem(color: Color.blue.opacity(0.45), label: "Secondary")
            }
        }
        .padding(16)
        .background(Color.romanSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.romanBorder, lineWidth: 0.5))
        .padding(.horizontal)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption2).foregroundStyle(Color.romanParchmentDim)
        }
    }

    private func drawHighlights(ctx: inout GraphicsContext, size: CGSize) {
        let muscleRects = highlightedMuscleRects(size: size)
        for (muscle, rects) in muscleRects {
            guard let color = highlightColor(for: muscle) else { continue }
            rects.forEach { rect in
                let path = Path(ellipseIn: rect)
                ctx.fill(path, with: .color(color.opacity(0.72)))
                ctx.stroke(path, with: .color(color.opacity(0.95)), lineWidth: 1)
            }
        }
    }

    private func highlightedMuscleRects(size: CGSize) -> [String: [CGRect]] {
        let w = size.width
        let h = size.height
        return [
            "Chest": [CGRect(x: w * 0.11, y: h * 0.20, width: w * 0.18, height: h * 0.10)],
            "Shoulders": [CGRect(x: w * 0.05, y: h * 0.14, width: w * 0.10, height: h * 0.07),
                          CGRect(x: w * 0.23, y: h * 0.14, width: w * 0.10, height: h * 0.07),
                          CGRect(x: w * 0.55, y: h * 0.14, width: w * 0.10, height: h * 0.07),
                          CGRect(x: w * 0.73, y: h * 0.14, width: w * 0.10, height: h * 0.07)],
            "Biceps": [CGRect(x: w * 0.05, y: h * 0.24, width: w * 0.09, height: h * 0.06),
                        CGRect(x: w * 0.23, y: h * 0.24, width: w * 0.09, height: h * 0.06)],
            "Triceps": [CGRect(x: w * 0.55, y: h * 0.20, width: w * 0.09, height: h * 0.07),
                         CGRect(x: w * 0.73, y: h * 0.20, width: w * 0.09, height: h * 0.07)],
            "Forearms": [CGRect(x: w * 0.05, y: h * 0.32, width: w * 0.08, height: h * 0.08),
                          CGRect(x: w * 0.23, y: h * 0.32, width: w * 0.08, height: h * 0.08),
                          CGRect(x: w * 0.55, y: h * 0.32, width: w * 0.08, height: h * 0.08),
                          CGRect(x: w * 0.73, y: h * 0.32, width: w * 0.08, height: h * 0.08)],
            "Core": [CGRect(x: w * 0.13, y: h * 0.30, width: w * 0.16, height: h * 0.12)],
            "Abs": [CGRect(x: w * 0.13, y: h * 0.30, width: w * 0.16, height: h * 0.12)],
            "Quads": [CGRect(x: w * 0.10, y: h * 0.52, width: w * 0.12, height: h * 0.18),
                       CGRect(x: w * 0.26, y: h * 0.52, width: w * 0.12, height: h * 0.18)],
            "Glutes": [CGRect(x: w * 0.56, y: h * 0.42, width: w * 0.12, height: h * 0.08),
                        CGRect(x: w * 0.74, y: h * 0.42, width: w * 0.12, height: h * 0.08)],
            "Hamstrings": [CGRect(x: w * 0.56, y: h * 0.52, width: w * 0.11, height: h * 0.18),
                            CGRect(x: w * 0.74, y: h * 0.52, width: w * 0.11, height: h * 0.18)],
            "Calves": [CGRect(x: w * 0.11, y: h * 0.76, width: w * 0.08, height: h * 0.16),
                        CGRect(x: w * 0.27, y: h * 0.76, width: w * 0.08, height: h * 0.16),
                        CGRect(x: w * 0.56, y: h * 0.76, width: w * 0.08, height: h * 0.16),
                        CGRect(x: w * 0.74, y: h * 0.76, width: w * 0.08, height: h * 0.16)],
            "Back": [CGRect(x: w * 0.56, y: h * 0.24, width: w * 0.16, height: h * 0.16)],
            "Lats": [CGRect(x: w * 0.56, y: h * 0.24, width: w * 0.16, height: h * 0.16)],
            "Lower Back": [CGRect(x: w * 0.60, y: h * 0.36, width: w * 0.14, height: h * 0.06)],
            "Traps": [CGRect(x: w * 0.56, y: h * 0.12, width: w * 0.18, height: h * 0.06)]
        ]
    }

    private func highlightColor(for muscle: String) -> Color? {
        let normalized = muscle.lowercased()
        if primaryMuscles.contains(where: { token in
            let candidate = token.lowercased()
            return candidate.contains(normalized) || normalized.contains(candidate)
        }) {
            return Color.blue.opacity(0.85)
        }
        if secondaryMuscles.contains(where: { token in
            let candidate = token.lowercased()
            return candidate.contains(normalized) || normalized.contains(candidate)
        }) {
            return Color.blue.opacity(0.45)
        }
        return nil
    }
}
