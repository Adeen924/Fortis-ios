import Foundation
import Combine

enum WeightUnit: String, CaseIterable, Identifiable {
    case lbs
    case kg

    var id: Self { self }
    var displayName: String {
        switch self {
        case .lbs: return "Pounds (lbs)"
        case .kg:  return "Kilograms (kg)"
        }
    }

    var symbol: String {
        switch self {
        case .lbs: return "lbs"
        case .kg:  return "kg"
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let weightUnitKey = "fortis_weight_unit"

    @Published var weightUnit: WeightUnit {
        didSet {
            UserDefaults.standard.set(weightUnit.rawValue, forKey: weightUnitKey)
        }
    }

    private init() {
        if let rawValue = UserDefaults.standard.string(forKey: weightUnitKey), let unit = WeightUnit(rawValue: rawValue) {
            weightUnit = unit
        } else {
            weightUnit = .lbs
        }
    }
}

extension Double {
    func formattedWeight(unit: WeightUnit, abbreviateThousands: Bool = true) -> String {
        let value = unit == .kg ? self * 0.45359237 : self
        if abbreviateThousands && abs(value) >= 1000 {
            return String(format: "%.1fk %@", value / 1000, unit.symbol)
        }
        return String(format: "%.1f %@", value, unit.symbol)
    }

    func storedWeight(from value: Double, unit: WeightUnit) -> Double {
        unit == .kg ? value / 0.45359237 : value
    }
}
