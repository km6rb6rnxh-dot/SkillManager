import SwiftUI

enum AppAppearance: String, CaseIterable {
    case system
    case light
    case dark

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AppTheme {
    // MARK: - Accent Colors (same in both modes, designed for contrast)

    static let skillBlue      = Color(red: 0.25, green: 0.55, blue: 0.95)
    static let skillBlueSoft  = Color(red: 0.25, green: 0.55, blue: 0.95).opacity(0.12)
    static let coworkPurple     = Color(red: 0.58, green: 0.35, blue: 0.92)
    static let coworkPurpleSoft = Color(red: 0.58, green: 0.35, blue: 0.92).opacity(0.12)
    static let resourceAmber     = Color(red: 0.85, green: 0.55, blue: 0.10)
    static let resourceAmberSoft = Color(red: 0.85, green: 0.55, blue: 0.10).opacity(0.12)
    static let successGreen     = Color(red: 0.20, green: 0.72, blue: 0.45)
    static let successGreenSoft = Color(red: 0.20, green: 0.72, blue: 0.45).opacity(0.10)
    static let warningOrange     = Color.orange
    static let warningOrangeSoft = Color.orange.opacity(0.10)
    static let starYellow = Color(red: 0.95, green: 0.72, blue: 0.15)
}
