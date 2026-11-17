import SwiftUI

public struct ProModeScreen: View {
    @Bindable var viewModel: ExpenseViewModel
    
    @State private var codeInput: String = ""
    @State private var alertMessage: String? = nil
    @State private var showAlert: Bool = false
    @State private var isSuccess: Bool = false
    
    // Animaciones de verificación y bienvenida PRO
    @State private var isVerifying: Bool = false
    @State private var verificationProgress: CGFloat = 0.0
    @State private var verificationText: String = "Verificando..."
    @State private var showWelcomeCelebration: Bool = false
    
    // Hojas interactivas para las funciones PRO
    @State private var isWalletSheetOpen: Bool = false
    @State private var isAddWalletOpen: Bool = false
    @State private var walletToEdit: Wallet? = nil
    @State private var isAprendeSheetOpen: Bool = false
    
    private var activeTheme: AppColorTheme {
        viewModel.activeTheme
    }
    
    public var body: some View {
        ZStack {
            ThemedModalBackground(theme: activeTheme)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header Banner
                    VStack(spacing: 12) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#F59E0B"), Color(hex: "#D97706")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .overlay {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.white)
                        }
                    
                    Text("MoneyDev PRO")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white)
                        .contrastTextOutline()
                    
                    if viewModel.isProUser {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Color(hex: "#F59E0B"))
                            Text("Modo PRO Activado de por vida")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color(hex: "#F59E0B"))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color(hex: "#F59E0B").opacity(0.15))
                        .clipShape(Capsule())
                    } else {
                        Text("Desbloquea todo el potencial de tu gestión financiera")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 10)
                
                // Code input box (if not PRO yet)
                if !viewModel.isProUser {
                    VStack(spacing: 14) {
                        Text("Ingresa tu Código de Activación")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.white)
                            .contrastTextOutline()
                        
                        TextField("XXX-XXX-XXX", text: $codeInput)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled(true)
                            .foregroundStyle(Color.white)
                            .submitLabel(.done)
                            .onSubmit {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                            .padding(14)
                            .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: activeTheme == .electricBlack ? Color.white.opacity(0.10) : activeTheme.primary.opacity(0.25), radius: 6, x: 0, y: 2)
                            .onChange(of: codeInput) { _, newValue in
                                formatProCode(newValue)
                            }
                        
                        if isVerifying {
                            VStack(spacing: 12) {
                                HStack {
                                    HStack(spacing: 8) {
                                        if verificationProgress >= 1.0 {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(Color(hex: "#10B981"))
                                        } else {
                                            ProgressView()
                                                .tint(Color(hex: "#F59E0B"))
                                                .scaleEffect(0.85)
                                        }
                                        
                                        Text(verificationText)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(verificationProgress >= 1.0 ? Color(hex: "#10B981") : AppColors.textPrimary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(Int(verificationProgress * 100))%")
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color(hex: "#F59E0B"))
                                }
                                
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(AppColors.midnightBlack)
                                            .frame(height: 10)
                                        
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: verificationProgress >= 1.0 ?
                                                    [Color(hex: "#34D399"), Color(hex: "#10B981")] :
                                                    [Color(hex: "#FDE047"), Color(hex: "#F59E0B"), Color(hex: "#EA580C")],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: max(10, geo.size.width * verificationProgress), height: 10)
                                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: verificationProgress)
                                    }
                                }
                                .frame(height: 10)
                            }
                            .padding(.vertical, 8)
                            .transition(.opacity.combined(with: .scale))
                        } else {
                            Button {
                                activateCode()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "key.fill")
                                    Text("Verificar y Activar")
                                }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "#F59E0B"), Color(hex: "#EA580C")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(codeInput.count < 11)
                            .opacity(codeInput.count < 11 ? 0.6 : 1.0)
                        }
                    }
                    .padding(18)
                    .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 18))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(
                        color: activeTheme == .electricBlack ?
                            Color.white.opacity(0.12) :
                            activeTheme.primary.opacity(0.24),
                        radius: 8, x: 0, y: 3
                    )
                }
                
                // PRO Features Section: Interactive, Ordered and Coherent
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Funciones y Beneficios PRO")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white)
                            .contrastTextOutline()
                        Spacer()
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color(hex: "#F59E0B"))
                    }
                    
                    // 1. MoneyBot Asistente IA
                    proFeatureCard(
                        title: "MoneyBot Asistente IA",
                        description: "Chatbot financiero inteligente, donde podrás consultar tu saldo, analizar gastos e ingresos con IA.",
                        icon: "sparkles",
                        iconGradient: [Color(hex: "#00D2FF"), Color(hex: "#1D4ED8")],
                        badgeText: "ABRIR",
                        badgeColor: Color(hex: "#00D2FF")
                    ) {
                        viewModel.openVoiceAssistant()
                    }
                    

                    proFeatureCard(
                        title: "Billeteras Extras",
                        description: "Crea hasta 10 billeteras independientes con saldos propios, monedas y colores personalizados.",
                        icon: "wallet.pass.fill",
                        iconGradient: [Color(hex: "#10B981"), Color(hex: "#059669")],
                        badgeText: "\(viewModel.wallets.count)/10",
                        badgeColor: Color(hex: "#10B981")
                    ) {
                        isWalletSheetOpen = true
                    }
                    
                    // 4. Temas Exclusivos 
                    proFeatureCard(
                        title: "Temas Exclusivos ",
                        description: "Personaliza tu app con azul neón, verde, rojo y más.",
                        icon: "paintpalette.fill",
                        iconGradient: [Color(hex: "#A855F7"), Color(hex: "#7C3AED")],
                        badgeText: "CONFIGURAR",
                        badgeColor: Color(hex: "#A855F7")
                    ) {
                        viewModel.openSettingsWithHighlight(.theme)
                    }
                    
                    // 5. Ícono Exclusivo 
                    proFeatureCard(
                        title: "Ícono Exclusivo ",
                        description: "Elige entre el ícono clásico de MoneyDev o el ícono dorado exclusivo de Modo PRO.",
                        icon: "app.badge.fill",
                        iconGradient: [Color(hex: "#F59E0B"), Color(hex: "#D97706")],
                        badgeText: "CAMBIAR",
                        badgeColor: Color(hex: "#F59E0B")
                    ) {
                        viewModel.openSettingsWithHighlight(.appIcon)
                    }
                    
                    // 6. Aprende con MoneyDev
                    proFeatureCard(
                        title: "Aprende con MoneyDev",
                        description: "Guías, conceptos clave y consejos prácticos para potenciar tus finanzas personales.",
                        icon: "graduationcap.fill",
                        iconGradient: [Color(hex: "#EC4899"), Color(hex: "#BE185D")],
                        badgeText: "EXPLORAR",
                        badgeColor: Color(hex: "#EC4899")
                    ) {
                        isAprendeSheetOpen = true
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 110)
        }
    }
    .keyboardDismissArrow()
        .sheet(isPresented: $isWalletSheetOpen) {
            WalletQuickSwitchSheet(
                viewModel: viewModel,
                onDismiss: { isWalletSheetOpen = false },
                onAddNew: {
                    isWalletSheetOpen = false
                    isAddWalletOpen = true
                },
                onEdit: { w in
                    isWalletSheetOpen = false
                    walletToEdit = w
                }
            )
            .themedSheetContainer(theme: viewModel.activeTheme)
        }
        .sheet(isPresented: $isAddWalletOpen) {
            AddWalletDialog(
                viewModel: viewModel,
                onDismiss: { isAddWalletOpen = false },
                onConfirm: { name, bal, curr, col in
                    viewModel.createWallet(name: name, initialBalance: bal, currency: curr, colorHex: col)
                    isAddWalletOpen = false
                }
            )
            .themedSheetContainer(theme: viewModel.activeTheme)
        }
        .sheet(item: $walletToEdit) { w in
            EditWalletDialog(
                wallet: w,
                theme: viewModel.activeTheme,
                canDelete: viewModel.wallets.count > 1 && !w.isDefault,
                existingWallets: viewModel.wallets,
                onDismiss: { walletToEdit = nil },
                onSave: { name, bal, curr, col in
                    viewModel.updateWallet(walletId: w.id, name: name, initialBalance: bal, currency: curr, colorHex: col)
                    walletToEdit = nil
                },
                onDelete: {
                    viewModel.deleteWallet(walletId: w.id)
                    walletToEdit = nil
                },
                onClearTransactions: {
                    viewModel.clearWalletTransactionsOnly(walletId: w.id)
                    walletToEdit = nil
                }
            )
            .themedSheetContainer(theme: viewModel.activeTheme)
        }
        .sheet(isPresented: $isAprendeSheetOpen) {
            AprendeConMoneyDevDialog(
                theme: activeTheme,
                onDismiss: { isAprendeSheetOpen = false }
            )
            .themedSheetContainer(theme: activeTheme)
        }
        .fullScreenCover(isPresented: $showWelcomeCelebration) {
            ProWelcomeCelebrationView {
                showWelcomeCelebration = false
            }
        }
        .alert(isSuccess ? "¡Felicidades!" : "Código de Activación", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage ?? "")
        }
    }
    
    @ViewBuilder
    private func proFeatureCard(
        title: String,
        description: String,
        icon: String,
        iconGradient: [Color],
        badgeText: String,
        badgeColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        let isPro = viewModel.isProUser
        
        let cardContent = HStack(spacing: 14) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: iconGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 46, height: 46)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.white)
                        .contrastTextOutline()
                    
                    Spacer()
                    
                    if isPro {
                        HStack(spacing: 3) {
                            Text(badgeText)
                                .font(.system(size: 10, weight: .black))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .black))
                        }
                        .foregroundStyle(badgeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(badgeColor.opacity(0.18))
                        .clipShape(Capsule())
                    }
                }
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(
            color: activeTheme == .electricBlack ?
                Color.white.opacity(0.12) :
                activeTheme.primary.opacity(0.22),
            radius: 8, x: 0, y: 3
        )
        
        if isPro {
            Button(action: action) {
                cardContent
            }
            .buttonStyle(.plain)
        } else {
            cardContent
        }
    }
    
    private func formatProCode(_ text: String) {
        let clean = text.uppercased().filter { $0 >= "A" && $0 <= "Z" }
        if clean.count <= 3 {
            codeInput = clean
        } else if clean.count <= 6 {
            let p1 = clean.prefix(3)
            let p2 = clean.dropFirst(3)
            codeInput = "\(p1)-\(p2)"
        } else {
            let p1 = clean.prefix(3)
            let p2 = clean.dropFirst(3).prefix(3)
            let p3 = clean.dropFirst(6).prefix(3)
            codeInput = "\(p1)-\(p2)-\(p3)"
        }
    }
    
    private func activateCode() {
        let raw = codeInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().replacingOccurrences(of: " ", with: "")
        
        if raw.contains(where: { $0.isNumber }) {
            alertMessage = "Código inválido: no debe contener números."
            showAlert = true
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            return
        }
        
        let lettersOnly = raw.filter { $0 >= "A" && $0 <= "Z" }
        guard lettersOnly.count == 9 else {
            alertMessage = "El código debe tener exactamente 9 letras (ej: XXX-XXX-XXX)."
            showAlert = true
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            return
        }
        
        // Reconstruir formato oficial XXX-XXX-XXX
        let start1 = lettersOnly.startIndex
        let end1 = lettersOnly.index(start1, offsetBy: 3)
        let end2 = lettersOnly.index(end1, offsetBy: 3)
        let end3 = lettersOnly.index(end2, offsetBy: 3)
        let p1 = String(lettersOnly[start1..<end1])
        let p2 = String(lettersOnly[end1..<end2])
        let p3 = String(lettersOnly[end2..<end3])
        let formattedCode = "\(p1)-\(p2)-\(p3)"
        
        // Verificar si es uno de los códigos válidos
        let isValid = ExpenseRepository.official20ProCodes.contains(formattedCode) || ExpenseRepository.official20ProCodes.contains(lettersOnly)
        
        guard isValid else {
            alertMessage = "Código incorrecto. Por favor verifica e intenta de nuevo."
            showAlert = true
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            return
        }
        
        // Si es válido, ejecutar la animación: "Verificando..." -> "Completado"
        withAnimation(.easeInOut(duration: 0.3)) {
            isVerifying = true
            verificationProgress = 0.0
            verificationText = "Verificando..."
        }
        
        let impactGenerator = UIImpactFeedbackGenerator(style: .light)
        impactGenerator.impactOccurred()
        
        Task {
            // Fase 1: progreso inicial
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.4)) {
                    verificationProgress = 0.45
                }
            }
            
            // Fase 2: progreso medio
            try? await Task.sleep(nanoseconds: 450_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) {
                    verificationProgress = 0.85
                }
            }
            
            // Fase 3: completado
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    verificationProgress = 1.0
                    verificationText = "Completado ✓"
                }
                let notifGen = UINotificationFeedbackGenerator()
                notifGen.notificationOccurred(.success)
            }
            
            // Fase 4: activar y mostrar pantalla de bienvenida
            try? await Task.sleep(nanoseconds: 700_000_000)
            await MainActor.run {
                _ = viewModel.activateProWithCode(formattedCode)
                withAnimation {
                    isVerifying = false
                    codeInput = ""
                    showWelcomeCelebration = true
                }
            }
        }
    }
}
