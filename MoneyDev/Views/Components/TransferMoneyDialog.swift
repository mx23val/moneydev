import SwiftUI

public struct TransferMoneyDialog: View {
    @Bindable var viewModel: ExpenseViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var sourceWalletId: Int64
    @State private var destinationWalletId: Int64?
    @State private var amountString: String = ""
    @State private var detailString: String = ""
    @State private var errorMessage: String? = nil
    @State private var isTransferring: Bool = false
    
    public init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
        let activeId = viewModel.activeWallet?.id ?? viewModel.financialSummary.activeWalletId
        _sourceWalletId = State(initialValue: activeId)
        _destinationWalletId = State(initialValue: nil)
    }
    
    private var sourceWallet: Wallet? {
        viewModel.wallets.first(where: { $0.id == sourceWalletId })
    }
    
    private var destinationWallet: Wallet? {
        guard let id = destinationWalletId else { return nil }
        return viewModel.wallets.first(where: { $0.id == id })
    }
    
    private var sourceAvailableBalance: Double {
        viewModel.walletBalances[sourceWalletId] ?? 0.0
    }
    
    private var activeTheme: AppColorTheme {
        viewModel.activeTheme
    }
    
    private var transferCardBackground: some View {
        ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 14)
            .shadow(
                color: activeTheme == .electricBlack ?
                    Color.white.opacity(0.10) :
                    activeTheme.primary.opacity(0.28),
                radius: 8, x: 0, y: 3
            )
    }
    
    private func transferInputFieldBackground(isFocused: Bool = false) -> some View {
        ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 14)
            .shadow(
                color: activeTheme == .electricBlack ?
                    (isFocused ? Color.white.opacity(0.30) : Color.white.opacity(0.08)) :
                    (isFocused ? activeTheme.primary.opacity(0.48) : activeTheme.primary.opacity(0.26)),
                radius: isFocused ? 10 : 7,
                x: 0,
                y: isFocused ? 3 : 2
            )
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                ThemedModalBackground(theme: activeTheme)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        // Header Card compacto con alto contraste
                        HStack(spacing: 12) {
                            Circle()
                                .fill(activeTheme == .electricBlack ? Color.white : activeTheme.primary.opacity(0.2))
                                .frame(width: 36, height: 36)
                                .overlay {
                                    Image(systemName: "arrow.left.arrow.right")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(activeTheme == .electricBlack ? Color.black : activeTheme.primary)
                                }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Transferir entre Billeteras")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.white)
                                    .contrastTextOutline()
                                
                                Text("Mueve saldo entre tus diferentes cuentas al instante")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.85))
                                    .contrastTextOutline()
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(transferCardBackground)
                        
                        // Selector Billetera Emisora (De)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Desde (Billetera Emisora)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.white)
                                .contrastTextOutline()
                            
                            Menu {
                                ForEach(viewModel.wallets) { w in
                                    Button {
                                        sourceWalletId = w.id
                                        if destinationWalletId == w.id {
                                            destinationWalletId = nil
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
                                        .frame(width: 11, height: 11)
                                    
                                    Text(sourceWallet?.name ?? "Seleccionar")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.white)
                                        .contrastTextOutline()
                                    
                                    Spacer()
                                    
                                    Text("Saldo: \(sourceWallet?.currencySymbol ?? "S/") \(FormatHelper.formatCurrency(sourceAvailableBalance))")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(AppColors.incomeEmeraldLight)
                                        .contrastTextOutline()
                                    
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.primary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 13)
                                .background(transferCardBackground)
                            }
                        }
                        
                        // Flecha de intercambio
                        Image(systemName: "arrow.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(activeTheme == .electricBlack ? Color.black : Color.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(activeTheme == .electricBlack ? Color.white : activeTheme.primary)
                                    .shadow(color: Color.black.opacity(0.35), radius: 4, x: 0, y: 1)
                            )
                        
                        // Selector Billetera Receptora (A)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Hacia (Billetera Receptora)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.white)
                                .contrastTextOutline()
                            
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
                                    if let dest = destinationWallet {
                                        Circle()
                                            .fill(Color(hex: dest.colorHex))
                                            .frame(width: 11, height: 11)
                                        
                                        Text(dest.name)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(Color.white)
                                            .contrastTextOutline()
                                    } else {
                                        Circle()
                                            .fill(Color.white.opacity(0.35))
                                            .frame(width: 11, height: 11)
                                        
                                        Text("Seleccionar billetera")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.65))
                                            .contrastTextOutline()
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.primary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 13)
                                .background(transferCardBackground)
                            }
                        }
                        
                        // Monto a Transferir
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Monto a Transferir")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.white)
                                .contrastTextOutline()
                            
                            HStack(spacing: 8) {
                                Text(sourceWallet?.currencySymbol ?? "S/")
                                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                                    .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.primary)
                                    .contrastTextOutline()
                                
                                TextField(
                                    "0.00",
                                    text: $amountString,
                                    prompt: Text("0.00").foregroundStyle(Color.white.opacity(0.5))
                                )
                                    .font(.system(size: 28, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.white)
                                    .contrastTextOutline()
                                    .keyboardType(.decimalPad)
                                    .onChange(of: amountString) { _, newValue in
                                        amountString = FormatHelper.validateMoneyInput(newValue)
                                    }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(transferInputFieldBackground())
                        }
                        
                        // Detalle (Opcional)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Detalle (Opcional)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.white)
                                .contrastTextOutline()
                            
                            HStack(spacing: 8) {
                                Image(systemName: "note.text")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.primary)
                                
                                TextField(
                                    "Detalle",
                                    text: $detailString,
                                    prompt: Text("Ej. Pago de tarjeta, ahorro, etc.").foregroundStyle(Color.white.opacity(0.5))
                                )
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.white)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .background(transferInputFieldBackground())
                        }
                        
                        // Mensaje de Error con alto contraste
                        if let errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color(hex: "#FF6B81"))
                                Text(errorMessage)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.white)
                                    .contrastTextOutline(color: Color.black.opacity(0.95), radius: 1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: "#380D17"))
                            )
                            .shadow(color: Color(hex: "#FF4D6D").opacity(0.35), radius: 8, x: 0, y: 2)
                        }
                        
                        // Botón de Confirmación con rueda de carga animada y máximo contraste
                        Button {
                            executeTransfer()
                        } label: {
                            HStack(spacing: 10) {
                                if isTransferring {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: activeTheme == .electricBlack ? Color.black : Color.white))
                                        .scaleEffect(0.95)
                                    Text("Procesando transferencia...")
                                        .font(.system(size: 15, weight: .black))
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("Confirmar Transferencia")
                                        .font(.system(size: 15, weight: .black))
                                }
                            }
                            .foregroundStyle(activeTheme == .electricBlack ? Color.black : Color.white)
                            .contrastTextOutline(color: activeTheme == .electricBlack ? Color.clear : Color.black.opacity(0.65), radius: 0.8)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                activeTheme == .electricBlack ?
                                    AnyShapeStyle(Color.white) :
                                    AnyShapeStyle(LinearGradient(colors: activeTheme.gradient, startPoint: .leading, endPoint: .trailing))
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: activeTheme == .electricBlack ? Color.white.opacity(0.35) : activeTheme.primary.opacity(0.4), radius: 8, x: 0, y: 2)
                        }
                        .disabled(isTransferring)
                        .padding(.top, 4)
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                }
                .scrollDismissesKeyboard(.interactively)
                
                // Notificación Flotante Superior
                if let toast = viewModel.floatingToast {
                    VStack {
                        FloatingToastView(toast: toast, theme: activeTheme) {
                            viewModel.dismissFloatingToast()
                        }
                        .padding(.top, 6)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(200)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Transferencia")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.white)
                        .contrastTextOutline()
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        viewModel.closeTransferDialog()
                        dismiss()
                    }
                    .foregroundStyle(Color.white)
                }
            }
            .keyboardDismissArrow()
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.fraction(0.75), .large])
        .presentationDragIndicator(.visible)
    }
    
    private func executeTransfer() {
        guard !isTransferring else { return }
        
        guard let destId = destinationWalletId else {
            errorMessage = "Selecciona una billetera receptora."
            viewModel.showFloatingToast(title: "Billetera Requerida", message: "Debes seleccionar una billetera receptora para la transferencia.", isSuccess: false, duration: 4.0)
            return
        }
        
        let clean = amountString.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let amount = Double(clean), amount > 0 else {
            errorMessage = "Ingresa un monto válido mayor a 0."
            viewModel.showFloatingToast(title: "Monto Requerido", message: "Ingresa un monto válido a transferir mayor a 0.", isSuccess: false, duration: 4.0)
            return
        }
        
        errorMessage = nil
        isTransferring = true
        
        Task { @MainActor in
            // Demora 1 segundo mostrando la rueda de carga animada
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            let (success, error) = viewModel.executeTransfer(
                sourceWalletId: sourceWalletId,
                destinationWalletId: destId,
                amount: amount,
                detail: detailString.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            if success {
                dismiss()
            } else {
                isTransferring = false
                errorMessage = error ?? "Error al procesar la transferencia."
                viewModel.showFloatingToast(title: "Error en Transferencia", message: error ?? "No se pudo realizar la transferencia.", isSuccess: false, duration: 4.0)
            }
        }
    }
}
