import UIKit

@MainActor
public enum AppIconManager {
    public static let iconBasic = "icon_basic"
    public static let iconPro = "icon_pro"
    
    // Alias de retrocompatibilidad
    public static let iconClassic = iconBasic
    public static let iconProGold = iconPro
    
    private static let iconStyleKey = "current_icon_style"
    
    public static var isSupportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }
    
    /// Devuelve el estilo de ícono guardado como preferencia del usuario
    public static var savedIconPreference: String {
        let saved = UserDefaults.standard.string(forKey: iconStyleKey)
        if saved == "pro_gold" || saved == iconPro {
            return iconPro
        }
        return iconBasic
    }
    
    /// Devuelve el ícono actualmente activo o seleccionado
    public static var currentIcon: String {
        savedIconPreference
    }
    
    public static func isProIconActive() -> Bool {
        savedIconPreference == iconPro
    }
    
    /// Sincroniza obligatoriamente el ícono del sistema con la preferencia guardada por el usuario.
    /// Esto garantiza que tanto la pantalla de inicio como las notificaciones de iOS muestren
    /// de manera idéntica y consistente el ícono seleccionado (Básico o Pro Dorado).
    @discardableResult
    public static func synchronizeAppIcon(retryCount: Int = 2) async -> Bool {
        guard UIApplication.shared.supportsAlternateIcons else {
            return false
        }
        
        // setAlternateIconName solo puede invocarse válidamente cuando la app está activa
        guard UIApplication.shared.applicationState == .active else {
            if retryCount > 0 {
                try? await Task.sleep(nanoseconds: 600_000_000)
                return await synchronizeAppIcon(retryCount: retryCount - 1)
            }
            return false
        }
        
        let shouldBePro = isProIconActive()
        let targetName: String? = shouldBePro ? iconPro : nil
        let currentSystemAlt = UIApplication.shared.alternateIconName
        
        // Si el sistema ya tiene exactamente el ícono deseado, no realizar llamadas redundantes
        if currentSystemAlt == targetName {
            return true
        }
        
        do {
            try await UIApplication.shared.setAlternateIconName(targetName)
            print("AppIconManager: Ícono sincronizado exitosamente con el sistema a: \(String(describing: targetName))")
            return true
        } catch {
            print("AppIconManager: Error sincronizando ícono a \(String(describing: targetName)): \(error.localizedDescription)")
            if retryCount > 0 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                return await synchronizeAppIcon(retryCount: retryCount - 1)
            }
            return false
        }
    }
    
    @discardableResult
    public static func setAppIcon(_ iconType: String) async -> Bool {
        let isPro = (iconType == iconPro || iconType == "pro_gold")
        let canonicalName = isPro ? iconPro : iconBasic
        UserDefaults.standard.set(canonicalName, forKey: iconStyleKey)
        
        guard UIApplication.shared.supportsAlternateIcons else {
            return false
        }
        
        let targetName: String? = isPro ? iconPro : nil
        let currentSystemAlt = UIApplication.shared.alternateIconName
        
        if currentSystemAlt == targetName {
            return true
        }
        
        do {
            try await UIApplication.shared.setAlternateIconName(targetName)
            print("AppIconManager: Ícono cambiado exitosamente a: \(String(describing: targetName))")
            NotificationCenter.default.post(name: NSNotification.Name("MoneyDev.AppIconDidChange"), object: nil)
            return true
        } catch {
            print("AppIconManager: Error al cambiar el ícono a \(String(describing: targetName)): \(error.localizedDescription)")
            return false
        }
    }
}
