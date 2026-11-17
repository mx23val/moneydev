import Foundation

public enum FormatHelper {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.locale = Locale(identifier: "en_US")
        f.groupingSeparator = ","
        f.decimalSeparator = "."
        return f
    }()
    
    public static func formatCurrency(_ amount: Double) -> String {
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }
    
    public static func formatNumber(_ amount: Double) -> String {
        return formatCurrency(amount)
    }
    
    /// Valida y formatea una entrada de texto monetaria para limitar a máximo 10 dígitos enteros y 2 decimales.
    /// Permite escribir punto o coma decimal mientras se ingresa el monto.
    public static func validateMoneyInput(_ input: String) -> String {
        let clean = input.replacingOccurrences(of: ",", with: ".")
        
        var result = ""
        var hasDot = false
        
        for char in clean {
            if char.isNumber {
                result.append(char)
            } else if char == "." && !hasDot {
                hasDot = true
                result.append(char)
            }
        }
        
        let parts = result.split(separator: ".", omittingEmptySubsequences: false)
        if parts.count >= 1 {
            var integerPart = String(parts[0])
            if integerPart.count > 10 {
                integerPart = String(integerPart.prefix(10))
            }
            
            if parts.count >= 2 {
                var decimalPart = String(parts[1])
                if decimalPart.count > 2 {
                    decimalPart = String(decimalPart.prefix(2))
                }
                return "\(integerPart).\(decimalPart)"
            } else if hasDot {
                return "\(integerPart)."
            } else {
                return integerPart
            }
        }
        return result
    }
    
    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_PE")
        f.dateFormat = "dd MMM"
        return f
    }()
    
    private static let longDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_PE")
        f.dateFormat = "d 'de' MMMM"
        return f
    }()
    
    private static let fullDateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_PE")
        f.dateFormat = "dd MMM, hh:mm a"
        return f
    }()
    
    public static func formatDate(_ dateMillis: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(dateMillis) / 1000.0)
        return shortDateFormatter.string(from: date)
    }
    
    public static func formatDateLong(_ dateMillis: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(dateMillis) / 1000.0)
        return longDateFormatter.string(from: date)
    }
    
    public static func formatTransactionDateLong(_ dateMillis: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(dateMillis) / 1000.0)
        let calendar = Calendar.current
        let baseDate = longDateFormatter.string(from: date)
        
        if calendar.isDateInToday(date) {
            return "Hoy, \(baseDate)"
        } else if calendar.isDateInYesterday(date) {
            return "Ayer, \(baseDate)"
        } else {
            return baseDate
        }
    }
    
    public static func formatTransactionDate(_ dateMillis: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(dateMillis) / 1000.0)
        let calendar = Calendar.current
        let baseDate = fullDateTimeFormatter.string(from: date)
        
        if calendar.isDateInToday(date) {
            return "Hoy, \(baseDate)"
        } else if calendar.isDateInYesterday(date) {
            return "Ayer, \(baseDate)"
        } else {
            return baseDate
        }
    }
    
    /// Obtiene la hora actual del dispositivo formateada con validación explícita de A.M. o P.M.
    public static func formatDeviceTimeAmPm(_ date: Date = Date()) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let isPm = hour >= 12
        let hour12 = hour % 12 == 0 ? 12 : hour % 12
        let minuteStr = String(format: "%02d", minute)
        let periodStr = isPm ? "P.M." : "A.M."
        return "\(hour12):\(minuteStr) \(periodStr)"
    }
    
    private static let chatTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_PE")
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()
    
    private static let chatDateSameYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_PE")
        f.dateFormat = "d 'de' MMMM"
        return f
    }()
    
    private static let chatDateOtherYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_PE")
        f.dateFormat = "d 'de' MMMM 'de' yyyy"
        return f
    }()
    
    /// Formatea la hora de un mensaje de chat estilo WhatsApp (ej: "10:45 a.m." o "22:45")
    public static func formatChatMessageTime(_ date: Date) -> String {
        return chatTimeFormatter.string(from: date).lowercased()
    }
    
    /// Formatea el texto de fecha flotante de la conversación (ej: "Hoy", "Ayer", "24 de Septiembre")
    public static func formatChatDateFloating(_ date: Date) -> String {
        let calendar = Calendar.autoupdatingCurrent
        if calendar.isDateInToday(date) {
            return "Hoy"
        } else if calendar.isDateInYesterday(date) {
            return "Ayer"
        } else {
            if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
                return chatDateSameYearFormatter.string(from: date).capitalized
            } else {
                return chatDateOtherYearFormatter.string(from: date).capitalized
            }
        }
    }
    
    /// Parsea de forma robusta cualquier expresión de hora (12h, 24h, palabras "tres de la tarde", "cuatro y media", "7 con 59 P.M.", "19:59", "7 y 35 pm", etc.)
    /// No interpreta montos monetarios (ej: "20 soles") como horas.
    public static func parseHourAndMinute(from raw: String) -> (hour: Int, minute: Int)? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !s.isEmpty else { return nil }
        s = s.replacingOccurrences(of: "\u{00a0}", with: " ")
        
        let hasNoon = s.contains("mediodía") || s.contains("medio día")
        let hasMidnight = s.contains("medianoche") || s.contains("media noche")
        if hasMidnight && !s.contains(":") && !s.contains("1") && !s.contains("2") {
            return (hour: 0, minute: 0)
        }
        if hasNoon && !s.contains(":") && !s.contains("1") && !s.contains("2") && !s.contains("3") {
            return (hour: 12, minute: 0)
        }
        
        // 1. Normalizar expresiones comunes de fracciones de hora
        s = s.replacingOccurrences(of: "y media", with: ":30")
        s = s.replacingOccurrences(of: "y cuarto", with: ":15")
        s = s.replacingOccurrences(of: "con media", with: ":30")
        s = s.replacingOccurrences(of: "con cuarto", with: ":15")
        
        // 2. Convertir palabras numéricas en español a dígitos
        let wordToNumber: [(String, String)] = [
            ("cincuenta y nueve", "59"), ("cincuenta y ocho", "58"), ("cincuenta y siete", "57"),
            ("cincuenta y seis", "56"), ("cincuenta y cinco", "55"), ("cincuenta y cuatro", "54"),
            ("cincuenta y tres", "53"), ("cincuenta y dos", "52"), ("cincuenta y uno", "51"),
            ("cincuenta", "50"),
            ("cuarenta y nueve", "49"), ("cuarenta y ocho", "48"), ("cuarenta y siete", "47"),
            ("cuarenta y seis", "46"), ("cuarenta y cinco", "45"), ("cuarenta y cuatro", "44"),
            ("cuarenta y tres", "43"), ("cuarenta y dos", "42"), ("cuarenta y uno", "41"),
            ("cuarenta", "40"),
            ("treinta y nueve", "39"), ("treinta y ocho", "38"), ("treinta y siete", "37"),
            ("treinta y seis", "36"), ("treinta y cinco", "35"), ("treinta y cuatro", "34"),
            ("treinta y tres", "33"), ("treinta y dos", "32"), ("treinta y uno", "31"),
            ("treinta", "30"),
            ("veintinueve", "29"), ("veintiocho", "28"), ("veintisiete", "27"),
            ("veintiseis", "26"), ("veintiséis", "26"), ("veinticinco", "25"),
            ("veinticuatro", "24"), ("veintitres", "23"), ("veintitrés", "23"),
            ("veintidos", "22"), ("veintidós", "22"), ("veintiuno", "21"),
            ("veinte", "20"),
            ("diecinueve", "19"), ("dieciocho", "18"), ("diecisiete", "17"),
            ("dieciseis", "16"), ("dieciséis", "16"), ("quince", "15"),
            ("catorce", "14"), ("trece", "13"), ("doce", "12"),
            ("once", "11"), ("diez", "10"), ("nueve", "9"),
            ("ocho", "8"), ("siete", "7"), ("seis", "6"),
            ("cinco", "5"), ("cuatro", "4"), ("tres", "3"),
            ("dos", "2"), ("una", "1"), ("uno", "1")
        ]
        
        var normalized = s
        for (word, num) in wordToNumber {
            let pattern = "\\b\(word)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                normalized = regex.stringByReplacingMatches(in: normalized, options: [], range: NSRange(location: 0, length: normalized.utf16.count), withTemplate: num)
            }
        }
        
        // Quitar espacios alrededor de :
        normalized = normalized.replacingOccurrences(of: #"\s*:\s*"#, with: ":", options: .regularExpression)
        
        let isGlobalPM = s.contains("pm") || s.contains("p.m") || s.contains("p. m") || s.contains("de la tarde") || s.contains("de la noche") || s.contains("tarde") || s.contains("noche") || s.contains("cena")
        let isGlobalAM = s.contains("am") || s.contains("a.m") || s.contains("a. m") || s.contains("de la mañana") || s.contains("de la madrugada") || s.contains("mañana") || s.contains("madrugada") || s.contains("desayuno")
        
        func resolvePeriod(suffix: String?, localContext: String) -> (isPM: Bool, isAM: Bool) {
            let sub = (suffix ?? "") + " " + localContext
            let isNight = sub.contains("noche") || sub.contains("medianoche")
            let pm = sub.contains("p") || sub.contains("tarde") || isNight
            let am = sub.contains("a") || sub.contains("mañana") || sub.contains("madrugada")
            if pm && !am { return (true, false) }
            if am && !pm { return (false, true) }
            return (isGlobalPM, isGlobalAM)
        }
        
        func adjustHour(rawHour: Int, suffix: String?, localContext: String, matchPM: Bool, matchAM: Bool) -> Int {
            var hour = rawHour
            let sub = (suffix ?? "") + " " + localContext
            let isNight = sub.contains("noche") || sub.contains("medianoche")
            
            if hour == 12 {
                if matchAM || isNight {
                    hour = 0
                } else {
                    hour = 12
                }
            } else if matchPM && hour < 12 {
                hour += 12
            } else if matchAM && hour == 12 {
                hour = 0
            } else if !matchAM && !matchPM && hour >= 1 && hour <= 6 {
                hour += 12
            }
            return hour
        }
        
        let periodPatternSuffix = #"(?:am|pm|a\.m\.|p\.m\.|a\. m\.|p\. m\.|de la tarde|de la noche|de la mañana|de la madrugada|del mediodía|del medio día)"#
        
        // Pattern 1: HH:MM con sufijo opcional de periodo (ej: "19:59", "7:59 pm", "7:59 de la noche", "7:30")
        let p1 = #"\b([0-1]?[0-9]|2[0-3]):([0-5][0-9])(?:\s*("# + periodPatternSuffix + #"))?\b"#
        if let regex = try? NSRegularExpression(pattern: p1, options: .caseInsensitive),
           let match = regex.firstMatch(in: normalized, options: [], range: NSRange(location: 0, length: normalized.utf16.count)) {
            let ns = normalized as NSString
            let hStr = ns.substring(with: match.range(at: 1))
            let mStr = ns.substring(with: match.range(at: 2))
            let suffix = match.range(at: 3).location != NSNotFound ? ns.substring(with: match.range(at: 3)).lowercased() : nil
            let (matchPM, matchAM) = resolvePeriod(suffix: suffix, localContext: normalized)
            
            if let h = Int(hStr), let m = Int(mStr) {
                let hour = adjustHour(rawHour: h, suffix: suffix, localContext: normalized, matchPM: matchPM, matchAM: matchAM)
                return (hour: hour, minute: m)
            }
        }
        
        // Pattern 2: HH con MM o HH y MM (ej: "7 con 35 pm", "7 y 20 de la noche", "7 y 35", "7 con 15")
        let p2 = #"\b([0-1]?[0-9]|2[0-3])\s+(?:con|y)\s+([0-5]?[0-9])(?:\s*("# + periodPatternSuffix + #"))?\b"#
        if let regex = try? NSRegularExpression(pattern: p2, options: .caseInsensitive),
           let match = regex.firstMatch(in: normalized, options: [], range: NSRange(location: 0, length: normalized.utf16.count)) {
            let ns = normalized as NSString
            let hStr = ns.substring(with: match.range(at: 1))
            let mStr = ns.substring(with: match.range(at: 2))
            let suffix = match.range(at: 3).location != NSNotFound ? ns.substring(with: match.range(at: 3)).lowercased() : nil
            let (matchPM, matchAM) = resolvePeriod(suffix: suffix, localContext: normalized)
            
            if let h = Int(hStr), let m = Int(mStr) {
                let hour = adjustHour(rawHour: h, suffix: suffix, localContext: normalized, matchPM: matchPM, matchAM: matchAM)
                return (hour: hour, minute: m)
            }
        }
        
        // Pattern 3: (a las | las)? HH seguido de periodo (ej: "a las 7 pm", "7 de la noche", "7 pm", "a las 7 de la tarde", "7 am")
        let p3 = #"\b(?:a\s+las?|las?)?\s*([0-1]?[0-9]|2[0-3])\s*("# + periodPatternSuffix + #")\b"#
        if let regex = try? NSRegularExpression(pattern: p3, options: .caseInsensitive),
           let match = regex.firstMatch(in: normalized, options: [], range: NSRange(location: 0, length: normalized.utf16.count)) {
            let ns = normalized as NSString
            let hStr = ns.substring(with: match.range(at: 1))
            let suffix = ns.substring(with: match.range(at: 2)).lowercased()
            let (matchPM, matchAM) = resolvePeriod(suffix: suffix, localContext: normalized)
            
            if let h = Int(hStr) {
                let hour = adjustHour(rawHour: h, suffix: suffix, localContext: normalized, matchPM: matchPM, matchAM: matchAM)
                return (hour: hour, minute: 0)
            }
        }
        
        // Pattern 4: Expresión "a las X" o "las X" sin sufijo explícito (ej: "a las 7", "las 8", "a la 1")
        let p4 = #"\b(?:a\s+las?|las?)\s+([0-1]?[0-9]|2[0-3])\b"#
        if let regex = try? NSRegularExpression(pattern: p4, options: .caseInsensitive),
           let match = regex.firstMatch(in: normalized, options: [], range: NSRange(location: 0, length: normalized.utf16.count)) {
            let ns = normalized as NSString
            let hStr = ns.substring(with: match.range(at: 1))
            if let h = Int(hStr) {
                let hour = adjustHour(rawHour: h, suffix: nil, localContext: normalized, matchPM: isGlobalPM, matchAM: isGlobalAM)
                return (hour: hour, minute: 0)
            }
        }
        
        // Pattern 5: Texto que responde EXCLUSIVAMENTE a la pregunta de hora (sin verbos ni palabras financieras)
        let financialKeywords = ["sol", "soles", "peso", "pesos", "dolar", "dólar", "dolares", "dólares", "s/", "$", "gasto", "gasté", "gaste", "pago", "pagué", "pague", "ingreso", "compre", "compré", "comida", "almuerzo", "cena", "taxi", "pasaje"]
        let hasFinancial = financialKeywords.contains { s.contains($0) }
        
        if !hasFinancial {
            let digitsOnly = normalized.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let h = Int(digitsOnly), h >= 0 && h <= 23 && normalized.count <= 6 {
                let hour = adjustHour(rawHour: h, suffix: nil, localContext: normalized, matchPM: isGlobalPM, matchAM: isGlobalAM)
                return (hour: hour, minute: 0)
            }
        }
        
        return nil
    }
    
    /// Divide un texto en cláusulas separadas por conjunciones o signos de puntuación respetando abreviaturas de tiempo
    public static func splitIntoClauses(_ raw: String) -> [String] {
        var cleanText = raw
        // Normalizar abreviaturas con puntos para evitar falsas divisiones en oraciones compuestas
        cleanText = cleanText.replacingOccurrences(of: #"(?i)p\.\s*m\."#, with: "pm", options: .regularExpression)
        cleanText = cleanText.replacingOccurrences(of: #"(?i)a\.\s*m\."#, with: "am", options: .regularExpression)
        cleanText = cleanText.replacingOccurrences(of: #"(?i)s\/\."#, with: "soles", options: .regularExpression)
        
        let pattern = #"(?:[\n\r;]+|\s+y\s+(?:en\s+|el\s+|la\s+|los\s+|las\s+|a\s+|al\s+|para\s+|por\s+)?|\s*,\s*|\s+e\s+|\.\s+(?=[A-Za-z]))"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return [raw]
        }
        let ns = cleanText as NSString
        let matches = regex.matches(in: cleanText, options: [], range: NSRange(location: 0, length: cleanText.utf16.count))
        var clauses: [String] = []
        var lastIdx = 0
        for m in matches {
            let chunk = ns.substring(with: NSRange(location: lastIdx, length: m.range.location - lastIdx)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunk.isEmpty {
                clauses.append(chunk)
            }
            lastIdx = m.range.location + m.range.length
        }
        let remainder = ns.substring(from: lastIdx).trimmingCharacters(in: .whitespacesAndNewlines)
        if !remainder.isEmpty {
            clauses.append(remainder)
        }
        return clauses.isEmpty ? [raw] : clauses
    }

    /// Extrae todas las horas y minutos encontradas en un texto en orden de aparición
    public static func parseAllHoursAndMinutes(from raw: String) -> [(hour: Int, minute: Int)] {
        let clauses = splitIntoClauses(raw)
        var results: [(hour: Int, minute: Int)] = []
        for clause in clauses {
            if let hm = parseHourAndMinute(from: clause) {
                results.append(hm)
            }
        }
        return results
    }

    /// Extrae la hora y minuto asociados específicamente a ciertas palabras clave en un texto compuesto
    /// Por ejemplo: si raw es "En comida fue a las 7:00 de la noche p.m. y en el cine fue a las 8 con 59 P.M."
    /// y keywords es ["cine"], extrae (hour: 20, minute: 59).
    public static func extractHour(forKeywords keywords: [String], from raw: String) -> (hour: Int, minute: Int)? {
        let validKeywords = keywords
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty && $0 != "movimiento" && $0.count >= 3 }
        guard !validKeywords.isEmpty else { return nil }
        
        let clauses = splitIntoClauses(raw)
        
        // 1. Buscar en la cláusula que contenga alguna de las palabras clave
        for clause in clauses {
            let lowerClause = clause.lowercased()
            let matches = validKeywords.contains { kw in
                lowerClause.contains(kw) || CategoryHelper.normalize(lowerClause).contains(CategoryHelper.normalize(kw))
            }
            if matches {
                if let hm = parseHourAndMinute(from: clause) {
                    return hm
                }
            }
        }
        
        // 2. Si no se encontró dentro de una sola cláusula, buscar alrededor de la palabra clave en una ventana de texto
        let lowerRaw = raw.lowercased()
        for kw in validKeywords {
            if let range = lowerRaw.range(of: kw) {
                let start = raw.index(range.lowerBound, offsetBy: -20, limitedBy: raw.startIndex) ?? raw.startIndex
                let end = raw.index(range.upperBound, offsetBy: 60, limitedBy: raw.endIndex) ?? raw.endIndex
                let window = String(raw[start..<end])
                if let hm = parseHourAndMinute(from: window) {
                    return hm
                }
            }
        }
        return nil
    }
}

