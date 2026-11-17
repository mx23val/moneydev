import SwiftUI
import UIKit

public struct ContactDialog: View {
    public var theme: AppColorTheme
    let onDismiss: () -> Void
    
    @State private var isCopied: Bool = false
    @Environment(\.openURL) private var openURL
    
    private let developerName = "NeoMax Dev"
    private let developerEmail = "mvalerioe1@gmail.com"
    
    public init(theme: AppColorTheme = .electricBlue, onDismiss: @escaping () -> Void) {
        self.theme = theme
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                ThemedModalBackground(theme: theme)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // Avatar / Badge
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: theme.gradient,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Circle().stroke(Color.white.opacity(theme == .electricBlack ? 0.6 : 0.2), lineWidth: 1)
                                )
                            
                            Image(systemName: "envelope.badge.fill")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(theme == .electricBlack ? Color.white : theme.onPrimaryText)
                        }
                        .shadow(color: theme.primary.opacity(0.35), radius: 8, x: 0, y: 3)
                        .padding(.top, 8)
                        
                        VStack(spacing: 10) {
                            Text("Para sugerencias, consultas o soporte de la app, puedes ponerte en contacto con el desarrollador:")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 12)
                                .contrastTextOutline(color: Color.black.opacity(0.6), radius: 2)
                            
                            VStack(spacing: 4) {
                                Text(developerName)
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppColors.textPrimary)
                                    .contrastTextOutline()
                                
                                Text(developerEmail)
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(theme == .electricBlack ? Color(hex: "#38BDF8") : theme.primary)
                                    .contrastTextOutline(color: Color.black.opacity(0.5), radius: 1.5)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .background(ThemedCardBackgroundView(theme: theme, cornerRadius: 14))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        
                        // Botones de acción
                        HStack(spacing: 12) {
                            Button {
                                UIPasteboard.general.string = developerEmail
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                                withAnimation(.spring) {
                                    isCopied = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    withAnimation {
                                        isCopied = false
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc.fill")
                                        .font(.system(size: 14, weight: .bold))
                                    Text(isCopied ? "¡Copiado!" : "Copiar Correo")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(ThemedCardBackgroundView(theme: theme, cornerRadius: 12))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            
                            Button {
                                if let url = URL(string: "mailto:\(developerEmail)?subject=MoneyDev%20-%20Soporte%20y%20Sugerencias") {
                                    openURL(url)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 14, weight: .bold))
                                    Text("Enviar Mensaje")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .foregroundStyle(theme == .electricBlack ? Color.white : theme.onPrimaryText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(
                                    LinearGradient(
                                        colors: theme == .electricBlack ?
                                            [Color(hex: "#262626"), Color(hex: "#111111")] :
                                            [theme.primary, theme.secondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(theme == .electricBlack ? Color.white.opacity(0.4) : Color.clear, lineWidth: 1)
                                )
                                .shadow(color: theme.primary.opacity(0.3), radius: 6, x: 0, y: 2)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 4)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Contacto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar", action: onDismiss)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                        .contrastTextOutline()
                }
            }
        }
        .presentationDetents([.fraction(0.50), .medium])
        .presentationDragIndicator(.visible)
    }
}
