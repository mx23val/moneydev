import Foundation
import AVFoundation
import Observation

@Observable
public final class TextToSpeechService: NSObject, @unchecked Sendable, AVSpeechSynthesizerDelegate {
    public static let shared = TextToSpeechService()
    
    public var isSpeaking: Bool = false
    public var spokenText: String = ""
    
    private let synthesizer = AVSpeechSynthesizer()
    private var onFinishedCallback: (() -> Void)? = nil
    /// Task activo de ElevenLabs. Cancelarlo antes de iniciar uno nuevo evita duplicaciones.
    private var currentSpeakTask: Task<Void, Never>? = nil
    
    public override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    /// Limpia formato Markdown, convierte montos a pronunciación natural, elimina TODOS los emojis y omite comillas, apóstrofes y paréntesis
    public static func cleanTextForSpeech(_ text: String) -> String {
        var clean = text
        
        // 1. Convertir montos y saldos (ej: S/3.50 -> "3 con 50 soles") antes de limpiar símbolos
        clean = convertCurrenciesForSpeech(clean)
        
        // 2. Convertir fechas incompletas o abreviadas (ej: "17 set" -> "17 de septiembre") a pronunciación humana completa
        clean = convertDatesForSpeech(clean)
        
        // 2.5 Convertir horas con AM / PM a locución humana clara (ej: "a las 5:04 P.M." -> "a las 5 y 4 pe eme")
        clean = convertTimesForSpeech(clean)
        
        // 2.7 Convertir operaciones matemáticas para que se pronuncien claramente (ej: "5 x 45" -> "5 por 45", "5 + 35" -> "5 más 35")
        clean = convertMathForSpeech(clean)
        
        // 3. Omitir TODOS los emoticones y símbolos pictográficos para que el sintetizador no lea "cara dando un beso", "destellos", etc.
        clean = removingEmojis(from: clean)
        
        // 4. Humanizar la lectura de la billetera y eliminar "dos puntos" (:) para que jamás diga "dos puntos"
        clean = naturalizeWalletAndStructureForSpeech(clean)
        
        // 5. Eliminar comillas, apóstrofes, paréntesis, corchetes y signos para que no diga "apóstrofe", "comillas", "abre paréntesis"
        clean = removingSpokenPunctuation(clean)
        
        // 6. Limpiar formato Markdown y viñetas
        clean = clean.replacingOccurrences(of: "\\*\\*", with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "\\*", with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "(?m)^\\s*•\\s*", with: ". ", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "•", with: ", ")
        // 7. Eliminar signos de exclamación e interrogación invertidos (¡, ¿) y cualquier puntuación o espacio inicial para que la primera palabra jamás se corte
        clean = clean.replacingOccurrences(of: "¡", with: "")
        clean = clean.replacingOccurrences(of: "¿", with: "")
        clean = clean.replacingOccurrences(of: #"^[\s.,;:!?'"·•\-_/\\*#]+"#, with: "", options: .regularExpression)
        
        // 8. Normalizar puntuación y espacios para evitar pausas vacías o entrecortes en el sintetizador
        clean = clean.replacingOccurrences(of: #"\s*([.,;])\s*"#, with: "$1 ", options: .regularExpression)
        clean = clean.replacingOccurrences(of: #"[.,;]{2,}"#, with: ".", options: .regularExpression)
        clean = clean.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        clean = clean.replacingOccurrences(of: #"\s+\."#, with: ".")
        
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Humaniza la lectura de la billetera y convierte dos puntos a pausas naturales sin pronunciar "dos puntos"
    public static func naturalizeWalletAndStructureForSpeech(_ text: String) -> String {
        var clean = text
        
        // 1. Convertir la línea de billetera a frase humana fluida: "en tu billetera [Nombre]"
        clean = clean.replacingOccurrences(of: "(?i)(?:•\\s*)?Billetera\\s*:\\s*", with: ". En tu billetera ", options: .regularExpression)
        
        // 2. Acrónimos de billeteras/bancos comunes para que se deletreen claramente sin trabas ni "B grande"
        let acronyms = [
            "BCP": "be ce pe",
            "BBVA": "be be uve a",
            "IBK": "i be ka",
            "BN": "be ene"
        ]
        for (acronym, spoken) in acronyms {
            clean = clean.replacingOccurrences(of: "(?i)\\b\(acronym)\\b", with: spoken, options: .regularExpression)
        }
        
        // 3. Eliminar dos puntos para que el sintetizador jamás diga "dos puntos", reemplazando por coma y pausa
        clean = clean.replacingOccurrences(of: ":\\s*", with: ", ", options: .regularExpression)
        
        return clean
    }
    
    /// Convierte fechas completas y abreviadas (ej: "Hoy, 17 de septiembre", "17 set", "17 sep") a pronunciación humana completa y sin duplicar sílabas
    public static func convertDatesForSpeech(_ text: String) -> String {
        var result = text
        
        // 1. Normalizar "Hoy," o "Ayer," seguido de día numérico a frase conversacional ("hoy 17 de...")
        result = result.replacingOccurrences(of: "(?i)\\b(hoy|ayer)[,\\s]+([0-9]{1,2})\\b", with: "$1 $2", options: .regularExpression)
        
        let monthMap: [(pattern: String, fullMonth: String)] = [
            ("(?i)\\b([0-9]{1,2})\\s*(?:de\\s*)?\\b(?:enero|ene)\\b\\.?", "$1 de enero"),
            ("(?i)\\b([0-9]{1,2})\\s*(?:de\\s*)?\\b(?:febrero|feb)\\b\\.?", "$1 de febrero"),
            ("(?i)\\b([0-9]{1,2})\\s*(?:de\\s*)?\\b(?:marzo|mar)\\b\\.?", "$1 de marzo"),
            ("(?i)\\b([0-9]{1,2})\\s*(?:de\\s*)?\\b(?:abril|abr)\\b\\.?", "$1 de abril"),
            ("(?i)\\b([0-9]{1,2})\\s*(?:de\\s*)?\\b(?:mayo|may)\\b\\.?", "$1 de mayo"),
            ("(?i)\\b([0-9]{1,2})\\s*(?:de\\s*)?\\b(?:junio|jun)\\b\\.?", "$1 de junio"),
            ("(?i)\\b([0-9]{1,2})\\s*(?:de\\s*)?\\b(?:julio|jul)\\b\\.?", "$1 de julio"),
            ("(?i)\\b([0-9]{1,2})\\s*(?:de\\s*)?\\b(?:agosto|ago)\\b\\.?", "$1 de agosto"),
            ("(?i)\\b([0-9]{1,2})\\s*(?:de\\s*)?\\b(?:septiembre|setiembre|sept|sep|set)\\b\\.?", "$1 de septiembre"),
            ("(?i)\\b([0-9]{1,2})\\s*(?:de\\s*)?\\b(?:octubre|oct)\\b\\.?", "$1 de octubre"),
            ("(?i)\\b([0-9]{1,2})\\s*(?:de\\s*)?\\b(?:noviembre|nov)\\b\\.?", "$1 de noviembre"),
            ("(?i)\\b([0-9]{1,2})\\s*(?:de\\s*)?\\b(?:diciembre|dic)\\b\\.?", "$1 de diciembre")
        ]
        
        for item in monthMap {
            result = result.replacingOccurrences(of: item.pattern, with: item.fullMonth, options: .regularExpression)
        }
        
        // Formato numérico "17/09" o "17/09/2026"
        let slashPattern = #"(?i)\b([0-9]{1,2})\/(0?[1-9]|1[0-2])(?:\/([0-9]{4}))?\b"#
        if let regex = try? NSRegularExpression(pattern: slashPattern) {
            let nsString = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
            let monthNames = ["", "enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
            
            for match in matches.reversed() {
                let day = nsString.substring(with: match.range(at: 1))
                let monthNum = Int(nsString.substring(with: match.range(at: 2))) ?? 1
                let monthName = monthNames[monthNum]
                var spoken = "\(day) de \(monthName)"
                if match.numberOfRanges > 3 && match.range(at: 3).location != NSNotFound {
                    let year = nsString.substring(with: match.range(at: 3))
                    spoken += " de \(year)"
                }
                result = (result as NSString).replacingCharacters(in: match.range(at: 0), with: spoken)
            }
        }
        
        return result
    }
    
    /// Convierte expresiones de hora con formato h:mm A.M. / P.M. a locución conversacional natural en español
    public static func convertTimesForSpeech(_ text: String) -> String {
        var result = text
        
        // Expresión para detectar "a las? [h]:[mm] [A.M./P.M.]" o "[h]:[mm] [A.M./P.M.]"
        let timePattern = #"(?i)(?:a\s+las?|a\s+la)?\s*\b([0-9]{1,2}):([0-9]{2})\s*(a\.?\s*m\.?|p\.?\s*m\.?)\b"#
        if let regex = try? NSRegularExpression(pattern: timePattern) {
            let nsString = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches.reversed() {
                let fullRange = match.range(at: 0)
                let hourStr = nsString.substring(with: match.range(at: 1))
                let minuteStr = nsString.substring(with: match.range(at: 2))
                let ampmStr = nsString.substring(with: match.range(at: 3)).lowercased()
                
                guard let hour = Int(hourStr), let minute = Int(minuteStr) else { continue }
                
                let isPm = ampmStr.contains("p")
                let periodSpoken = isPm ? "pe eme" : "a eme"
                
                let hourPrefix: String
                if hour == 1 {
                    hourPrefix = "a la una"
                } else {
                    hourPrefix = "a las \(hour)"
                }
                
                let minuteSpoken: String
                if minute == 0 {
                    minuteSpoken = "en punto"
                } else if minute == 1 {
                    minuteSpoken = "y un minuto"
                } else {
                    minuteSpoken = "y \(minute)"
                }
                
                let spokenPhrase = "\(hourPrefix) \(minuteSpoken) \(periodSpoken)"
                result = (result as NSString).replacingCharacters(in: fullRange, with: spokenPhrase)
            }
        }
        
        // Reemplazos adicionales de seguridad si queda algún "A.M." o "P.M." suelto
        result = result.replacingOccurrences(of: "(?i)\\bA\\.?M\\.?\\b", with: "a eme", options: .regularExpression)
        result = result.replacingOccurrences(of: "(?i)\\bP\\.?M\\.?\\b", with: "pe eme", options: .regularExpression)
        
        return result
    }
    
    /// Convierte operaciones y símbolos matemáticos a lenguaje hablado natural en español
    public static func convertMathForSpeech(_ text: String) -> String {
        var result = text
        // Porcentaje: "18%" -> "18 por ciento"
        result = result.replacingOccurrences(of: #"(?i)\b([0-9]+(?:\.[0-9]+)?)\s*%\b"#, with: "$1 por ciento", options: .regularExpression)
        // Multiplicación entre dígitos: "5 x 45" o "5 * 45" o "5 × 45"
        result = result.replacingOccurrences(of: #"(?<=[0-9])\s*[xX*×]\s*(?=[0-9])"#, with: " por ", options: .regularExpression)
        // Suma entre dígitos: "5 + 35"
        result = result.replacingOccurrences(of: #"(?<=[0-9])\s*\+\s*(?=[0-9])"#, with: " más ", options: .regularExpression)
        // Resta entre dígitos: "50 - 20"
        result = result.replacingOccurrences(of: #"(?<=[0-9])\s*[-–—]\s*(?=[0-9])"#, with: " menos ", options: .regularExpression)
        // División entre dígitos: "100 / 4" o "100 ÷ 4"
        result = result.replacingOccurrences(of: #"(?<=[0-9])\s*[/÷]\s*(?=[0-9])"#, with: " entre ", options: .regularExpression)
        // Signo igual: "= 225"
        result = result.replacingOccurrences(of: #"\s*=\s*"#, with: " es igual a ", options: .regularExpression)
        return result
    }
    
    /// Elimina comillas, apóstrofes, paréntesis, llaves y caracteres para que el sintetizador jamás los verbalice
    public static func removingSpokenPunctuation(_ text: String) -> String {
        let charsToRemove = CharacterSet(charactersIn: "\"'“”‘’«»`´()[]{}<>\\/|~^_#*:")
        let components = text.components(separatedBy: charsToRemove)
        let joined = components.joined(separator: " ")
        return joined.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
    }
    
    // MARK: - Conversión Numérica y Monetaria a Palabras en Español
    
    private static let spellOutFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .spellOut
        f.locale = Locale(identifier: "es_PE")
        return f
    }()
    
    /// Parsea de forma robusta cadenas monetarias con posibles separadores de miles y decimales
    public static func parseNumericAmount(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // Caso 1: Tiene tanto '.' como ',' (ej: "2,788.80" o "2.788,80")
        if trimmed.contains(".") && trimmed.contains(",") {
            if let lastDot = trimmed.lastIndex(of: "."), let lastComma = trimmed.lastIndex(of: ",") {
                if lastDot > lastComma {
                    // La coma es separador de miles y el punto es decimal (ej: 2,788.80)
                    let clean = trimmed.replacingOccurrences(of: ",", with: "")
                    return Double(clean)
                } else {
                    // El punto es separador de miles y la coma es decimal (ej: 2.788,80)
                    let clean = trimmed.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
                    return Double(clean)
                }
            }
        }
        
        // Caso 2: Solo tiene comas (ej: "2788,80" o "2,788")
        if trimmed.contains(",") {
            let parts = trimmed.split(separator: ",")
            if parts.count == 2 && parts[1].count <= 2 {
                let clean = trimmed.replacingOccurrences(of: ",", with: ".")
                return Double(clean)
            } else {
                let clean = trimmed.replacingOccurrences(of: ",", with: "")
                return Double(clean)
            }
        }
        
        // Caso 3: Solo tiene puntos (ej: "2788.80" o "2.788")
        if trimmed.contains(".") {
            let parts = trimmed.split(separator: ".")
            if parts.count == 2 && parts[1].count <= 2 {
                return Double(trimmed)
            } else if parts.count == 2 && parts[1].count == 3 {
                let clean = trimmed.replacingOccurrences(of: ".", with: "")
                return Double(clean)
            }
        }
        
        return Double(trimmed)
    }
    
    /// Convierte formatos monetarios como "S/ 2,788.80", "2788.80 soles", "$150", "€20.50" a pronunciación en palabras exactas
    public static func convertCurrenciesForSpeech(_ text: String) -> String {
        var result = text
        
        // 1. Detectar Soles (S/, S/., PEN) con cualquier formato numérico
        let solPrefixPattern = #"(?i)(?:S\/\.?|PEN)\s*([0-9]{1,3}(?:[.,\s][0-9]{3})*(?:[.,][0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)(?:\s*(?:soles|sol))?"#
        if let regex = try? NSRegularExpression(pattern: solPrefixPattern) {
            let nsString = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches.reversed() {
                let fullRange = match.range(at: 0)
                let numStr = nsString.substring(with: match.range(at: 1))
                if let val = parseNumericAmount(numStr) {
                    let spoken = formatAmountToSpokenWords(val, currencyName: "sol", currencyPlural: "soles", centName: "céntimo", centPlural: "céntimos")
                    result = (result as NSString).replacingCharacters(in: fullRange, with: spoken)
                }
            }
        }
        
        // 2. Detectar Dólares ($, USD)
        let dollarPrefixPattern = #"(?i)(?:\$|USD)\s*([0-9]{1,3}(?:[.,\s][0-9]{3})*(?:[.,][0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)(?:\s*(?:d[oó]lares|d[oó]lar))?"#
        if let regex = try? NSRegularExpression(pattern: dollarPrefixPattern) {
            let nsString = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches.reversed() {
                let fullRange = match.range(at: 0)
                let numStr = nsString.substring(with: match.range(at: 1))
                if let val = parseNumericAmount(numStr) {
                    let spoken = formatAmountToSpokenWords(val, currencyName: "dólar", currencyPlural: "dólares", centName: "centavo", centPlural: "centavos")
                    result = (result as NSString).replacingCharacters(in: fullRange, with: spoken)
                }
            }
        }
        
        // 3. Detectar Euros (€, EUR)
        let euroPrefixPattern = #"(?i)(?:€|EUR)\s*([0-9]{1,3}(?:[.,\s][0-9]{3})*(?:[.,][0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)(?:\s*(?:euros|euro))?"#
        if let regex = try? NSRegularExpression(pattern: euroPrefixPattern) {
            let nsString = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches.reversed() {
                let fullRange = match.range(at: 0)
                let numStr = nsString.substring(with: match.range(at: 1))
                if let val = parseNumericAmount(numStr) {
                    let spoken = formatAmountToSpokenWords(val, currencyName: "euro", currencyPlural: "euros", centName: "céntimo", centPlural: "céntimos")
                    result = (result as NSString).replacingCharacters(in: fullRange, with: spoken)
                }
            }
        }
        
        // 4. Detectar números seguidos de la palabra moneda (ej: "2,788.80 soles", "50 dólares", "10.50 euros")
        let trailingCurrencyPattern = #"(?i)\b([0-9]{1,3}(?:[.,\s][0-9]{3})*(?:[.,][0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)\s*(soles|sol|d[oó]lares|d[oó]lar|euros|euro)\b"#
        if let regex = try? NSRegularExpression(pattern: trailingCurrencyPattern) {
            let nsString = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches.reversed() {
                let fullRange = match.range(at: 0)
                let numStr = nsString.substring(with: match.range(at: 1))
                let currWord = nsString.substring(with: match.range(at: 2)).lowercased()
                
                if let val = parseNumericAmount(numStr) {
                    let spoken: String
                    if currWord.contains("sol") {
                        spoken = formatAmountToSpokenWords(val, currencyName: "sol", currencyPlural: "soles", centName: "céntimo", centPlural: "céntimos")
                    } else if currWord.contains("d") {
                        spoken = formatAmountToSpokenWords(val, currencyName: "dólar", currencyPlural: "dólares", centName: "centavo", centPlural: "centavos")
                    } else {
                        spoken = formatAmountToSpokenWords(val, currencyName: "euro", currencyPlural: "euros", centName: "céntimo", centPlural: "céntimos")
                    }
                    result = (result as NSString).replacingCharacters(in: fullRange, with: spoken)
                }
            }
        }
        
        // 5. Reemplazar cualquier símbolo de moneda residual
        result = result.replacingOccurrences(of: "S/.", with: "soles ")
        result = result.replacingOccurrences(of: "S/", with: "soles ")
        result = result.replacingOccurrences(of: "s/.", with: "soles ")
        result = result.replacingOccurrences(of: "s/", with: "soles ")
        result = result.replacingOccurrences(of: "$", with: "dólares ")
        result = result.replacingOccurrences(of: "€", with: "euros ")
        
        return result
    }
    
    /// Convierte un monto a palabras exactas en español (ej: 2788.80 -> "dos mil setecientos ochenta y ocho con ochenta soles")
    public static func formatAmountToSpokenWords(
        _ amount: Double,
        currencyName: String = "sol",
        currencyPlural: String = "soles",
        centName: String = "céntimo",
        centPlural: String = "céntimos"
    ) -> String {
        let rounded = (amount * 100).rounded() / 100
        let intPart = Int64(rounded)
        let cents = Int((rounded - Double(intPart)) * 100 + 0.001)
        
        let intWords = spellOutFormatter.string(from: NSNumber(value: intPart)) ?? "\(intPart)"
        
        if cents == 0 {
            if intPart == 1 {
                return "un \(currencyName)"
            } else {
                return "\(intWords) \(currencyPlural)"
            }
        } else {
            let centWords = spellOutFormatter.string(from: NSNumber(value: cents)) ?? "\(cents)"
            if intPart == 0 {
                return cents == 1 ? "un \(centName)" : "\(centWords) \(centPlural)"
            } else if intPart == 1 {
                return "un \(currencyName) con \(centWords) \(currencyPlural)"
            } else {
                return "\(intWords) con \(centWords) \(currencyPlural)"
            }
        }
    }
    
    /// Formatea un valor numérico a texto conversacional en soles
    public static func formatAmountToSpokenSoles(_ amount: Double) -> String {
        formatAmountToSpokenWords(amount, currencyName: "sol", currencyPlural: "soles", centName: "céntimo", centPlural: "céntimos")
    }
    
    /// Filtra y elimina todos los emojis del texto para que el sintetizador de voz no lea sus nombres
    public static func removingEmojis(from text: String) -> String {
        return text.filter { char in
            // Permitir caracteres latinos básicos, letras, dígitos y signos de puntuación
            if let firstScalar = char.unicodeScalars.first, firstScalar.value < 0x200 {
                return true
            }
            // Excluir cualquier escalar que sea presentación de emoji o pictograma
            for scalar in char.unicodeScalars {
                if scalar.properties.isEmojiPresentation { return false }
                if scalar.properties.isEmoji && scalar.value > 0x2000 { return false }
                if (0x1F000...0x1FAFF).contains(scalar.value) { return false }
                if (0x2600...0x27BF).contains(scalar.value) { return false }
            }
            return true
        }
    }
    
    /// Devuelve las voces en español disponibles ordenadas de mayor a menor fidelidad natural
    public var availableSpanishVoices: [AVSpeechSynthesisVoice] {
        let all = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.starts(with: "es") }
        return all.sorted { Self.voiceScore(for: $0) > Self.voiceScore(for: $1) }
    }
    
    /// Identificador de la voz elegida por el usuario guardada en UserDefaults
    public var selectedVoiceIdentifier: String {
        get {
            UserDefaults.standard.string(forKey: "key_moneybot_voice_id") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "key_moneybot_voice_id")
        }
    }
    
    /// Obtiene la voz actualmente activa (seleccionada por el usuario o la mejor voz neural disponible)
    public var currentVoice: AVSpeechSynthesisVoice? {
        let savedId = selectedVoiceIdentifier
        if !savedId.isEmpty, let voice = AVSpeechSynthesisVoice(identifier: savedId) {
            return voice
        }
        // Seleccionar automáticamente la voz neural / mejorada de mayor calidad en español
        return availableSpanishVoices.first ?? AVSpeechSynthesisVoice(language: "es-ES")
    }
    
    /// Calificación de calidad para priorizar voces neurales/Siri sobre sintetizadores compactos antiguos
    public static func voiceScore(for voice: AVSpeechSynthesisVoice) -> Int {
        var score = 0
        if voice.quality == .premium {
            score += 1000
        } else if voice.quality == .enhanced {
            score += 500
        } else {
            score += 10
        }
        
        let idLower = voice.identifier.lowercased()
        if idLower.contains("neural") { score += 300 }
        if idLower.contains("siri") { score += 250 }
        if idLower.contains("premium") { score += 100 }
        if idLower.contains("compact") { score -= 60 }
        if idLower.contains("eloquence") { score -= 250 }
        
        return score
    }
    
    /// Reproduce una muestra de prueba con la voz Apple seleccionada y opcionalmente notifica al terminar
    public func previewVoice(_ voice: AVSpeechSynthesisVoice, onFinished: (() -> Void)? = nil) {
        selectedVoiceIdentifier = voice.identifier
        speak(text: "Hola, soy MoneyBot. Esta es mi voz para registrar tus movimientos.", onFinished: onFinished)
    }
    
    /// Cambia la voz de ElevenLabs y reproduce una muestra de prueba.
    /// Si ElevenLabs falla, el fallback nativo de speak() asegura que siempre se escuche algo.
    public func previewElevenLabsVoice(_ voice: ElevenLabsVoiceOption, onFinished: (() -> Void)? = nil) {
        ElevenLabsService.shared.selectedVoice = voice
        speak(
            text: "Hola, soy MoneyBot con la voz \(voice.displayName). Listo para registrar tus gastos.",
            onFinished: onFinished
        )
    }
    
    /// Reproduce el texto en voz alta:
    /// 1º intenta ElevenLabs (si hay API key válida).
    /// 2º si falla (401, 429, sin red, timeout), cae de inmediato al sintetizador nativo de Apple.
    /// El orbe y el flujo de MoneyBot NUNCA se interrumpen.
    public func speak(text: String, onFinished: (() -> Void)? = nil) {
        stop()
        
        let cleanedText = Self.cleanTextForSpeech(text)
        guard !cleanedText.isEmpty else {
            onFinished?()
            return
        }
        
        self.spokenText = cleanedText
        self.onFinishedCallback = onFinished
        self.isSpeaking = true
        
        let elevenKey = ElevenLabsService.shared.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !elevenKey.isEmpty {
            // ── INTENTO 1: ElevenLabs TTS neural ─────────────────────────────────
            let task = Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isSpeaking = true
                guard !Task.isCancelled else { return }
                do {
                    try await ElevenLabsService.shared.speak(text: cleanedText) { [weak self] in
                        Task { @MainActor in
                            guard let self = self else { return }
                            let cb = self.onFinishedCallback
                            self.onFinishedCallback = nil
                            self.isSpeaking = false
                            self.spokenText = ""
                            cb?()
                        }
                    }
                } catch {
                    // Cancelación limpia: no hacer fallback si el Task fue cancelado intencionalmente
                    if (error as? CancellationError) != nil { return }
                    // ── FALLBACK INMEDIATO: Sintetizador nativo Apple ────────────────
                    guard !Task.isCancelled else { return }
                    print("TextToSpeechService: ElevenLabs falló (\(error.localizedDescription)) — usando Apple TTS")
                    self.speakNative(cleanedText)
                }
            }
            currentSpeakTask = task
        } else {
            // ── Sin API key: Apple TTS directamente ─────────────────────────
            speakNative(cleanedText)
        }
    }
    
    // MARK: - Sintetizador Nativo Apple (Fallback garantizado)
    
    /// Reproduce el texto directamente con AVSpeechSynthesizer.
    /// Llamado cuando ElevenLabs no está disponible o falla.
    private func speakNative(_ cleanedText: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let session = AVAudioSession.sharedInstance()
            do {
                if session.category != .playAndRecord {
                    try session.setCategory(
                        .playAndRecord,
                        mode: .default,
                        options: [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP]
                    )
                }
                try session.setActive(true)
                try? session.overrideOutputAudioPort(.speaker)
            } catch {
                print("TextToSpeechService: AVAudioSession error en fallback: \(error.localizedDescription)")
            }
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                let utterance = AVSpeechUtterance(string: cleanedText)
                
                if let bestVoice = self.currentVoice {
                    utterance.voice = bestVoice
                } else if let voiceEs = AVSpeechSynthesisVoice(language: "es-ES") {
                    utterance.voice = voiceEs
                }
                
                utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
                utterance.pitchMultiplier = 1.0
                utterance.volume = 1.0
                utterance.preUtteranceDelay = 0.05
                utterance.postUtteranceDelay = 0.10
                
                self.isSpeaking = true
                self.synthesizer.speak(utterance)
            }
        }
    }
    
    /// Detiene de inmediato la reproducción de voz (ElevenLabs + Apple) y opcionalmente libera la sesión de audio
    public func stop(deactivateSession: Bool = false) {
        // Cancelar Task de ElevenLabs en vuelo ANTES de detener el reproductor
        // Esto evita que un Task antiguo termine e invoque speakNative() causando duplicación
        currentSpeakTask?.cancel()
        currentSpeakTask = nil
        
        // Detener ElevenLabs si estaba reproduciendo
        ElevenLabsService.shared.stop()
        
        // Detener sintetizador nativo
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        if deactivateSession {
            DispatchQueue.global(qos: .userInitiated).async {
                try? AVAudioSession.sharedInstance().setActive(false)
            }
        }
        onFinishedCallback = nil
        Task { @MainActor in
            self.isSpeaking = false
            self.spokenText = ""
        }
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let callback = onFinishedCallback
        onFinishedCallback = nil
        Task { @MainActor in
            // Margen acústico de 120ms para que el hardware del parlante vacíe completamente la última sílaba sin recortarla
            try? await Task.sleep(nanoseconds: 120_000_000)
            self.isSpeaking = false
            self.spokenText = ""
            callback?()
        }
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onFinishedCallback = nil
        Task { @MainActor in
            self.isSpeaking = false
            self.spokenText = ""
        }
    }
}
