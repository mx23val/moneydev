import SwiftUI
import LocalAuthentication

public struct AppLockScreenView: View {
    @Bindable var viewModel: ExpenseViewModel
    private var securityManager = AppSecurityManager.shared
    
    @State private var enteredPIN: String = ""
    @State private var enteredPassword: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var errorMessage: String? = nil
    @State private var shakeAttempts: Int = 0
    @State private var isAuthenticatingBiometrics: Bool = false
    
    private var activeTheme: AppColorTheme {
        viewModel.activeTheme
    }
    
    public init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ZStack {
            // Fondo con base 100% sólida opaca y degradado temático ambiental ultra oscuro
            ThemedModalBackground(theme: activeTheme)
            
            VStack(spacing: 24) {
                Spacer()
                
                // Emblema y Título
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill((activeTheme == .electricBlack ? Color.white : activeTheme.primary).opacity(0.15))
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .stroke((activeTheme == .electricBlack ? Color.white : activeTheme.primary).opacity(0.35), lineWidth: 1.5)
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: activeTheme == .electricBlack ? [Color.white, Color(hex: "#94A3B8")] : activeTheme.gradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    Text("MoneyDev Seguro")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .contrastTextOutline()
                    
                    Text(securityManager.lockType == .pin ? "Ingresa tu PIN de seguridad" : "Ingresa tu contraseña de acceso")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                        .contrastTextOutline()
                }
                
                // Mensaje de Error si hay
                if let errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 13))
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(AppColors.expenseRoseLight)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppColors.expenseRose.opacity(0.15))
                    .clipShape(Capsule())
                    .transition(.opacity.combined(with: .scale))
                }
                
                // CONTENIDO SEGÚN TIPO: PIN O CONTRASEÑA
                if securityManager.lockType == .pin {
                    pinDisplayAndKeypad
                } else {
                    passwordInputSection
                }
                
                Spacer()
                
                // Botón Biométrico adicional al pie
                if securityManager.isBiometricsEnabled && securityManager.canUseBiometrics {
                    Button {
                        triggerBiometrics(isManual: true)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: securityManager.availableBiometryType.iconName)
                                .font(.system(size: 20, weight: .bold))
                            Text("Desbloquear con \(securityManager.availableBiometryType.rawValue)")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentTextColor)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(AppColors.darkNavySurface)
                        .clipShape(Capsule())
                        .shadow(color: (activeTheme == .electricBlack ? Color.white : activeTheme.primary).opacity(0.25), radius: 6, x: 0, y: 2)
                    }
                    .padding(.bottom, 20)
                }
            }
            .padding(.horizontal, 24)
        }
        .keyboardDismissArrow()
        .onAppear {
            if securityManager.isBiometricsEnabled && securityManager.canUseBiometrics {
                // Iniciar autenticación biométrica automática sin mostrar errores a simple vista
                triggerBiometrics(isManual: false)
            }
        }
    }
    
    // MARK: - Sección PIN: Puntos indicadores y Teclado Numérico
    private var pinDisplayAndKeypad: some View {
        let targetLength = max(6, securityManager.savedPasscodeLength)
        return VStack(spacing: 30) {
            // Indicador de Puntos del PIN
            HStack(spacing: 12) {
                ForEach(0..<targetLength, id: \.self) { index in
                    let isFilled = index < enteredPIN.count
                    Circle()
                        .fill(isFilled ? activeTheme.primary : AppColors.darkNavySurface)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(isFilled ? activeTheme.primary : AppColors.cardBorderNavy, lineWidth: 1.5)
                        )
                        .scaleEffect(isFilled ? 1.15 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: enteredPIN)
                }
            }
            .padding(.vertical, 8)
            .modifier(ShakeEffect(shakes: shakeAttempts * 2))
            
            // Teclado Numérico Bancario (1 al 9, Biometría, 0, Borrar)
            VStack(spacing: 14) {
                HStack(spacing: 24) {
                    keypadButton("1")
                    keypadButton("2")
                    keypadButton("3")
                }
                HStack(spacing: 24) {
                    keypadButton("4")
                    keypadButton("5")
                    keypadButton("6")
                }
                HStack(spacing: 24) {
                    keypadButton("7")
                    keypadButton("8")
                    keypadButton("9")
                }
                HStack(spacing: 24) {
                    // Botón Biometría o espacio
                    if securityManager.isBiometricsEnabled && securityManager.canUseBiometrics {
                        Button {
                            triggerBiometrics(isManual: true)
                        } label: {
                            Image(systemName: securityManager.availableBiometryType.iconName)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(activeTheme.primary)
                                .frame(width: 72, height: 72)
                                .background(AppColors.darkNavySurface)
                                .clipShape(Circle())
                        }
                    } else {
                        Color.clear
                            .frame(width: 72, height: 72)
                    }
                    
                    keypadButton("0")
                    
                    // Botón Retroceso
                    Button {
                        if !enteredPIN.isEmpty {
                            enteredPIN.removeLast()
                            errorMessage = nil
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                    } label: {
                        Image(systemName: "delete.left.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)
                            .frame(width: 72, height: 72)
                            .background(AppColors.darkNavySurface)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }
    
    private func keypadButton(_ digit: String) -> some View {
        let targetLength = max(6, securityManager.savedPasscodeLength)
        return Button {
            guard enteredPIN.count < targetLength else { return }
            enteredPIN.append(digit)
            errorMessage = nil
            
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            // Si coincide exactamente con la longitud requerida, verificar de inmediato
            if enteredPIN.count == targetLength {
                if securityManager.verifySecret(enteredPIN) {
                    unlockSuccess()
                } else {
                    handleIncorrectAttempt()
                }
            }
        } label: {
            Text(digit)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .contrastTextOutline()
                .frame(width: 72, height: 72)
                .background(Color(hex: "#090E1A"))
                .clipShape(Circle())
                .overlay(Circle().stroke(AppColors.cardBorderNavy.opacity(0.7), lineWidth: 1.2))
                .shadow(color: Color.black.opacity(0.7), radius: 5, x: 0, y: 3)
        }
    }
    
    // MARK: - Sección Contraseña
    private var passwordInputSection: some View {
        VStack(spacing: 16) {
            HStack {
                if isPasswordVisible {
                    TextField("Contraseña", text: $enteredPassword)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColors.textPrimary)
                        .submitLabel(.done)
                        .onSubmit {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                } else {
                    SecureField("Contraseña", text: $enteredPassword)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColors.textPrimary)
                        .submitLabel(.done)
                        .onSubmit {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                }
                
                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(AppColors.textMuted)
                }
            }
            .padding(16)
            .themedInputField(cornerRadius: 14)
            .modifier(ShakeEffect(shakes: shakeAttempts * 2))
            
            Button {
                validatePassword()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text("Desbloquear")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: activeTheme.gradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(enteredPassword.isEmpty)
            .opacity(enteredPassword.isEmpty ? 0.6 : 1.0)
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Validación y Desbloqueo
    private func validatePassword() {
        if securityManager.verifySecret(enteredPassword) {
            unlockSuccess()
        } else {
            handleIncorrectAttempt()
        }
    }
    
    private func triggerBiometrics(isManual: Bool = false) {
        guard !isAuthenticatingBiometrics else { return }
        isAuthenticatingBiometrics = true
        if isManual {
            errorMessage = nil
        }
        
        Task {
            let (success, error) = await securityManager.authenticateWithBiometrics()
            isAuthenticatingBiometrics = false
            if success {
                unlockSuccess()
            } else if isManual, let error = error {
                withAnimation(.default) {
                    errorMessage = error
                }
            }
        }
    }
    
    private func unlockSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        withAnimation(.easeInOut(duration: 0.18)) {
            securityManager.unlock()
        }
    }
    
    private func handleIncorrectAttempt() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        
        withAnimation(.default) {
            shakeAttempts += 1
            errorMessage = securityManager.lockType == .pin ? "PIN incorrecto" : "Contraseña incorrecta"
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            enteredPIN = ""
            enteredPassword = ""
        }
    }
}

// MARK: - Modificador de Sacudida (Shake Effect)
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit = 3
    var animatableData: CGFloat
    
    init(shakes: Int) {
        self.animatableData = CGFloat(shakes)
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
                y: 0
            )
        )
    }
}
