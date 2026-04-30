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

// MARK: - Roman Color Palette
extension Color {
    // Backgrounds — deepest obsidian to elevated stone
    static let romanBackground   = Color(red: 0.055, green: 0.051, blue: 0.047)  // #0E0D0C
    static let romanSurface      = Color(red: 0.114, green: 0.106, blue: 0.098)  // #1D1B19
    static let romanSurfaceHigh  = Color(red: 0.176, green: 0.165, blue: 0.153)  // #2D2A27
    static let romanBorder       = Color(red: 0.275, green: 0.255, blue: 0.224)  // #464139

    // Accents — Roman gold, battle crimson, aged bronze
    static let romanGold         = Color(red: 0.800, green: 0.667, blue: 0.271)  // #CCAA45
    static let romanGoldDim      = Color(red: 0.502, green: 0.420, blue: 0.165)  // #806B2A
    static let romanCrimson      = Color(red: 0.600, green: 0.110, blue: 0.110)  // #991C1C
    static let romanBronze       = Color(red: 0.569, green: 0.431, blue: 0.196)  // #916E32

    // Text — warm parchment tones
    static let romanParchment    = Color(red: 0.941, green: 0.914, blue: 0.847)  // #F0E9D8
    static let romanParchmentDim = Color(red: 0.502, green: 0.478, blue: 0.424)  // #807A6C
}

// MARK: - ShapeStyle extensions (makes .romanGold etc work in foregroundStyle / fill)
extension ShapeStyle where Self == Color {
    static var romanBackground:   Color { Color(red: 0.055, green: 0.051, blue: 0.047) }
    static var romanSurface:      Color { Color(red: 0.114, green: 0.106, blue: 0.098) }
    static var romanSurfaceHigh:  Color { Color(red: 0.176, green: 0.165, blue: 0.153) }
    static var romanBorder:       Color { Color(red: 0.275, green: 0.255, blue: 0.224) }
    static var romanGold:         Color { Color(red: 0.800, green: 0.667, blue: 0.271) }
    static var romanGoldDim:      Color { Color(red: 0.502, green: 0.420, blue: 0.165) }
    static var romanCrimson:      Color { Color(red: 0.600, green: 0.110, blue: 0.110) }
    static var romanBronze:       Color { Color(red: 0.569, green: 0.431, blue: 0.196) }
    static var romanParchment:    Color { Color(red: 0.941, green: 0.914, blue: 0.847) }
    static var romanParchmentDim: Color { Color(red: 0.502, green: 0.478, blue: 0.424) }
}

// MARK: - Gradient helpers
extension LinearGradient {
    static let romanGoldGradient = LinearGradient(
        colors: [Color(red: 0.878, green: 0.761, blue: 0.380), .romanGold, .romanGoldDim],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let romanDarkGradient = LinearGradient(
        colors: [.romanBackground, Color(red: 0.082, green: 0.075, blue: 0.067)],
        startPoint: .top,
        endPoint: .bottom
    )
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

// MARK: - Roman Card Modifier
struct RomanCard: ViewModifier {
    var elevated: Bool = false
    func body(content: Content) -> some View {
        content
            .background(elevated ? Color.romanSurfaceHigh : Color.romanSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.romanBorder, lineWidth: 0.5)
            )
    }
}

extension View {
    func romanCard(elevated: Bool = false) -> some View {
        modifier(RomanCard(elevated: elevated))
    }
    func fortisCard() -> some View {
        modifier(RomanCard())
    }
}
