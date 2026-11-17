import Foundation

public enum EnvConfig {
    private static var envVars: [String: String] = {
        var vars = ProcessInfo.processInfo.environment
        
        // 1. Intentar leer desde el Bundle principal (.env o env)
        if let path = Bundle.main.path(forResource: ".env", ofType: nil) ??
                      Bundle.main.path(forResource: "env", ofType: nil) {
            loadEnvFile(from: path, into: &vars)
        }
        
        // 2. Intentar leer desde el directorio de trabajo actual (entornos de desarrollo)
        let cwd = FileManager.default.currentDirectoryPath
        let envPath = (cwd as NSString).appendingPathComponent(".env")
        if FileManager.default.fileExists(atPath: envPath) {
            loadEnvFile(from: envPath, into: &vars)
        }
        
        // 3. Intentar leer desde Secrets.plist en el Bundle principal
        if let secretsBundlePath = Bundle.main.path(forResource: "Secrets", ofType: "plist") {
            loadPlistFile(from: secretsBundlePath, into: &vars)
        }
        
        // 4. Intentar leer desde Secrets.plist en el directorio local de desarrollo
        let localSecretsPath = (cwd as NSString).appendingPathComponent("Secrets.plist")
        if FileManager.default.fileExists(atPath: localSecretsPath) {
            loadPlistFile(from: localSecretsPath, into: &vars)
        }
        
        return vars
    }()
    
    private static func loadEnvFile(from path: String, into vars: inout [String: String]) {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                var val = parts[1].trimmingCharacters(in: .whitespaces)
                if (val.hasPrefix("\"") && val.hasSuffix("\"")) || (val.hasPrefix("'") && val.hasSuffix("'")) {
                    val = String(val.dropFirst().dropLast())
                }
                vars[key] = val
            }
        }
    }
    
    private static func loadPlistFile(from path: String, into vars: inout [String: String]) {
        guard let data = FileManager.default.contents(atPath: path),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return
        }
        for (key, val) in plist {
            if let strVal = val as? String {
                vars[key] = strVal
            }
        }
    }
    
    public static func get(_ key: String, default defaultValue: String = "") -> String {
        return envVars[key] ?? defaultValue
    }
    
    /// Clave predeterminada (mantenida vacía por seguridad para evitar exposición en repositorios públicos).
    public static var defaultGeminiApiKey: String = ""
    
    public static var geminiApiKey: String {
        // Prioridad 1: Clave personalizada por el usuario desde Configuración / UserDefaults
        if let userKey = UserDefaults.standard.string(forKey: "key_gemini_api_key")?.trimmingCharacters(in: .whitespacesAndNewlines),
           !userKey.isEmpty && userKey != "MY_GEMINI_API_KEY" && userKey != "YOUR_GEMINI_API_KEY_HERE" {
            return userKey
        }
        
        // Prioridad 2: Clave provista en Secrets.plist o .env cargados en envVars
        let envKey = get("GEMINI_API_KEY").trimmingCharacters(in: .whitespacesAndNewlines)
        if !envKey.isEmpty && envKey != "MY_GEMINI_API_KEY" && envKey != "YOUR_GEMINI_API_KEY_HERE" {
            return envKey
        }
        
        // Prioridad 3: Inyección vía Info.plist (desde Config.xcconfig)
        if let plistKey = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String {
            let trimmed = plistKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed != "MY_GEMINI_API_KEY" && trimmed != "YOUR_GEMINI_API_KEY_HERE" {
                return trimmed
            }
        }
        
        // Prioridad 4: Clave estática por defecto (debe mantenerse vacía en el repositorio)
        let staticKey = defaultGeminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !staticKey.isEmpty && staticKey != "MY_GEMINI_API_KEY" && staticKey != "YOUR_GEMINI_API_KEY_HERE" {
            return staticKey
        }
        
        return ""
    }
    
    public static var isGeminiConfigured: Bool {
        return !geminiApiKey.isEmpty
    }
    
    public static func setGeminiApiKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: "key_gemini_api_key")
        } else {
            UserDefaults.standard.set(trimmed, forKey: "key_gemini_api_key")
        }
    }
}
