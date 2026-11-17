import SwiftUI

public enum AppColors {
    // Fondos Midnight & Obsidian
    public static let slateBlack = Color(hex: "#070B14")
    public static let midnightBlack = Color(hex: "#0B132B")
    public static let darkNavySurface = Color(hex: "#111D38")
    public static let navySurfaceVariant = Color(hex: "#18284A")
    public static let cardBorderNavy = Color(hex: "#223A6B")
    public static let cardBackgroundGlass = Color(hex: "#0F1A30")
    
    // Ingresos y Gastos
    public static let incomeEmerald = Color(hex: "#10B981")
    public static let incomeEmeraldLight = Color(hex: "#34D399")
    public static let incomeBg = Color(hex: "#064E3B")
    public static let incomeChipBg = Color(hex: "#062D24")
    
    public static let expenseRose = Color(hex: "#F43F5E")
    public static let expenseRoseLight = Color(hex: "#FB7185")
    public static let expenseBg = Color(hex: "#4C0519")
    public static let expenseChipBg = Color(hex: "#2E0915")
    
    // Textos y divisores
    public static let textPrimary = Color(hex: "#F8FAFC")
    public static let textSecondary = Color(hex: "#94A3B8")
    public static let textMuted = Color(hex: "#64748B")
    public static let divider = Color(hex: "#1E293B")
}

public enum AppColorTheme: String, CaseIterable, Identifiable, Sendable {
    case electricBlue = "electric_blue"
    case electricOrange = "electric_orange"
    case electricGreen = "electric_green"
    case electricGray = "electric_gray"
    case electricRed = "electric_red"
    case electricPurple = "electric_purple"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .electricBlue: return "Azul Eléctrico (Predeterminado)"
        case .electricOrange: return "Naranja Eléctrico"
        case .electricGreen: return "Verde Eléctrico"
        case .electricGray: return "Gris Eléctrico"
        case .electricRed: return "Rojo Eléctrico"
        case .electricPurple: return "Morado Eléctrico"
        }
    }
    
    public var isProOnly: Bool {
        switch self {
        case .electricBlue, .electricOrange: return false
        default: return true
        }
    }
    
    public var primary: Color {
        switch self {
        case .electricBlue: return Color(hex: "#38BDF8")
        case .electricOrange: return Color(hex: "#FF7A00")
        case .electricGreen: return Color(hex: "#00FF87")
        case .electricGray: return Color(hex: "#CBD5E1")
        case .electricRed: return Color(hex: "#FF3B30")
        case .electricPurple: return Color(hex: "#A855F7")
        }
    }
    
    public var secondary: Color {
        switch self {
        case .electricBlue: return Color(hex: "#60A5FA")
        case .electricOrange: return Color(hex: "#FB923C")
        case .electricGreen: return Color(hex: "#34D399")
        case .electricGray: return Color(hex: "#94A3B8")
        case .electricRed: return Color(hex: "#FB7185")
        case .electricPurple: return Color(hex: "#C084FC")
        }
    }
    
    public var gradient: [Color] {
        switch self {
        case .electricBlue:
            return [Color(hex: "#00D2FF"), Color(hex: "#38BDF8"), Color(hex: "#1D4ED8")]
        case .electricOrange:
            return [Color(hex: "#FF9100"), Color(hex: "#FF7A00"), Color(hex: "#EA580C")]
        case .electricGreen:
            return [Color(hex: "#00FF87"), Color(hex: "#10B981"), Color(hex: "#059669")]
        case .electricGray:
            return [Color(hex: "#F1F5F9"), Color(hex: "#CBD5E1"), Color(hex: "#64748B")]
        case .electricRed:
            return [Color(hex: "#FF5252"), Color(hex: "#FF3B30"), Color(hex: "#BE123C")]
        case .electricPurple:
            return [Color(hex: "#D8B4FE"), Color(hex: "#A855F7"), Color(hex: "#7E22CE")]
        }
    }
    
    public static func fromId(_ id: String?) -> AppColorTheme {
        guard let id else { return .electricBlue }
        return AppColorTheme(rawValue: id) ?? .electricBlue
    }
}
