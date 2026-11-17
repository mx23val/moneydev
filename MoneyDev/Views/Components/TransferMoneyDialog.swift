import SwiftUI

public struct TransferMoneyDialog: View {
    @Bindable var viewModel: ExpenseViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var sourceWalletId: Int64
    @State private var destinationWalletId: Int64
    @State private var amountString: String = ""
    @State private var errorMessage: String? = nil
    
    public init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
        let activeId = viewModel.activeWallet?.id ?? viewModel.financialSummary.activeWalletId
        let otherWallet = viewModel.wallets.first(where: { $0.id != activeId })
        _sourceWalletId = State(initialValue: activeId)
        _destinationWalletId = State(initialValue: otherWallet?.id ?? activeId)
    }
    
    private var sourceWallet: Wallet? {
        viewModel.wallets.first(where: { $0.id == sourceWalletId })
    }
    
    private var destinationWallet: Wallet? {
        viewModel.wallets.first(where: { $0.id == destinationWalletId })
    }
    
    private var sourceAvailableBalance: Double {
        viewModel.walletBalances[sourceWalletId] ?? 0.0
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AppColors.midnightBlack.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Header Card
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: "#38BDF8").opacity(0.2))
                            .frame(width: 48, height: 48)
                            .overlay {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(Color(hex: "#38BDF8"))
                            }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Transferir entre Billeteras")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(AppColors.textPrimary)
                            
                            Text("Mueve saldo entre tus diferentes cuentas al instante")
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.darkNavySurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    // Selector Billetera Emisora (De)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Desde (Billetera Emisora)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                        
                        Menu {
                            ForEach(viewModel.wallets) { w in
                                Button {
                                    sourceWalletId = w.id
                                    if destinationWalletId == w.id {
                                        if let other = viewModel.wallets.first(where: { $0.id != w.id }) {
                                            destinationWalletId = other.id
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(w.name)
                                        if sourceWalletId == w.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Color(hex: sourceWallet?.colorHex ?? "#38BDF8"))
                                    .frame(width: 12, height: 12)
                                
                                Text(sourceWallet?.name ?? "Seleccionar")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppColors.textPrimary)
                                
                                Spacer()
                                
                                Text("Saldo: \(sourceWallet?.currencySymbol ?? "S/") \(FormatHelper.formatCurrency(sourceAvailableBalance))")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AppColors.incomeEmeraldLight)
                                
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppColors.textMuted)
                            }
                            .padding(14)
                            .background(AppColors.darkNavySurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(AppColors.cardBorderNavy, lineWidth: 1)
                            )
                        }
                    }
                    
                    // Flecha de intercambio
                    Image(systemName: "arrow.down")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "#38BDF8"))
                        .frame(width: 36, height: 36)
                        .background(AppColors.navySurfaceVariant)
                        .clipShape(Circle())
                    
                    // Selector Billetera Receptora (A)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hacia (Billetera Receptora)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                        
                        Menu {
                            ForEach(viewModel.wallets.filter { $0.id != sourceWalletId }) { w in
                                Button {
                                    destinationWalletId = w.id
                                } label: {
                                    HStack {
                                        Text(w.name)
                                        if destinationWalletId == w.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Color(hex: destinationWallet?.colorHex ?? "#00FF87"))
                                    .frame(width: 12, height: 12)
                                
                                Text(destinationWallet?.name ?? "Seleccionar destino")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppColors.textPrimary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppColors.textMuted)
                            }
                            .padding(14)
                            .background(AppColors.darkNavySurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(AppColors.cardBorderNavy, lineWidth: 1)
                            )
                        }
                    }
                    
                    // Monto a Transferir
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Monto a Transferir")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                        
                        HStack(spacing: 4) {
                            Text(sourceWallet?.currencySymbol ?? "S/")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#38BDF8"))
                            
                            TextField("0.00", text: $amountString)
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundStyle(AppColors.textPrimary)
                                .keyboardType(.decimalPad)
                        }
                        .padding(14)
                        .background(AppColors.darkNavySurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppColors.cardBorderNavy, lineWidth: 1)
                        )
                    }
                    
                    if let errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(AppColors.expenseRose)
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppColors.expenseRoseLight)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.expenseBg.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    Spacer()
                    
                    // Botón Confirmar Transferencia
                    Button {
                        executeTransfer()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Confirmar Transferencia")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#00D2FF"), Color(hex: "#1D4ED8")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(20)
            }
            .navigationTitle("Transferencia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") {
                        viewModel.closeTransferDialog()
                        dismiss()
                    }
                    .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func executeTransfer() {
        let clean = amountString.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let amount = Double(clean), amount > 0 else {
            errorMessage = "Ingresa un monto válido mayor a 0."
            return
        }
        
        let (success, error) = viewModel.executeTransfer(
            sourceWalletId: sourceWalletId,
            destinationWalletId: destinationWalletId,
            amount: amount
        )
        
        if success {
            dismiss()
        } else {
            errorMessage = error ?? "Error al procesar la transferencia."
        }
    }
}
