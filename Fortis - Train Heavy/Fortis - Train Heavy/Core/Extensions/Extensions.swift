import SwiftUI
import Foundation

// MARK: - Formatters
extension Double {
    var lbsFormatted: String {
        if self >= 1000 { return String(format: "%.1fk lbs", self / 1000) }
        return String(format: "%.1f lbs", self)
    }
}

extension TimeInterval {
    var durationFormatted: String {
        let d = Int(self)
        let h = d / 3600
        let m = (d % 3600) / 60
        let s = d % 60
        if h > 0 { return String(format: "%dh %dm", h, m) }
        if m > 0 { return String(format: "%dm %ds", m, s) }
        return "\(s)s"
    }
}

// MARK: - Color helpers
extension Color {
    static let fortisOrange = Color.orange
    static let fortisBackground = Color(.systemGroupedBackground)
    static let fortisCard = Color(.secondarySystemGroupedBackground)
}

// MARK: - Environment Keys
private struct ShowWorkoutKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var showWorkout: () -> Void {
        get { self[ShowWorkoutKey.self] }
        set { self[ShowWorkoutKey.self] = newValue }
    }
}

// MARK: - View Modifiers
struct FortisCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

extension View {
    func fortisCard() -> some View {
        modifier(FortisCard())
    }
}
