import SwiftUI

public struct TransactionItemCard: View {
    let transaction: Transaction
    let currencySymbol: String
    let isHidden: Bool
    var theme: AppColorTheme = .electricBlue
    let onTap: () -> Void
    let onDelete: () -> Void
    
    private var formattedDate: String {
        FormatHelper.formatTransactionDate(transaction.dateMillis)
    }
    
    public init(
        transaction: Transaction,
        currencySymbol: String,
        isHidden: Bool = false,
        theme: AppColorTheme = .electricBlue,
        onTap: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.transaction = transaction
        self.currencySymbol = currencySymbol
        self.isHidden = isHidden
        self.theme = theme
        self.onTap = onTap
        self.onDelete = onDelete
    }
    
    public var body: some View {
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
            
            // Transaction Details (Title & Category in single line)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(transaction.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .contrastTextOutline()
                        .lineLimit(1)
                    
                    if transaction.isIrrevocableMovement() {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.textMuted)
                    } else if transaction.isFixedExpensePayment() {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 10))
                            .foregroundStyle(Color(hex: "#38BDF8"))
                    }
                }
                
                // Texto de la categoría en una sola línea completa
                Text(transaction.category)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                    .contrastTextOutline()
                    .lineLimit(1)
                
                if !transaction.notes.isEmpty {
                    Text(AiExpenseParser.formatSpokenNoteToDigits(transaction.notes))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(AppColors.textMuted)
                        .contrastTextOutline()
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(0)
            
            Spacer(minLength: 8)
            
            // Amount Display, Date/Time & 3-Dots Action Menu
            HStack(spacing: 6) {
                VStack(alignment: .trailing, spacing: 3) {
                    if isHidden {
                        Text("••••••")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                            .contrastTextOutline()
                    } else {
                        let sign = transaction.type == .income ? "+" : "-"
                        let amountColor = transaction.type == .income ? AppColors.incomeEmeraldLight : AppColors.expenseRoseLight
                        
                        Text("\(sign)\(currencySymbol) \(FormatHelper.formatCurrency(transaction.amount))")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(amountColor)
                            .contrastTextOutline()
                            .lineLimit(1)
                    }
                    
                    // Fecha y hora pasadas al lado derecho, justo debajo del monto, sin reducir tamaño ni recortar
                    Text(formattedDate)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                        .contrastTextOutline()
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .layoutPriority(1)
                
                // Botón flotante de 3 puntos verticales
                Menu {
                    if transaction.isIrrevocableMovement() {
                        Button {
                            onTap()
                        } label: {
                            Label("Ver detalles de transferencia", systemImage: "info.circle")
                        }
                    } else if transaction.isFixedExpensePayment() {
                        // Un gasto fijo pagado NO se puede editar, SOLO se puede eliminar
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Eliminar movimiento", systemImage: "trash")
                        }
                    } else {
                        Button {
                            onTap()
                        } label: {
                            Label("Editar movimiento", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Eliminar movimiento", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(width: 26, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            ThemedCardBackgroundView(theme: theme, cornerRadius: 14)
        )
        .compositingGroup()
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            if transaction.isIrrevocableMovement() {
                Button(action: onTap) {
                    Label("Ver detalles de transferencia", systemImage: "info.circle")
                }
            } else if transaction.isFixedExpensePayment() {
                // Un gasto fijo pagado NO se puede editar, SOLO se puede eliminar
                Button(role: .destructive, action: onDelete) {
                    Label("Eliminar movimiento", systemImage: "trash")
                }
            } else {
                Button(action: onTap) {
                    Label("Editar movimiento", systemImage: "pencil")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Eliminar movimiento", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Equatable para Descarte Instantáneo de Redibujado a 120 FPS
extension TransactionItemCard: Equatable {
    public static func == (lhs: TransactionItemCard, rhs: TransactionItemCard) -> Bool {
        lhs.transaction.id == rhs.transaction.id &&
        lhs.transaction.title == rhs.transaction.title &&
        lhs.transaction.amount == rhs.transaction.amount &&
        lhs.transaction.typeRaw == rhs.transaction.typeRaw &&
        lhs.transaction.category == rhs.transaction.category &&
        lhs.transaction.dateMillis == rhs.transaction.dateMillis &&
        lhs.transaction.notes == rhs.transaction.notes &&
        lhs.transaction.isIrrevocable == rhs.transaction.isIrrevocable &&
        lhs.currencySymbol == rhs.currencySymbol &&
        lhs.isHidden == rhs.isHidden &&
        lhs.theme == rhs.theme
    }
}
