import SwiftUI

public struct TransactionItemCard: View {
    let transaction: Transaction
    let currencySymbol: String
    let isHidden: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    
    private var formattedDate: String {
        let date = Date(timeIntervalSince1970: Double(transaction.dateMillis) / 1000.0)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.dateFormat = "dd MMM, hh:mm a"
        return formatter.string(from: date)
    }
    
    public init(
        transaction: Transaction,
        currencySymbol: String,
        isHidden: Bool = false,
        onTap: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.transaction = transaction
        self.currencySymbol = currencySymbol
        self.isHidden = isHidden
        self.onTap = onTap
        self.onDelete = onDelete
    }
    
    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Category Icon
                let iconSymbol = CategoryHelper.getCategoryIcon(name: transaction.category, type: transaction.type)
                let color = CategoryHelper.getCategoryColor(name: transaction.category, type: transaction.type)
                
                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: iconSymbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(color)
                    }
                
                // Transaction Details (Title, Category, Notes, Date)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(transaction.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(1)
                        
                        if transaction.isIrrevocableMovement() {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(AppColors.textMuted)
                        }
                    }
                    
                    HStack(spacing: 6) {
                        Text(transaction.category)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(color)
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.textMuted)
                        
                        Text(formattedDate)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    
                    if !transaction.notes.isEmpty {
                        Text(transaction.notes)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(AppColors.textMuted)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Amount Display
                VStack(alignment: .trailing, spacing: 2) {
                    if isHidden {
                        Text("••••••")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                    } else {
                        let sign = transaction.type == .income ? "+" : "-"
                        let amountColor = transaction.type == .income ? AppColors.incomeEmeraldLight : AppColors.expenseRoseLight
                        
                        Text("\(sign)\(currencySymbol) \(FormatHelper.formatCurrency(transaction.amount))")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(amountColor)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.darkNavySurface.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppColors.cardBorderNavy.opacity(0.6), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !transaction.isIrrevocableMovement() {
                Button(action: onTap) {
                    Label("Editar movimiento", systemImage: "pencil")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Eliminar movimiento", systemImage: "trash")
                }
            } else {
                Button(action: onTap) {
                    Label("Ver detalles de transferencia", systemImage: "info.circle")
                }
            }
        }
    }
}
