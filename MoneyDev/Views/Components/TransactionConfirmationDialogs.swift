import SwiftUI

// Diálogo de confirmación de transferencia exitosa
public struct TransferSuccessDialog: View {
    let result: TransferResult
    var theme: AppColorTheme = .electricBlue
    let onDismiss: () -> Void
    
    public var body: some View {
        VStack(spacing: 18) {
            // Icono de éxito con halo
            ZStack {
                Circle()
                    .fill(AppColors.incomeEmerald.opacity(0.18))
                    .frame(width: 68, height: 68)
                
                Circle()
                    .stroke(AppColors.incomeEmerald.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 68, height: 68)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(AppColors.incomeEmeraldLight)
            }
            .padding(.top, 4)
            
            // Título principal con contraste
            Text("¡Transferencia Exitosa!")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(Color.white)
                .contrastTextOutline()
            
            // Apartado de información con sombreado temático
            VStack(spacing: 8) {
                Text("\(result.currencySymbol) \(FormatHelper.formatCurrency(result.amount))")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(theme == .electricBlack ? Color.white : theme.accentTextColor)
                    .contrastTextOutline()
                
                HStack(spacing: 6) {
                    Text(result.sourceWalletName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.95))
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme == .electricBlack ? Color.white : theme.accentIconColor)
                    
                    Text(result.destinationWalletName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.95))
                }
                .contrastTextOutline()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: "#121828"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                (theme == .electricBlack ? Color.white : theme.primary).opacity(0.25),
                                lineWidth: 1
                            )
                    )
            )
            
            // Botón Aceptar con estilo y colores acordes al tema activo
            Button(action: onDismiss) {
                Text("Aceptar")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(theme == .electricBlack ? Color.black : theme.onPrimaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: theme == .electricBlack ? [Color.white, Color(hex: "#E2E8F0")] : theme.gradient,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(
                        color: theme == .electricBlack ?
                            Color.white.opacity(0.12) :
                            theme.primary.opacity(0.35),
                        radius: 7, x: 0, y: 2
                    )
            }
            .padding(.top, 2)
        }
        .padding(22)
        .background(
            ZStack {
                // 1. Base 100% sólida opaca para evitar transparencias indeseadas
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(hex: "#0A0E1A"))
                
                // 2. Degradado temático profundo y nítido
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                (theme == .electricBlack ? Color(hex: "#1E2230") : theme.primary).opacity(0.24),
                                Color(hex: "#0E1424"),
                                Color(hex: "#080B14")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // 3. Relieve perimetral luminoso nítido
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                (theme == .electricBlack ? Color.white : theme.primary).opacity(0.65),
                                (theme == .electricBlack ? Color.white.opacity(0.3) : theme.secondary).opacity(0.25)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(
            color: Color.black.opacity(0.85),
            radius: 24, x: 0, y: 8
        )
        .padding(20)
    }
}

// Diálogo de detalles de transferencia irrevocable
public struct TransferMovementDetailsDialog: View {
    let transaction: Transaction
    let currencySymbol: String
    var theme: AppColorTheme = .electricBlue
    let onDismiss: () -> Void
    
    public init(transaction: Transaction, currencySymbol: String, theme: AppColorTheme = .electricBlue, onDismiss: @escaping () -> Void) {
        self.transaction = transaction
        self.currencySymbol = currencySymbol
        self.theme = theme
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                ThemedModalBackground(theme: theme)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Header Card
                        HStack(spacing: 12) {
                            Circle()
                                .fill((theme == .electricBlack ? Color.white : theme.primary).opacity(0.18))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Image(systemName: "arrow.left.arrow.right")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(theme == .electricBlack ? Color.white : theme.primary)
                                }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(transaction.title)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(AppColors.textPrimary)
                                    .contrastTextOutline()
                                
                                Text("Transferencia entre Billeteras")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppColors.textSecondary)
                                    .contrastTextOutline()
                            }
                            
                            Spacer()
                        }
                        .padding(14)
                        .background(ThemedCardBackgroundView(theme: theme, cornerRadius: 14))
                        
                        // Movement Info Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Monto:")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppColors.textSecondary)
                                    .contrastTextOutline()
                                Spacer()
                                Text("\(currencySymbol) \(FormatHelper.formatCurrency(transaction.amount))")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppColors.textPrimary)
                                    .contrastTextOutline()
                            }
                            
                            Divider().background(AppColors.cardBorderNavy)
                            
                            HStack {
                                Text("Tipo:")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppColors.textSecondary)
                                    .contrastTextOutline()
                                Spacer()
                                Text(transaction.type == .income ? "Transferencia Recibida" : "Transferencia Enviada")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(transaction.type == .income ? AppColors.incomeEmeraldLight : AppColors.expenseRoseLight)
                                    .contrastTextOutline()
                            }
                            
                            if !transaction.notes.isEmpty {
                                Divider().background(AppColors.cardBorderNavy)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Detalle / Nota:")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(AppColors.textSecondary)
                                        .contrastTextOutline()
                                    Text(AiExpenseParser.formatSpokenNoteToDigits(transaction.notes))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(AppColors.textPrimary)
                                        .contrastTextOutline()
                                }
                            }
                        }
                        .padding(16)
                        .background(ThemedCardBackgroundView(theme: theme, cornerRadius: 14))
                        
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.textMuted)
                            Text("Las transferencias son movimientos que no pueden ser alterados, modificados o eliminados.")
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.textMuted)
                        }
                        .padding(.horizontal, 4)
                        
                        Button(action: onDismiss) {
                            Text("Cerrar")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(AppColors.navySurfaceVariant)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.top, 4)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Detalle del Movimiento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") {
                        onDismiss()
                    }
                    .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .presentationDetents([.fraction(0.52)])
        .presentationDragIndicator(.visible)
    }
}

