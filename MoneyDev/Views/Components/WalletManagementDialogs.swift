import SwiftUI
import UIKit

// MARK: - Helper para Configuración de Scroll en Hojas de Presentación
public struct SheetScrollExpandsConfig: UIViewRepresentable {
    public var expandsWhenScrolled: Bool = false
    
    public init(expandsWhenScrolled: Bool = false) {
        self.expandsWhenScrolled = expandsWhenScrolled
    }
    
    public func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            var responder: UIResponder? = view
            while let r = responder {
                if let vc = r as? UIViewController, let sheet = vc.sheetPresentationController {
                    sheet.prefersScrollingExpandsWhenScrolledToEdge = expandsWhenScrolled
                    break
                }
                responder = r.next
            }
        }
        return view
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {}
}

private struct WalletScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Add Wallet Dialog
public struct AddWalletDialog: View {
    @Bindable var viewModel: ExpenseViewModel
    let onDismiss: () -> Void
    let onConfirm: (String, Double, String, String) -> Void
    
    @State private var name: String = ""
    @State private var balanceText: String = ""
    @State private var currency: String = "S/"
    @State private var selectedColor: String = "#007AFF"
    @State private var errorMessage: String? = nil
    @State private var showNameLimitAlert: Bool = false
    
    private let availableColors = ["#007AFF", "#10B981", "#FF7A00", "#FF3B30", "#A855F7", "#EAB308", "#EC4899", "#06B6D4", "#84CC16", "#64748B"]
    private let currencies = ["S/", "$", "€", "MXN", "CLP", "ARS"]
    
    public init(
        viewModel: ExpenseViewModel,
        onDismiss: @escaping () -> Void,
        onConfirm: @escaping (String, Double, String, String) -> Void
    ) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        self.onConfirm = onConfirm
    }
    
    private var maxWalletsAllowed: Int {
        viewModel.isProUser ? 10 : 3
    }
    
    private var isAtWalletLimit: Bool {
        viewModel.wallets.count >= maxWalletsAllowed
    }
    
    private var theme: AppColorTheme {
        viewModel.activeTheme
    }
    
    private var themedCardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                LinearGradient(
                    colors: theme == .electricBlack ?
                        [Color.white.opacity(0.08), Color.white.opacity(0.02)] :
                        [theme.primary.opacity(0.14), theme.secondary.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.darkNavySurface.opacity(0.95))
            )
            .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 2)
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                ThemedModalBackground(theme: theme)
                
                VStack(spacing: 0) {
                    if isAtWalletLimit {
                        VStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: "#F59E0B").opacity(0.2))
                                .frame(width: 56, height: 56)
                                .overlay {
                                    Image(systemName: "lock.shield.fill")
                                        .font(.system(size: 26))
                                        .foregroundStyle(Color(hex: "#F59E0B"))
                                }
                            
                            Text("Límite de Billeteras Alcanzado")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.white)
                            
                            Text(viewModel.isProUser ?
                                "Has alcanzado el límite máximo de 10 billeteras permitidas en Modo PRO. Puedes editar o administrar tus billeteras existentes." :
                                "En el Modo Básico puedes crear un máximo de 3 billeteras. Activa el Modo PRO para poder crear hasta 10 billeteras.")
                                .font(.system(size: 14))
                                .foregroundStyle(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                            
                            if !viewModel.isProUser {
                                Button {
                                    onDismiss()
                                    viewModel.setActiveTab(2) // Ir a Modo PRO
                                } label: {
                                    Text("Ver Modo PRO")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 48)
                                        .background(Color(hex: "#F59E0B"))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .padding(.top, 8)
                            } else {
                                Button {
                                    onDismiss()
                                } label: {
                                    Text("Entendido")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 48)
                                        .background(AppColors.darkNavySurface)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding(20)
                        .background(themedCardBackground)
                        .padding(16)
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 14) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Nombre de la Billetera")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(theme == .electricBlack ? Color.white : theme.accentTextColor)
                                    
                                    TextField("Ej: Cuenta Sueldo BCP, Efectivo...", text: $name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.white)
                                        .submitLabel(.done)
                                        .onSubmit {
                                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                        }
                                        .onChange(of: name) { oldValue, newValue in
                                            if newValue.count > 30 {
                                                name = String(newValue.prefix(30))
                                                showNameLimitAlert = true
                                                let generator = UINotificationFeedbackGenerator()
                                                generator.notificationOccurred(.warning)
                                            } else if newValue.count == 30 && oldValue.count < 30 {
                                                showNameLimitAlert = true
                                                let generator = UINotificationFeedbackGenerator()
                                                generator.notificationOccurred(.warning)
                                            }
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .background(themedCardBackground)
                                    
                                    HStack {
                                        if name.count >= 30 {
                                            HStack(spacing: 4) {
                                                Image(systemName: "info.circle.fill")
                                                    .font(.system(size: 11, weight: .bold))
                                                Text("Límite de 30 caracteres alcanzado")
                                                    .font(.system(size: 11, weight: .bold))
                                            }
                                            .foregroundStyle(Color(hex: "#F59E0B"))
                                        }
                                        
                                        Spacer()
                                        
                                        Text("\(name.count)/30")
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundStyle(name.count >= 30 ? Color(hex: "#F59E0B") : AppColors.textMuted)
                                    }
                                    .padding(.horizontal, 4)
                                }
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Moneda")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(theme == .electricBlack ? Color.white : theme.accentTextColor)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(currencies, id: \.self) { c in
                                                currencyPill(symbol: c)
                                            }
                                        }
                                        .padding(.horizontal, 2)
                                        .padding(.vertical, 2)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(themedCardBackground)
                                }
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Saldo Inicial")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(theme == .electricBlack ? Color.white : theme.accentTextColor)
                                    
                                    HStack(spacing: 8) {
                                        Text(currency)
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                            .foregroundStyle(theme == .electricBlack ? Color.white : theme.primary)
                                        
                                        TextField("0.00", text: $balanceText)
                                            .font(.system(size: 24, weight: .black, design: .rounded))
                                            .foregroundStyle(Color.white)
                                            .keyboardType(.decimalPad)
                                            .onChange(of: balanceText) { _, newValue in
                                                balanceText = FormatHelper.validateMoneyInput(newValue)
                                            }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(themedCardBackground)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Color Identificador (10 Colores Básicos)")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(theme == .electricBlack ? Color.white : theme.accentTextColor)
                                    
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 12) {
                                        ForEach(availableColors, id: \.self) { c in
                                            Circle()
                                                .fill(Color(hex: c))
                                                .frame(width: 32, height: 32)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.white, lineWidth: selectedColor == c ? 2.5 : 0)
                                                        .shadow(color: Color.black.opacity(0.4), radius: 2)
                                                )
                                                .shadow(color: selectedColor == c ? Color(hex: c).opacity(0.5) : Color.clear, radius: 4)
                                                .onTapGesture {
                                                    selectedColor = c
                                                }
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 14)
                                    .background(themedCardBackground)
                                }
                                
                                if let errorMessage {
                                    Text(errorMessage)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(AppColors.expenseRoseLight)
                                }
                                
                                // Botón Crear Billetera dentro del ScrollView para permanecer fijo en su lugar
                                Button {
                                    submit()
                                } label: {
                                    Text("Crear Billetera")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(theme == .electricBlack ? Color.black : Color.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 48)
                                        .background(
                                            LinearGradient(
                                                colors: theme == .electricBlack ?
                                                    [Color.white, Color(hex: "#CBD5E1")] :
                                                    theme.gradient,
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .shadow(color: theme == .electricBlack ? Color.white.opacity(0.2) : theme.primary.opacity(0.35), radius: 6, x: 0, y: 2)
                                }
                                .padding(.top, 8)
                                .padding(.bottom, 20)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .padding(.bottom, 12)
                        }
                    }
                }
            }
            .navigationTitle("Nueva Billetera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isAtWalletLimit ? "Cerrar" : "Cancelar", action: onDismiss)
                        .foregroundStyle(Color.white)
                }
                if !isAtWalletLimit {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Crear") {
                            submit()
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(theme == .electricBlack ? Color.white : (theme == .electricYellow ? Color(hex: "#F59E0B") : theme.primary))
                    }
                }
            }
            .alert("Límite alcanzado", isPresented: $showNameLimitAlert) {
                Button("Entendido", role: .cancel) { }
            } message: {
                Text("El nombre de la billetera no puede superar los 30 caracteres.")
            }
        }
        .keyboardDismissArrow()
        .presentationDetents(isAtWalletLimit ? [.fraction(0.50), .medium] : [.fraction(0.78), .large])
        .presentationDragIndicator(.hidden)
    }
    
    private func submit() {
        guard !isAtWalletLimit else { return }
        let cleanName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))
        guard !cleanName.isEmpty else {
            errorMessage = "Ingresa un nombre para la billetera."
            viewModel.showFloatingToast(title: "Campo Requerido", message: "Ingresa un nombre para la billetera.", isSuccess: false, duration: 4.0)
            return
        }
        let isDuplicate = viewModel.wallets.contains { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == cleanName.lowercased() }
        if isDuplicate {
            errorMessage = "Ya existe una billetera con ese nombre."
            viewModel.showFloatingToast(title: "Nombre Duplicado", message: "Ya tienes una billetera registrada llamada '\(cleanName)'.", isSuccess: false, duration: 4.0)
            return
        }
        if viewModel.wallets.count >= viewModel.maxWalletsAllowed {
            errorMessage = "Has alcanzado el límite máximo de billeteras (\(viewModel.maxWalletsAllowed))."
            return
        }
        let cleanBal = balanceText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        let amount = Double(cleanBal) ?? 0.0
        onConfirm(cleanName, amount, currency, selectedColor)
        onDismiss()
    }
    
    @ViewBuilder
    private func currencyPill(symbol: String) -> some View {
        let isSelected = currency == symbol
        let textColor: Color = isSelected ? (theme == .electricBlack ? Color.black : theme.onPrimaryText) : AppColors.textPrimary
        let bgColor: Color = isSelected ? (theme == .electricBlack ? Color.white : theme.primary) : Color(hex: "#101928")
        let strokeColor: Color = isSelected ? (theme == .electricBlack ? Color.black.opacity(0.15) : Color.white.opacity(0.35)) : Color.white.opacity(0.08)
        let shadowColor: Color = isSelected ? (theme == .electricBlack ? Color.white.opacity(0.25) : theme.primary.opacity(0.35)) : Color.black.opacity(0.2)
        
        Button {
            currency = symbol
        } label: {
            Text(symbol)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .foregroundStyle(textColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(bgColor)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(strokeColor, lineWidth: 1)
                )
                .shadow(color: shadowColor, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Edit Wallet Dialog
public struct EditWalletDialog: View {
    let wallet: Wallet
    let theme: AppColorTheme
    let canDelete: Bool
    let existingWallets: [Wallet]
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
    @State private var errorMessage: String? = nil
    @State private var showNameLimitAlert: Bool = false
    
    private let availableColors = ["#007AFF", "#10B981", "#FF7A00", "#FF3B30", "#A855F7", "#EAB308", "#EC4899", "#06B6D4", "#84CC16", "#64748B"]
    
    public init(
        wallet: Wallet,
        theme: AppColorTheme = .electricBlue,
        canDelete: Bool = true,
        existingWallets: [Wallet] = [],
        onDismiss: @escaping () -> Void,
        onSave: @escaping (String, Double, String, String) -> Void,
        onDelete: @escaping () -> Void,
        onClearTransactions: @escaping () -> Void
    ) {
        self.wallet = wallet
        self.theme = theme
        self.canDelete = canDelete
        self.existingWallets = existingWallets
        self.onDismiss = onDismiss
        self.onSave = onSave
        self.onDelete = onDelete
        self.onClearTransactions = onClearTransactions
        _name = State(initialValue: wallet.name)
        _balanceText = State(initialValue: wallet.initialBalance == 0.0 ? "" : String(format: "%.2f", wallet.initialBalance))
        _currency = State(initialValue: wallet.currencySymbol)
        _selectedColor = State(initialValue: wallet.colorHex)
    }
    
    private var themedRowBackground: some View {
        ThemedCardBackgroundView(theme: theme, cornerRadius: 14)
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                ThemedModalBackground(theme: theme)
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        // Bloque 1: Nombre de la Billetera
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Nombre de la Billetera")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(theme == .electricBlack ? Color.white : theme.accentTextColor)
                                .contrastTextOutline()
                            
                            TextField("Ej: Cuenta Sueldo BCP, Efectivo...", text: $name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .submitLabel(.done)
                                .onSubmit {
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                }
                                .onChange(of: name) { oldValue, newValue in
                                    if newValue.count > 30 {
                                        name = String(newValue.prefix(30))
                                        showNameLimitAlert = true
                                        let generator = UINotificationFeedbackGenerator()
                                        generator.notificationOccurred(.warning)
                                    } else if newValue.count == 30 && oldValue.count < 30 {
                                        showNameLimitAlert = true
                                        let generator = UINotificationFeedbackGenerator()
                                        generator.notificationOccurred(.warning)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .themedInputField(theme: theme, cornerRadius: 14)
                            
                            HStack {
                                if name.count >= 30 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "info.circle.fill")
                                            .font(.system(size: 11, weight: .bold))
                                        Text("Límite de 30 caracteres alcanzado")
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                    .foregroundStyle(Color(hex: "#F59E0B"))
                                }
                                
                                Spacer()
                                
                                Text("\(name.count)/30")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(name.count >= 30 ? Color(hex: "#F59E0B") : AppColors.textMuted)
                            }
                            .padding(.horizontal, 4)
                            
                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppColors.expenseRoseLight)
                            }
                        }
                        
                        // Bloque 2: Saldo Inicial
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Saldo Inicial")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(theme == .electricBlack ? Color.white : theme.accentTextColor)
                                .contrastTextOutline()
                            
                            HStack(spacing: 8) {
                                Text(currency)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(theme == .electricBlack ? Color.white : theme.primary)
                                    .contrastTextOutline()
                                
                                TextField("0.00", text: $balanceText, prompt: Text("0.00").foregroundStyle(AppColors.textMuted))
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.white)
                                    .contrastTextOutline()
                                    .keyboardType(.decimalPad)
                                    .onChange(of: balanceText) { _, newValue in
                                        balanceText = FormatHelper.validateMoneyInput(newValue)
                                    }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .themedInputField(theme: theme, cornerRadius: 14)
                        }
                        
                        // Bloque 3: Moneda
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Moneda")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(theme == .electricBlack ? Color.white : theme.accentTextColor)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(["S/", "$", "€", "MXN", "CLP", "ARS"], id: \.self) { c in
                                        currencyPill(symbol: c)
                                    }
                                }
                                .padding(.horizontal, 2)
                                .padding(.vertical, 2)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(themedRowBackground)
                        }
                        
                        // Bloque 4: Color (10 Colores Básicos)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Color (10 Colores Básicos)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(theme == .electricBlack ? Color.white : theme.accentTextColor)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 12) {
                                ForEach(availableColors, id: \.self) { c in
                                    Circle()
                                        .fill(Color(hex: c))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: selectedColor == c ? 2.5 : 0)
                                                .shadow(color: Color.black.opacity(0.4), radius: 2)
                                        )
                                        .shadow(color: selectedColor == c ? Color(hex: c).opacity(0.5) : Color.clear, radius: 4)
                                        .onTapGesture { selectedColor = c }
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .background(themedRowBackground)
                        }
                        
                        // Bloque 5: Gestión de Movimientos
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Gestión de Movimientos")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(theme == .electricBlack ? Color.white : theme.accentTextColor)
                            
                            VStack(spacing: 8) {
                                Button {
                                    showConfirmClear = true
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.counterclockwise")
                                            .font(.system(size: 14, weight: .bold))
                                        Text("Limpiar movimientos de esta cuenta")
                                            .font(.system(size: 14, weight: .semibold))
                                        Spacer()
                                    }
                                    .foregroundStyle(Color(hex: "#F59E0B"))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(themedRowBackground)
                                }
                                .buttonStyle(.plain)
                                
                                if canDelete && !wallet.isDefault {
                                    Button {
                                        showConfirmDelete = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "trash.fill")
                                                .font(.system(size: 14, weight: .bold))
                                            Text("Eliminar billetera")
                                                .font(.system(size: 14, weight: .semibold))
                                            Spacer()
                                        }
                                        .foregroundStyle(AppColors.expenseRoseLight)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .background(themedRowBackground)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Editar Billetera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar", action: onDismiss)
                        .foregroundStyle(Color.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        let cleanName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))
                        guard !cleanName.isEmpty else {
                            errorMessage = "Ingresa un nombre para la billetera."
                            return
                        }
                        let isDuplicate = existingWallets.contains { $0.id != wallet.id && $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == cleanName.lowercased() }
                        if isDuplicate {
                            errorMessage = "Ya existe otra billetera con ese nombre."
                            return
                        }
                        let cleanBal = balanceText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
                        let amount = cleanBal.isEmpty ? 0.0 : (Double(cleanBal) ?? wallet.initialBalance)
                        onSave(cleanName, amount, currency, selectedColor)
                        onDismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(theme == .electricBlack ? Color.white : (theme == .electricYellow ? Color(hex: "#F59E0B") : theme.primary))
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
            .alert("Límite alcanzado", isPresented: $showNameLimitAlert) {
                Button("Entendido", role: .cancel) { }
            } message: {
                Text("El nombre de la billetera no puede superar los 30 caracteres.")
            }
        }
        .keyboardDismissArrow()
        .presentationDetents([.fraction(0.85), .large])
        .presentationDragIndicator(.visible)
    }
    
    @ViewBuilder
    private func currencyPill(symbol: String) -> some View {
        let isSelected = currency == symbol
        let textColor: Color = isSelected ? (theme == .electricBlack ? Color.black : theme.onPrimaryText) : AppColors.textPrimary
        let bgColor: Color = isSelected ? (theme == .electricBlack ? Color.white : theme.primary) : Color(hex: "#101928")
        let strokeColor: Color = isSelected ? (theme == .electricBlack ? Color.black.opacity(0.15) : Color.white.opacity(0.35)) : Color.white.opacity(0.08)
        let shadowColor: Color = isSelected ? (theme == .electricBlack ? Color.white.opacity(0.25) : theme.primary.opacity(0.35)) : Color.black.opacity(0.2)
        
        Button {
            currency = symbol
        } label: {
            Text(symbol)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .foregroundStyle(textColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(bgColor)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(strokeColor, lineWidth: 1)
                )
                .shadow(color: shadowColor, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
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
    
    @State private var isReordering: Bool = false
    @State private var showLimitAlert: Bool = false
    @State private var walletScrollProgress: CGFloat = 0.0
    @State private var canScrollWallets: Bool = false
    
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
    
    private var activeTheme: AppColorTheme {
        viewModel.activeTheme
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                ThemedModalBackground(theme: activeTheme)
                
                VStack(spacing: 16) {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isReordering ? "Reordenar Billeteras" : "Mis Billeteras")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Color.white)
                            Text(isReordering ? "Arrastra las tarjetas para cambiar su orden" : "\(viewModel.wallets.count)/\(viewModel.isProUser ? "10" : "3") activas")
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        // Botón Reordenar (al costado izquierdo del botón Nueva)
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                isReordering.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: isReordering ? "checkmark" : "arrow.up.arrow.down")
                                    .font(.system(size: 11, weight: .bold))
                                Text(isReordering ? "Listo" : "Reordenar")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(isReordering ? Color.white : (activeTheme == .electricBlack ? Color.white : activeTheme.primary))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isReordering ? Color(hex: "#10B981") : activeTheme.primary.opacity(0.18))
                            .clipShape(Capsule())
                        }
                        
                        // Botón Nueva
                        if !isReordering {
                            Button {
                                if viewModel.wallets.count >= viewModel.maxWalletsAllowed {
                                    showLimitAlert = true
                                } else {
                                    onAddNew()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                    Text("Nueva")
                                }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(activeTheme.primary.opacity(0.18))
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    
                    let currentActiveId = viewModel.activeWallet?.id ?? 1
                    
                    if isReordering {
                        List {
                            ForEach(viewModel.wallets) { w in
                                walletReorderCard(wallet: w, isActive: w.id == currentActiveId)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                            }
                            .onMove { indices, newOffset in
                                viewModel.reorderWallets(from: indices, to: newOffset)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .environment(\.editMode, .constant(.active))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ZStack(alignment: .trailing) {
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 10) {
                                    ForEach(viewModel.wallets) { w in
                                        walletItemCard(wallet: w, isActive: w.id == currentActiveId)
                                    }
                                }
                                .padding(.leading, 16)
                                .padding(.trailing, 22)
                                .padding(.bottom, 16)
                            }
                            .onScrollGeometryChange(for: CGFloat.self) { geo in
                                let scrollable = geo.contentSize.height - geo.containerSize.height
                                return scrollable > 0 ? min(max(geo.contentOffset.y / scrollable, 0.0), 1.0) : 0.0
                            } action: { _, progress in
                                walletScrollProgress = progress
                            }
                            .onScrollGeometryChange(for: Bool.self) { geo in
                                (geo.contentSize.height - geo.containerSize.height) > 4
                            } action: { _, canScroll in
                                canScrollWallets = canScroll
                            }
                            
                            // Barra desplazadora lateral adaptativa que se expande a la altura total de la ventana
                            if canScrollWallets {
                                GeometryReader { geo in
                                    let trackH = max(geo.size.height - 24, 40)
                                    let thumbH = max(min(trackH * 0.40, 90), 45)
                                    let travelDistance = max(trackH - thumbH, 1)
                                    ZStack(alignment: .top) {
                                        Capsule()
                                            .fill(Color.white.opacity(0.15))
                                            .frame(width: 5, height: trackH)
                                        
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: activeTheme == .electricBlack ?
                                                        [Color.white, Color(hex: "#94A3B8")] :
                                                        [activeTheme.primary, activeTheme.accentIconColor],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .frame(width: 5, height: thumbH)
                                            .offset(y: travelDistance * walletScrollProgress)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                                    .padding(.trailing, 6)
                                    .padding(.vertical, 12)
                                }
                                .allowsHitTesting(false)
                                .transition(.opacity)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(SheetScrollExpandsConfig(expandsWhenScrolled: false))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar", action: onDismiss)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.primary)
                }
            }
        }
        .presentationDetents([.fraction(0.45), .medium, .large])
        .presentationDragIndicator(.visible)
        .themedSheetContainer(theme: activeTheme)
        .ignoresSafeArea(.container, edges: .bottom)
        .alert("Límite de Billeteras Alcanzado", isPresented: $showLimitAlert) {
            if !viewModel.isProUser {
                Button("Ver Modo PRO") {
                    onDismiss()
                    viewModel.setActiveTab(2)
                }
                Button("Cancelar", role: .cancel) { }
            } else {
                Button("Entendido", role: .cancel) { }
            }
        } message: {
            Text(viewModel.isProUser ?
                "Has alcanzado el límite máximo de 10 billeteras en Modo PRO. Puedes administrar o editar tus billeteras existentes." :
                "En el Modo Básico puedes crear un máximo de 3 billeteras. Pasa al Modo PRO para crear hasta 10 billeteras.")
        }
    }
    
    @ViewBuilder
    private func walletReorderCard(wallet: Wallet, isActive: Bool) -> some View {
        let bal = viewModel.walletBalances[wallet.id] ?? 0.0
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: wallet.colorHex))
                .frame(width: 14, height: 14)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(wallet.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isActive ? .white : AppColors.textPrimary)
                
                Text("\(wallet.currencySymbol) \(FormatHelper.formatCurrency(bal))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.primary)
            }
            
            Spacer()
            
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.primary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    isActive ?
                        LinearGradient(
                            colors: [
                                activeTheme == .electricBlack ? Color.white.opacity(0.12) : activeTheme.primary.opacity(0.20),
                                Color(hex: "#101928")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [
                                Color(hex: "#101928").opacity(0.85),
                                Color(hex: "#0B111C").opacity(0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
                .shadow(
                    color: Color.black.opacity(0.35),
                    radius: 4,
                    x: 0,
                    y: 2
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    @ViewBuilder
    private func walletItemCard(wallet: Wallet, isActive: Bool) -> some View {
        let bal = viewModel.walletBalances[wallet.id] ?? 0.0
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: wallet.colorHex))
                .frame(width: 14, height: 14)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(wallet.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isActive ? .white : AppColors.textPrimary)
                
                Text("\(wallet.currencySymbol) \(FormatHelper.formatCurrency(bal))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.primary)
            }
            
            Spacer()
            
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.primary)
            }
            
            Button {
                onEdit(wallet)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(8)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    isActive ?
                        LinearGradient(
                            colors: [
                                activeTheme == .electricBlack ? Color.white.opacity(0.12) : activeTheme.primary.opacity(0.20),
                                Color(hex: "#101928")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [
                                Color(hex: "#101928").opacity(0.85),
                                Color(hex: "#0B111C").opacity(0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
                .shadow(
                    color: isActive ?
                        (activeTheme == .electricBlack ? Color.white.opacity(0.15) : activeTheme.primary.opacity(0.30)) :
                        Color.black.opacity(0.35),
                    radius: isActive ? 6 : 4,
                    x: 0,
                    y: 2
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture {
            viewModel.selectWallet(wallet.id)
            onDismiss()
        }
    }
}

// MARK: - Pure Floating Wallet Picker (Para la pestaña de estadísticas)
public struct FloatingWalletSelectorDialog: View {
    @Bindable var viewModel: ExpenseViewModel
    let onDismiss: () -> Void
    
    public init(viewModel: ExpenseViewModel, onDismiss: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
    }
    
    private var activeTheme: AppColorTheme {
        viewModel.activeTheme
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                ThemedModalBackground(theme: activeTheme)
                
                VStack(spacing: 14) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 10) {
                            let currentActiveId = viewModel.activeWallet?.id ?? 1
                            ForEach(viewModel.wallets) { wallet in
                                let isActive = wallet.id == currentActiveId
                                let bal = viewModel.walletBalances[wallet.id] ?? 0.0
                                Button {
                                    viewModel.selectWallet(wallet.id)
                                    onDismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(Color(hex: wallet.colorHex))
                                            .frame(width: 14, height: 14)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(wallet.name)
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundStyle(isActive ? .white : AppColors.textPrimary)
                                            
                                            Text("\(wallet.currencySymbol) \(FormatHelper.formatCurrency(bal))")
                                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.primary)
                                        }
                                        
                                        Spacer()
                                        
                                        if isActive {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.primary)
                                        }
                                    }
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(
                                                isActive ?
                                                    LinearGradient(
                                                        colors: [
                                                            activeTheme == .electricBlack ? Color.white.opacity(0.12) : activeTheme.primary.opacity(0.20),
                                                            Color(hex: "#101928")
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ) :
                                                    LinearGradient(
                                                        colors: [
                                                            Color(hex: "#101928").opacity(0.85),
                                                            Color(hex: "#0B111C").opacity(0.95)
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                            )
                                            .shadow(color: Color.black.opacity(0.35), radius: 4, x: 0, y: 2)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Seleccionar Billetera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar", action: onDismiss)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.primary)
                }
            }
        }
        .presentationDetents([.fraction(0.45), .medium, .large])
        .presentationDragIndicator(.visible)
        .themedSheetContainer(theme: activeTheme)
    }
}

/// Selector flotante compacto de billeteras con diseño de cristal líquido de Apple para la pestaña de estadísticas
public struct StatsLiquidGlassWalletPicker: View {
    @Bindable var viewModel: ExpenseViewModel
    let onDismiss: () -> Void
    
    public init(viewModel: ExpenseViewModel, onDismiss: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
    }
    
    private var activeTheme: AppColorTheme {
        viewModel.activeTheme
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Cabecera compacta
            HStack(spacing: 6) {
                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.primary)
                
                Text("Billeteras")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.85))
                
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 5) {
                    let currentActiveId = viewModel.activeWallet?.id ?? 1
                    ForEach(viewModel.wallets) { wallet in
                        let isActive = wallet.id == currentActiveId
                        let bal = viewModel.walletBalances[wallet.id] ?? 0.0
                        
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            viewModel.selectWallet(wallet.id)
                            onDismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(hex: wallet.colorHex))
                                    .frame(width: 10, height: 10)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(isActive ? 0.9 : 0.25), lineWidth: 1)
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(wallet.name)
                                        .font(.system(size: 13, weight: isActive ? .bold : .semibold))
                                        .foregroundStyle(Color.white)
                                        .lineLimit(1)
                                    
                                    Text("\(wallet.currencySymbol) \(FormatHelper.formatCurrency(bal))")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(isActive ? (activeTheme == .electricBlack ? Color.white : activeTheme.primary) : Color.white.opacity(0.65))
                                }
                                
                                Spacer()
                                
                                if isActive {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.primary)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(
                                        isActive ?
                                            (activeTheme == .electricBlack ? Color.white.opacity(0.16) : activeTheme.primary.opacity(0.24)) :
                                            Color.white.opacity(0.04)
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        isActive ?
                                            (activeTheme == .electricBlack ? Color.white.opacity(0.35) : activeTheme.primary.opacity(0.50)) :
                                            Color.white.opacity(0.06),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 250)
        }
        .padding(12)
        .frame(width: 230)
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
                            benefitRow(icon: "arrow.triangle.2.circlepath", color: "#F59E0B", title: "Copia de Seguridad", description: "Exporta y restaura copias completas de tus datos de forma 100% privada y segura.")
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
                .themedSheetContainer(theme: .electricBlue)
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
    public var theme: AppColorTheme
    let onDismiss: () -> Void
    
    @State private var searchQuery: String = ""
    @State private var selectedCategory: String = "Todos"
    @State private var expandedTopicId: String? = "regla_50_30_20"
    
    private static let categories = ["Todos", "Hábitos de Oro", "Fugas y Control", "Deudas y Ahorro", "Inversiones y Riqueza"]
    
    private static let topics: [FinancialTopicItem] = [
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
        Self.topics.filter { topic in
            let matchesCategory = selectedCategory == "Todos" || topic.category == selectedCategory
            let matchesSearch = searchQuery.isEmpty ||
                topic.title.localizedCaseInsensitiveContains(searchQuery) ||
                topic.definition.localizedCaseInsensitiveContains(searchQuery) ||
                topic.goldenRule.localizedCaseInsensitiveContains(searchQuery)
            return matchesCategory && matchesSearch
        }
    }
    
    public init(theme: AppColorTheme = .electricBlue, onDismiss: @escaping () -> Void) {
        self.theme = theme
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                ThemedModalBackground(theme: theme)
                
                VStack(spacing: 12) {
                    // Barra de búsqueda
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(theme == .electricBlack ? Color.white.opacity(0.7) : theme.accentIconColor)
                        TextField("Buscar regla, hábito, fórmula...", text: $searchQuery)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.white)
                            .contrastTextOutline()
                            .submitLabel(.done)
                            .onSubmit {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                    }
                    .padding(12)
                    .background(ThemedCardBackgroundView(theme: theme, cornerRadius: 12))
                    .padding(.horizontal, 16)
                    
                    // Categorías chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Self.categories, id: \.self) { cat in
                                let isSelected = selectedCategory == cat
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                        selectedCategory = cat
                                    }
                                } label: {
                                    Text(cat)
                                        .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                        .foregroundStyle(isSelected ? (theme == .electricBlack ? Color.black : theme.onPrimaryText) : Color.white.opacity(0.85))
                                        .contrastTextOutline(color: isSelected ? Color.clear : Color.black.opacity(0.85))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(
                                            Group {
                                                if isSelected {
                                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                        .fill(
                                                            LinearGradient(
                                                                colors: theme == .electricBlack ? [Color.white, Color(hex: "#E2E8F0")] : theme.gradient,
                                                                startPoint: .leading,
                                                                endPoint: .trailing
                                                            )
                                                        )
                                                        .shadow(color: theme.primary.opacity(0.4), radius: 4, x: 0, y: 2)
                                                } else {
                                                    ThemedCardBackgroundView(theme: theme, cornerRadius: 16)
                                                }
                                            }
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(TopicCardHeaderButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Lista de Temas Fluida y de Alto Rendimiento (120 FPS)
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredTopics) { topic in
                                TopicCardView(
                                    topic: topic,
                                    isExpanded: expandedTopicId == topic.id,
                                    theme: theme,
                                    onToggle: {
                                        expandedTopicId = (expandedTopicId == topic.id) ? nil : topic.id
                                    }
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
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                        .contrastTextOutline()
                }
            }
        }
        .themedSheetContainer(theme: theme)
        .keyboardDismissBlueCheck()
    }
}

// MARK: - Topic Card View & Button Style para Máxima Fluidez
private struct TopicCardHeaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct TopicCardView: View {
    let topic: FinancialTopicItem
    let isExpanded: Bool
    let theme: AppColorTheme
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header de la tarjeta con área de toque completa y respuesta táctil instantánea
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    onToggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Text(topic.iconEmoji)
                        .font(.system(size: 22))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(topic.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.white)
                            .contrastTextOutline()
                        Text(topic.category)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(hex: topic.accentColorHex))
                            .contrastTextOutline()
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .contrastTextOutline()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(TopicCardHeaderButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider().background(Color.white.opacity(0.15))
                    
                    Text(topic.definition)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .contrastTextOutline()
                        .lineSpacing(3)
                    
                    // Ejemplo práctico
                    VStack(alignment: .leading, spacing: 4) {
                        Text("💡 Ejemplo Práctico")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(Color(hex: topic.accentColorHex))
                            .contrastTextOutline()
                        Text(topic.practicalExample)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white)
                            .contrastTextOutline()
                            .lineSpacing(2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        ThemedCardBackgroundView(theme: theme, cornerRadius: 10)
                    )
                    
                    // Tip MoneyDev
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "app.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(theme == .electricBlack ? Color.white : Color(hex: "#38BDF8"))
                        Text(topic.moneyDevActionTip)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(theme == .electricBlack ? Color.white : Color(hex: "#38BDF8"))
                            .contrastTextOutline()
                    }
                    
                    // Regla de Oro
                    HStack(alignment: .top, spacing: 8) {
                        Text("👑")
                        Text(topic.goldenRule)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(hex: "#F59E0B"))
                            .contrastTextOutline()
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(ThemedCardBackgroundView(theme: theme, cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isExpanded ?
                        (theme == .electricBlack ? Color.white.opacity(0.6) : Color(hex: topic.accentColorHex).opacity(0.6)) :
                        Color.white.opacity(theme == .electricBlack ? 0.14 : 0.08),
                    lineWidth: 1
                )
        )
        .shadow(
            color: theme == .electricBlack ?
                Color.white.opacity(0.10) :
                theme.primary.opacity(0.20),
            radius: 7, x: 0, y: 2
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            if !isExpanded {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    onToggle()
                }
            }
        }
    }
}
