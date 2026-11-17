import UIKit

public enum AppIconManager {
    public static let iconClassic = "classic"
    public static let iconProGold = "pro_gold"
    
    public static var isSupportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }
    
    public static var currentIcon: String {
        if let alt = UIApplication.shared.alternateIconName {
            return alt
        }
        return UserDefaults.standard.string(forKey: "current_icon_style") ?? iconClassic
    }
    
    public static func setAppIcon(_ iconType: String) async -> Bool {
        UserDefaults.standard.set(iconType, forKey: "current_icon_style")
        
        guard UIApplication.shared.supportsAlternateIcons else {
            return false
        }
        
        let targetName: String? = (iconType == iconProGold) ? "AppIconProGold" : nil
        do {
            try await UIApplication.shared.setAlternateIconName(targetName)
            return true
        } catch {
            print("AppIconManager: No se pudo cambiar el ícono de la app: \(error)")
            return false
        }
    }
}
