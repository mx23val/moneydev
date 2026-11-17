import WidgetKit
import SwiftUI
import ActivityKit

public struct MoneyBotLiveActivityWidget: Widget {
    public init() {}
    
    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: MoneyBotActivityAttributes.self) { context in
            // MARK: - Banner de Pantalla de Bloqueo (Todos los iPhones)
            LockScreenLiveActivityView(context: context)
                .widgetURL(URL(string: "moneydev://live-voice"))
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Isla Dinámica Expandida
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hexString: "#00D2FF"), Color(hexString: "#0072FF")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 26, height: 26)
                            
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("MoneyBot")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(Color.white)
                            Text(context.state.statusText)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(hexString: "#00D2FF"))
                        }
                    }
                    .padding(.leading, 6)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(context.state.isSpeaking ? Color(hexString: "#00D2FF") : Color(hexString: "#10B981"))
                            .frame(width: 8, height: 8)
                            .shadow(color: (context.state.isSpeaking ? Color(hexString: "#00D2FF") : Color(hexString: "#10B981")).opacity(0.8), radius: 4)
                        
                        Text(context.state.isSpeaking ? "Hablando" : "En Vivo")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.9))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                    )
                    .padding(.trailing, 6)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        Image(systemName: context.state.isSpeaking ? "waveform" : "mic.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hexString: "#00D2FF"))
                        
                        Text(context.state.subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.88))
                            .lineLimit(1)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hexString: "#00D2FF"))
                    Text("Money")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white)
                }
                .padding(.leading, 4)
            } compactTrailing: {
                HStack(spacing: 3) {
                    Circle()
                        .fill(context.state.isSpeaking ? Color(hexString: "#00D2FF") : Color(hexString: "#10B981"))
                        .frame(width: 7, height: 7)
                    Image(systemName: context.state.isSpeaking ? "waveform" : "mic.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.9))
                    Text(context.state.isSpeaking ? "" : "🎙")
                        .font(.system(size: 8))
                }
                .padding(.trailing, 4)
            } minimal: {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hexString: "#00D2FF"))
            }
        }
    }
}

// MARK: - Vista para la Pantalla de Bloqueo / Notificaciones
private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<MoneyBotActivityAttributes>
    
    var body: some View {
        HStack(spacing: 14) {
            // Orbe / Ícono brillante
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hexString: "#00D2FF"), Color(hexString: "#0055FF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: Color(hexString: "#00D2FF").opacity(0.5), radius: 8)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("MoneyBot Live")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white)
                    
                    Circle()
                        .fill(context.state.isSpeaking ? Color(hexString: "#00D2FF") : Color(hexString: "#10B981"))
                        .frame(width: 7, height: 7)
                    
                    Text(context.state.statusText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hexString: "#00D2FF"))
                }
                
                Text(context.state.subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: context.state.isSpeaking ? "waveform" : "mic.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hexString: "#00D2FF"))
                .padding(10)
                .background(Circle().fill(Color.white.opacity(0.10)))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(hexString: "#111827").opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.3), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - Color Hex Helper
private extension Color {
    init(hexString: String) {
        let clean = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
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
            (a, r, g, b) = (255, 0, 0, 0)
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
