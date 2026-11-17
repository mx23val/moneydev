import SwiftUI

// Diálogo de confirmación de transferencia exitosa
public struct TransferSuccessDialog: View {
    let result: TransferResult
    let onDismiss: () -> Void
    
    public var body: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(AppColors.incomeEmerald.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(AppColors.incomeEmeraldLight)
                }
            
            Text("¡Transferencia Exitosa!")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
            
            VStack(spacing: 6) {
                Text("\(result.currencySymbol) \(FormatHelper.formatCurrency(result.amount))")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "#38BDF8"))
                
                Text("De: \(result.sourceWalletName) ➔ Para: \(result.destinationWalletName)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(AppColors.darkNavySurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            
            Button(action: onDismiss) {
                Text("Aceptar")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color(hex: "#38BDF8"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(24)
        .background(AppColors.midnightBlack)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(24)
    }
}

// Diálogo de detalles de transferencia irrevocable
public struct TransferMovementDetailsDialog: View {
    let transaction: Transaction
    let currencySymbol: String
    let onDismiss: () -> Void
    
    public var body: some View {
        VStack(spacing: 16) {
            HStack {
                Circle()
                    .fill(Color(hex: "#38BDF8").opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(hex: "#38BDF8"))
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(transaction.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                    
                    Text("Movimiento de Transferencia")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textSecondary)
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Monto:")
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Text("\(currencySymbol) \(FormatHelper.formatCurrency(transaction.amount))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                }
                
                HStack {
                    Text("Tipo:")
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Text(transaction.type == .income ? "Transferencia Recibida" : "Transferencia Enviada")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(transaction.type == .income ? AppColors.incomeEmeraldLight : AppColors.expenseRoseLight)
                }
                
                if !transaction.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nota:")
                            .foregroundStyle(AppColors.textSecondary)
                        Text(transaction.notes)
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }
            }
            .padding()
            .background(AppColors.darkNavySurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textMuted)
                Text("Las transferencias son irrevocables para proteger la consistencia de los saldos.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.textMuted)
            }
            
            Button(action: onDismiss) {
                Text("Cerrar")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppColors.navySurfaceVariant)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .background(AppColors.midnightBlack)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(20)
    }
}
