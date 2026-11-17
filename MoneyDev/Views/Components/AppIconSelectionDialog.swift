import SwiftUI

public struct AppIconSelectionDialog: View {
    let isProUser: Bool
    let onDismiss: () -> Void
    
    @State private var currentIcon: String = AppIconManager.currentIcon
    @State private var alertMessage: String? = nil
    @State private var showAlert: Bool = false
    
    public init(isProUser: Bool, onDismiss: @escaping () -> Void) {
        self.isProUser = isProUser
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AppColors.midnightBlack.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Selecciona el Ícono de la App")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                    
                    HStack(spacing: 16) {
                        // Ícono Clásico
                        iconOption(
                            title: "Clásico Neón",
                            iconType: AppIconManager.iconClassic,
                            colors: [Color(hex: "#00D2FF"), Color(hex: "#1D4ED8")],
                            isPro: false
                        )
                        
                        // Ícono Oro PRO
                        iconOption(
                            title: "Oro 24K PRO",
                            iconType: AppIconManager.iconProGold,
                            colors: [Color(hex: "#F59E0B"), Color(hex: "#78350F")],
                            isPro: true
                        )
                    }
                    .padding(.horizontal, 10)
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Text("Cerrar")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(AppColors.navySurfaceVariant)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(20)
            }
            .navigationTitle("Ícono de MoneyDev")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Aviso", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage ?? "")
            }
        }
        .presentationDetents([.medium])
    }
    
    private func iconOption(title: String, iconType: String, colors: [Color], isPro: Bool) -> some View {
        let isSelected = currentIcon == iconType
        let isLocked = isPro && !isProUser
        
        return Button {
            if isLocked {
                alertMessage = "El ícono Oro 24K es exclusivo de la versión PRO."
                showAlert = true
            } else {
                Task {
                    _ = await AppIconManager.setAppIcon(iconType)
                    currentIcon = iconType
                }
            }
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 72, height: 72)
                        .shadow(color: colors.first?.opacity(0.4) ?? .clear, radius: 8)
                    
                    Image(systemName: isPro ? "crown.fill" : "dollarsign.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                    
                    if isSelected {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.white)
                                    .background(Circle().fill(Color.blue))
                                    .offset(x: 6, y: 6)
                            }
                        }
                        .frame(width: 72, height: 72)
                    } else if isLocked {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(Circle().fill(Color.black.opacity(0.6)))
                                    .offset(x: 4, y: -4)
                            }
                            Spacer()
                        }
                        .frame(width: 72, height: 72)
                    }
                }
                
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? .white : AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(isSelected ? AppColors.darkNavySurface : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color(hex: "#38BDF8") : AppColors.cardBorderNavy, lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }
}
