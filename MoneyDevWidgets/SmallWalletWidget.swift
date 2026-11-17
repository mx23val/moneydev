import WidgetKit
import SwiftUI

public struct SmallWalletEntry: TimelineEntry {
    public let date: Date
    public let wallet: WidgetWalletData
    public let totalBalance: Double
}

public struct SmallWalletProvider: AppIntentTimelineProvider {
    public init() {}
    
    public func placeholder(in context: Context) -> SmallWalletEntry {
        let fallback = WidgetSharedData.fallbackData
        return SmallWalletEntry(
            date: Date(),
            wallet: fallback.wallets[0],
            totalBalance: fallback.totalBalance
        )
    }
    
    public func snapshot(for configuration: SelectWalletAppIntent, in context: Context) async -> SmallWalletEntry {
        let data = WidgetDataManager.loadData()
        let walletId = configuration.wallet.flatMap { Int64($0.id) }
        let wallet = WidgetDataManager.wallet(for: walletId, in: data)
        return SmallWalletEntry(date: Date(), wallet: wallet, totalBalance: data.totalBalance)
    }
    
    public func timeline(for configuration: SelectWalletAppIntent, in context: Context) async -> Timeline<SmallWalletEntry> {
        let data = WidgetDataManager.loadData()
        let walletId = configuration.wallet.flatMap { Int64($0.id) }
        let wallet = WidgetDataManager.wallet(for: walletId, in: data)
        let entry = SmallWalletEntry(date: Date(), wallet: wallet, totalBalance: data.totalBalance)
        
        // Actualizar cada 30 minutos o cuando la app escriba nuevos datos
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

public struct SmallWalletWidgetView: View {
    public let entry: SmallWalletEntry
    
    public var body: some View {
        let accentColor = Color(hex: entry.wallet.colorHex)
        
        ZStack {
            // Fondo oscuro con gradiente suave
            LinearGradient(
                colors: [
                    Color(hex: "#0F172A"),
                    Color(hex: "#090D16"),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Halo de luz sutil en la esquina superior con el color de la billetera
            RadialGradient(
                colors: [
                    accentColor.opacity(0.32),
                    accentColor.opacity(0.08),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 5,
                endRadius: 110
            )
            
            VStack(alignment: .leading, spacing: 0) {
                // Encabezado: Icono de la billetera y nombre
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.20))
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle()
                                    .stroke(accentColor.opacity(0.40), lineWidth: 1)
                            )
                        
                        Image(systemName: sanitizedIcon(entry.wallet.iconName))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(accentColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.wallet.name)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                            .lineLimit(1)
                        
                        Text("Billetera")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.50))
                    }
                    
                    Spacer()
                }
                
                Spacer()
                
                // Etiqueta de Saldo Disponible
                HStack(spacing: 4) {
                    Text("SALDO TOTAL")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(accentColor)
                        .tracking(0.6)
                }
                .padding(.bottom, 2)
                
                // Monto del Saldo Total
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(entry.wallet.currencySymbol)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.75))
                    
                    Text(formatAmount(entry.wallet.balance))
                        .font(.system(size: 23, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white)
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Barra indicadora inferior
                HStack {
                    Capsule()
                        .fill(accentColor)
                        .frame(width: 24, height: 3)
                    
                    Spacer()
                    
                    Text("MoneyDev")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.30))
                }
            }
            .padding(14)
        }
        .widgetURL(URL(string: "moneydev://wallet?id=\(entry.wallet.id)"))
    }
    
    private func formatAmount(_ val: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "es_PE")
        return formatter.string(from: NSNumber(value: val)) ?? String(format: "%.2f", val)
    }
    
    private func sanitizedIcon(_ name: String) -> String {
        let systemIcons = ["wallet.pass.fill", "creditcard.fill", "banknote.fill", "building.columns.fill", "bag.fill", "cart.fill", "dollarsign.circle.fill"]
        if systemIcons.contains(name) { return name }
        return "wallet.pass.fill"
    }
}

public struct SmallWalletWidget: Widget {
    public let kind: String = "SmallWalletWidget"
    
    public init() {}
    
    public var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectWalletAppIntent.self,
            provider: SmallWalletProvider()
        ) { entry in
            SmallWalletWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.black
                }
        }
        .configurationDisplayName("Saldo de Billetera")
        .description("Visualiza una billetera en específico y su saldo total disponible.")
        .supportedFamilies([.systemSmall])
    }
}

// Extensión para color HEX en Widget
private extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch clean.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 210, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
