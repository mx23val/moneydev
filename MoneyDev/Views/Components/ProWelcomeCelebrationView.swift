import SwiftUI

public struct ProWelcomeCelebrationView: View {
    let onDismiss: () -> Void
    
    @State private var appearAnimation: Bool = false
    @State private var crownScale: CGFloat = 0.5
    @State private var crownRotation: Double = -15
    @State private var particleGlow: Bool = false
    
    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        ZStack {
            // Fondo oscuro con gradiente dorado
            AppColors.slateBlack.ignoresSafeArea()
            
            RadialGradient(
                colors: [
                    Color(hex: "#F59E0B").opacity(0.25),
                    Color(hex: "#B45309").opacity(0.12),
                    AppColors.slateBlack
                ],
                center: .top,
                startRadius: 20,
                endRadius: 400
            )
            .ignoresSafeArea()
            
            // Partículas flotantes doradas decorativas
            ForEach(0..<14, id: \.self) { index in
                Circle()
                    .fill(Color(hex: "#FDE047").opacity(Double.random(in: 0.3...0.7)))
                    .frame(width: CGFloat.random(in: 4...10), height: CGFloat.random(in: 4...10))
                    .position(
                        x: CGFloat((index * 27 + 35) % 360),
                        y: CGFloat((index * 53 + 70) % 650)
                    )
                    .scaleEffect(particleGlow ? 1.4 : 0.8)
                    .animation(
                        .easeInOut(duration: Double.random(in: 1.5...3.0))
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.1),
                        value: particleGlow
                    )
            }
            
            VStack(spacing: 24) {
                Spacer()
                
                // Corona Dorada 3D Brillante con Aureola
                ZStack {
                    // Aureola exterior
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: "#F59E0B").opacity(0.4), Color.clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 75
                            )
                        )
                        .frame(width: 150, height: 150)
                        .scaleEffect(particleGlow ? 1.2 : 0.9)
                    
                    // Círculo central con degradado oro
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#FBBF24"), Color(hex: "#D97706"), Color(hex: "#78350F")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)
                        .shadow(color: Color(hex: "#F59E0B").opacity(0.6), radius: 20, x: 0, y: 8)
                    
                    // Ícono de corona
                    Image(systemName: "crown.fill")
                        .font(.system(size: 46, weight: .black))
                        .foregroundStyle(.white)
                        .scaleEffect(crownScale)
                        .rotationEffect(.degrees(crownRotation))
                        .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                
                // Textos de Bienvenida
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color(hex: "#F59E0B"))
                        Text("¡FELICITACIONES!")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(Color(hex: "#F59E0B"))
                            .tracking(2)
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color(hex: "#F59E0B"))
                    }
                    
                    Text("¡Bienvenido al\nModo PRO!")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                    
                    Text("Has desbloqueado todas las funciones premium de por vida.")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                // Tarjetas de Beneficios Desbloqueados (5 beneficios completos)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        benefitRow(icon: "wallet.pass.fill", title: "Billeteras Ilimitadas", subtitle: "Crea cuentas bancarias, efectivo y ahorros sin límites.")
                        benefitRow(icon: "sparkles", title: "MoneyBot Asistente IA", subtitle: "Dictado inteligente por voz y análisis financiero avanzado.")
                        benefitRow(icon: "paintpalette.fill", title: "Temas Neón Exclusivos", subtitle: "Acceso a colores Neón Verde, Púrpura, Rojo y Gris.")
                        benefitRow(icon: "app.badge.fill", title: "Ícono Exclusivo", subtitle: "Elige entre el ícono clásico de MoneyDev o el dorado exclusivo.")
                        benefitRow(icon: "graduationcap.fill", title: "Aprende con MoneyDev", subtitle: "Guías, conceptos clave y consejos prácticos para tus finanzas.")
                    }
                    .padding(.horizontal, 20)
                }
                .frame(maxHeight: 330)
                
                Spacer()
                
                // Botón de Inicio
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    onDismiss()
                } label: {
                    HStack(spacing: 8) {
                        Text("Comenzar a Disfrutar")
                            .font(.system(size: 16, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#FDE047"), Color(hex: "#F59E0B"), Color(hex: "#D97706")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color(hex: "#F59E0B").opacity(0.4), radius: 12, x: 0, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .opacity(appearAnimation ? 1.0 : 0.0)
            .offset(y: appearAnimation ? 0 : 30)
        }
        .onAppear {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appearAnimation = true
                crownScale = 1.0
                crownRotation = 0
            }
            
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                particleGlow = true
            }
        }
    }
    
    private func benefitRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#F59E0B").opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: "#F59E0B"))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(Color(hex: "#F59E0B"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppColors.darkNavySurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#F59E0B").opacity(0.2), lineWidth: 1)
        )
    }
}
