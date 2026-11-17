import SwiftUI

public struct VoiceAssistantCard: View {
    let onOpenChat: () -> Void
    
    public init(onOpenChat: @escaping () -> Void) {
        self.onOpenChat = onOpenChat
    }
    
    public var body: some View {
        Button(action: onOpenChat) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#00D2FF"), Color(hex: "#1D4ED8")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("MoneyBot IA")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                        
                        Text("Asistente")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(hex: "#38BDF8"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#38BDF8").opacity(0.15))
                            .clipShape(Capsule())
                    }
                    
                    Text("Pregúntame sobre tus gastos o dicta tus movimientos con voz")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.textMuted)
            }
            .padding(14)
            .background(AppColors.darkNavySurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "#00D2FF").opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
