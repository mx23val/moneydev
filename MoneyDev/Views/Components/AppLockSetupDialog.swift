import SwiftUI
import LocalAuthentication

public struct AppLockSetupDialog: View {
    @Bindable var viewModel: ExpenseViewModel
    @Environment(\.dismiss) private var dismiss
    
    private var securityManager = AppSecurityManager.shared
    
    // Estado de autorización para editar si ya está configurado
    @State private var isAuthenticatedToEdit: Bool = false
    @State private var verifyInputPIN: String = ""
    @State private var verifyInputPassword: String = ""
    @State private var verifyErrorMessage: String? = nil
    @State private var verifyShakeAttempts: Int = 0
    @State private var isAuthenticatingFaceID: Bool = false
    
    // Estados para configurar/reemplazar la clave
    @State private var selectedLockType: AppSecurityManager.LockType = .pin
    @State private var secretInput: String = ""
    @State private var secretConfirm: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var enableBiometrics: Bool = true
    @State private var biometricsVerified: Bool = false
    @State private var isVerifyingBiometrics: Bool = false
    
    @State private var errorMessage: String? = nil
    @State private var showSuccessAlert: Bool = false
    @State private var showRemoveConfirmation: Bool = false
    
    private var activeTheme: AppColorTheme {
        viewModel.activeTheme
    }
    
    public init(viewModel: ExpenseViewModel) {
        self.viewModel = viewModel
    }
    
    private var themedCardBackground: some View {
        ThemedCardBackgroundView(theme: activeTheme, cornerRadius: 14)
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                ThemedModalBackground(theme: activeTheme)
                
                if securityManager.isLockEnabled && !isAuthenticatedToEdit {
                    // Pantalla de autenticación previa obligatoria
                    authenticationChallengeView
                } else {
                    // Pantalla de configuración y edición de clave
                    setupFormView
                }
                
                if showRemoveConfirmation {
                    deactivateLockConfirmationModal
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showRemoveConfirmation)
            .navigationTitle(securityManager.isLockEnabled ? (isAuthenticatedToEdit ? "Editar Bloqueo" : "Bloquear app") : "Bloquear app")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .foregroundStyle(AppColors.textSecondary)
                }
            }
            .keyboardDismissArrow()
            .onAppear {
                securityManager.checkBiometricAvailability()
                enableBiometrics = securityManager.isBiometricsEnabled
                selectedLockType = securityManager.lockType
                
                if !securityManager.isLockEnabled {
                    isAuthenticatedToEdit = true
                } else {
                    isAuthenticatedToEdit = false
                    if securityManager.isBiometricsEnabled && securityManager.canUseBiometrics {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            triggerAuthenticationFaceID()
                        }
                    }
                }
            }
            .alert("¡Bloqueo Actualizado!", isPresented: $showSuccessAlert) {
                Button("Entendido", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("La configuración de seguridad de tu aplicación se ha actualizado exitosamente.")
            }

        }
    }
    
    // MARK: - Pantalla de Autenticación Previa (Desafío de Seguridad)
    private var authenticationChallengeView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icono de candado con escudo
            ZStack {
                Circle()
                    .fill(activeTheme.accentColor.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Circle()
                    .stroke(activeTheme.accentColor.opacity(0.4), lineWidth: 1.5)
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
            
            VStack(spacing: 8) {
                Text("Autenticación Requerida")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                
                Text("Ingresa tu \(securityManager.lockType == .pin ? "PIN actual" : "contraseña actual") o usa \(securityManager.availableBiometryType.rawValue) para poder editar y reemplazar la seguridad.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Mensaje de Error
            if let verifyErrorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 13))
                    Text(verifyErrorMessage)
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(AppColors.expenseRoseLight)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AppColors.expenseRose.opacity(0.15))
                .clipShape(Capsule())
            }
            
            // Input según tipo
            if securityManager.lockType == .pin {
                // PIN dots
                HStack(spacing: 12) {
                    let maxDots = max(6, verifyInputPIN.count)
                    ForEach(0..<maxDots, id: \.self) { index in
                        let isFilled = index < verifyInputPIN.count
                        Circle()
                            .fill(isFilled ? activeTheme.accentColor : AppColors.darkNavySurface)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(isFilled ? activeTheme.accentColor : AppColors.cardBorderNavy, lineWidth: 1.5)
                            )
                            .scaleEffect(isFilled ? 1.15 : 1.0)
                    }
                }
                .padding(.vertical, 8)
                .modifier(ShakeEffect(shakes: verifyShakeAttempts * 2))
                
                // Teclado numérico
                VStack(spacing: 14) {
                    HStack(spacing: 24) {
                        verifyKeypadButton("1")
                        verifyKeypadButton("2")
                        verifyKeypadButton("3")
                    }
                    HStack(spacing: 24) {
                        verifyKeypadButton("4")
                        verifyKeypadButton("5")
                        verifyKeypadButton("6")
                    }
                    HStack(spacing: 24) {
                        verifyKeypadButton("7")
                        verifyKeypadButton("8")
                        verifyKeypadButton("9")
                    }
                    HStack(spacing: 24) {
                        if securityManager.isBiometricsEnabled && securityManager.canUseBiometrics {
                            Button {
                                triggerAuthenticationFaceID()
                            } label: {
                                Image(systemName: securityManager.availableBiometryType.iconName)
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(activeTheme.accentIconColor)
                                    .frame(width: 72, height: 72)
                                    .background(AppColors.darkNavySurface)
                                    .clipShape(Circle())
                            }
                        } else {
                            Color.clear.frame(width: 72, height: 72)
                        }
                        
                        verifyKeypadButton("0")
                        
                        Button {
                            if !verifyInputPIN.isEmpty {
                                verifyInputPIN.removeLast()
                                verifyErrorMessage = nil
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
            } else {
                // Password input
                VStack(spacing: 16) {
                    HStack {
                        SecureField("Ingresa contraseña actual", text: $verifyInputPassword)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    .padding(16)
                    .themedInputField(theme: activeTheme, cornerRadius: 14)
                    .modifier(ShakeEffect(shakes: verifyShakeAttempts * 2))
                    
                    Button {
                        validateVerifyPassword()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.open.fill")
                                .font(.system(size: 15, weight: .bold))
                            Text("Verificar y Editar")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(activeTheme.onPrimaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: activeTheme == .electricBlack ? [Color(hex: "#1E293B"), Color(hex: "#0F172A")] : activeTheme.gradient,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(activeTheme.pillBorder, lineWidth: 1)
                        )
                    }
                    .disabled(verifyInputPassword.isEmpty)
                }
                .padding(.horizontal, 16)
            }
            
            Spacer()
            
            // Botón biométrico al pie si está disponible
            if securityManager.isBiometricsEnabled && securityManager.canUseBiometrics {
                Button {
                    triggerAuthenticationFaceID()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: securityManager.availableBiometryType.iconName)
                            .font(.system(size: 18, weight: .bold))
                        Text("Verificar con \(securityManager.availableBiometryType.rawValue)")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(activeTheme.accentIconColor)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(AppColors.darkNavySurface)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(activeTheme.accentColor.opacity(0.35), lineWidth: 1)
                    )
                }
                .padding(.bottom, 20)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Formulario de Configuración y Reemplazo de Clave
    private var setupFormView: some View {
        ScrollView {
            VStack(spacing: 22) {
                // Header con Escudo de Seguridad
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#00D2FF").opacity(0.3), Color(hex: "#1D4ED8").opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 76, height: 76)
                        
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#00D2FF"), Color(hex: "#3B82F6")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .padding(.top, 8)
                    
                    Text(securityManager.isLockEnabled ? "Editar Bloqueo" : "Bloquear app")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                    
                    Text(securityManager.isLockEnabled ?
                         "Reemplaza tu contraseña o PIN actual y actualiza la configuración de Face ID o Touch ID." :
                         "Protege el acceso a tus finanzas, cuentas y balances. Si la app se cierra o queda en segundo plano por más de 3 minutos, se bloqueará automáticamente.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                
                // Si ya está configurado, mostrar estado actual
                if securityManager.isLockEnabled {
                    configuredStatusCard
                }
                
                // Selector de Tipo de Bloqueo (PIN vs Contraseña)
                VStack(alignment: .leading, spacing: 10) {
                    Text("TIPO DE PROTECCIÓN")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentTextColor)
                        .padding(.horizontal, 4)
                    
                    HStack(spacing: 12) {
                        lockTypeButton(type: .pin, title: "PIN Numérico", subtitle: "6 a 10 dígitos", icon: "number")
                        lockTypeButton(type: .password, title: "Contraseña", subtitle: "Hasta 15 caracteres", icon: "textformat")
                    }
                }
                
                // Formulario de Entrada de Nueva Clave
                VStack(alignment: .leading, spacing: 14) {
                    Text(selectedLockType == .pin ? "INGRESA NUEVO PIN" : "INGRESA NUEVA CONTRASEÑA")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentTextColor)
                        .padding(.horizontal, 4)
                    
                    // Campo Principal
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            if selectedLockType == .pin {
                                TextField("Ingresa PIN (6 a 10 dígitos)", text: $secretInput)
                                    .keyboardType(.numberPad)
                                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                                    .foregroundStyle(AppColors.textPrimary)
                                    .onChange(of: secretInput) { _, val in
                                        let filtered = val.filter { $0.isNumber }
                                        if filtered.count > 10 {
                                            secretInput = String(filtered.prefix(10))
                                        } else if filtered != val {
                                            secretInput = filtered
                                        }
                                    }
                            } else {
                                if isPasswordVisible {
                                    TextField("Máximo 15 caracteres", text: $secretInput)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(AppColors.textPrimary)
                                        .submitLabel(.done)
                                        .onSubmit {
                                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                        }
                                } else {
                                    SecureField("Máximo 15 caracteres", text: $secretInput)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(AppColors.textPrimary)
                                        .submitLabel(.done)
                                        .onSubmit {
                                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                        }
                                }
                            }
                            
                            if selectedLockType == .password {
                                Button {
                                    isPasswordVisible.toggle()
                                } label: {
                                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                        .font(.system(size: 15))
                                        .foregroundStyle(AppColors.textMuted)
                                }
                            }
                        }
                        .padding(14)
                        .themedInputField(theme: activeTheme, cornerRadius: 14)
                        
                        // Indicador de longitud
                        HStack {
                            Spacer()
                            if selectedLockType == .pin {
                                let count = secretInput.count
                                let isValidLen = count >= 6 && count <= 10
                                Text("\(count)/10 dígitos \(count >= 6 ? "✓" : "(Mínimo 6)")")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(isValidLen ? AppColors.incomeEmeraldLight : AppColors.expenseRoseLight)
                            } else {
                                let count = secretInput.count
                                Text("\(count)/15 caracteres")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(count > 0 && count <= 15 ? AppColors.incomeEmeraldLight : AppColors.textMuted)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    
                    // Campo de Confirmación
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            if selectedLockType == .pin {
                                TextField("Confirma tu PIN", text: $secretConfirm)
                                    .keyboardType(.numberPad)
                                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                                    .foregroundStyle(AppColors.textPrimary)
                                    .onChange(of: secretConfirm) { _, val in
                                        let filtered = val.filter { $0.isNumber }
                                        if filtered.count > 10 {
                                            secretConfirm = String(filtered.prefix(10))
                                        } else if filtered != val {
                                            secretConfirm = filtered
                                        }
                                    }
                            } else {
                                if isPasswordVisible {
                                    TextField("Confirma tu contraseña", text: $secretConfirm)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(AppColors.textPrimary)
                                        .submitLabel(.done)
                                        .onSubmit {
                                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                        }
                                } else {
                                    SecureField("Confirma tu contraseña", text: $secretConfirm)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(AppColors.textPrimary)
                                        .submitLabel(.done)
                                        .onSubmit {
                                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                        }
                                }
                            }
                        }
                        .padding(14)
                        .themedInputField(theme: activeTheme, cornerRadius: 14)
                        
                        if !secretConfirm.isEmpty {
                            HStack {
                                Spacer()
                                if secretInput == secretConfirm {
                                    Label("Las claves coinciden", systemImage: "checkmark.circle.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(AppColors.incomeEmeraldLight)
                                } else {
                                    Label("Las claves no coinciden", systemImage: "xmark.circle.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(AppColors.expenseRoseLight)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }
                
                // SECCIÓN BIOMÉTRICA (FACE ID O TOUCH ID)
                VStack(alignment: .leading, spacing: 10) {
                    Text("DESBLOQUEO BIOMÉTRICO")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentTextColor)
                        .padding(.horizontal, 4)
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill((activeTheme == .electricBlack ? Color.white : activeTheme.accentColor).opacity(0.15))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: securityManager.availableBiometryType.iconName)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(activeTheme == .electricBlack ? Color.white : activeTheme.accentColor)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(securityManager.availableBiometryType == .faceID ? "Usar Face ID" :
                                     securityManager.availableBiometryType == .touchID ? "Usar Touch ID" : "Biometría")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(AppColors.textPrimary)
                                
                                Text("Desbloquea instantáneamente sin escribir tu \(selectedLockType.rawValue.lowercased()).")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $enableBiometrics)
                                .labelsHidden()
                                .tint(activeTheme.toggleTint)
                        }
                        .padding(14)
                        .background(themedCardBackground)
                        
                        // Botón para solicitar Face ID / Touch ID en el momento y validar al usuario
                        Button {
                            requestBiometricVerification()
                        } label: {
                            HStack(spacing: 8) {
                                if isVerifyingBiometrics {
                                    ProgressView()
                                        .tint(Color(hex: "#00D2FF"))
                                } else {
                                    Image(systemName: biometricsVerified ? "checkmark.circle.fill" : securityManager.availableBiometryType.iconName)
                                        .font(.system(size: 16, weight: .bold))
                                }
                                
                                Text(biometricsVerified ? "✓ Identidad Verificada" : securityManager.biometryActionTitle)
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundStyle(biometricsVerified ? AppColors.incomeEmeraldLight : Color(hex: "#00D2FF"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                (biometricsVerified ? AppColors.incomeEmerald : Color(hex: "#00D2FF")).opacity(0.12)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        (biometricsVerified ? AppColors.incomeEmerald : Color(hex: "#00D2FF")).opacity(0.35),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .disabled(isVerifyingBiometrics)
                    }
                    .padding(14)
                    .background(AppColors.darkNavySurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                // Mensaje de Error si hay
                if let errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppColors.expenseRoseLight)
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.expenseRoseLight)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.expenseRose.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                // Botón de Guardar / Reemplazar
                Button {
                    saveLockConfiguration()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text(securityManager.isLockEnabled ? "Reemplazar Contraseña y Guardar" : "Activar Bloqueo")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(activeTheme.onPrimaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(
                            colors: activeTheme == .electricBlack ? [Color(hex: "#1E293B"), Color(hex: "#0F172A")] : activeTheme.gradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(activeTheme.pillBorder, lineWidth: 1)
                    )
                    .shadow(color: (activeTheme == .electricBlack ? Color.white.opacity(0.15) : activeTheme.primary.opacity(0.35)), radius: 10)
                }
                
                // Botón Desactivar si ya está activo (con estilo de botón y sombreado visible)
                if securityManager.isLockEnabled {
                    Button(role: .destructive) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showRemoveConfirmation = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.slash.fill")
                                .font(.system(size: 15, weight: .bold))
                            Text("Desactivar Bloqueo de la App")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(Color(hex: "#FF4D6D"))
                        .contrastTextOutline()
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: "#220D15").opacity(0.92),
                                            Color(hex: "#14060B").opacity(0.96)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color(hex: "#FF4D6D").opacity(0.35), lineWidth: 1)
                                )
                        )
                        .shadow(color: Color(hex: "#FF4D6D").opacity(0.28), radius: 8, x: 0, y: 3)
                        .shadow(color: Color.black.opacity(0.55), radius: 6, x: 0, y: 3)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(20)
            .padding(.bottom, 30)
        }
    }
    
    // MARK: - Tarjeta de Estado si ya está configurado
    private var configuredStatusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 24))
                .foregroundStyle(AppColors.incomeEmeraldLight)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Protección Activa")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                
                Text("Tipo actual: \(securityManager.lockType.rawValue) • \(securityManager.isBiometricsEnabled ? securityManager.availableBiometryType.rawValue : "Solo clave")")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary)
            }
            
            Spacer()
        }
        .padding(14)
        .background(AppColors.incomeEmerald.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.incomeEmerald.opacity(0.35), lineWidth: 1)
        )
    }
    
    // MARK: - Botón Selector de Tipo
    private func lockTypeButton(type: AppSecurityManager.LockType, title: String, subtitle: String, icon: String) -> some View {
        let isSelected = (selectedLockType == type)
        
        return Button {
            selectedLockType = type
            secretInput = ""
            secretConfirm = ""
            errorMessage = nil
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(isSelected ? (activeTheme == .electricBlack ? Color.white : activeTheme.accentIconColor) : AppColors.textSecondary)
                
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isSelected ?
                    (activeTheme == .electricBlack ? Color.white.opacity(0.16) : activeTheme.primary.opacity(0.20)) :
                    Color(hex: "#101827")
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: isSelected ? (activeTheme == .electricBlack ? Color.white.opacity(0.2) : activeTheme.primary.opacity(0.35)) : Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Teclado y Validaciones del Desafío Previo
    private func verifyKeypadButton(_ digit: String) -> some View {
        Button {
            guard verifyInputPIN.count < 10 else { return }
            verifyInputPIN.append(digit)
            verifyErrorMessage = nil
            
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            if verifyInputPIN.count >= 6 {
                if securityManager.verifySecret(verifyInputPIN) {
                    unlockToEditSuccess()
                } else if verifyInputPIN.count == 10 {
                    handleIncorrectVerifyAttempt()
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
    
    private func validateVerifyPassword() {
        if securityManager.verifySecret(verifyInputPassword) {
            unlockToEditSuccess()
        } else {
            handleIncorrectVerifyAttempt()
        }
    }
    
    private func unlockToEditSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isAuthenticatedToEdit = true
        }
    }
    
    private func handleIncorrectVerifyAttempt() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        withAnimation(.default) {
            verifyShakeAttempts += 1
            verifyErrorMessage = securityManager.lockType == .pin ? "PIN incorrecto" : "Contraseña incorrecta"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            verifyInputPIN = ""
            verifyInputPassword = ""
        }
    }
    
    private func triggerAuthenticationFaceID() {
        guard !isAuthenticatingFaceID else { return }
        isAuthenticatingFaceID = true
        verifyErrorMessage = nil
        
        Task {
            let (success, error) = await securityManager.authenticateWithBiometrics(reason: "Confirma tu identidad para modificar la configuración de seguridad")
            await MainActor.run {
                isAuthenticatingFaceID = false
                if success {
                    unlockToEditSuccess()
                } else if let err = error, !err.contains("cancel") && !err.contains("Cancel") {
                    verifyErrorMessage = err
                }
            }
        }
    }
    
    // MARK: - Acciones de Configuración
    private func requestBiometricVerification() {
        isVerifyingBiometrics = true
        errorMessage = nil
        
        Task {
            let (success, error) = await securityManager.testBiometricsForSetup()
            await MainActor.run {
                isVerifyingBiometrics = false
                if success {
                    biometricsVerified = true
                    enableBiometrics = true
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                } else {
                    biometricsVerified = false
                    errorMessage = error ?? "No se pudo verificar la biometría."
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }
    
    private func saveLockConfiguration() {
        errorMessage = nil
        let clean = secretInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanConfirm = secretConfirm.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validaciones
        guard !clean.isEmpty else {
            errorMessage = "Por favor ingresa tu \(selectedLockType.rawValue.lowercased())."
            return
        }
        
        if selectedLockType == .pin {
            guard clean.count >= 6 && clean.count <= 10 else {
                errorMessage = "El PIN debe tener un mínimo de 6 dígitos y un máximo de 10 dígitos."
                return
            }
            guard clean.allSatisfy({ $0.isNumber }) else {
                errorMessage = "El PIN solo puede contener números."
                return
            }
        } else {
            guard clean.count <= 15 else {
                errorMessage = "La contraseña debe tener como máximo 15 caracteres."
                return
            }
        }
        
        guard clean == cleanConfirm else {
            errorMessage = "Las dos claves no coinciden. Por favor verifícalas."
            return
        }
        
        let result = securityManager.setupLock(
            type: selectedLockType,
            secret: clean,
            enableBiometrics: enableBiometrics
        )
        
        if result.success {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            showSuccessAlert = true
        } else {
            errorMessage = result.message
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
    
    // MARK: - Modal Flotante para Desactivar Bloqueo
    private var deactivateLockConfirmationModal: some View {
        ZStack {
            // Fondo oscuro semitransparente con desenfoque suave
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showRemoveConfirmation = false
                    }
                }
            
            // Ventana flotante con degradado del tema y alto contraste
            VStack(spacing: 18) {
                // Icono representativo
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.28))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "lock.slash.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.white)
                        .contrastTextOutline()
                }
                
                // Título
                Text("¿Desactivar Bloqueo?")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.white)
                    .contrastTextOutline()
                    .multilineTextAlignment(.center)
                
                // Mensaje explicativo
                Text("Cualquiera que tenga acceso al dispositivo podrá abrir la app y ver tus registros financieros sin necesidad de PIN ni biometría.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .contrastTextOutline()
                    .padding(.horizontal, 4)
                
                // Acciones
                VStack(spacing: 10) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showRemoveConfirmation = false
                        }
                        securityManager.removeLock()
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.warning)
                        dismiss()
                    } label: {
                        Text("Desactivar Bloqueo")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.white)
                            .contrastTextOutline()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: "#DC2626"))
                            )
                            .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
                    }
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showRemoveConfirmation = false
                        }
                    } label: {
                        Text("Cancelar")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .contrastTextOutline()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.35))
                            )
                    }
                }
                .padding(.top, 4)
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: activeTheme == .electricBlack ?
                                [Color(hex: "#1E293B"), Color(hex: "#0F172A")] :
                                activeTheme.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.65), radius: 24, x: 0, y: 12)
            )
            .frame(maxWidth: 320)
            .padding(24)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        .zIndex(100)
    }
}
