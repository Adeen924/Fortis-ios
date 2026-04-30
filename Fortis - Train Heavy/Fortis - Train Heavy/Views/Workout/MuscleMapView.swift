import SwiftUI

enum BodySide { case front, back }

struct MuscleMapView: View {
    let primaryMuscles: [String]
    let secondaryMuscles: [String]

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 28) {
                diagramPanel(.front)
                diagramPanel(.back)
            }
            HStack(spacing: 20) {
                legendItem(color: Color.blue.opacity(0.8),   label: "Primary")
                legendItem(color: Color.blue.opacity(0.4), label: "Secondary")
            }
        }
        .padding(16)
        .background(Color.romanSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.romanBorder, lineWidth: 0.5))
        .padding(.horizontal)
    }

    private func diagramPanel(_ side: BodySide) -> some View {
        VStack(spacing: 6) {
            Text(side == .front ? "FRONT" : "BACK")
                .font(.system(size: 8, weight: .bold))
                .tracking(2)
                .foregroundStyle(Color.romanParchmentDim)
            Canvas { ctx, size in
                self.drawSilhouette(ctx: &ctx, w: size.width, h: size.height)
                self.drawMuscles(ctx: &ctx, w: size.width, h: size.height, side: side)
            }
            .frame(width: 100, height: 200)
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption2).foregroundStyle(Color.romanParchmentDim)
        }
    }

    // MARK: - Silhouette

    private func drawSilhouette(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        let sf = Color.romanSurfaceHigh
        let sb = Color.romanBorder
        let sw: CGFloat = 0.5

        // Head
        do { let r = CGRect(x: w*0.35, y: h*0.005, width: w*0.30, height: h*0.115)
             let p = Path(ellipseIn: r); ctx.fill(p, with: .color(sf)); ctx.stroke(p, with: .color(sb), lineWidth: sw) }
        // Neck
        do { let r = CGRect(x: w*0.42, y: h*0.115, width: w*0.16, height: h*0.045)
             let p = Path(roundedRect: r, cornerRadius: 3); ctx.fill(p, with: .color(sf)); ctx.stroke(p, with: .color(sb), lineWidth: sw) }
        // Torso
        do { let r = CGRect(x: w*0.24, y: h*0.155, width: w*0.52, height: h*0.265)
             let p = Path(roundedRect: r, cornerRadius: 10); ctx.fill(p, with: .color(sf)); ctx.stroke(p, with: .color(sb), lineWidth: sw) }
        // Hips
        do { let r = CGRect(x: w*0.25, y: h*0.415, width: w*0.50, height: h*0.08)
             let p = Path(roundedRect: r, cornerRadius: 8); ctx.fill(p, with: .color(sf)); ctx.stroke(p, with: .color(sb), lineWidth: sw) }
        // Left upper arm
        do { let r = CGRect(x: w*0.07, y: h*0.155, width: w*0.17, height: h*0.155)
             let p = Path(roundedRect: r, cornerRadius: 8); ctx.fill(p, with: .color(sf)); ctx.stroke(p, with: .color(sb), lineWidth: sw) }
        // Right upper arm
        do { let r = CGRect(x: w*0.76, y: h*0.155, width: w*0.17, height: h*0.155)
             let p = Path(roundedRect: r, cornerRadius: 8); ctx.fill(p, with: .color(sf)); ctx.stroke(p, with: .color(sb), lineWidth: sw) }
        // Left forearm
        do { let r = CGRect(x: w*0.08, y: h*0.310, width: w*0.15, height: h*0.135)
             let p = Path(roundedRect: r, cornerRadius: 7); ctx.fill(p, with: .color(sf)); ctx.stroke(p, with: .color(sb), lineWidth: sw) }
        // Right forearm
        do { let r = CGRect(x: w*0.77, y: h*0.310, width: w*0.15, height: h*0.135)
             let p = Path(roundedRect: r, cornerRadius: 7); ctx.fill(p, with: .color(sf)); ctx.stroke(p, with: .color(sb), lineWidth: sw) }
        // Left thigh
        do { let r = CGRect(x: w*0.25, y: h*0.490, width: w*0.23, height: h*0.245)
             let p = Path(roundedRect: r, cornerRadius: 9); ctx.fill(p, with: .color(sf)); ctx.stroke(p, with: .color(sb), lineWidth: sw) }
        // Right thigh
        do { let r = CGRect(x: w*0.52, y: h*0.490, width: w*0.23, height: h*0.245)
             let p = Path(roundedRect: r, cornerRadius: 9); ctx.fill(p, with: .color(sf)); ctx.stroke(p, with: .color(sb), lineWidth: sw) }
        // Left calf
        do { let r = CGRect(x: w*0.26, y: h*0.735, width: w*0.21, height: h*0.205)
             let p = Path(roundedRect: r, cornerRadius: 8); ctx.fill(p, with: .color(sf)); ctx.stroke(p, with: .color(sb), lineWidth: sw) }
        // Right calf
        do { let r = CGRect(x: w*0.53, y: h*0.735, width: w*0.21, height: h*0.205)
             let p = Path(roundedRect: r, cornerRadius: 8); ctx.fill(p, with: .color(sf)); ctx.stroke(p, with: .color(sb), lineWidth: sw) }
        // Left foot
        do { let r = CGRect(x: w*0.21, y: h*0.935, width: w*0.25, height: h*0.055)
             let p = Path(roundedRect: r, cornerRadius: 4); ctx.fill(p, with: .color(sf)); ctx.stroke(p, with: .color(sb), lineWidth: sw) }
        // Right foot
        do { let r = CGRect(x: w*0.54, y: h*0.935, width: w*0.25, height: h*0.055)
             let p = Path(roundedRect: r, cornerRadius: 4); ctx.fill(p, with: .color(sf)); ctx.stroke(p, with: .color(sb), lineWidth: sw) }
    }

    // MARK: - Muscle Overlays

    private func drawMuscles(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, side: BodySide) {
        if side == .front {
            drawHighlight(ctx: &ctx, muscle: "Chest",
                rects: [CGRect(x: w*0.29, y: h*0.18, width: w*0.42, height: h*0.09)])
            drawHighlight(ctx: &ctx, muscle: "Shoulders",
                rects: [CGRect(x: w*0.08, y: h*0.155, width: w*0.165, height: h*0.08),
                        CGRect(x: w*0.755, y: h*0.155, width: w*0.165, height: h*0.08)])
            drawHighlight(ctx: &ctx, muscle: "Biceps",
                rects: [CGRect(x: w*0.085, y: h*0.240, width: w*0.14, height: h*0.075),
                        CGRect(x: w*0.775, y: h*0.240, width: w*0.14, height: h*0.075)])
            drawHighlight(ctx: &ctx, muscle: "Forearms",
                rects: [CGRect(x: w*0.090, y: h*0.330, width: w*0.13, height: h*0.095),
                        CGRect(x: w*0.780, y: h*0.330, width: w*0.13, height: h*0.095)])
            drawHighlight(ctx: &ctx, muscle: "Core",
                rects: [CGRect(x: w*0.31, y: h*0.260, width: w*0.38, height: h*0.125)])
            drawHighlight(ctx: &ctx, muscle: "Abs",
                rects: [CGRect(x: w*0.31, y: h*0.260, width: w*0.38, height: h*0.125)])
            drawHighlight(ctx: &ctx, muscle: "Quads",
                rects: [CGRect(x: w*0.26, y: h*0.505, width: w*0.21, height: h*0.195),
                        CGRect(x: w*0.53, y: h*0.505, width: w*0.21, height: h*0.195)])
            drawHighlight(ctx: &ctx, muscle: "Legs",
                rects: [CGRect(x: w*0.26, y: h*0.505, width: w*0.21, height: h*0.195),
                        CGRect(x: w*0.53, y: h*0.505, width: w*0.21, height: h*0.195)])
            drawHighlight(ctx: &ctx, muscle: "Hip Flexors",
                rects: [CGRect(x: w*0.28, y: h*0.42, width: w*0.21, height: h*0.075),
                        CGRect(x: w*0.51, y: h*0.42, width: w*0.21, height: h*0.075)])
            drawHighlight(ctx: &ctx, muscle: "Calves",
                rects: [CGRect(x: w*0.27, y: h*0.750, width: w*0.19, height: h*0.155),
                        CGRect(x: w*0.54, y: h*0.750, width: w*0.19, height: h*0.155)])
        } else {
            drawHighlight(ctx: &ctx, muscle: "Traps",
                rects: [CGRect(x: w*0.26, y: h*0.155, width: w*0.48, height: h*0.07)])
            drawHighlight(ctx: &ctx, muscle: "Back",
                rects: [CGRect(x: w*0.25, y: h*0.220, width: w*0.22, height: h*0.150),
                        CGRect(x: w*0.53, y: h*0.220, width: w*0.22, height: h*0.150)])
            drawHighlight(ctx: &ctx, muscle: "Lats",
                rects: [CGRect(x: w*0.25, y: h*0.220, width: w*0.22, height: h*0.150),
                        CGRect(x: w*0.53, y: h*0.220, width: w*0.22, height: h*0.150)])
            drawHighlight(ctx: &ctx, muscle: "Shoulders",
                rects: [CGRect(x: w*0.08, y: h*0.155, width: w*0.165, height: h*0.065),
                        CGRect(x: w*0.755, y: h*0.155, width: w*0.165, height: h*0.065)])
            drawHighlight(ctx: &ctx, muscle: "Triceps",
                rects: [CGRect(x: w*0.085, y: h*0.205, width: w*0.14, height: h*0.090),
                        CGRect(x: w*0.775, y: h*0.205, width: w*0.14, height: h*0.090)])
            drawHighlight(ctx: &ctx, muscle: "Forearms",
                rects: [CGRect(x: w*0.090, y: h*0.330, width: w*0.13, height: h*0.095),
                        CGRect(x: w*0.780, y: h*0.330, width: w*0.13, height: h*0.095)])
            drawHighlight(ctx: &ctx, muscle: "Lower Back",
                rects: [CGRect(x: w*0.30, y: h*0.360, width: w*0.40, height: h*0.055)])
            drawHighlight(ctx: &ctx, muscle: "Glutes",
                rects: [CGRect(x: w*0.26, y: h*0.420, width: w*0.23, height: h*0.075),
                        CGRect(x: w*0.51, y: h*0.420, width: w*0.23, height: h*0.075)])
            drawHighlight(ctx: &ctx, muscle: "Hamstrings",
                rects: [CGRect(x: w*0.26, y: h*0.505, width: w*0.21, height: h*0.185),
                        CGRect(x: w*0.53, y: h*0.505, width: w*0.21, height: h*0.185)])
            drawHighlight(ctx: &ctx, muscle: "Legs",
                rects: [CGRect(x: w*0.26, y: h*0.505, width: w*0.21, height: h*0.185),
                        CGRect(x: w*0.53, y: h*0.505, width: w*0.21, height: h*0.185)])
            drawHighlight(ctx: &ctx, muscle: "Calves",
                rects: [CGRect(x: w*0.27, y: h*0.750, width: w*0.19, height: h*0.155),
                        CGRect(x: w*0.54, y: h*0.750, width: w*0.19, height: h*0.155)])
        }
    }

    private func drawHighlight(ctx: inout GraphicsContext, muscle: String, rects: [CGRect]) {
        guard let c = highlightColor(for: muscle) else { return }
        for rect in rects {
            let path = Path(ellipseIn: rect)
            ctx.fill(path, with: .color(c.opacity(0.72)))
            ctx.stroke(path, with: .color(c.opacity(0.90)), lineWidth: 0.8)
        }
    }

    private func highlightColor(for muscle: String) -> Color? {
        let lo = muscle.lowercased()
        if primaryMuscles.contains(where: { token in
            let t = token.lowercased(); return t.contains(lo) || lo.contains(t)
        }) { return Color.blue.opacity(0.8) }
        if secondaryMuscles.contains(where: { token in
            let t = token.lowercased(); return t.contains(lo) || lo.contains(t)
        }) { return Color.blue.opacity(0.4) }
        return nil
    }
}
