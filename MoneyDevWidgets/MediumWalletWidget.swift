import WidgetKit
import SwiftUI

public struct MediumWalletEntry: TimelineEntry {
    public let date: Date
    public let wallet: WidgetWalletData
    public let totalBalance: Double
}

public struct MediumWalletProvider: AppIntentTimelineProvider {
    public init() {}
    
    public func placeholder(in context: Context) -> MediumWalletEntry {
        let fallback = WidgetSharedData.fallbackData
        return MediumWalletEntry(
            date: Date(),
            wallet: fallback.wallets[0],
            totalBalance: fallback.totalBalance
        )
    }
    
    public func snapshot(for configuration: SelectWalletAppIntent, in context: Context) async -> MediumWalletEntry {
        let data = WidgetDataManager.loadData()
        let walletId = configuration.wallet.flatMap { Int64($0.id) }
        let wallet = WidgetDataManager.wallet(for: walletId, in: data)
        return MediumWalletEntry(date: Date(), wallet: wallet, totalBalance: data.totalBalance)
    }
    
    public func timeline(for configuration: SelectWalletAppIntent, in context: Context) async -> Timeline<MediumWalletEntry> {
        let data = WidgetDataManager.loadData()
        let walletId = configuration.wallet.flatMap { Int64($0.id) }
        let wallet = WidgetDataManager.wallet(for: walletId, in: data)
        let entry = MediumWalletEntry(date: Date(), wallet: wallet, totalBalance: data.totalBalance)
        
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

public struct MediumWalletWidgetView: View {
    public let entry: MediumWalletEntry
    
    public var body: some View {
        let accentColor = Color(hex: entry.wallet.colorHex)
        
        ZStack {
            // Fondo oscuro refinado
            LinearGradient(
                colors: [
                    Color(hex: "#0F172A"),
                    Color(hex: "#090D16"),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Halo de luz sutil en el fondo
            RadialGradient(
                colors: [
                    accentColor.opacity(0.28),
                    accentColor.opacity(0.05),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 10,
                endRadius: 180
            )
            
            HStack(spacing: 12) {
                // Columna Izquierda: Información de la billetera y Saldo Total
                Link(destination: URL(string: "moneydev://wallet?id=\(entry.wallet.id)")!) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Encabezado
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(accentColor.opacity(0.22))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(accentColor.opacity(0.45), lineWidth: 1)
                                    )
                                
                                Image(systemName: sanitizedIcon(entry.wallet.iconName))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(accentColor)
                            }
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.wallet.name)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.white)
                                    .lineLimit(1)
                                
                                Text("Billetera")
                                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.50))
                            }
                            
                            Spacer()
                        }
                        
                        Spacer()
                        
                        // Etiqueta de Saldo
                        Text("SALDO TOTAL DISPONIBLE")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(accentColor)
                            .tracking(0.6)
                            .padding(.bottom, 2)
                        
                        // Monto del Saldo
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(entry.wallet.currencySymbol)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.75))
                            
                            Text(formatAmount(entry.wallet.balance))
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundStyle(Color.white)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        // Resumen mensual de ingresos y gastos
                        HStack(spacing: 10) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Color(hex: "#10B981"))
                                Text(formatCompact(entry.wallet.monthlyIncome, symbol: entry.wallet.currencySymbol))
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(hex: "#10B981"))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(Color(hex: "#10B981").opacity(0.12))
                            )
                            
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.right")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Color(hex: "#F43F5E"))
                                Text(formatCompact(entry.wallet.monthlyExpense, symbol: entry.wallet.currencySymbol))
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(hex: "#F43F5E"))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(Color(hex: "#F43F5E").opacity(0.12))
                            )
                        }
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.12))
                    .padding(.vertical, 6)
                
                // Columna Derecha: Botón de Dictado por Voz (Acceso Directo al Micrófono)
                Link(destination: URL(string: "moneydev://voice-dictation?walletId=\(entry.wallet.id)")!) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            accentColor,
                                            Color(hex: "#3B82F6")
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 52, height: 52)
                                .shadow(color: accentColor.opacity(0.55), radius: 8, x: 0, y: 3)
                            
                            Circle()
                                .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                                .frame(width: 52, height: 52)
                            
                            Image(systemName: "mic.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Color.white)
                        }
                        
                        VStack(spacing: 1) {
                            Text("Dictar por voz")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(Color.white)
                                .lineLimit(1)
                            
                            Text("Registrar")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.60))
                        }
                    }
                    .frame(width: 95)
                    .frame(maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                }
            }
            .padding(14)
        }
    }
    
    private func formatAmount(_ val: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "es_PE")
        return formatter.string(from: NSNumber(value: val)) ?? String(format: "%.2f", val)
    }
    
    private func formatCompact(_ val: Double, symbol: String) -> String {
        if val >= 1000 {
            return String(format: "\(symbol)%.1fk", val / 1000)
        }
        return String(format: "\(symbol)%.0f", val)
    }
    
    private func sanitizedIcon(_ name: String) -> String {
        let systemIcons = ["wallet.pass.fill", "creditcard.fill", "banknote.fill", "building.columns.fill", "bag.fill", "cart.fill", "dollarsign.circle.fill"]
        if systemIcons.contains(name) { return name }
        return "wallet.pass.fill"
    }
}

public struct MediumWalletWidget: Widget {
    public let kind: String = "MediumWalletWidget"
    
    public init() {}
    
    public var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectWalletAppIntent.self,
            provider: MediumWalletProvider()
        ) { entry in
            MediumWalletWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.black
                }
        }
        .configurationDisplayName("Billetera y Dictado")
        .description("Visualiza una billetera, saldo total y accede con un toque al dictado por voz.")
        .supportedFamilies([.systemMedium])
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
