import Foundation
import LocalAuthentication
import Security
import CryptoKit
import Observation

@Observable
public final class AppSecurityManager: @unchecked Sendable {
    public static let shared = AppSecurityManager()
    
    public enum BiometryType: String {
        case faceID = "Face ID"
        case touchID = "Touch ID"
        case opticID = "Optic ID"
        case none = "No disponible"
        
        public var iconName: String {
            switch self {
            case .faceID:
                return "faceid"
            case .touchID:
                return "touchid"
            case .opticID:
                return "opticid"
            case .none:
                return "lock.shield.fill"
            }
        }
    }
    
    public enum LockType: String, Codable {
        case pin = "PIN"
        case password = "Contraseña"
    }
    
    // MARK: - Published Properties
    public var isLockEnabled: Bool = false
    public var lockType: LockType = .pin
    public var isBiometricsEnabled: Bool = false
    public var isAppLocked: Bool = false
    public var isEvaluatingBiometrics: Bool = false
    
    // Info del hardware biométrico
    public var availableBiometryType: BiometryType = .none
    public var canUseBiometrics: Bool = false
    
    // Timeout de 3 minutos (180 segundos)
    public let timeoutSeconds: TimeInterval = 180.0
    private var lastBackgroundTimestamp: Date? = nil
    
    // Claves de UserDefaults / Keychain
    private let keyLockEnabled = "key_moneydev_app_lock_enabled"
    private let keyLockType = "key_moneydev_app_lock_type"
    private let keyBiometricsEnabled = "key_moneydev_biometrics_enabled"
    private let keyPasscodeHash = "key_moneydev_passcode_hash"
    private let keyPasscodeLength = "key_moneydev_passcode_length"
    private let keychainService = "com.moneydev.applock"
    private let keychainAccount = "user_passcode"
    
    public var savedPasscodeLength: Int = 6
    
    private init() {
        loadSettings()
        checkBiometricAvailability()
        
        // Si el bloqueo está habilitado al abrir en frío, la app inicia bloqueada
        if isLockEnabled {
            isAppLocked = true
        }
    }
    
    // MARK: - Detección de Biometría (Face ID / Touch ID)
    public func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        canUseBiometrics = canEvaluate
        
        switch context.biometryType {
        case .faceID:
            availableBiometryType = .faceID
        case .touchID:
            availableBiometryType = .touchID
        case .opticID:
            availableBiometryType = .opticID
        case .none:
            availableBiometryType = .none
        @unknown default:
            availableBiometryType = canEvaluate ? .touchID : .none
        }
    }
    
    public var biometryActionTitle: String {
        switch availableBiometryType {
        case .faceID:
            return "Solicitar Face ID"
        case .touchID:
            return "Solicitar Touch ID"
        case .opticID:
            return "Solicitar Optic ID"
        case .none:
            return "Solicitar Biometría"
        }
    }
    
    public var securitySubtitle: String {
        switch availableBiometryType {
        case .faceID:
            return "Protege con pin, contraseña o Face ID"
        case .touchID:
            return "Protege con pin, contraseña o Touch ID"
        case .opticID:
            return "Protege con pin, contraseña o Optic ID"
        case .none:
            return "Protege con pin o contraseña"
        }
    }
    
    // MARK: - Autenticación Biométrica
    public func authenticateWithBiometrics(reason: String = "Desbloquea MoneyDev para acceder a tus finanzas") async -> (success: Bool, error: String?) {
        let context = LAContext()
        context.localizedCancelTitle = "Cancelar"
        context.localizedFallbackTitle = "Usar \(lockType.rawValue)"
        
        var authError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) else {
            await MainActor.run {
                self.canUseBiometrics = false
            }
            return (false, nil)
        }
        
        await MainActor.run {
            self.isEvaluatingBiometrics = true
        }
        
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                Task { @MainActor in
                    self.isEvaluatingBiometrics = false
                    if success {
                        self.unlock()
                        continuation.resume(returning: (true, nil))
                    } else {
                        var friendlyMessage: String? = nil
                        if let laError = error as? LAError {
                            switch laError.code {
                            case .userCancel, .systemCancel, .appCancel, .userFallback:
                                friendlyMessage = nil
                            case .authenticationFailed:
                                friendlyMessage = "Rostro o huella no reconocida. Intenta de nuevo o ingresa tu \(self.lockType.rawValue)."
                            case .biometryLockout:
                                friendlyMessage = "Demasiados intentos fallidos. Ingresa tu \(self.lockType.rawValue)."
                            case .biometryNotAvailable, .biometryNotEnrolled:
                                self.canUseBiometrics = false
                                friendlyMessage = nil
                            default:
                                friendlyMessage = nil
                            }
                        } else if let nsError = error as NSError?, nsError.code == 6 {
                            self.canUseBiometrics = false
                            friendlyMessage = nil
                        }
                        continuation.resume(returning: (false, friendlyMessage))
                    }
                }
            }
        }
    }
    
    /// Prueba la biometría durante la configuración para confirmar que es el usuario del dispositivo
    public func testBiometricsForSetup() async -> (success: Bool, error: String?) {
        let context = LAContext()
        context.localizedCancelTitle = "Cancelar"
        
        var authError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) else {
            return (false, "El dispositivo no tiene biometría configurada o activa.")
        }
        
        return await withCheckedContinuation { continuation in
            let reason = "Confirma tu identidad con \(self.availableBiometryType.rawValue) para activar el bloqueo."
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                Task { @MainActor in
                    if success {
                        continuation.resume(returning: (true, nil))
                    } else {
                        let msg = error?.localizedDescription ?? "No se pudo verificar tu identidad biométrica."
                        continuation.resume(returning: (false, msg))
                    }
                }
            }
        }
    }
    
    // MARK: - Configurar y Guardar Bloqueo
    public func setupLock(type: LockType, secret: String, enableBiometrics: Bool) -> (success: Bool, message: String) {
        let clean = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch type {
        case .pin:
            guard clean.count >= 6 && clean.count <= 10 else {
                return (false, "El PIN debe tener entre 6 y 10 dígitos numéricos.")
            }
            guard clean.allSatisfy({ $0.isNumber }) else {
                return (false, "El PIN solo puede contener dígitos numéricos.")
            }
        case .password:
            guard !clean.isEmpty && clean.count <= 15 else {
                return (false, "La contraseña debe tener un máximo de 15 caracteres.")
            }
        }
        
        // Guardar secreto con hash SHA-256 en Keychain y UserDefaults
        saveSecret(clean)
        
        // Guardar configuración
        UserDefaults.standard.set(true, forKey: keyLockEnabled)
        UserDefaults.standard.set(type.rawValue, forKey: keyLockType)
        UserDefaults.standard.set(enableBiometrics, forKey: keyBiometricsEnabled)
        UserDefaults.standard.set(clean.count, forKey: keyPasscodeLength)
        
        self.isLockEnabled = true
        self.lockType = type
        self.isBiometricsEnabled = enableBiometrics
        self.savedPasscodeLength = clean.count
        self.isAppLocked = false
        self.lastBackgroundTimestamp = nil
        
        return (true, "¡Bloqueo de aplicación configurado exitosamente!")
    }
    
    // MARK: - Verificar Secreto
    public func verifySecret(_ secret: String) -> Bool {
        let clean = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let savedHash = getSavedSecretHash() else { return false }
        let inputHash = hashSecret(clean)
        let matches = (inputHash == savedHash)
        if matches {
            unlock()
        }
        return matches
    }
    
    // MARK: - Desactivar Bloqueo
    public func removeLock() {
        deleteSecret()
        UserDefaults.standard.set(false, forKey: keyLockEnabled)
        UserDefaults.standard.removeObject(forKey: keyLockType)
        UserDefaults.standard.removeObject(forKey: keyBiometricsEnabled)
        UserDefaults.standard.removeObject(forKey: keyPasscodeLength)
        
        self.isLockEnabled = false
        self.isBiometricsEnabled = false
        self.savedPasscodeLength = 6
        self.isAppLocked = false
        self.lastBackgroundTimestamp = nil
    }
    
    // MARK: - Desbloqueo y Estado
    public func unlock() {
        self.isAppLocked = false
        self.lastBackgroundTimestamp = nil
    }
    
    public func lockNow() {
        guard isLockEnabled else { return }
        self.isAppLocked = true
    }
    
    // MARK: - Gestión de Segundo Plano (3 minutos / Auto-recarga bancaria)
    public func appDidEnterBackground() {
        guard isLockEnabled else { return }
        // Si MoneyBot Live Voice está conversando activamente en segundo plano, no iniciar temporizador de bloqueo
        if MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive { return }
        self.lastBackgroundTimestamp = Date()
    }
    
    public func appDidBecomeActive(onAutoReloadRequired: (() -> Void)? = nil) {
        checkBiometricAvailability()
        guard isLockEnabled else { return }
        if isEvaluatingBiometrics { return }
        if MoneyBotLiveVoiceSessionManager.shared.isLiveSessionActive { return }
        
        if let lastDate = lastBackgroundTimestamp {
            let elapsed = Date().timeIntervalSince(lastDate)
            lastBackgroundTimestamp = nil
            if elapsed >= timeoutSeconds {
                // Pasaron más de 3 minutos en segundo plano: bloquear y autorecargar
                self.isAppLocked = true
                onAutoReloadRequired?()
            }
        }
        // Si lastBackgroundTimestamp es nil, no se vuelve a bloquear porque no estuvo en segundo plano
    }
    
    // MARK: - Almacenamiento Seguro (Keychain + Hash SHA-256)
    private func hashSecret(_ secret: String) -> String {
        let salted = "moneydev_salt_sec_\(secret)"
        let digest = SHA256.hash(data: Data(salted.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func saveSecret(_ secret: String) {
        let hashed = hashSecret(secret)
        
        // 1. Guardar en Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: Data(hashed.utf8)
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
        
        // 2. Guardar también en UserDefaults seguro como respaldo
        UserDefaults.standard.set(hashed, forKey: keyPasscodeHash)
    }
    
    private func getSavedSecretHash() -> String? {
        // Consultar primero Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        if status == errSecSuccess, let data = dataTypeRef as? Data, let str = String(data: data, encoding: .utf8) {
            return str
        }
        
        // Fallback a UserDefaults
        return UserDefaults.standard.string(forKey: keyPasscodeHash)
    }
    
    private func deleteSecret() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: keyPasscodeHash)
    }
    
    private func loadSettings() {
        self.isLockEnabled = UserDefaults.standard.bool(forKey: keyLockEnabled)
        if let typeStr = UserDefaults.standard.string(forKey: keyLockType), let type = LockType(rawValue: typeStr) {
            self.lockType = type
        }
        self.isBiometricsEnabled = UserDefaults.standard.bool(forKey: keyBiometricsEnabled)
        let storedLen = UserDefaults.standard.integer(forKey: keyPasscodeLength)
        self.savedPasscodeLength = storedLen >= 6 ? storedLen : 6
    }
}
