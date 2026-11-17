import SwiftUI

public enum MoneyBotOrbState: Equatable {
    case listening(audioLevel: Float)
    case thinking
    case speaking
}

public struct MoneyBotLiveVoiceOrbView: View {
    public let state: MoneyBotOrbState
    public let theme: AppColorTheme
    
    @State private var smoothedAudioLevel: CGFloat = 0.0
    @State private var targetAudioLevel: CGFloat = 0.0
    @State private var lerpTask: Task<Void, Never>? = nil
    
    public init(state: MoneyBotOrbState, theme: AppColorTheme) {
        self.state = state
        self.theme = theme
    }
    
    private var baseColors: [Color] {
        switch theme {
        case .electricBlack:
            return [Color(hex: "#38BDF8"), Color(hex: "#818CF8"), Color(hex: "#C084FC"), Color(hex: "#38BDF8")]
        case .electricGreen:
            return [Color(hex: "#00FF87"), Color(hex: "#10B981"), Color(hex: "#06B6D4"), Color(hex: "#00FF87")]
        case .electricYellow:
            return [Color(hex: "#FACC15"), Color(hex: "#FB923C"), Color(hex: "#F59E0B"), Color(hex: "#FACC15")]
        case .electricOrange:
            return [Color(hex: "#FF7A00"), Color(hex: "#F43F5E"), Color(hex: "#FB923C"), Color(hex: "#FF7A00")]
        case .electricPurple:
            return [Color(hex: "#A855F7"), Color(hex: "#EC4899"), Color(hex: "#6366F1"), Color(hex: "#A855F7")]
        case .electricPink:
            return [Color(hex: "#EC4899"), Color(hex: "#F43F5E"), Color(hex: "#A855F7"), Color(hex: "#EC4899")]
        case .electricRed:
            return [Color(hex: "#FF3B30"), Color(hex: "#FB7185"), Color(hex: "#F97316"), Color(hex: "#FF3B30")]
        default:
            return [Color(hex: "#00D2FF"), Color(hex: "#38BDF8"), Color(hex: "#818CF8"), Color(hex: "#00D2FF")]
        }
    }
    
    public var body: some View {
        TimelineView(.animation) { timeline in
            // Tiempo continuo unificado sin discontinuidades angulares
            let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000)
            
            // Rotaciones base continuas (garantizan cero saltos angulares entre cambios de estado)
            let baseAngle = (t * 36.0).truncatingRemainder(dividingBy: 360.0)
            let counterAngle = (-t * 22.0).truncatingRemainder(dividingBy: 360.0)
            let thinkingAngle = (t * 110.0).truncatingRemainder(dividingBy: 360.0)
            
            // Respiración armónica de reposo (tranquila y continua)
            let baseBreathing = sin(t * 2.2) * 0.032
            
            // Dinámica fluida según estado (voz usuario vs voz bot vs pensamiento)
            let (orbScale, glowOpacity, ringExpansion, ringOpacity, showThinkingCorona, activePerimeterPower): (CGFloat, Double, CGFloat, Double, Bool, CGFloat) = {
                switch state {
                case .speaking:
                    // Cadencia conversacional multi-frecuencia viva y suave para la voz del bot
                    let w1: Double = sin(t * 5.6) * 0.48
                    let w2: Double = sin(t * 3.1) * 0.32
                    let w3: Double = cos(t * 7.8) * 0.20
                    let botVoice: CGFloat = CGFloat((w1 + w2 + w3 + 1.0) * 0.5)
                    let scale: CGFloat = 1.0 + baseBreathing + botVoice * 0.09
                    let glow: Double = 0.55 + Double(botVoice) * 0.30
                    let ringExp: CGFloat = botVoice * 20.0
                    let ringOp: Double = 0.35 + Double(botVoice) * 0.45
                    return (scale, glow, ringExp, ringOp, false, botVoice)
                    
                case .thinking:
                    // Pulso suave y meditativo mientras MoneyBot procesa
                    let pulseVal: Double = (sin(t * 3.6) + 1.0) * 0.5
                    let thinkPulse: CGFloat = CGFloat(pulseVal)
                    let scale: CGFloat = 1.0 + baseBreathing * 0.6
                    let glow: Double = 0.35 + Double(thinkPulse) * 0.20
                    let ringExp: CGFloat = 4.0 + thinkPulse * 8.0
                    let ringOp: Double = 0.25 + Double(thinkPulse) * 0.25
                    return (scale, glow, ringExp, ringOp, true, 0.20)
                    
                case .listening:
                    // Reactividad ultra fluida usando smoothedAudioLevel interpolado por frame
                    let userVoice = smoothedAudioLevel
                    let idleVal: Double = (sin(t * 3.2) + 1.0) * 0.5
                    let idlePulse: CGFloat = CGFloat(idleVal)
                    let scale: CGFloat = 1.0 + baseBreathing + userVoice * 0.15
                    let glow: Double = 0.30 + Double(idlePulse) * 0.15 + Double(userVoice) * 0.40
                    let ringExp: CGFloat = idlePulse * 6.0 + userVoice * 24.0
                    let ringOp: Double = 0.20 + Double(idlePulse) * 0.15 + Double(userVoice) * 0.55
                    return (scale, glow, ringExp, ringOp, false, userVoice)
                }
            }()
            
            let baseSize: CGFloat = 160
            
            ZStack {
                // 1. Halo difuso exterior (Atmósfera ambiental expansiva a 60/120 FPS)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                baseColors[0].opacity(glowOpacity),
                                baseColors[1].opacity(glowOpacity * 0.45),
                                baseColors[0].opacity(0.04),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: baseSize * 1.55
                        )
                    )
                    .frame(width: baseSize * 3.1, height: baseSize * 3.1)
                    .scaleEffect(orbScale)
                    .blur(radius: 14)
                
                // 2. Anillo de expansión resonante (Onda acústica suave sin cortes)
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                baseColors[0].opacity(ringOpacity),
                                baseColors[1].opacity(ringOpacity * 0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.2 + ringExpansion * 0.12
                    )
                    .frame(
                        width: baseSize + 20 + ringExpansion,
                        height: baseSize + 20 + ringExpansion
                    )
                    .blur(radius: 2)
                
                // 3. Orbe Central Multicapa Líquido
                ZStack {
                    // Capa de fondo con degradado angular líquido en rotación continua
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: baseColors,
                                center: .center,
                                startAngle: .degrees(baseAngle),
                                endAngle: .degrees(baseAngle + 360)
                            )
                        )
                        .frame(width: baseSize, height: baseSize)
                        .blur(radius: 3)
                    
                    // Capa de contrarotación cromática para dar sensación de fluidos internos
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [
                                    Color.white.opacity(0.35),
                                    baseColors[1].opacity(0.20),
                                    Color.clear,
                                    baseColors[2].opacity(0.25),
                                    Color.white.opacity(0.35)
                                ],
                                center: .center,
                                startAngle: .degrees(counterAngle),
                                endAngle: .degrees(counterAngle + 360)
                            )
                        )
                        .frame(width: baseSize, height: baseSize)
                        .blendMode(.screen)
                    
                    // Volumen 3D y brillo esférico (luz cenital superior izquierda)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.65),
                                    baseColors[0].opacity(0.25),
                                    Color.black.opacity(0.55)
                                ],
                                center: UnitPoint(x: 0.35, y: 0.28),
                                startRadius: 8,
                                endRadius: baseSize * 0.72
                            )
                        )
                        .frame(width: baseSize, height: baseSize)
                        .blendMode(.overlay)
                    
                    // Corona orbital de pensamiento (visible durante procesamiento con IA)
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color.white.opacity(0.9),
                                    baseColors[0],
                                    Color.clear,
                                    Color.white.opacity(0.9)
                                ],
                                center: .center,
                                startAngle: .degrees(thinkingAngle),
                                endAngle: .degrees(thinkingAngle + 360)
                            ),
                            lineWidth: 3.0
                        )
                        .frame(width: baseSize * 1.08, height: baseSize * 1.08)
                        .opacity(showThinkingCorona ? 1.0 : 0.0)
                    
                    // Borde de cristal estilo lente líquida
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.85),
                                    Color.white.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: baseSize - 2, height: baseSize - 2)
                    
                    // 4. Borde Perimetral Neon Reactivo a la Voz
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    baseColors[0],
                                    Color.white.opacity(0.95),
                                    baseColors[1],
                                    baseColors[2],
                                    baseColors[0]
                                ],
                                center: .center,
                                startAngle: .degrees(baseAngle + 90),
                                endAngle: .degrees(baseAngle + 450)
                            ),
                            lineWidth: 3.0 + activePerimeterPower * 2.5
                        )
                        .frame(
                            width: baseSize + 4 + activePerimeterPower * 8,
                            height: baseSize + 4 + activePerimeterPower * 8
                        )
                        .shadow(
                            color: baseColors[0].opacity(Double(0.60 + activePerimeterPower * 0.35)),
                            radius: 12 + activePerimeterPower * 10
                        )
                        .shadow(
                            color: Color.white.opacity(Double(0.40 + activePerimeterPower * 0.35)),
                            radius: 4
                        )
                }
                .scaleEffect(orbScale)
                .shadow(
                    color: baseColors[0].opacity(glowOpacity),
                    radius: 20 + activePerimeterPower * 14,
                    x: 0,
                    y: 0
                )
            }
        }
        .frame(width: 170, height: 170)
        // ─── Loop de interpolación EMA a ~60fps ──────────────────────────────────
        // Se corre en un Task independiente para NO mutar @State dentro del body render.
        // EMA factor 0.18: respuesta rápida al ataque, decaimiento suave al soltar.
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_666_667) // ~60fps
                await MainActor.run {
                    let factor: CGFloat = 0.18
                    let newVal = smoothedAudioLevel + (targetAudioLevel - smoothedAudioLevel) * factor
                    if abs(newVal - smoothedAudioLevel) > 0.0005 {
                        smoothedAudioLevel = newVal
                    }
                }
            }
        }
        .onChange(of: state, initial: true) { _, newState in
            switch newState {
            case .listening(let level):
                // Actualizar el target; el suavizado ocurre en el task de 60fps
                targetAudioLevel = CGFloat(min(max(level, 0.0), 1.0))
            case .speaking, .thinking:
                // Al salir del modo listening, desacelerar suavemente a cero
                targetAudioLevel = 0.0
            }
        }
    }
}
