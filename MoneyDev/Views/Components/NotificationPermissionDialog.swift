import SwiftUI

public struct NotificationPermissionDialog: View {
    let onAccept: () -> Void
    let onDismiss: () -> Void
    
    public init(onAccept: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.onAccept = onAccept
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Header con ícono
            HStack(spacing: 12) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#00D2FF"), Color(hex: "#1D4ED8")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                    }
                
                Text("¡Activa tus Recordatorios!")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Descripción explicativa
            VStack(alignment: .leading, spacing: 10) {
                Text("Para que no olvides registrar tus gastos e ingresos del día y tener tus finanzas siempre al 100%, autoriza las notificaciones de MoneyDev.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(4)
                
                HStack(alignment: .top, spacing: 6) {
                    Text("🔔")
                    Text("Te avisaremos con un toque amigable solo a las 9:00 AM si aún no has registrado movimientos hoy.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textMuted)
                }
                .padding(10)
                .background(AppColors.navySurfaceVariant.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            // Botones de acción
            HStack(spacing: 12) {
                Button(action: onDismiss) {
                    Text("Más tarde")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(AppColors.darkNavySurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.cardBorderNavy, lineWidth: 1)
                        )
                }
                
                Button(action: onAccept) {
                    Text("Autorizar")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color(hex: "#38BDF8"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(24)
        .background(AppColors.midnightBlack)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(AppColors.cardBorderNavy, lineWidth: 1.2)
        )
        .padding(24)
    }
}
