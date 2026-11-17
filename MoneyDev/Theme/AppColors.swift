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
    
    // Textos y divisores (Optimizados para máximo contraste y legibilidad)
    public static let textPrimary = Color(hex: "#FFFFFF")
    public static let textSecondary = Color(hex: "#E2E8F0")
    public static let textMuted = Color(hex: "#A0AEC0")
    public static let divider = Color(hex: "#1E293B")
}

public enum AppColorTheme: String, CaseIterable, Identifiable, Sendable {
    case electricBlue = "electric_blue"
    case electricOrange = "electric_orange"
    case electricGreen = "electric_green"
    case electricGray = "electric_gray"
    case electricRed = "electric_red"
    case electricPurple = "electric_purple"
    case electricPink = "electric_pink"
    case electricBlack = "electric_black"
    case electricYellow = "electric_yellow"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .electricBlue: return "Azul Eléctrico (Predeterminado)"
        case .electricOrange: return "Naranja Eléctrico"
        case .electricGreen: return "Verde Eléctrico"
        case .electricGray: return "Gris Eléctrico"
        case .electricRed: return "Rojo Eléctrico"
        case .electricPurple: return "Morado Eléctrico"
        case .electricPink: return "Rosado Neón"
        case .electricBlack: return "Negro Puro"
        case .electricYellow: return "Amarillo Neón"
        }
    }
    
    public var isProOnly: Bool {
        switch self {
        case .electricBlue, .electricOrange: return false
        default: return true
        }
    }
    
    public var primaryHex: String {
        switch self {
        case .electricBlue: return "#38BDF8"
        case .electricOrange: return "#FF7A00"
        case .electricGreen: return "#00FF87"
        case .electricGray: return "#CBD5E1"
        case .electricRed: return "#FF3B30"
        case .electricPurple: return "#A855F7"
        case .electricPink: return "#EC4899"
        case .electricBlack: return "#000000"
        case .electricYellow: return "#FACC15"
        }
    }
    
    public var primary: Color {
        Color(hex: primaryHex)
    }
    
    public var secondary: Color {
        switch self {
        case .electricBlue: return Color(hex: "#60A5FA")
        case .electricOrange: return Color(hex: "#FB923C")
        case .electricGreen: return Color(hex: "#34D399")
        case .electricGray: return Color(hex: "#94A3B8")
        case .electricRed: return Color(hex: "#FB7185")
        case .electricPurple: return Color(hex: "#C084FC")
        case .electricPink: return Color(hex: "#F472B6")
        case .electricBlack: return Color(hex: "#0A0A0E")
        case .electricYellow: return Color(hex: "#FDE047")
        }
    }
    
    public var gradient: [Color] {
        // Se mantiene la API para los controles existentes, pero las superficies
        // dejan de cambiar de tono dentro de un mismo botón.
        [primary, primary]
    }
    
    /// Color para el fondo de botones/píldoras activas
    public var pillBackground: Color {
        switch self {
        case .electricBlack:
            return Color(hex: "#000000") // 100% Negro Puro, nunca blanco
        default:
            return primary.opacity(0.34)
        }
    }
    
    /// Borde de botones/píldoras activas
    public var pillBorder: Color {
        switch self {
        case .electricBlack:
            return Color.white.opacity(0.65) // Borde nítido para resaltar el botón negro
        default:
            return Color.white.opacity(0.28)
        }
    }
    
    /// Color del texto cuando se encuentra sobre pillBackground o gradientes
    public var onPrimaryText: Color {
        switch self {
        case .electricBlack:
            return Color.white // Texto blanco sobre fondo negro
        case .electricYellow:
            return Color(hex: "#0F172A") // Texto oscuro sobre fondos muy luminosos
        case .electricGray:
            return Color.white
        case .electricBlue:
            return Color.white
        default:
            return Color.white
        }
    }
    
    /// Color de acento para iconos sobre superficies oscuras
    public var accentIconColor: Color {
        switch self {
        case .electricBlack:
            return Color(hex: "#F8FAFC") // Iconos claros sobre superficies oscuras
        default:
            return primary
        }
    }
    
    /// Color de acento para textos y elementos sobre fondos oscuros (contraste automático)
    public var accentColor: Color {
        switch self {
        case .electricBlack:
            return Color(hex: "#F8FAFC") // Blanco nítido para contraste sobre fondos oscuros
        default:
            return primary
        }
    }
    
    /// Color de texto de acento
    public var accentTextColor: Color {
        accentColor
    }
    
    /// Color de acento para controles interactivos Toggle/Switch con alto contraste (evita blanco sobre blanco)
    public var toggleTint: Color {
        switch self {
        case .electricBlack:
            return Color(hex: "#38BDF8") // Cian eléctrico radiante de alto contraste sobre negro puro
        default:
            return primary
        }
    }
    
    /// Valor Hexadecimal del color de acento para reportes y gráficos
    public var accentHex: String {
        switch self {
        case .electricBlack:
            return "#F8FAFC"
        default:
            return primaryHex
        }
    }
    
    /// Fondo principal de la aplicación. Conserva el contraste necesario para datos
    /// financieros, pero cada tema tiene una identidad cromática visible en toda la UI.
    public var appBackgroundGradient: [Color] {
        let background: Color
        switch self {
        case .electricBlue:
            background = Color(hex: "#0C151C")
        case .electricOrange:
            background = Color(hex: "#16110D")
        case .electricGreen:
            background = Color(hex: "#0C1712")
        case .electricGray:
            background = Color(hex: "#13181E")
        case .electricRed:
            background = Color(hex: "#170D11")
        case .electricPurple:
            background = Color(hex: "#120E19")
        case .electricPink:
            background = Color(hex: "#160C12")
        case .electricBlack:
            background = Color.black
        case .electricYellow:
            background = Color(hex: "#17150C")
        }
        return [background, background, background]
    }

    /// Superficie sólida secundaria. Es más clara que el fondo, conserva el
    /// matiz del tema actual y evita usar el azul fijo como base de la interfaz.
    public var interfaceSurface: Color {
        switch self {
        case .electricBlue: return Color(hex: "#142431")
        case .electricOrange: return Color(hex: "#2A1C12")
        case .electricGreen: return Color(hex: "#12291D")
        case .electricGray: return Color(hex: "#222A32")
        case .electricRed: return Color(hex: "#2B171C")
        case .electricPurple: return Color(hex: "#241B30")
        case .electricPink: return Color(hex: "#2B1722")
        case .electricBlack: return Color(hex: "#151515")
        case .electricYellow: return Color(hex: "#2B2715")
        }
    }

    /// Halo ambiental apenas perceptible: el tema unifica toda la pantalla, no crea capas de color.
    public var appBackgroundGlow: Color {
        self == .electricBlack ? Color.white.opacity(0.012) : primary.opacity(0.045)
    }
    
    public static func fromId(_ id: String?) -> AppColorTheme {
        guard let id else { return .electricBlue }
        return AppColorTheme(rawValue: id) ?? .electricBlue
    }
}

// MARK: - Fondo Temático Ultra Oscuro para Modales e Interfaces
public struct ThemedModalBackground: View {
    public let theme: AppColorTheme
    
    public init(theme: AppColorTheme) {
        self.theme = theme
    }
    
    public var body: some View {
        theme.appBackgroundGradient[0]
            .ignoresSafeArea()
    }
}

// MARK: - Modificador de Contraste para Textos (Alto Rendimiento 120 FPS)
public struct ContrastTextModifier: ViewModifier {
    public var shadowColor: Color
    public var radius: CGFloat
    
    public init(shadowColor: Color = Color.black.opacity(0.85), radius: CGFloat = 0.8) {
        self.shadowColor = shadowColor
        self.radius = radius
    }
    
    public func body(content: Content) -> some View {
        content
            .shadow(color: shadowColor.opacity(0.80), radius: min(radius, 0.6), x: 0, y: 0.7)
    }
}

// MARK: - Fondo Temático Unificado para Contenido
public struct ThemedCardBackgroundView: View {
    public let theme: AppColorTheme
    public var cornerRadius: CGFloat
    
    public init(theme: AppColorTheme = .electricBlue, cornerRadius: CGFloat = 14) {
        self.theme = theme
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(theme.interfaceSurface)
    }
}

// MARK: - Modificador de Campo de Entrada con Teclado (Idéntico al estilo de Agregar Nueva Billetera)
public struct ThemedInputFieldModifier: ViewModifier {
    public var theme: AppColorTheme
    public var cornerRadius: CGFloat
    public var borderColor: Color?
    public var isFocused: Bool
    
    public init(theme: AppColorTheme = .electricBlue, cornerRadius: CGFloat = 14, borderColor: Color? = nil, isFocused: Bool = false) {
        self.theme = theme
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.isFocused = isFocused
    }
    
    public func body(content: Content) -> some View {
        content
            .background(
                ThemedCardBackgroundView(theme: theme, cornerRadius: cornerRadius)
            )
    }
}

// MARK: - Modificador de Presentación de Sheet para Cerrar Huecos Inferiores
public struct ThemedSheetContainerModifier: ViewModifier {
    public var theme: AppColorTheme
    
    public init(theme: AppColorTheme) {
        self.theme = theme
    }
    
    public func body(content: Content) -> some View {
        content
            .presentationBackground {
                ThemedModalBackground(theme: theme)
            }
    }
}

public extension View {
    /// Aplica un borde / relieve sutil de alto contraste a los textos para que se distingan claramente sobre cualquier fondo
    func contrastTextOutline(color: Color = Color.black.opacity(0.85), radius: CGFloat = 0.8) -> some View {
        self.modifier(ContrastTextModifier(shadowColor: color, radius: radius))
    }
    
    /// Aplica el fondo y sombreado idéntico al campo de "Agregar Nueva Billetera"
    func themedInputField(theme: AppColorTheme = .electricBlue, cornerRadius: CGFloat = 14, borderColor: Color? = nil, isFocused: Bool = false) -> some View {
        self.modifier(ThemedInputFieldModifier(theme: theme, cornerRadius: cornerRadius, borderColor: borderColor, isFocused: isFocused))
    }
    
    /// Configura el contenedor del modal desplegable (sheet) con fondo degradado continuo hasta el borde inferior sin dejar aperturas
    func themedSheetContainer(theme: AppColorTheme) -> some View {
        self.modifier(ThemedSheetContainerModifier(theme: theme))
    }
}

