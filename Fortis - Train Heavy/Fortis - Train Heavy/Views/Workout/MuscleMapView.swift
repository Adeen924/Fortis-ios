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
        let musclePaths = highlightedMusclePaths(size: size)
        for (muscle, paths) in musclePaths {
            guard let color = highlightColor(for: muscle) else { continue }
            paths.forEach { path in
                ctx.fill(path, with: .color(color.opacity(0.72)))
                ctx.stroke(path, with: .color(color.opacity(0.95)), lineWidth: 1)
            }
        }
    }

    private func highlightedMusclePaths(size: CGSize) -> [String: [Path]] {
        let w = size.width
        let h = size.height
        return [
            "Chest": [Path(roundedRect: CGRect(x: w * 0.12, y: h * 0.18, width: w * 0.12, height: h * 0.12), cornerRadius: 8),
                      Path(roundedRect: CGRect(x: w * 0.26, y: h * 0.18, width: w * 0.12, height: h * 0.12), cornerRadius: 8)],
            "Shoulders": [Path(ellipseIn: CGRect(x: w * 0.05, y: h * 0.17, width: w * 0.10, height: h * 0.10)),
                          Path(ellipseIn: CGRect(x: w * 0.35, y: h * 0.17, width: w * 0.10, height: h * 0.10)),
                          Path(ellipseIn: CGRect(x: w * 0.55, y: h * 0.17, width: w * 0.10, height: h * 0.10)),
                          Path(ellipseIn: CGRect(x: w * 0.85, y: h * 0.17, width: w * 0.10, height: h * 0.10))],
            "Biceps": [Path(ellipseIn: CGRect(x: w * 0.10, y: h * 0.28, width: w * 0.08, height: h * 0.14)),
                       Path(ellipseIn: CGRect(x: w * 0.32, y: h * 0.28, width: w * 0.08, height: h * 0.14))],
            "Triceps": [Path(ellipseIn: CGRect(x: w * 0.58, y: h * 0.30, width: w * 0.06, height: h * 0.15)),
                        Path(ellipseIn: CGRect(x: w * 0.86, y: h * 0.30, width: w * 0.06, height: h * 0.15))],
            "Forearms": [Path(roundedRect: CGRect(x: w * 0.10, y: h * 0.42, width: w * 0.08, height: h * 0.16), cornerRadius: 4),
                         Path(roundedRect: CGRect(x: w * 0.32, y: h * 0.42, width: w * 0.08, height: h * 0.16), cornerRadius: 4),
                         Path(roundedRect: CGRect(x: w * 0.58, y: h * 0.42, width: w * 0.08, height: h * 0.16), cornerRadius: 4),
                         Path(roundedRect: CGRect(x: w * 0.86, y: h * 0.42, width: w * 0.08, height: h * 0.16), cornerRadius: 4)],
            "Core": [Path { p in
                p.move(to: CGPoint(x: w * 0.14, y: h * 0.30))
                p.addLine(to: CGPoint(x: w * 0.20, y: h * 0.30))
                p.addLine(to: CGPoint(x: w * 0.18, y: h * 0.55))
                p.addLine(to: CGPoint(x: w * 0.12, y: h * 0.50))
                p.closeSubpath()
            }, Path { p in
                p.move(to: CGPoint(x: w * 0.30, y: h * 0.30))
                p.addLine(to: CGPoint(x: w * 0.36, y: h * 0.30))
                p.addLine(to: CGPoint(x: w * 0.38, y: h * 0.50))
                p.addLine(to: CGPoint(x: w * 0.32, y: h * 0.55))
                p.closeSubpath()
            }],
            "Abs": [Path(roundedRect: CGRect(x: w * 0.20, y: h * 0.30, width: w * 0.10, height: h * 0.25), cornerRadius: 6)],
            "Quads": [Path(ellipseIn: CGRect(x: w * 0.16, y: h * 0.60, width: w * 0.08, height: h * 0.25)),
                      Path(ellipseIn: CGRect(x: w * 0.26, y: h * 0.60, width: w * 0.08, height: h * 0.25))],
            "Glutes": [Path(ellipseIn: CGRect(x: w * 0.62, y: h * 0.60, width: w * 0.10, height: h * 0.15)),
                       Path(ellipseIn: CGRect(x: w * 0.78, y: h * 0.60, width: w * 0.10, height: h * 0.15))],
            "Hamstrings": [Path(ellipseIn: CGRect(x: w * 0.64, y: h * 0.75, width: w * 0.08, height: h * 0.20)),
                           Path(ellipseIn: CGRect(x: w * 0.78, y: h * 0.75, width: w * 0.08, height: h * 0.20))],
            "Calves": [Path(ellipseIn: CGRect(x: w * 0.64, y: h * 0.85, width: w * 0.08, height: h * 0.15)),
                       Path(ellipseIn: CGRect(x: w * 0.78, y: h * 0.85, width: w * 0.08, height: h * 0.15)),
                       Path(ellipseIn: CGRect(x: w * 0.18, y: h * 0.85, width: w * 0.04, height: h * 0.15)),
                       Path(ellipseIn: CGRect(x: w * 0.28, y: h * 0.85, width: w * 0.04, height: h * 0.15))],
            "Back": [Path { p in
                p.move(to: CGPoint(x: w * 0.55, y: h * 0.30))
                p.addLine(to: CGPoint(x: w * 0.70, y: h * 0.30))
                p.addLine(to: CGPoint(x: w * 0.75, y: h * 0.55))
                p.addLine(to: CGPoint(x: w * 0.60, y: h * 0.60))
                p.closeSubpath()
            }, Path { p in
                p.move(to: CGPoint(x: w * 0.75, y: h * 0.30))
                p.addLine(to: CGPoint(x: w * 0.90, y: h * 0.30))
                p.addLine(to: CGPoint(x: w * 0.85, y: h * 0.60))
                p.addLine(to: CGPoint(x: w * 0.70, y: h * 0.55))
                p.closeSubpath()
            }],
            "Lats": [Path { p in
                p.move(to: CGPoint(x: w * 0.55, y: h * 0.30))
                p.addLine(to: CGPoint(x: w * 0.70, y: h * 0.30))
                p.addLine(to: CGPoint(x: w * 0.75, y: h * 0.55))
                p.addLine(to: CGPoint(x: w * 0.60, y: h * 0.60))
                p.closeSubpath()
            }, Path { p in
                p.move(to: CGPoint(x: w * 0.75, y: h * 0.30))
                p.addLine(to: CGPoint(x: w * 0.90, y: h * 0.30))
                p.addLine(to: CGPoint(x: w * 0.85, y: h * 0.60))
                p.addLine(to: CGPoint(x: w * 0.70, y: h * 0.55))
                p.closeSubpath()
            }],
            "Lower Back": [Path(roundedRect: CGRect(x: w * 0.72, y: h * 0.30, width: w * 0.06, height: h * 0.35), cornerRadius: 3)],
            "Traps": [Path { p in
                p.move(to: CGPoint(x: w * 0.60, y: h * 0.10))
                p.addLine(to: CGPoint(x: w * 0.75, y: h * 0.10))
                p.addLine(to: CGPoint(x: w * 0.85, y: h * 0.30))
                p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.30))
                p.closeSubpath()
            }]
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
