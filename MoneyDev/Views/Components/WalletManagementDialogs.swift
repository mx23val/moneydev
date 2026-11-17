import SwiftUI

// MARK: - Add Wallet Dialog
public struct AddWalletDialog: View {
    @Bindable var viewModel: ExpenseViewModel
    let onDismiss: () -> Void
    let onConfirm: (String, Double, String, String) -> Void
    
    @State private var name: String = ""
    @State private var balanceText: String = ""
    @State private var currency: String = "S/"
    @State private var selectedColor: String = "#00D2FF"
    @State private var errorMessage: String? = nil
    
    private let availableColors = ["#00D2FF", "#00FF87", "#FF7A00", "#A855F7", "#FF3B30", "#CBD5E1", "#38BDF8", "#F59E0B"]
    private let currencies = ["S/", "$", "€", "MXN", "COP", "CLP", "ARS"]
    
    public init(
        viewModel: ExpenseViewModel,
        onDismiss: @escaping () -> Void,
        onConfirm: @escaping (String, Double, String, String) -> Void
    ) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        self.onConfirm = onConfirm
    }
    
    private var isAtWalletLimit: Bool {
        !viewModel.isProUser && viewModel.wallets.count >= 3
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AppColors.midnightBlack.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    if isAtWalletLimit {
                        VStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: "#F59E0B").opacity(0.2))
                                .frame(width: 56, height: 56)
                                .overlay {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 26))
                                        .foregroundStyle(Color(hex: "#F59E0B"))
                                }
                            
                            Text("Límite de Billeteras Alcanzado")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(AppColors.textPrimary)
                            
                            Text("En el plan gratuito puedes crear hasta 3 billeteras. Para crear billeteras ilimitadas, activa el Modo PRO.")
                                .font(.system(size: 13))
                                .foregroundStyle(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                            
                            Button {
                                onDismiss()
                                viewModel.setActiveTab(1) // Ir a Modo PRO
                            } label: {
                                Text("Ver Modo PRO")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 46)
                                    .background(Color(hex: "#F59E0B"))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.top, 8)
                        }
                        .padding(20)
                        .background(AppColors.darkNavySurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        // Formulario de Nueva Billetera
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Nombre de la Billetera")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppColors.textSecondary)
                                
                                TextField("Ej: Cuenta Sueldo BCP, Efectivo...", text: $name)
                                    .font(.system(size: 15))
                                    .foregroundStyle(AppColors.textPrimary)
                                    .padding(12)
                                    .background(AppColors.darkNavySurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AppColors.cardBorderNavy, lineWidth: 1)
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Moneda")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppColors.textSecondary)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(currencies, id: \.self) { c in
                                            Button {
                                                currency = c
                                            } label: {
                                                Text(c)
                                                    .font(.system(size: 13, weight: currency == c ? .bold : .medium))
                                                    .foregroundStyle(currency == c ? .white : AppColors.textPrimary)
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 7)
                                                    .background(currency == c ? Color(hex: "#38BDF8") : AppColors.darkNavySurface)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Saldo Inicial")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppColors.textSecondary)
                                
                                HStack(spacing: 6) {
                                    Text(currency)
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color(hex: "#38BDF8"))
                                    
                                    TextField("0.00", text: $balanceText)
                                        .font(.system(size: 26, weight: .black, design: .rounded))
                                        .foregroundStyle(AppColors.textPrimary)
                                        .keyboardType(.decimalPad)
                                }
                                .padding(12)
                                .background(AppColors.darkNavySurface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppColors.cardBorderNavy, lineWidth: 1)
                                )
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Color Identificador")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppColors.textSecondary)
                                
                                HStack(spacing: 10) {
                                    ForEach(availableColors, id: \.self) { c in
                                        Circle()
                                            .fill(Color(hex: c))
                                            .frame(width: 30, height: 30)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: selectedColor == c ? 2.5 : 0)
                                            )
                                            .onTapGesture {
                                                selectedColor = c
                                            }
                                    }
                                }
                            }
                            
                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppColors.expenseRoseLight)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            submit()
                        } label: {
                            Text("Crear Billetera")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color(hex: "#38BDF8"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Nueva Billetera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar", action: onDismiss)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func submit() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            errorMessage = "Ingresa un nombre para la billetera."
            return
        }
        let cleanBal = balanceText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        let amount = Double(cleanBal) ?? 0.0
        onConfirm(cleanName, amount, currency, selectedColor)
        onDismiss()
    }
}

// MARK: - Edit Wallet Dialog
public struct EditWalletDialog: View {
    let wallet: Wallet
    let canDelete: Bool
    let onDismiss: () -> Void
    let onSave: (String, Double, String, String) -> Void
    let onDelete: () -> Void
    let onClearTransactions: () -> Void
    
    @State private var name: String
    @State private var balanceText: String
    @State private var currency: String
    @State private var selectedColor: String
    @State private var showConfirmDelete: Bool = false
    @State private var showConfirmClear: Bool = false
    
    private let availableColors = ["#00D2FF", "#00FF87", "#FF7A00", "#A855F7", "#FF3B30", "#CBD5E1", "#38BDF8", "#F59E0B"]
    
    public init(
        wallet: Wallet,
        canDelete: Bool = true,
        onDismiss: @escaping () -> Void,
        onSave: @escaping (String, Double, String, String) -> Void,
        onDelete: @escaping () -> Void,
        onClearTransactions: @escaping () -> Void
    ) {
        self.wallet = wallet
        self.canDelete = canDelete
        self.onDismiss = onDismiss
        self.onSave = onSave
        self.onDelete = onDelete
        self.onClearTransactions = onClearTransactions
        _name = State(initialValue: wallet.name)
        _balanceText = State(initialValue: String(format: "%.2f", wallet.initialBalance))
        _currency = State(initialValue: wallet.currencySymbol)
        _selectedColor = State(initialValue: wallet.colorHex)
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AppColors.midnightBlack.ignoresSafeArea()
                
                Form {
                    Section("Datos de la Billetera") {
                        TextField("Nombre", text: $name)
                            .foregroundStyle(AppColors.textPrimary)
                        
                        HStack {
                            Text("Saldo Inicial")
                                .foregroundStyle(AppColors.textSecondary)
                            Spacer()
                            TextField("0.00", text: $balanceText)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .foregroundStyle(AppColors.textPrimary)
                        }
                        
                        Picker("Moneda", selection: $currency) {
                            ForEach(["S/", "$", "€", "MXN", "COP", "CLP", "ARS"], id: \.self) { c in
                                Text(c).tag(c)
                            }
                        }
                    }
                    .listRowBackground(AppColors.darkNavySurface)
                    
                    Section("Color") {
                        HStack(spacing: 10) {
                            ForEach(availableColors, id: \.self) { c in
                                Circle()
                                    .fill(Color(hex: c))
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle().stroke(Color.white, lineWidth: selectedColor == c ? 2.5 : 0)
                                    )
                                    .onTapGesture { selectedColor = c }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(AppColors.darkNavySurface)
                    
                    Section("Gestión de Movimientos") {
                        Button {
                            showConfirmClear = true
                        } label: {
                            Label("Limpiar movimientos de esta cuenta", systemImage: "arrow.counterclockwise")
                                .foregroundStyle(Color(hex: "#F59E0B"))
                        }
                        
                        if canDelete && !wallet.isDefault {
                            Button(role: .destructive) {
                                showConfirmDelete = true
                            } label: {
                                Label("Eliminar billetera", systemImage: "trash.fill")
                                    .foregroundStyle(AppColors.expenseRoseLight)
                            }
                        }
                    }
                    .listRowBackground(AppColors.darkNavySurface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Editar Billetera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar", action: onDismiss)
                        .foregroundStyle(AppColors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        let cleanBal = balanceText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
                        let amount = Double(cleanBal) ?? wallet.initialBalance
                        onSave(name, amount, currency, selectedColor)
                        onDismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(Color(hex: "#38BDF8"))
                }
            }
            .alert("¿Limpiar movimientos?", isPresented: $showConfirmClear) {
                Button("Limpiar", role: .destructive) {
                    onClearTransactions()
                    onDismiss()
                }
                Button("Cancelar", role: .cancel) { }
            } message: {
                Text("Se eliminarán todas las transacciones asociadas a '\(wallet.name)'. El saldo inicial se mantendrá.")
            }
            .alert("¿Eliminar billetera?", isPresented: $showConfirmDelete) {
                Button("Eliminar", role: .destructive) {
                    onDelete()
                    onDismiss()
                }
                Button("Cancelar", role: .cancel) { }
            } message: {
                Text("Se borrará la billetera '\(wallet.name)' y todos sus registros.")
            }
        }
    }
}

// MARK: - Standalone Delete Wallet Confirm Dialog
public struct DeleteWalletConfirmDialog: View {
    let wallet: Wallet
    let onConfirm: () -> Void
    let onDismiss: () -> Void
    
    public init(wallet: Wallet, onConfirm: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.wallet = wallet
        self.onConfirm = onConfirm
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        VStack(spacing: 18) {
            Circle()
                .fill(AppColors.expenseRoseLight.opacity(0.15))
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppColors.expenseRoseLight)
                }
            
            Text("¿Eliminar billetera?")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
            
            Text("Se borrará permanentemente la billetera '\(wallet.name)' y todos los movimientos asociados a ella.")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            
            HStack(spacing: 12) {
                Button("Cancelar", action: onDismiss)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppColors.darkNavySurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Button("Eliminar") {
                    onConfirm()
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(AppColors.expenseRoseLight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(22)
        .background(AppColors.darkNavySurface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppColors.cardBorderNavy, lineWidth: 1)
        )
        .padding(24)
    }
}

// MARK: - Standalone Clear Wallet Transactions Confirm Dialog
public struct ClearWalletTransactionsConfirmDialog: View {
    let wallet: Wallet
    let onConfirm: () -> Void
    let onDismiss: () -> Void
    
    public init(wallet: Wallet, onConfirm: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.wallet = wallet
        self.onConfirm = onConfirm
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        VStack(spacing: 18) {
            Circle()
                .fill(Color(hex: "#F59E0B").opacity(0.15))
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(hex: "#F59E0B"))
                }
            
            Text("¿Limpiar movimientos?")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
            
            Text("Se borrarán todos los movimientos registrados en '\(wallet.name)'. El saldo inicial de la billetera se conservará intacto.")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            
            HStack(spacing: 12) {
                Button("Cancelar", action: onDismiss)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppColors.darkNavySurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Button("Limpiar") {
                    onConfirm()
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color(hex: "#F59E0B"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(22)
        .background(AppColors.darkNavySurface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppColors.cardBorderNavy, lineWidth: 1)
        )
        .padding(24)
    }
}

// MARK: - Quick Switch Sheet
public struct WalletQuickSwitchSheet: View {
    @Bindable var viewModel: ExpenseViewModel
    let onDismiss: () -> Void
    let onAddNew: () -> Void
    let onEdit: (Wallet) -> Void
    
    public init(
        viewModel: ExpenseViewModel,
        onDismiss: @escaping () -> Void,
        onAddNew: @escaping () -> Void,
        onEdit: @escaping (Wallet) -> Void
    ) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        self.onAddNew = onAddNew
        self.onEdit = onEdit
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AppColors.midnightBlack.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mis Cuentas y Billeteras")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(AppColors.textPrimary)
                            Text("\(viewModel.wallets.count)/\(viewModel.isProUser ? "10" : "3") activas")
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.textMuted)
                        }
                        Spacer()
                        Button(action: onAddNew) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Nueva")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(hex: "#38BDF8"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(hex: "#38BDF8").opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(viewModel.wallets) { w in
                                let isActive = (viewModel.activeWallet?.id ?? 1) == w.id
                                let bal = viewModel.walletBalances[w.id] ?? 0.0
                                
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color(hex: w.colorHex))
                                        .frame(width: 14, height: 14)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(w.name)
                                            .font(.system(size: 15, weight: isActive ? .bold : .medium))
                                            .foregroundStyle(isActive ? .white : AppColors.textPrimary)
                                        
                                        Text("\(w.currencySymbol) \(FormatHelper.formatCurrency(bal))")
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .foregroundStyle(Color(hex: "#38BDF8"))
                                    }
                                    
                                    Spacer()
                                    
                                    if isActive {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(Color(hex: "#38BDF8"))
                                    }
                                    
                                    Button {
                                        onEdit(w)
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(AppColors.textMuted)
                                            .padding(8)
                                    }
                                }
                                .padding(14)
                                .background(isActive ? AppColors.darkNavySurface : AppColors.darkNavySurface.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(isActive ? Color(hex: "#38BDF8").opacity(0.6) : AppColors.cardBorderNavy, lineWidth: 1)
                                )
                                .onTapGesture {
                                    viewModel.selectWallet(w.id)
                                    onDismiss()
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Listo", action: onDismiss)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Upgrade Plan Dialog (Showcase PRO)
public struct UpgradePlanDialog: View {
    let onDismiss: () -> Void
    let onOpenProMode: () -> Void
    @State private var showAprendeDialog: Bool = false
    
    public init(onDismiss: @escaping () -> Void, onOpenProMode: @escaping () -> Void = {}) {
        self.onDismiss = onDismiss
        self.onOpenProMode = onOpenProMode
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AppColors.midnightBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Badge encabezado
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(Color(hex: "#F59E0B"))
                            Text("MoneyDev PRO")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundStyle(AppColors.textPrimary)
                            Spacer()
                            Text("Pago Único")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppColors.incomeEmeraldLight)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppColors.incomeEmeraldLight.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 4)
                        
                        // Lista de Beneficios
                        VStack(spacing: 12) {
                            benefitRow(icon: "creditcard.and.123", color: "#38BDF8", title: "Billeteras Ilimitadas", description: "Gestiona todas tus cuentas de banco, efectivo y ahorros sin restricciones.")
                            benefitRow(icon: "bubble.left.and.sparkles.fill", color: "#A855F7", title: "MoneyBot IA", description: "Asistente financiero personal inteligente con análisis predictivo.")
                            benefitRow(icon: "paintpalette.fill", color: "#EC4899", title: "Temas Exclusivos", description: "Personaliza la aplicación con paletas de color y estilos premium.")
                            benefitRow(icon: "arrow.down.doc.fill", color: "#10B981", title: "Exportación PDF y CSV", description: "Genera reportes financieros detallados listos para compartir o imprimir.")
                            benefitRow(icon: "arrow.triangle.2.circlepath", color: "#F59E0B", title: "Copia de Seguridad Cloud", description: "Exporta y restaura copias completas de tus datos en formato JSON 100% privado.")
                        }
                        
                        // Botón Aprende con MoneyDev
                        Button {
                            showAprendeDialog = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "book.fill")
                                Text("Aprende con MoneyDev (Finanzas Personales)")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(Color(hex: "#38BDF8"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#38BDF8").opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Botón de activación
                        Button {
                            onDismiss()
                            onOpenProMode()
                        } label: {
                            Text("Activar con Código PRO")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(colors: [Color(hex: "#F59E0B"), Color(hex: "#FBBF24")], startPoint: .leading, endPoint: .trailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Plan PRO")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar", action: onDismiss)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .sheet(isPresented: $showAprendeDialog) {
                AprendeConMoneyDevDialog {
                    showAprendeDialog = false
                }
            }
        }
    }
    
    private func benefitRow(icon: String, color: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(Color(hex: color).opacity(0.15))
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: color))
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(2)
            }
            
            Spacer()
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

// MARK: - Aprende Con MoneyDev Dialog
public struct FinancialTopicItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let category: String
    public let iconEmoji: String
    public let definition: String
    public let practicalExample: String
    public let moneyDevActionTip: String
    public let goldenRule: String
    public let accentColorHex: String
}

public struct AprendeConMoneyDevDialog: View {
    let onDismiss: () -> Void
    
    @State private var searchQuery: String = ""
    @State private var selectedCategory: String = "Todos"
    @State private var expandedTopicId: String? = "regla_50_30_20"
    
    private let categories = ["Todos", "Hábitos de Oro", "Fugas y Control", "Deudas y Ahorro", "Inversiones y Riqueza"]
    
    private let topics: [FinancialTopicItem] = [
        FinancialTopicItem(
            id: "regla_50_30_20",
            title: "Regla 50 / 30 / 20",
            category: "Hábitos de Oro",
            iconEmoji: "🎯",
            definition: "La fórmula estándar de oro para distribuir tus ingresos netos mensuales:\n• 50% Necesidades básicas (alquiler/hipoteca, servicios, comida, transporte).\n• 30% Deseos y estilo de vida (cenas, salidas, compras personales).\n• 20% Ahorro e Inversión (fondo de emergencia, metas de futuro).",
            practicalExample: "Si ganas S/ 2,400 al mes netos:\n• S/ 1,200 van a gastos indispensables.\n• S/ 720 para gustos sin culpa.\n• S/ 480 directos a tu ahorro o inversión.",
            moneyDevActionTip: "Crea una Billetera llamada 'Ahorro 20%' y transfiere esta cantidad el día que cobras.",
            goldenRule: "Nunca gastes primero y ahorres lo que sobre; distribuye desde el primer día.",
            accentColorHex: "#38BDF8"
        ),
        FinancialTopicItem(
            id: "gastos_hormiga",
            title: "Gastos Hormiga (Microfugas)",
            category: "Fugas y Control",
            iconEmoji: "🐜",
            definition: "Micro-gastos cotidianos e impulsivos que parecen inofensivos (café de paso, golosinas, snacks, botellas de agua) pero que sumados drenan entre el 10% y 25% de tus ingresos.",
            practicalExample: "Un gasto de S/ 8 al día:\n• En 1 mes = S/ 240\n• En 1 año = S/ 2,880 tirados sin darte cuenta.",
            moneyDevActionTip: "Usa el Dictado por Voz rápido de MoneyDev para registrar hasta el gasto de 1 sol. En Estadísticas verás la suma total.",
            goldenRule: "Lo que no se mide, no se puede controlar ni mejorar.",
            accentColorHex: "#F87171"
        ),
        FinancialTopicItem(
            id: "gastos_vampiro",
            title: "Gastos Vampiro (Suscripciones Ocultas)",
            category: "Fugas y Control",
            iconEmoji: "🧛",
            definition: "Gastos fijos o recurrentes silenciosos que chupan tu saldo mes tras mes sin que los disfrutes (apps olvidadas, membresías no usadas, comisiones bancarias).",
            practicalExample: "2 apps a S/ 29 y una membresía de S/ 80 suman S/ 1,656 al año que podrías haber ahorrado.",
            moneyDevActionTip: "Revisa periódicamente la sección 'Gastos Fijos' y cancela lo que no uses al menos 3 veces por semana.",
            goldenRule: "Si pagas por algo que no usas semanalmente, es una fuga, no una comodidad.",
            accentColorHex: "#FB7185"
        ),
        FinancialTopicItem(
            id: "fondo_emergencia",
            title: "Fondo de Emergencia (Paz Mental)",
            category: "Deudas y Ahorro",
            iconEmoji: "🛡️",
            definition: "Un colchón financiero intocable equivalente a 3 a 6 meses de tus gastos fijos mínimos de subsistencia. Solo para emergencias de salud o desempleo.",
            practicalExample: "Si tus costos básicos son S/ 1,500/mes, tu fondo ideal es de S/ 4,500 a S/ 9,000 en una cuenta segura y líquida.",
            moneyDevActionTip: "Crea una billetera llamada 'Fondo de Emergencia' y no la toques para gastos cotidianos.",
            goldenRule: "El fondo de emergencia no es para ganar rentabilidad, sino para comprar tranquilidad.",
            accentColorHex: "#FBBF24"
        ),
        FinancialTopicItem(
            id: "superavit_deficit",
            title: "Superávit vs Déficit (Flujo de Caja)",
            category: "Fugas y Control",
            iconEmoji: "⚖️",
            definition: "• Superávit: Ingresos > Gastos (¡creces!).\n• Déficit: Gastos > Ingresos (perdiendo dinero o cavando deuda).\nLa meta es cerrar cada mes con superávit constante.",
            practicalExample: "Ganas S/ 3,000 y gastas S/ 2,400 = Superávit de S/ 600. Gastas S/ 3,200 = Déficit de -S/ 200.",
            moneyDevActionTip: "Revisa la tarjeta de balance principal en MoneyDev. La barra verde debe superar siempre a la roja.",
            goldenRule: "Vivir por debajo de tus posibilidades es el primer paso hacia la libertad.",
            accentColorHex: "#34D399"
        ),
        FinancialTopicItem(
            id: "pagate_primero",
            title: "Págate a ti Mismo Primero",
            category: "Hábitos de Oro",
            iconEmoji: "👑",
            definition: "Apenas entre dinero a tus manos, separa automáticamente un porcentaje (10% a 20%) para tu patrimonio antes de pagar cualquier factura.",
            practicalExample: "Apenas cae tu sueldo el 30, apartas S/ 300 a tu cuenta de ahorro. Vives con el resto.",
            moneyDevActionTip: "Registra un movimiento de Ahorro en MoneyDev el mismo día que ingresa tu sueldo.",
            goldenRule: "Trata a tu ahorro como la factura más sagrada e impostergable del mes.",
            accentColorHex: "#F59E0B"
        ),
        FinancialTopicItem(
            id: "deudas_nieve_avalancha",
            title: "Bola de Nieve vs Avalancha",
            category: "Deudas y Ahorro",
            iconEmoji: "🏔️",
            definition: "• Bola de Nieve: Pagas el mínimo en todas y atacas con todo la deuda más pequeña (victoria psicológica rápida).\n• Avalancha: Atacas la deuda con mayor tasa de interés (ahorras más dinero).",
            practicalExample: "Tarjeta A (S/ 600 al 40%) y Préstamo B (S/ 4,000 al 15%). Bola de nieve liquida la de 600 primero. Avalancha ataca la del 40% primero.",
            moneyDevActionTip: "Registra tus abonos con la categoría 'Deudas' en MoneyDev para ver cómo baja tu carga.",
            goldenRule: "El mejor interés del mercado es el que te ahorras al no pagar intereses de tarjetas.",
            accentColorHex: "#38BDF8"
        ),
        FinancialTopicItem(
            id: "interes_compuesto",
            title: "Interés Compuesto (La 8va Maravilla)",
            category: "Inversiones y Riqueza",
            iconEmoji: "📈",
            definition: "Ocurre cuando las ganancias que generas se suman a tu capital para generar aún más ganancias. Con el tiempo, el crecimiento se vuelve exponencial.",
            practicalExample: "Ahorrar S/ 250/mes al 9% anual:\n• En 10 años: S/ 48,000 (ganaste S/ 18,000 en intereses).\n• En 25 años: S/ 280,000 (¡más de S/ 200,000 en intereses!).",
            moneyDevActionTip: "La clave no es cuánto pones hoy, sino empezar joven y no retirar los rendimientos.",
            goldenRule: "El que entiende el interés compuesto lo gana; el que no lo entiende, lo paga.",
            accentColorHex: "#A78BFA"
        ),
        FinancialTopicItem(
            id: "activos_vs_pasivos",
            title: "Activos vs Pasivos",
            category: "Inversiones y Riqueza",
            iconEmoji: "💼",
            definition: "• Activo: Pone dinero en tu bolsillo (inversiones, alquileres, negocios).\n• Pasivo: Saca dinero de tu bolsillo (autos costosos, compras a crédito que no producen).",
            practicalExample: "Comprar un auto para pasear es un pasivo. Usar ese mismo auto para un negocio de reparto es un activo.",
            moneyDevActionTip: "Crea billeteras para separar tu capital de trabajo de tus fondos de consumo.",
            goldenRule: "Los ricos compran activos; la clase media compra pasivos pensando que son activos.",
            accentColorHex: "#10B981"
        ),
        FinancialTopicItem(
            id: "regla_24_horas",
            title: "Regla de las 24 / 48 Horas",
            category: "Hábitos de Oro",
            iconEmoji: "⏳",
            definition: "Para cualquier compra que no sea de primera necesidad, espera 24 a 48 horas antes de pagar. El 80% de las compras impulsivas se descartan solas.",
            practicalExample: "Ves una prenda de S/ 250. Esperas 24 horas y ves que no la necesitas. Te acabas de ahorrar S/ 250.",
            moneyDevActionTip: "Pregúntale a MoneyBot: '¿Tengo suficiente saldo libre para un gusto de 250 soles?' antes de decidir.",
            goldenRule: "La emoción compra, pero la razón paga las cuotas.",
            accentColorHex: "#F472B6"
        )
    ]
    
    private var filteredTopics: [FinancialTopicItem] {
        topics.filter { topic in
            let matchesCategory = selectedCategory == "Todos" || topic.category == selectedCategory
            let matchesSearch = searchQuery.isEmpty ||
                topic.title.localizedCaseInsensitiveContains(searchQuery) ||
                topic.definition.localizedCaseInsensitiveContains(searchQuery) ||
                topic.goldenRule.localizedCaseInsensitiveContains(searchQuery)
            return matchesCategory && matchesSearch
        }
    }
    
    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AppColors.midnightBlack.ignoresSafeArea()
                
                VStack(spacing: 12) {
                    // Barra de búsqueda
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(AppColors.textMuted)
                        TextField("Buscar regla, hábito, fórmula...", text: $searchQuery)
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    .padding(12)
                    .background(AppColors.darkNavySurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    
                    // Categorías chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.self) { cat in
                                let isSelected = selectedCategory == cat
                                Button {
                                    selectedCategory = cat
                                } label: {
                                    Text(cat)
                                        .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                        .foregroundStyle(isSelected ? .white : AppColors.textSecondary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(isSelected ? Color(hex: "#38BDF8") : AppColors.darkNavySurface)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Lista de Temas
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(filteredTopics) { topic in
                                let isExpanded = expandedTopicId == topic.id
                                
                                VStack(alignment: .leading, spacing: 10) {
                                    // Header de la tarjeta
                                    Button {
                                        withAnimation(.spring) {
                                            expandedTopicId = isExpanded ? nil : topic.id
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Text(topic.iconEmoji)
                                                .font(.system(size: 22))
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(topic.title)
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundStyle(AppColors.textPrimary)
                                                Text(topic.category)
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(Color(hex: topic.accentColorHex))
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(AppColors.textMuted)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    
                                    if isExpanded {
                                        VStack(alignment: .leading, spacing: 12) {
                                            Divider().background(AppColors.cardBorderNavy)
                                            
                                            Text(topic.definition)
                                                .font(.system(size: 13))
                                                .foregroundStyle(AppColors.textSecondary)
                                                .lineSpacing(3)
                                            
                                            // Ejemplo práctico
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("💡 Ejemplo Práctico")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(Color(hex: topic.accentColorHex))
                                                Text(topic.practicalExample)
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(AppColors.textPrimary)
                                                    .lineSpacing(2)
                                            }
                                            .padding(10)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(AppColors.navySurfaceVariant.opacity(0.4))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            
                                            // Tip MoneyDev
                                            HStack(alignment: .top, spacing: 8) {
                                                Image(systemName: "app.fill")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(Color(hex: "#38BDF8"))
                                                Text(topic.moneyDevActionTip)
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(Color(hex: "#38BDF8"))
                                            }
                                            
                                            // Regla de Oro
                                            HStack(alignment: .top, spacing: 8) {
                                                Text("👑")
                                                Text(topic.goldenRule)
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(Color(hex: "#F59E0B"))
                                            }
                                        }
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                    }
                                }
                                .padding(16)
                                .background(AppColors.darkNavySurface)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(isExpanded ? Color(hex: topic.accentColorHex).opacity(0.6) : AppColors.cardBorderNavy, lineWidth: 1)
                                )
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Aprende con MoneyDev")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Listo", action: onDismiss)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }
}
