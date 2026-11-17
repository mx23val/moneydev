import SwiftUI

public struct BalanceHeaderCard: View {
    @Bindable var viewModel: ExpenseViewModel
    let onTransferClick: () -> Void
    let onAddExpenseClick: () -> Void
    let onAddIncomeClick: () -> Void
    let onVoiceClick: (() -> Void)?
    
    private var activeTheme: AppColorTheme {
        AppColorTheme.fromId(viewModel.financialSummary.themeColorId)
    }
    
    public init(
        viewModel: ExpenseViewModel,
        onTransferClick: @escaping () -> Void,
        onAddExpenseClick: @escaping () -> Void,
        onAddIncomeClick: @escaping () -> Void,
        onVoiceClick: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onTransferClick = onTransferClick
        self.onAddExpenseClick = onAddExpenseClick
        self.onAddIncomeClick = onAddIncomeClick
        self.onVoiceClick = onVoiceClick
    }
    
    private var activeWalletNumber: Int {
        let activeId = viewModel.activeWallet?.id ?? viewModel.financialSummary.activeWalletId
        if let index = viewModel.wallets.firstIndex(where: { $0.id == activeId }) {
            return index + 1
        }
        return 1
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header Top Bar: Wallet Name + Eye button
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(activeTheme.accentIconColor)
                    
                    Text(viewModel.financialSummary.activeWalletName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                    
                    if viewModel.wallets.count > 1 {
                        Text("(\(activeWalletNumber))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                
                Spacer()
                
                Button {
                    withAnimation(.spring) {
                        viewModel.toggleHideBalance()
                    }
                } label: {
                    Image(systemName: viewModel.isBalanceHidden ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(AppColors.navySurfaceVariant.opacity(0.6))
                        .clipShape(Circle())
                }
            }
            
            // Current Balance Display
            VStack(alignment: .leading, spacing: 4) {
                Text("Saldo Total Disponible")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(viewModel.financialSummary.currencySymbol)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(activeTheme.accentIconColor)
                    
                    if viewModel.isBalanceHidden {
                        Text("******")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                    } else {
                        Text(FormatHelper.formatCurrency(viewModel.financialSummary.currentBalance))
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Income / Expense Summary Badges
            HStack(spacing: 10) {
                // Total Income
                HStack(spacing: 8) {
                    Circle()
                        .fill(AppColors.incomeEmerald.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppColors.incomeEmerald)
                        }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ingresos")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                        
                        Text(viewModel.isBalanceHidden ? "+\(viewModel.financialSummary.currencySymbol) ****" : "+\(viewModel.financialSummary.currencySymbol)\(FormatHelper.formatCurrency(viewModel.financialSummary.totalIncome))")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.incomeEmeraldLight)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.navySurfaceVariant.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Total Expense
                HStack(spacing: 8) {
                    Circle()
                        .fill(AppColors.expenseRose.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "arrow.down.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppColors.expenseRose)
                        }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gastos")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                        
                        Text(viewModel.isBalanceHidden ? "-\(viewModel.financialSummary.currencySymbol) ****" : "-\(viewModel.financialSummary.currencySymbol)\(FormatHelper.formatCurrency(viewModel.financialSummary.totalExpense))")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.expenseRoseLight)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.navySurfaceVariant.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Fila de 3 Acciones Rápidas Proporcionadas (Gasto, Ingreso, Transferir)
            HStack(spacing: 8) {
                // 1. Botón Gasto
                actionCardButton(
                    title: "Gasto",
                    icon: "minus.circle.fill",
                    textColor: AppColors.expenseRoseLight,
                    bgColor: AppColors.expenseBg.opacity(0.65),
                    borderColor: AppColors.expenseRose.opacity(0.4),
                    action: onAddExpenseClick
                )
                
                // 2. Botón Ingreso
                actionCardButton(
                    title: "Ingreso",
                    icon: "plus.circle.fill",
                    textColor: AppColors.incomeEmeraldLight,
                    bgColor: AppColors.incomeBg.opacity(0.65),
                    borderColor: AppColors.incomeEmerald.opacity(0.4),
                    action: onAddIncomeClick
                )
                
                // 3. Botón Transferir
                actionCardButton(
                    title: "Transferir",
                    icon: "arrow.left.arrow.right",
                    textColor: activeTheme.accentIconColor,
                    bgColor: activeTheme == .electricBlack ? Color(hex: "#1E293B").opacity(0.5) : activeTheme.primary.opacity(0.12),
                    borderColor: activeTheme == .electricBlack ? Color.white.opacity(0.15) : activeTheme.primary.opacity(0.35),
                    action: onTransferClick
                )
            }
        }
        .padding(18)
        .background(
            ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 20)
        )
        .shadow(
            color: Color.black.opacity(0.35),
            radius: 8,
            x: 0,
            y: 4
        )
    }
    
    // MARK: - Helper para Botones de Acción Rápida con Proporción Perfecta (1/3 Ancho)
    private func actionCardButton(
        title: String,
        icon: String,
        textColor: Color,
        bgColor: Color,
        borderColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .contrastTextOutline()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 1.5)
        }
        .buttonStyle(.plain)
    }
}
