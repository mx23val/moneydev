import Foundation

public struct ParsedTransactionDraft: Hashable, Sendable, Identifiable {
    public var id: String { "\(title)_\(amount)_\(category)_\(isYesterday)" }
    public let title: String
    public let amount: Double
    public let type: TransactionType
    public let category: String
    public let notes: String
    public let isYesterday: Bool
    public let explicitHour: String?
    public let faltaHora: Bool
    
    public init(
        title: String,
        amount: Double,
        type: TransactionType,
        category: String,
        notes: String = "",
        isYesterday: Bool = false,
        explicitHour: String? = nil,
        faltaHora: Bool = false
    ) {
        self.title = title
        self.amount = amount
        self.type = type
        self.category = category
        self.notes = notes
        self.isYesterday = isYesterday
        self.explicitHour = explicitHour
        self.faltaHora = faltaHora
    }
}

public enum AiParseResult: Sendable {
    case success([ParsedTransactionDraft])
    case noMovementType
    case emptyOrUnrecognized
    case decimalMissingCon
}

public enum AiExpenseParser {
    private static let candidateUrls = [
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent",
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-lite-latest:generateContent",
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent"
    ]
    
    public static func hasAmbiguousAdjacentNumbers(_ text: String) -> Bool {
        let pattern = #"(?<![.\d])\b(\d+)\s+(\d{1,2})\b(?![.\d])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }
    
    public static func splitClauses(_ text: String) -> [String] {
        let pattern = #"(?:[,;]|\.(?!\d)|\s+y\s+|\s+ademas\s+|\s+tambien\s+|\s+e\s+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return [text]
        }
        let range = NSRange(text.startIndex..., in: text)
        var segments: [String] = []
        var lastIndex = text.startIndex
        for m in regex.matches(in: text, range: range) {
            if let r = Range(m.range, in: text) {
                let seg = String(text[lastIndex..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !seg.isEmpty { segments.append(seg) }
                lastIndex = r.upperBound
            }
        }
        let rem = String(text[lastIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !rem.isEmpty { segments.append(rem) }
        return segments
    }
    
    public static func parseNaturalLanguage(_ input: String) async -> AiParseResult {
        let phoneticCleaned = SpeechRecognitionService.normalizePhoneticSpokenText(input)
        let cleanInput = phoneticCleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanInput.isEmpty { return .emptyOrUnrecognized }
        
        let normInput = CategoryHelper.normalize(cleanInput)
        let textWithDigits = convertSpanishNumberWordsInText(cleanInput)
        
        // 0. Interceptar números adyacentes ambiguos sin "con" (ej: "dos 50", "tres 70")
        if hasAmbiguousAdjacentNumbers(textWithDigits) {
            return .decimalMissingCon
        }
        
        let numbers = extractNumbersFromText(textWithDigits)
        
        // 1. If no numbers were found in either digits or words
        if numbers.isEmpty {
            return .emptyOrUnrecognized
        }
        
        // 2. If numbers are present but NO movement context/verb/category is detected
        if !hasFinancialContext(normInput) {
            return .noMovementType
        }
        
        // 3. Fast local deterministic parser first (Instant <1ms response)
        let localResult = parseLocallyResult(cleanInput)
        if case .success(let drafts) = localResult, !drafts.isEmpty {
            return localResult
        }
        if case .decimalMissingCon = localResult {
            return .decimalMissingCon
        }
        
        // 4. Fallback to Gemini API if key is present
        let apiKey = EnvConfig.geminiApiKey
        if !apiKey.isEmpty {
            do {
                let aiResult = try await callGeminiApi(text: cleanInput, apiKey: apiKey)
                if !aiResult.isEmpty {
                    return .success(aiResult)
                }
            } catch {
                print("AiExpenseParser: Error en Gemini API: \(error.localizedDescription)")
            }
        }
        
        return localResult
    }
    
    public static func parseLocallyResult(_ text: String) -> AiParseResult {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanText.isEmpty { return .emptyOrUnrecognized }
        
        let normFullText = CategoryHelper.normalize(cleanText)
        let textWithDigits = convertSpanishNumberWordsInText(cleanText)
        
        // Interceptar números ambiguos sin "con"
        if hasAmbiguousAdjacentNumbers(textWithDigits) {
            return .decimalMissingCon
        }
        
        let numberList = extractNumbersFromText(textWithDigits)
        
        if numberList.isEmpty { return .emptyOrUnrecognized }
        if !hasFinancialContext(normFullText) { return .noMovementType }
        
        var drafts: [ParsedTransactionDraft] = []
        
        let formattedNotes = formatSpokenNoteToDigits(cleanText)
        
        // Exactly 1 number present
        if numberList.count == 1 {
            let amount = numberList[0]
            let isIncome = isIncomeIndicator(normFullText)
            let type: TransactionType = isIncome ? .income : .expense
            let (category, title) = inferCategoryAndTitle(normSeg: normFullText, originalSeg: cleanText, type: type)
            
            let isYesterday = normFullText.contains("ayer") || normFullText.contains("anoche")
            let explicitHm = FormatHelper.parseHourAndMinute(from: cleanText)
            let explicitHourStr = explicitHm.map { String(format: "%02d:%02d", $0.hour, $0.minute) }
            let faltaHora = isYesterday && (explicitHm == nil)
            
            drafts.append(
                ParsedTransactionDraft(
                    title: title.prefix(1).uppercased() + title.dropFirst(),
                    amount: amount,
                    type: type,
                    category: category,
                    notes: formattedNotes,
                    isYesterday: isYesterday,
                    explicitHour: explicitHourStr,
                    faltaHora: faltaHora
                )
            )
            return .success(drafts)
        }
        
        // Multiple numbers: split into clauses WITHOUT breaking decimal dots (e.g. 20.50)
        let rawSegments = splitClauses(textWithDigits)
        
        var accumulatedContext = ""
        for seg in rawSegments {
            let segNorm = CategoryHelper.normalize(seg)
            let numbersInSeg = extractNumbersFromText(seg)
            
            if !numbersInSeg.isEmpty {
                for amount in numbersInSeg {
                    let combinedNorm = accumulatedContext.isEmpty ? segNorm : "\(accumulatedContext) \(segNorm)"
                    let segIsIncome = isIncomeIndicator(combinedNorm)
                    let type: TransactionType = segIsIncome ? .income : .expense
                    let (category, title) = inferCategoryAndTitle(normSeg: combinedNorm, originalSeg: seg, type: type)
                    
                    let isYesterday: Bool = {
                        let segLower = segNorm.lowercased()
                        let combLower = combinedNorm.lowercased()
                        if segLower.contains("ayer") || segLower.contains("anoche") {
                            return true
                        }
                        if combLower.contains("ayer") && !segLower.contains("hoy") {
                            return true
                        }
                        return false
                    }()
                    let explicitHm = FormatHelper.parseHourAndMinute(from: seg) ?? FormatHelper.parseHourAndMinute(from: accumulatedContext)
                    let explicitHourStr = explicitHm.map { String(format: "%02d:%02d", $0.hour, $0.minute) }
                    let faltaHora = isYesterday && (explicitHm == nil)
                    
                    drafts.append(
                        ParsedTransactionDraft(
                            title: title.prefix(1).uppercased() + title.dropFirst(),
                            amount: amount,
                            type: type,
                            category: category,
                            notes: formattedNotes,
                            isYesterday: isYesterday,
                            explicitHour: explicitHourStr,
                            faltaHora: faltaHora
                        )
                    )
                }
                accumulatedContext = ""
            } else {
                accumulatedContext = accumulatedContext.isEmpty ? segNorm : "\(accumulatedContext) \(segNorm)"
            }
        }
        
        if drafts.isEmpty {
            for amount in numberList {
                let isIncome = isIncomeIndicator(normFullText)
                let type: TransactionType = isIncome ? .income : .expense
                let (category, title) = inferCategoryAndTitle(normSeg: normFullText, originalSeg: cleanText, type: type)
                let isYesterday = normFullText.contains("ayer") || normFullText.contains("anoche")
                let explicitHm = FormatHelper.parseHourAndMinute(from: cleanText)
                let explicitHourStr = explicitHm.map { String(format: "%02d:%02d", $0.hour, $0.minute) }
                let faltaHora = isYesterday && (explicitHm == nil)
                drafts.append(
                    ParsedTransactionDraft(
                        title: title.prefix(1).uppercased() + title.dropFirst(),
                        amount: amount,
                        type: type,
                        category: category,
                        notes: formattedNotes,
                        isYesterday: isYesterday,
                        explicitHour: explicitHourStr,
                        faltaHora: faltaHora
                    )
                )
            }
        }
        
        return !drafts.isEmpty ? .success(drafts) : .emptyOrUnrecognized
    }
    
    public static func extractNumbersFromText(_ text: String) -> [Double] {
        var numbers: [Double] = []
        let pattern = #"(?<!\w)(\d+(?:\.\d{1,2})?)(?!\w)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return numbers }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for m in matches {
            if let r = Range(m.range(at: 1), in: text) {
                if let num = Double(text[r]), num > 0 {
                    numbers.append(num)
                }
            }
        }
        return numbers
    }
    
    public static func convertSpanishNumberWordsInText(_ input: String) -> String {
        var text = " " + CategoryHelper.normalize(input).lowercased() + " "
        
        // 0. Preprocess thousands and millions with dots/commas
        text = text.replacingOccurrences(of: #"(?i)\b(\d{1,3})[\.,](\d{3})[\.,](\d{3})(?:[\.,](\d{1,2}))?\b"#, with: "$1$2$3", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)\b(\d{1,3})[\.,](\d{3})\b"#, with: "$1$2", options: .regularExpression)
        
        // 1. Spoken fractions
        text = text.replacingOccurrences(of: #"(?i)\bmedio\s+millon(?:es)?\b"#, with: "500000", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)\bun\s+millon\s+y\s+medio\b"#, with: "1500000", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)\bmedio\s+(?:sol|dolar|euro|peso)\b"#, with: "0.50", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)\bun\s+sol\s+y\s+medio\b"#, with: "1.50", options: .regularExpression)
        
        // 2. Hundreds, Tens, Units
        let hundreds = [
            ("novecientos", 900), ("ochocientos", 800), ("setecientos", 700),
            ("seiscientos", 600), ("quinientos", 500), ("cuatrocientos", 400),
            ("trescientos", 300), ("doscientos", 200), ("ciento", 100), ("cien", 100)
        ]
        let tens = [
            ("noventa", 90), ("ochenta", 80), ("setenta", 70),
            ("sesenta", 60), ("cincuenta", 50), ("cuarenta", 40),
            ("treinta", 30), ("veinte", 20)
        ]
        let units = [
            ("veintinueve", 29), ("veintiocho", 28), ("veintisiete", 27),
            ("veintiseis", 26), ("veinticinco", 25), ("veinticuatro", 24),
            ("veintitres", 23), ("veintidos", 22), ("veintiuno", 21), ("veintiun", 21),
            ("diecinueve", 19), ("dieciocho", 18), ("diecisiete", 17),
            ("dieciseis", 16), ("quince", 15), ("catorce", 14),
            ("trece", 13), ("doce", 12), ("once", 11), ("diez", 10),
            ("nueve", 9), ("ocho", 8), ("siete", 7), ("seis", 6),
            ("cinco", 5), ("cuatro", 4), ("tres", 3), ("dos", 2),
            ("uno", 1), ("un", 1), ("una", 1), ("cero", 0)
        ]
        
        // 1. Hundreds + Tens + Units (e.g., "ciento cincuenta y cinco" -> 155, "ciento cincuenta" -> 150, "doscientos veinticinco" -> 225)
        for (hWord, hVal) in hundreds {
            for (tWord, tVal) in tens {
                for (uWord, uVal) in units where (1...9).contains(uVal) {
                    text = text.replacingOccurrences(of: #"(?i)\b\#(hWord)\s+\#(tWord)\s+y\s+\#(uWord)\b"#, with: "\(hVal + tVal + uVal)", options: .regularExpression)
                }
                text = text.replacingOccurrences(of: #"(?i)\b\#(hWord)\s+\#(tWord)\b"#, with: "\(hVal + tVal)", options: .regularExpression)
            }
            for (uWord, uVal) in units where (1...29).contains(uVal) {
                text = text.replacingOccurrences(of: #"(?i)\b\#(hWord)\s+\#(uWord)\b"#, with: "\(hVal + uVal)", options: .regularExpression)
            }
            text = text.replacingOccurrences(of: #"(?i)\b\#(hWord)\b"#, with: "\(hVal)", options: .regularExpression)
        }
        
        // 2. Tens + Units (e.g., "cincuenta y cinco" -> 55, "cuarenta" -> 40)
        for (tWord, tVal) in tens {
            for (uWord, uVal) in units where (1...9).contains(uVal) {
                text = text.replacingOccurrences(of: #"(?i)\b\#(tWord)\s+y\s+\#(uWord)\b"#, with: "\(tVal + uVal)", options: .regularExpression)
            }
            text = text.replacingOccurrences(of: #"(?i)\b\#(tWord)\b"#, with: "\(tVal)", options: .regularExpression)
        }
        
        for (uWord, uVal) in units {
            if uWord == "un" || uWord == "una" {
                text = text.replacingOccurrences(of: #"(?i)\b\#(uWord)\s+(sol|soles|dolar|dolares|euro|euros|pesos|lucas|mil|miles|millon|millones|k)\b"#, with: "1 $1", options: .regularExpression)
            } else {
                text = text.replacingOccurrences(of: #"(?i)\b\#(uWord)\b"#, with: "\(uVal)", options: .regularExpression)
            }
        }
        
        // Thousands
        text = text.replacingOccurrences(of: #"(?i)\b(\d+)(?:mil|k)\b"#, with: "$1000", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)\b(?:1\s+|un\s+)?(?:mil|miles)\b"#, with: "1000", options: .regularExpression)
        
        // Decimals & Centavos
        // 0. Decimal comma notation (e.g., "2,50" -> "2.50", "3,70" -> "3.70")
        text = text.replacingOccurrences(of: #"(?i)\b(\d+),(\d{1,2})\b"#, with: "$1.$2", options: .regularExpression)
        
        // 1. Spoken half expressions with currency or standalone (e.g. "dos soles y medio" -> "2.50 soles", "cinco y medio" -> "5.50")
        text = text.replacingOccurrences(of: #"(?i)\b(\d+)\s*(soles|sol|dolares|dolar|euros|euro|pesos|peso|lucas|luca)\s+(?:y\s+)?medio\b"#, with: "$1.50 $2", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)\b(\d+)\s+y\s+medio\b"#, with: "$1.50", options: .regularExpression)
        
        // 2. Centavos with single digit prioritized first (e.g. "2 soles con 5 centavos" -> "2.05 soles")
        text = text.replacingOccurrences(of: #"(?i)\b(\d+)\s*(soles|sol|dolares|dolar|euros|euro|pesos|peso|lucas|luca)?\s+(?:con|y)\s+(\d)\s+(?:centavos|centimos|céntimos|cts)\b"#, with: "$1.0$3 $2", options: .regularExpression)
        
        // 3. Currency followed by decimal part, with or without "con" / "y" (e.g. "dos soles 50", "tres soles con 70", "un sol 50", "cinco pesos con 80")
        text = text.replacingOccurrences(of: #"(?i)\b(\d+)\s*(soles|sol|dolares|dolar|euros|euro|pesos|peso|lucas|luca)\s+(?:con\s+|y\s+)?(\d{1,2})(?:\s+(?:centavos|centimos|céntimos|cts))?\b"#, with: "$1.$3 $2", options: .regularExpression)
        
        // 4. Number + "con" + 1 or 2 digits with currency after (e.g. "3 con 70 soles" -> "3.70 soles")
        text = text.replacingOccurrences(of: #"(?i)\b(\d+)\s+con\s+(\d{1,2})\s*(soles|sol|dolares|dolar|euros|euro|pesos|peso|lucas|luca)\b"#, with: "$1.$2 $3", options: .regularExpression)
        
        // 5. Standalone number + "con" + 1 or 2 digits (e.g. "tres con 70" -> "3.70", "dos con 50" -> "2.50", "15 con 80" -> "15.80")
        text = text.replacingOccurrences(of: #"(?i)\b(\d+)\s+con\s+(\d{1,2})(?:\s+(?:centavos|centimos|céntimos|cts))?\b"#, with: "$1.$2", options: .regularExpression)
        
        // 6. Connectors with "punto" or "coma" (e.g. "dos punto 50" -> "2.50")
        text = text.replacingOccurrences(of: #"(?i)\b(\d+)\s*(?:punto|coma)\s*(\d{1,2})\b"#, with: "$1.$2", options: .regularExpression)
        
        // 7. Standalone centavos (e.g. "50 centimos" -> "0.50")
        text = text.replacingOccurrences(of: #"(?i)\b(\d{1,2})\s+(?:centavos|centimos|céntimos|cts)\b"#, with: "0.$1", options: .regularExpression)
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public static func formatSpokenNoteToDigits(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        
        var text = " " + trimmed + " "
        
        // 0. Notación decimal con comas: "3,50" -> "3.50"
        text = text.replacingOccurrences(of: #"(?i)\b(\d+),(\d{1,2})\b"#, with: "$1.$2", options: .regularExpression)
        
        // 1. Fracciones habladas
        text = text.replacingOccurrences(of: #"(?i)\bmedio\s+mill[oó]n(?:es)?\b"#, with: "500000", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)\bun\s+mill[oó]n\s+y\s+medio\b"#, with: "1500000", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)\bmedio\s+(?:sol|d[oó]lar|euro|peso)\b"#, with: "0.50", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)\bun\s+sol\s+y\s+medio\b"#, with: "1.50", options: .regularExpression)
        
        // 2. Centenas
        let hundreds: [(String, Int)] = [
            ("novecientos|novecientas", 900),
            ("ochocientos|ochocientas", 800),
            ("setecientos|setecientas", 700),
            ("seiscientos|seiscientas", 600),
            ("quinientos|quinientas", 500),
            ("cuatrocientos|cuatrocientas", 400),
            ("trescientos|trescientas", 300),
            ("doscientos|doscientas", 200),
            ("ciento", 100),
            ("cien", 100)
        ]
        
        let tens: [(String, Int)] = [
            ("noventa", 90),
            ("ochenta", 80),
            ("setenta", 70),
            ("sesenta", 60),
            ("cincuenta", 50),
            ("cuarenta", 40),
            ("treinta", 30),
            ("veinte", 20)
        ]
        
        let units: [(String, Int)] = [
            ("veintinueve", 29), ("veintiocho", 28), ("veintisiete", 27),
            ("veintiséis|veintiseis", 26), ("veinticinco", 25), ("veinticuatro", 24),
            ("veintitrés|veintitres", 23), ("veintidós|veintidos", 22), ("veintiuno|veintiún|veintiun", 21),
            ("diecinueve", 19), ("dieciocho", 18), ("diecisiete", 17),
            ("dieciséis|dieciseis", 16), ("quince", 15), ("catorce", 14),
            ("trece", 13), ("doce", 12), ("once", 11), ("diez", 10),
            ("nueve", 9), ("ocho", 8), ("siete", 7), ("seis", 6),
            ("cinco", 5), ("cuatro", 4), ("tres", 3), ("dos", 2),
            ("cero", 0)
        ]
        
        // Centenas + Decenas + Unidades
        for (hPat, hVal) in hundreds {
            for (tPat, tVal) in tens {
                for (uPat, uVal) in units where (1...9).contains(uVal) {
                    text = text.replacingOccurrences(of: #"(?i)\b(?:\#(hPat))\s+(?:\#(tPat))\s+y\s+(?:\#(uPat))\b"#, with: "\(hVal + tVal + uVal)", options: .regularExpression)
                }
                text = text.replacingOccurrences(of: #"(?i)\b(?:\#(hPat))\s+(?:\#(tPat))\b"#, with: "\(hVal + tVal)", options: .regularExpression)
            }
            for (uPat, uVal) in units where (1...29).contains(uVal) {
                text = text.replacingOccurrences(of: #"(?i)\b(?:\#(hPat))\s+(?:\#(uPat))\b"#, with: "\(hVal + uVal)", options: .regularExpression)
            }
            text = text.replacingOccurrences(of: #"(?i)\b(?:\#(hPat))\b"#, with: "\(hVal)", options: .regularExpression)
        }
        
        // Decenas + Unidades (ej: "cincuenta y cinco" -> 55, "setenta y cinco" -> 75)
        for (tPat, tVal) in tens {
            for (uPat, uVal) in units where (1...9).contains(uVal) {
                text = text.replacingOccurrences(of: #"(?i)\b(?:\#(tPat))\s+y\s+(?:\#(uPat))\b"#, with: "\(tVal + uVal)", options: .regularExpression)
            }
            text = text.replacingOccurrences(of: #"(?i)\b(?:\#(tPat))\b"#, with: "\(tVal)", options: .regularExpression)
        }
        
        // Unidades individuales
        for (uPat, uVal) in units {
            text = text.replacingOccurrences(of: #"(?i)\b(?:\#(uPat))\b"#, with: "\(uVal)", options: .regularExpression)
        }
        
        // "un" / "una" / "uno" con conectores o moneda
        text = text.replacingOccurrences(of: #"(?i)\b(?:un|una|uno)\s+con\b"#, with: "1 con", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)\b(?:un|una)\s+(sol|soles|d[oó]lar|d[oó]lares|euro|euros|peso|pesos|luca|lucas|mill[oó]n|millones)\b"#, with: "1 $1", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)\buno\b"#, with: "1", options: .regularExpression)
        
        // Miles compuestos (ej: "dos mil" -> 2000, "mil quinientos" -> 1500, "tres mil doscientos" -> 3200)
        text = text.replacingOccurrences(of: #"(?i)\b(\d+)\s+mil\s+(\d{1,3})\b"#, with: "$1$2", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)\b(?:1\s+)?mil\s+(\d{1,3})\b"#, with: "1$1", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)\b(\d+)\s*(?:mil|k)\b"#, with: "$1000", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)\b(?:1\s+)?mil\b"#, with: "1000", options: .regularExpression)
        
        // Expresiones con medio
        text = text.replacingOccurrences(of: #"(?i)\b(\d+)\s*(soles|sol|d[oó]lares|d[oó]lar|euros|euro|pesos|peso|lucas|luca)\s+(?:y\s+)?medio\b"#, with: "$1.50 $2", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)\b(\d+)\s+y\s+medio\b"#, with: "$1.50", options: .regularExpression)
        
        // Céntimos con 1 solo dígito (ej: "2 con 5 centavos" -> "2.05")
        text = text.replacingOccurrences(of: #"(?i)\b(\d+)\s*(soles|sol|d[oó]lares|d[oó]lar|euros|euro|pesos|peso|lucas|luca)?\s+(?:con|y)\s+(\d)\s+(?:centavos|centimos|c[eé]ntimos|cts)\b"#, with: "$1.0$3 $2", options: .regularExpression)
        
        // Moneda seguida de decimal (ej: "2 soles con 50", "2 soles 50")
        text = text.replacingOccurrences(of: #"(?i)\b(\d+)\s*(soles|sol|d[oó]lares|d[oó]lar|euros|euro|pesos|peso|lucas|luca)\s+(?:con\s+|y\s+)?(\d{1,2})(?:\s+(?:centavos|centimos|c[eé]ntimos|cts))?\b"#, with: "$1.$3 $2", options: .regularExpression)
        
        // Número + "con" + 1 o 2 dígitos con moneda tras de sí (ej: "3 con 70 soles" -> "3.70 soles")
        text = text.replacingOccurrences(of: #"(?i)\b(\d+)\s+con\s+(\d{1,2})\s*(soles|sol|d[oó]lares|d[oó]lar|euros|euro|pesos|peso|lucas|luca)\b"#, with: "$1.$2 $3", options: .regularExpression)
        
        // Número + "con" + 1 o 2 dígitos (ej: "3 con 50" -> "3.50", "5 con 75" -> "5.75")
        text = text.replacingOccurrences(of: #"(?i)\b(\d+)\s+con\s+(\d{1,2})(?:\s+(?:centavos|centimos|c[eé]ntimos|cts))?\b"#, with: "$1.$2", options: .regularExpression)
        
        // Conectores con "punto" o "coma"
        text = text.replacingOccurrences(of: #"(?i)\b(\d+)\s*(?:punto|coma)\s*(\d{1,2})\b"#, with: "$1.$2", options: .regularExpression)
        
        // Céntimos aislados
        text = text.replacingOccurrences(of: #"(?i)\b(\d{1,2})\s+(?:centavos|centimos|c[eé]ntimos|cts)\b"#, with: "0.$1", options: .regularExpression)
        
        // Limpieza de espacios múltiples
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public static func hasFinancialContext(_ normText: String) -> Bool {
        if isIncomeIndicator(normText) { return true }
        
        let currencyKeywords = [
            "sol", "soles", "dolar", "dolares", "euro", "euros", "peso", "pesos", "luca", "lucas", "centavos", "centimos"
        ]
        if currencyKeywords.contains(where: { CategoryHelper.hasWordOrPhrase(normText: normText, normTarget: $0) }) {
            return true
        }
        
        let bankKeywords = ["yape", "plin", "bcp", "interbank", "bbva", "scotiabank"]
        if bankKeywords.contains(where: { CategoryHelper.hasWordOrPhrase(normText: normText, normTarget: $0) }) {
            return true
        }
        
        let expenseVerbs = [
            "gaste", "compre", "pague", "perdi", "aposte", "costo", "consumi",
            "alquile", "rente", "sali", "salimos", "fui al", "fui a", "salida",
            "pedi", "pedimos", "di propina", "deje propina", "pague propina",
            "comer", "comi", "cenar", "cene", "almorzar", "almorce", "desayunar", "desayune"
        ]
        if expenseVerbs.contains(where: { CategoryHelper.hasWordOrPhrase(normText: normText, normTarget: $0) }) {
            return true
        }
        for cat in CategoryHelper.expenseCategories {
            if CategoryHelper.hasWordOrPhrase(normText: normText, normTarget: cat.name) { return true }
            for syn in cat.synonyms {
                if CategoryHelper.hasWordOrPhrase(normText: normText, normTarget: syn) { return true }
            }
        }
        for cat in CategoryHelper.incomeCategories {
            if CategoryHelper.hasWordOrPhrase(normText: normText, normTarget: cat.name) { return true }
            for syn in cat.synonyms {
                if CategoryHelper.hasWordOrPhrase(normText: normText, normTarget: syn) { return true }
            }
        }
        return false
    }
    private static func isIncomeIndicator(_ normText: String) -> Bool {
        let incomeKeywords = [
            "me dieron", "dieron", "me regalaron", "regalaron", "regalo de", "bono",
            "cobre", "cobrar", "cobro", "gane", "gane apuesta", "ganancia", "premio", "sueldo",
            "salario", "quincena", "me pagaron", "pagaron", "recibi", "ingreso", "deposito",
            "me depositaron", "me transfirieron", "reembolso", "devolucion", "venta", "vendi", "propina",
            "freelance", "freelancer", "chamba", "cachuelo"
        ]
        let expenseKeywords = [
            "gaste", "compre", "pague", "perdi", "aposte", "costo", "consumi", "sali"
        ]
        if normText.contains("me dieron") || normText.contains("me regalaron") { return true }
        
        // Préstamo vs Pago de Deuda
        let normLower = normText.lowercased()
        let mentionsPrestamo = normLower.contains("prestamo") || normLower.contains("préstamo") || normLower.contains("prestaron") || normLower.contains("prestado") || normLower.contains("saque un prestamo") || normLower.contains("saque prestamo")
        let mentionsDeuda = normLower.contains("deuda") || normLower.contains("credito") || normLower.contains("crédito")
        let mentionsPago = normLower.contains("pague") || normLower.contains("pagué") || normLower.contains("pago") || normLower.contains("pagar") || normLower.contains("cancele") || normLower.contains("cancelé") || normLower.contains("cuota")
        
        if mentionsPrestamo && !mentionsPago {
            return true // "Saque un prestamo de yape de 500 soles" -> Ingreso
        }
        if (mentionsDeuda || mentionsPrestamo) && mentionsPago {
            return false // "Pagué mi deuda de yape 500 soles", "Pagué mi credito de yape 500 soles" -> Gasto
        }
        
        let hasInc = incomeKeywords.contains { normText.contains($0) }
        let hasExp = expenseKeywords.contains { normText.contains($0) }
        return hasInc && !hasExp
    }
    
    public static func detectPeruvianBank(_ text: String) -> String? {
        let norm = CategoryHelper.normalize(text).lowercased()
        if CategoryHelper.hasWordOrPhrase(normText: norm, normTarget: "yape") || norm.contains("yape") {
            return "Yape"
        }
        if CategoryHelper.hasWordOrPhrase(normText: norm, normTarget: "plin") || norm.contains("plin") {
            return "Plin"
        }
        if CategoryHelper.hasWordOrPhrase(normText: norm, normTarget: "bcp") || norm.contains("banco de credito") || norm.contains("credito bcp") {
            return "BCP"
        }
        if CategoryHelper.hasWordOrPhrase(normText: norm, normTarget: "interbank") || norm.contains("inter bank") {
            return "Interbank"
        }
        if CategoryHelper.hasWordOrPhrase(normText: norm, normTarget: "bbva") || norm.contains("continental") {
            return "BBVA"
        }
        if CategoryHelper.hasWordOrPhrase(normText: norm, normTarget: "scotiabank") || norm.contains("scotia") {
            return "Scotiabank"
        }
        return nil
    }
    
    private static func inferCategoryAndTitle(normSeg: String, originalSeg: String, type: TransactionType) -> (category: String, title: String) {
        if type == .income {
            let mentionsPrestamo = normSeg.contains("prestamo") || normSeg.contains("préstamo") || normSeg.contains("prestaron") || normSeg.contains("prestado") || (normSeg.contains("credito") && !normSeg.contains("pague") && !normSeg.contains("pago"))
            if mentionsPrestamo {
                if let bank = detectPeruvianBank(normSeg) {
                    return ("Préstamo", bank)
                }
                return ("Préstamo", "Préstamo")
            }
            
            if normSeg.contains("freelance") || normSeg.contains("freelancer") {
                return ("Trabajo", "Freelance")
            }
            if normSeg.contains("trabajo") || normSeg.contains("chamba") || normSeg.contains("cachuelo") {
                return ("Trabajo", "Trabajo")
            }
            if normSeg.contains("sueldo") || normSeg.contains("salario") || normSeg.contains("quincena") || normSeg.contains("pago mensual") {
                return ("Salario", "Sueldo")
            }
            if normSeg.contains("venta") || normSeg.contains("vendi") || normSeg.contains("cobre venta") {
                return ("Ventas", "Venta")
            }
            if normSeg.contains("apuesta") || normSeg.contains("premio") || normSeg.contains("loteria") || normSeg.contains("gane") {
                return ("Premios y Apuestas", "Premio")
            }
            if normSeg.contains("regalo") || normSeg.contains("me dieron") || normSeg.contains("propina") {
                return ("Regalos", "Regalo")
            }
            if normSeg.contains("devolucion") || normSeg.contains("reembolso") {
                return ("Devoluciones", "Devolución")
            }
            
            // Check synonyms of income categories
            for cat in CategoryHelper.incomeCategories {
                let sortedSynonyms = cat.synonyms.sorted { $0.count > $1.count }
                for syn in sortedSynonyms {
                    if CategoryHelper.hasWordOrPhrase(normText: normSeg, normTarget: syn) {
                        let cleanTitle = syn.prefix(1).uppercased() + syn.dropFirst()
                        return (cat.name, cleanTitle)
                    }
                }
            }
            return ("Otros Ingresos", "Ingreso")
        } else {
            // Prioridad para Deuda / Crédito y Bancos de Perú
            let mentionsDeuda = normSeg.contains("deuda") || normSeg.contains("credito") || normSeg.contains("crédito") || (normSeg.contains("prestamo") && (normSeg.contains("pague") || normSeg.contains("pago") || normSeg.contains("cuota")))
            if mentionsDeuda {
                if let bank = detectPeruvianBank(normSeg) {
                    return ("Deuda", bank)
                }
                if normSeg.contains("credito") || normSeg.contains("crédito") {
                    return ("Deuda", "Crédito")
                }
                return ("Deuda", "Deuda")
            }
            
            // Prioridad para Electrónica y Tecnología
            let techKeywords = [
                "laptop", "laptops", "computadora", "computadoras", "pc", "ordenador",
                "tablet", "tablets", "ipad", "celular", "celulares", "smartphone", "iphone",
                "audifonos", "audífonos", "auriculares", "airpods", "teclado", "mouse",
                "cargador", "cargadores", "smartwatch", "apple watch", "reloj inteligente",
                "televisor", "smart tv", "pantalla", "monitor", "consola", "consolas",
                "playstation", "ps5", "ps4", "xbox", "nintendo", "nintendo switch",
                "gadget", "gadgets", "impresora", "camara", "cámara"
            ]
            for kw in techKeywords {
                if CategoryHelper.hasWordOrPhrase(normText: normSeg, normTarget: kw) {
                    let cleanTitle = kw.prefix(1).uppercased() + kw.dropFirst()
                    return ("Electrónica y Tecnología", cleanTitle)
                }
            }
            
            // Prioridad para Comida y Alimentos (Categoría Oficial: Alimentación)
            let foodKeywords = [
                ("comprar un pollo", "Pollo"), ("comprar pollo", "Pollo"), ("pollo a la brasa", "Pollo a la Brasa"),
                ("pollo", "Pollo"), ("pollos", "Pollo"),
                ("almuerzo", "Almuerzo"), ("almorce", "Almuerzo"), ("almorzar", "Almuerzo"),
                ("desayuno", "Desayuno"), ("desayune", "Desayuno"), ("desayunar", "Desayuno"),
                ("cena", "Cena"), ("cene", "Cena"), ("cenar", "Cena"),
                ("comida", "Almuerzo"), ("comer", "Almuerzo"), ("alimento", "Víveres"), ("alimentos", "Víveres"),
                ("supermercado", "Supermercado"), ("mercado", "Mercado"), ("viveres", "Víveres"),
                ("abarrotes", "Abarrotes"), ("bodega", "Bodega"),
                ("restaurante", "Restaurante"), ("chifa", "Chifa"), ("ceviche", "Ceviche"),
                ("pizza", "Pizza"), ("hamburguesa", "Hamburguesa"),
                ("delivery", "Delivery"), ("starbucks", "Starbucks"), ("postre", "Postre"),
                ("helado", "Helado"),
                ("piqueo", "Piqueo"), ("piqueos", "Piqueo"), ("pi keo", "Piqueo"), ("piqueito", "Piqueo"),
                ("canchita", "Canchita"), ("popcorn", "Canchita"), ("palomitas", "Canchita"),
                ("snack", "Snack"), ("snacks", "Snack")
            ]
            for (kw, title) in foodKeywords {
                if CategoryHelper.hasWordOrPhrase(normText: normSeg, normTarget: kw) {
                    return ("Alimentación", title)
                }
            }
            if CategoryHelper.hasWordOrPhrase(normText: normSeg, normTarget: "cafe") {
                return ("Alimentación", "Café")
            }
            if CategoryHelper.hasWordOrPhrase(normText: normSeg, normTarget: "pan") {
                return ("Alimentación", "Panadería")
            }
            
            // Prioridad para Transporte
            let transportKeywords = [
                ("taxi", "Taxi"), ("uber", "Uber"), ("didi", "DiDi"), ("cabify", "Cabify"), ("indrive", "InDrive"),
                ("gasolina", "Gasolina"), ("combustible", "Combustible"), ("petroleo", "Petróleo"), ("grifo", "Grifo"),
                ("pasaje", "Pasaje"), ("metro", "Metro"), ("tren", "Tren"), ("combi", "Combi")
            ]
            for (kw, title) in transportKeywords {
                if CategoryHelper.hasWordOrPhrase(normText: normSeg, normTarget: kw) {
                    return ("Transporte", title)
                }
            }
            if CategoryHelper.hasWordOrPhrase(normText: normSeg, normTarget: "bus") {
                return ("Transporte", "Bus")
            }
            
            // Prioridad para Suscripciones y Entretenimiento
            let subsKeywords = [
                ("netflix", "Netflix"), ("spotify", "Spotify"), ("youtube", "YouTube"),
                ("prime", "Amazon Prime"), ("disney", "Disney+"), ("chatgpt", "ChatGPT"), ("apple", "Apple")
            ]
            for (kw, title) in subsKeywords {
                if CategoryHelper.hasWordOrPhrase(normText: normSeg, normTarget: kw) {
                    return ("Suscripciones", title)
                }
            }
            let entKeywords = [
                ("cine", "Cine"), ("pelicula", "Película"), ("cineplanet", "Cineplanet"),
                ("cinemark", "Cinemark"), ("cerveza", "Cerveza"), ("cervezas", "Cerveza"),
                ("chela", "Cerveza"), ("chelas", "Cerveza"),
                ("trago", "Trago"), ("tragos", "Trago"),
                ("discoteca", "Discoteca"), ("disco", "Discoteca"),
                ("fiesta", "Fiesta"), ("juerga", "Juerga"), ("farra", "Farra")
            ]
            for (kw, title) in entKeywords {
                if CategoryHelper.hasWordOrPhrase(normText: normSeg, normTarget: kw) {
                    return ("Entretenimiento", title)
                }
            }
            if CategoryHelper.hasWordOrPhrase(normText: normSeg, normTarget: "bar") {
                return ("Entretenimiento", "Bar")
            }
            
            // Prioridad para Salud y Farmacia
            let healthKeywords = [
                ("farmacia", "Farmacia"), ("medicina", "Medicina"), ("pastilla", "Pastillas"),
                ("doctor", "Doctor"), ("clinica", "Clínica"), ("dentista", "Dentista")
            ]
            for (kw, title) in healthKeywords {
                if CategoryHelper.hasWordOrPhrase(normText: normSeg, normTarget: kw) {
                    return ("Salud", title)
                }
            }
            
            // Prioridad para Ropa y Compras
            let shopKeywords = [
                ("zapatillas", "Zapatillas"), ("zapatos", "Zapatos"), ("calzado", "Calzado"),
                ("pantalon", "Pantalón"), ("polo", "Polo"), ("camisa", "Camisa"),
                ("casaca", "Casaca"), ("vestido", "Vestido"), ("ropa", "Ropa"),
                ("cartera", "Cartera"), ("mochila", "Mochila")
            ]
            for (kw, title) in shopKeywords {
                if CategoryHelper.hasWordOrPhrase(normText: normSeg, normTarget: kw) {
                    return ("Compras", title)
                }
            }
            
            // Prioridad para Servicios y Hogar (usando límites exactos para evitar falsos positivos con 'gas', etc.)
            if CategoryHelper.hasWordOrPhrase(normText: normSeg, normTarget: "luz") || normSeg.contains("electricidad") || normSeg.contains("enel") || normSeg.contains("pluz") {
                return ("Servicios", "Luz")
            }
            if CategoryHelper.hasWordOrPhrase(normText: normSeg, normTarget: "agua") || normSeg.contains("sedapal") {
                return ("Servicios", "Agua")
            }
            if normSeg.contains("internet") || normSeg.contains("wifi") || normSeg.contains("fibra") {
                return ("Servicios", "Internet")
            }
            if normSeg.contains("recarga") || normSeg.contains("plan movil") || normSeg.contains("claro") || normSeg.contains("movistar") || normSeg.contains("entel") || normSeg.contains("bitel") {
                return ("Servicios", "Telefonía y Recarga")
            }
            // 'gas' con límite exacto de palabra para nunca confundir con 'gasté' o 'gaste'
            if CategoryHelper.hasWordOrPhrase(normText: normSeg, normTarget: "gas") || normSeg.contains("balon") || normSeg.contains("calidda") {
                return ("Servicios", "Gas")
            }
            
            // Recorrer todas las categorías y sinónimos registrados (priorizando frases largas primero)
            for cat in CategoryHelper.expenseCategories {
                let sortedSynonyms = cat.synonyms.sorted { $0.count > $1.count }
                for syn in sortedSynonyms {
                    if CategoryHelper.hasWordOrPhrase(normText: normSeg, normTarget: syn) {
                        let cleanTitle = syn.prefix(1).uppercased() + syn.dropFirst()
                        return (cat.name, cleanTitle)
                    }
                }
                if CategoryHelper.hasWordOrPhrase(normText: normSeg, normTarget: cat.name) {
                    return (cat.name, cat.name)
                }
            }
            return ("Otros", "Gasto")
        }
    }
    
    private static func callGeminiApi(text: String, apiKey: String) async throws -> [ParsedTransactionDraft] {
        let availableExpenses = CategoryHelper.allCategories(for: .expense).map { $0.name }.joined(separator: ", ")
        let availableIncomes = CategoryHelper.allCategories(for: .income).map { $0.name }.joined(separator: ", ")
        
        let systemPrompt = """
        Eres un asistente financiero ultra inteligente y experto en clasificar gastos e ingresos en español.
        Analiza el texto y responde ÚNICAMENTE con un arreglo JSON de objetos:
        [
          {
            "title": "Nombre corto del concepto",
            "amount": 25.0,
            "type": "EXPENSE" o "INCOME",
            "category": "Nombre exacto de categoría oficial",
            "notes": "Texto del usuario"
          }
        ]
        
        CATÁLOGO OFICIAL DE CATEGORÍAS (ESTRICTAMENTE PROHIBIDO INVENTAR OTRAS):
        - Para gastos (EXPENSE): [\(availableExpenses)]
        - Para ingresos (INCOME): [\(availableIncomes)]
        
        REGLAS DE CATEGORIZACIÓN:
        - TODO lo referente a comida, alimentos, comer, comprar un pollo, pollo a la brasa, restaurante, chifa, pizza, hamburguesa, almuerzo, cena, desayuno, mercado, supermercado, víveres, delivery, etc. DEBE SER OBLIGATORIAMENTE "Alimentación" (JAMÁS inventes "Comida" ni "Alimentos").
        - Todo lo referente a sueldo, nómina, quincena o remuneración laboral DEBE SER OBLIGATORIAMENTE "Salario" (JAMÁS inventes "Sueldo").
        - Si el texto menciona 'freelance', 'freelancer', 'chamba' o 'trabajo' como ingreso, la categoría DEBE ser 'Trabajo' y el título 'Freelance' o 'Trabajo'.
        - BANCOS DE PERÚ Y PRÉSTAMOS / DEUDAS (Yape, Plin, BCP, Interbank, BBVA, Scotiabank):
          * Si el usuario dice que sacó o pidió un préstamo (ej: "Saque un prestamo de yape de 500 soles", "Préstamo de BCP de 1000 soles"):
            type: "INCOME", category: "Préstamo", title: nombre del banco (ej. "Yape", "BCP", "Plin", "Interbank", "BBVA", "Scotiabank").
          * Si el usuario dice que pagó su deuda, crédito o cuota (ej: "Pagué mi deuda de yape 500 soles", "Pagué mi credito de yape 500 soles"):
            type: "EXPENSE", category: "Deuda", title: nombre del banco (ej. "Yape", "BCP", "Plin", "Interbank", "BBVA", "Scotiabank").
        - Si no coincide con ninguna específica, usa exclusivamente "Otros" para gastos o "Otros Ingresos" para ingresos.
        """
        
        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "\(systemPrompt)\n\nTexto del usuario: \"\(text)\""]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1
            ]
        ]
        
        let httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        for baseUrl in candidateUrls {
            guard let url = URL(string: "\(baseUrl)?key=\(apiKey)") else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = httpBody
            request.timeoutInterval = 6.0
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { continue }
                
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let candidates = json["candidates"] as? [[String: Any]],
                      let firstCandidate = candidates.first,
                      let content = firstCandidate["content"] as? [String: Any],
                      let parts = content["parts"] as? [[String: Any]] else { continue }
                
                let textParts = parts.compactMap { part -> String? in
                    if let isThought = part["thought"] as? Bool, isThought {
                        return nil
                    }
                    return part["text"] as? String
                }
                var rawText = textParts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !rawText.isEmpty else { continue }
                
                if rawText.hasPrefix("```json") {
                    rawText = rawText.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                } else if rawText.hasPrefix("```") {
                    rawText = rawText.replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                guard let parsedData = rawText.data(using: .utf8),
                      let jsonArray = try? JSONSerialization.jsonObject(with: parsedData) as? [[String: Any]] else { continue }
                
                var results: [ParsedTransactionDraft] = []
                for item in jsonArray {
                    let title = item["title"] as? String ?? "Movimiento"
                    let amount = (item["amount"] as? NSNumber)?.doubleValue ?? 0.0
                    let typeStr = item["type"] as? String ?? "EXPENSE"
                    let type: TransactionType = typeStr.caseInsensitiveCompare("INCOME") == .orderedSame ? .income : .expense
                    let rawCategory = item["category"] as? String ?? (type == .income ? "Otros Ingresos" : "Otros")
                    let category = CategoryHelper.resolveCategory(nameOrKeyword: rawCategory, type: type)
                    let notes = item["notes"] as? String ?? text
                    let formattedNote = formatSpokenNoteToDigits(notes)
                    
                    if amount > 0 {
                        results.append(
                            ParsedTransactionDraft(
                                title: title,
                                amount: amount,
                                type: type,
                                category: category,
                                notes: formattedNote
                            )
                        )
                    }
                }
                if !results.isEmpty {
                    return results
                }
            } catch {
                continue
            }
        }
        return []
    }
}
