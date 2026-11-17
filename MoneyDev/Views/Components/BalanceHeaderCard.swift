import SwiftUI

public struct BalanceHeaderCard: View {
    @Bindable var viewModel: ExpenseViewModel
    let onTransferClick: () -> Void
    let onAddExpenseClick: () -> Void
    let onAddIncomeClick: () -> Void
    let onVoiceClick: () -> Void
    
    private var activeTheme: AppColorTheme {
        AppColorTheme.fromId(viewModel.financialSummary.themeColorId)
    }
    
    public init(
        viewModel: ExpenseViewModel,
        onTransferClick: @escaping () -> Void,
        onAddExpenseClick: @escaping () -> Void,
        onAddIncomeClick: @escaping () -> Void,
        onVoiceClick: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onTransferClick = onTransferClick
        self.onAddExpenseClick = onAddExpenseClick
        self.onAddIncomeClick = onAddIncomeClick
        self.onVoiceClick = onVoiceClick
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header Top Bar: Wallet Name + Eye button
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(activeTheme.primary)
                    
                    Text(viewModel.financialSummary.activeWalletName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                    
                    if viewModel.wallets.count > 1 {
                        Text("(\(viewModel.wallets.count))")
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
                
                if viewModel.isBalanceHidden {
                    Text("••••••••")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(viewModel.financialSummary.currencySymbol)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(activeTheme.primary)
                        
                        Text(FormatHelper.formatCurrency(viewModel.financialSummary.currentBalance))
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Income / Expense Summary Badges
            HStack(spacing: 12) {
                // Total Income
                HStack(spacing: 10) {
                    Circle()
                        .fill(AppColors.incomeEmerald.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "arrow.down.left")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppColors.incomeEmerald)
                        }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ingresos")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                        
                        Text(viewModel.isBalanceHidden ? "••••" : "+\(viewModel.financialSummary.currencySymbol)\(FormatHelper.formatCurrency(viewModel.financialSummary.totalIncome))")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.incomeEmeraldLight)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.navySurfaceVariant.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Total Expense
                HStack(spacing: 10) {
                    Circle()
                        .fill(AppColors.expenseRose.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppColors.expenseRose)
                        }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gastos")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                        
                        Text(viewModel.isBalanceHidden ? "••••" : "-\(viewModel.financialSummary.currencySymbol)\(FormatHelper.formatCurrency(viewModel.financialSummary.totalExpense))")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.expenseRoseLight)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.navySurfaceVariant.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Quick Actions Buttons Row
            HStack(spacing: 10) {
                // Botón Dictado por Voz
                Button(action: onVoiceClick) {
                    HStack(spacing: 6) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Voz")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(
                        LinearGradient(colors: activeTheme.gradient, startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Botón Gasto
                Button(action: onAddExpenseClick) {
                    HStack(spacing: 6) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Gasto")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(AppColors.expenseRoseLight)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(AppColors.expenseBg.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.expenseRose.opacity(0.4), lineWidth: 1)
                    )
                }
                
                // Botón Ingreso
                Button(action: onAddIncomeClick) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Ingreso")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(AppColors.incomeEmeraldLight)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(AppColors.incomeBg.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.incomeEmerald.opacity(0.4), lineWidth: 1)
                    )
                }
                
                // Botón Transferir
                Button(action: onTransferClick) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(width: 42, height: 42)
                        .background(AppColors.navySurfaceVariant.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.cardBorderNavy, lineWidth: 1)
                        )
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppColors.darkNavySurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppColors.cardBorderNavy, lineWidth: 1.2)
                )
        )
    }
}
