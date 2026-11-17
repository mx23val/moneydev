import Foundation

public enum FinancialAiResponse: Sendable {
    case answer(String)
    case registerMovement(drafts: [ParsedTransactionDraft], confirmationText: String, targetWalletId: Int64? = nil, pendingDrafts: [ParsedTransactionDraft] = [])
    case askTransferConfirmation(pending: PendingTransferVoiceState, message: String)
    case executeTransferVoice(pending: PendingTransferVoiceState, message: String)
    case notUnderstood(String)
}

public enum FinancialAiAssistantEngine {
    private static let candidateUrls = [
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent",
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-lite-latest:generateContent",
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent"
    ]
    
    // MARK: - Generación de Mensaje de Bienvenida Contextual e Inteligente
    public static func generateWelcomeMessage(
        allTransactions: [Transaction] = [],
        wallets: [Wallet] = [],
        summary: FinancialSummary = FinancialSummary(),
        selectedWalletId: Int64? = nil
    ) -> String {
        return "Hola, Soy Moneybot, tu asistente con inteligencia artificial destinado a registrar todos tus movimientos. ¿En qué te puedo ayudar?"
    }
    
    // MARK: - Helper de Coincidencia de Billeteras
    private static func matchWallet(candidate: String, in wallets: [Wallet]) -> Wallet? {
        let clean = CategoryHelper.normalize(candidate).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        
        if let exact = wallets.first(where: { CategoryHelper.normalize($0.name).lowercased() == clean }) {
            return exact
        }
        for w in wallets {
            let wNorm = CategoryHelper.normalize(w.name).lowercased()
            if clean == wNorm || clean.contains(wNorm) || wNorm.contains(clean) {
                return w
            }
        }
        if clean.contains("bcp") || clean.contains("credito") {
            if let w = wallets.first(where: { CategoryHelper.normalize($0.name).lowercased().contains("bcp") }) {
                return w
            }
        }
        if clean.contains("interbank") || clean.contains("inter bank") {
            if let w = wallets.first(where: { CategoryHelper.normalize($0.name).lowercased().contains("interbank") }) {
                return w
            }
        }
        if clean.contains("bbva") || clean.contains("continental") {
            if let w = wallets.first(where: { CategoryHelper.normalize($0.name).lowercased().contains("bbva") }) {
                return w
            }
        }
        if clean.contains("scotiabank") || clean.contains("scotia") {
            if let w = wallets.first(where: { CategoryHelper.normalize($0.name).lowercased().contains("scotiabank") }) {
                return w
            }
        }
        if clean.contains("yape") {
            if let w = wallets.first(where: { CategoryHelper.normalize($0.name).lowercased().contains("yape") }) {
                return w
            }
        }
        if clean.contains("plin") {
            if let w = wallets.first(where: { CategoryHelper.normalize($0.name).lowercased().contains("plin") }) {
                return w
            }
        }
        if clean.contains("efectivo") || clean.contains("cash") {
            if let w = wallets.first(where: {
                let n = CategoryHelper.normalize($0.name).lowercased()
                return n.contains("efectivo") || n.contains("cash")
            }) {
                return w
            }
        }
        return nil
    }
    
    // MARK: - Procesamiento Principal de Consultas
    public static func processQuery(
        rawQuery: String,
        allTransactions: [Transaction],
        wallets: [Wallet],
        summary: FinancialSummary,
        selectedWalletId: Int64? = nil,
        pendingTransfer: PendingTransferVoiceState? = nil,
        pendingTransactions: [ExtractedTransaction] = [],
        fixedExpenses: [FixedExpense] = []
    ) async -> FinancialAiResponse {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return .notUnderstood("No logré entenderte. Por favor, intenta de nuevo diciéndome un gasto, ingreso o consulta sobre tus finanzas.")
        }
        
        let cleanedQuery = SpeechRecognitionService.normalizePhoneticSpokenText(query)
        let norm = CategoryHelper.normalize(cleanedQuery).lowercased()
        
        // 0. VERIFICAR SI HAY UNA TRANSFERENCIA PENDIENTE DE CONFIRMAR
        if let pending = pendingTransfer {
            let affirmativeWords = ["si", "sí", "estoy seguro", "proceder", "confirmo", "confirmar", "dale", "hazlo", "claro", "por supuesto", "adelante", "ok", "correcto", "de acuerdo", "yes"]
            let negativeWords = ["no", "cancela", "cancelar", "no transferir", "detener", "ya no", "no gracias", "espera"]
            
            if affirmativeWords.contains(where: { CategoryHelper.hasWordOrPhrase(normText: norm, normTarget: $0) || norm == $0 }) {
                return .executeTransferVoice(pending: pending, message: "¡Listo! Procediendo con la transferencia...")
            } else if negativeWords.contains(where: { CategoryHelper.hasWordOrPhrase(normText: norm, normTarget: $0) || norm == $0 }) {
                return .answer("Entendido, he cancelado la transferencia.")
            }
        }
        
        // 0.1 COMPLETAR HORA DE TRANSACCIÓN PENDIENTE (MODO OFFLINE Y ASISTIDO)
        if !pendingTransactions.isEmpty {
            let parsedCleanPromptHour = FormatHelper.parseHourAndMinute(from: cleanedQuery)
                ?? FormatHelper.extractHour(forKeywords: [pendingTransactions.first?.titulo ?? "", pendingTransactions.first?.concepto ?? ""], from: cleanedQuery)
            
            let mentionsNewAmount: Bool = {
                let lower = cleanedQuery.lowercased()
                let pattern = #"(?:\b(?:s\/?|soles?|dolares?|dólares?|pesos?|euros?)|(?<!\w)[\$€])\s*\d+|\d+\s*(?:soles?|dolares?|dólares?|pesos?|euros?)\b"#
                return lower.range(of: pattern, options: .regularExpression) != nil
            }()
            
            if let hm = parsedCleanPromptHour, !mentionsNewAmount {
                let pending = pendingTransactions.first!
                let hourStr = String(format: "%02d:%02d", hm.hour, hm.minute)
                
                // Conservar la oración completa original para el concepto/notas
                let fullOriginalSentence = (!pending.concepto.isEmpty && pending.concepto.lowercased() != "movimiento")
                    ? pending.concepto
                    : cleanedQuery
                
                let movementName = (!pending.titulo.isEmpty && pending.titulo.lowercased() != "movimiento")
                    ? pending.titulo
                    : "Gasto"
                
                // Clasificar correctamente la categoría con respecto a ese movimiento del día de ayer
                let resolvedCategory: String = {
                    let catFromTitle = CategoryHelper.resolveCategory(nameOrKeyword: movementName, type: pending.tipo == .INGRESO ? .income : .expense)
                    if catFromTitle != "Otros" && catFromTitle != "Otros Ingresos" {
                        return catFromTitle
                    }
                    if !pending.categoria.isEmpty && pending.categoria != "Otros" && pending.categoria != "Otros Ingresos" {
                        return CategoryHelper.resolveCategory(nameOrKeyword: pending.categoria, type: pending.tipo == .INGRESO ? .income : .expense)
                    }
                    return CategoryHelper.resolveCategory(nameOrKeyword: "\(movementName) \(fullOriginalSentence)", type: pending.tipo == .INGRESO ? .income : .expense)
                }()
                
                let draft = ParsedTransactionDraft(
                    title: movementName,
                    amount: pending.monto,
                    type: pending.tipo == .INGRESO ? .income : .expense,
                    category: resolvedCategory,
                    notes: fullOriginalSentence,
                    isYesterday: true,
                    explicitHour: hourStr,
                    faltaHora: false
                )
                
                let remainingPending = Array(pendingTransactions.dropFirst())
                let cal = Calendar.current
                let now = Date()
                let yesterday = cal.date(byAdding: .day, value: -1, to: now) ?? now
                let dateAyerStr = FormatHelper.formatTransactionDateLong(Int64(yesterday.timeIntervalSince1970 * 1000))
                
                let timeDate = cal.date(bySettingHour: hm.hour, minute: hm.minute, second: 0, of: yesterday) ?? yesterday
                let formattedTimeStr = FormatHelper.formatDeviceTimeAmPm(timeDate)
                
                let tStr = draft.type == .income ? "Ingreso" : "Gasto"
                let icon = draft.type == .income ? "💰" : "💸"
                let targetWalletName: String = (pending.billetera?.isEmpty == false) ? (pending.billetera ?? "Billetera Principal") : (wallets.first(where: { $0.id == (selectedWalletId ?? summary.activeWalletId) })?.name ?? "Billetera Principal")
                
                var confirmationText = """
                ✅ **\(tStr) Registrado** \(icon)
                • Concepto: **\(fullOriginalSentence)**
                • Detalle: **\(movementName)**
                • Monto: **\(summary.currencySymbol) \(FormatHelper.formatCurrency(draft.amount))**
                • Categoría: **\(draft.category)**
                • Fecha: **\(dateAyerStr) a las \(formattedTimeStr)**
                • Billetera: **\(targetWalletName)**
                """
                
                if let nextPending = remainingPending.first {
                    let nextName = !nextPending.titulo.isEmpty && nextPending.titulo.lowercased() != "movimiento" ? nextPending.titulo : nextPending.concepto
                    confirmationText += "\n\n¿A qué hora exacta realizaste el gasto de \(summary.currencySymbol) \(FormatHelper.formatCurrency(nextPending.monto)) en \(nextName) el día de ayer?"
                }
                
                let targetWalletId = wallets.first(where: { CategoryHelper.normalize($0.name).localizedCaseInsensitiveContains(CategoryHelper.normalize(targetWalletName)) })?.id ?? selectedWalletId ?? summary.activeWalletId
                
                return .registerMovement(
                    drafts: [draft],
                    confirmationText: confirmationText,
                    targetWalletId: targetWalletId,
                    pendingDrafts: remainingPending.map { p in
                        ParsedTransactionDraft(
                            title: p.titulo,
                            amount: p.monto,
                            type: p.tipo == .INGRESO ? .income : .expense,
                            category: p.categoria,
                            notes: p.concepto.isEmpty ? fullOriginalSentence : p.concepto,
                            isYesterday: true,
                            explicitHour: nil,
                            faltaHora: true
                        )
                    }
                )
            }
        }
        
        let expenseOrDebtKeywords = ["pague", "gaste", "compre", "deuda", "prestamo", "credito", "saque", "recibi", "ingreso", "gasto", "cuota"]
        let containsExpenseOrDebt = expenseOrDebtKeywords.contains(where: { CategoryHelper.hasWordOrPhrase(normText: norm, normTarget: $0) })
        
        // Determinar billetera objetivo: no desviar a otra billetera si se trata de un gasto, deuda o préstamo
        var detectedWalletId: Int64? = nil
        if !containsExpenseOrDebt && !norm.contains("todas las billeteras") && !norm.contains("todas mis billeteras") {
            for w in wallets {
                let wNorm = CategoryHelper.normalize(w.name).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                guard !wNorm.isEmpty else { continue }
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: wNorm))\\b"
                if norm.range(of: pattern, options: .regularExpression) != nil || (wNorm.count > 3 && norm.contains(wNorm)) {
                    detectedWalletId = w.id
                    break
                }
            }
        }
        
        var effectiveWalletId = detectedWalletId ?? selectedWalletId
        if effectiveWalletId == nil && !norm.contains("todas") {
            effectiveWalletId = summary.activeWalletId
        }
        
        let targetTransactions: [Transaction]
        let scopeText: String
        let currentScopeBalance: Double
        
        if let effectiveWalletId, let w = wallets.first(where: { $0.id == effectiveWalletId }) {
            targetTransactions = allTransactions.filter { $0.walletId == effectiveWalletId }
            let inc = targetTransactions.filter { $0.type == .income }.reduce(0.0) { $0 + $1.amount }
            let exp = targetTransactions.filter { $0.type == .expense }.reduce(0.0) { $0 + $1.amount }
            currentScopeBalance = max(0.0, w.initialBalance + inc - exp)
            scopeText = "en tu billetera '**\(w.name)**'"
        } else {
            targetTransactions = allTransactions
            var total = 0.0
            for w in wallets {
                let wTxs = allTransactions.filter { $0.walletId == w.id }
                let inc = wTxs.filter { $0.type == .income }.reduce(0.0) { $0 + $1.amount }
                let exp = wTxs.filter { $0.type == .expense }.reduce(0.0) { $0 + $1.amount }
                total += max(0.0, w.initialBalance + inc - exp)
            }
            currentScopeBalance = total
            scopeText = "en **Todas tus Billeteras** (\(wallets.count))"
        }
        
        // 0. AYUDA O MENÚ PRINCIPAL
        if norm == "menu" || norm == "ayuda" || norm.contains("que puedes hacer") {
            let welcome = generateWelcomeMessage(allTransactions: targetTransactions, wallets: wallets, summary: summary)
            return .answer(welcome)
        }
        
        // 0.4 OPERACIONES MATEMÁTICAS Y CÁLCULOS ARITMÉTICOS (OFFLINE Y CONEXO A FINANZAS)
        let activeWName = wallets.first(where: { $0.id == (effectiveWalletId ?? summary.activeWalletId) })?.name ?? "tu billetera"
        if let mathResponse = evaluateMathQuery(
            norm: norm,
            query: cleanedQuery,
            activeWalletName: activeWName,
            currencySymbol: summary.currencySymbol
        ) {
            return mathResponse
        }
        
        // 0.5 TRANSFERENCIA ENTRE BILLETERAS POR VOZ (OFFLINE INTELIGENTE Y PRECISO)
        let transferVerbs = ["transfiere", "transferir", "transferencia", "pasa", "pasar", "envia", "enviar", "mueve", "mover"]
        let isTransferIntent = !containsExpenseOrDebt && transferVerbs.contains(where: { CategoryHelper.hasWordOrPhrase(normText: norm, normTarget: $0) })
        
        if isTransferIntent {
            if wallets.count < 2 {
                return .answer("⚠️ Necesitas tener al menos 2 billeteras registradas para transferir dinero entre ellas.")
            }
            
            let textWithDigits = AiExpenseParser.convertSpanishNumberWordsInText(query)
            let numbers = AiExpenseParser.extractNumbersFromText(textWithDigits)
            guard let amount = numbers.first, amount > 0 else {
                return .answer("⚠️ Por favor indica un monto válido mayor a 0 para transferir. Por ejemplo: 'Transfiere 50 soles de BCP a Interbank'.")
            }
            
            // Limpieza del texto para aislar nombres de billetera
            var cleanForWallets = norm
            for verb in transferVerbs {
                cleanForWallets = cleanForWallets.replacingOccurrences(of: "\\b\(verb)\\b", with: " ", options: .regularExpression)
            }
            cleanForWallets = cleanForWallets.replacingOccurrences(of: "\\b\\d+(?:\\.\\d+)?\\b", with: " ", options: .regularExpression)
            cleanForWallets = cleanForWallets.replacingOccurrences(of: "\\b(?:soles|sol|dolares|dólares|pesos|euros|lucas|luca)\\b", with: " ", options: .regularExpression)
            cleanForWallets = cleanForWallets.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
            
            var sourceCandidate: String? = nil
            var destCandidate: String? = nil
            
            // Patrón 1: "de [origen] a [destino]"
            let pat1 = #"(?i)\b(?:de|desde)\s+(?:mi\s+billetera\s+)?([a-zA-Z0-9\s]+?)\s+(?:a|hacia|al)\s+(?:mi\s+billetera\s+)?([a-zA-Z0-9\s]+)"#
            if let r = try? NSRegularExpression(pattern: pat1),
               let m = r.firstMatch(in: cleanForWallets, range: NSRange(location: 0, length: cleanForWallets.utf16.count)) {
                let ns = cleanForWallets as NSString
                sourceCandidate = ns.substring(with: m.range(at: 1))
                destCandidate = ns.substring(with: m.range(at: 2))
            }
            
            // Patrón 2: "a [destino] de [origen]"
            if destCandidate == nil {
                let pat2 = #"(?i)\b(?:a|hacia|al)\s+(?:mi\s+billetera\s+)?([a-zA-Z0-9\s]+?)\s+(?:de|desde)\s+(?:mi\s+billetera\s+)?([a-zA-Z0-9\s]+)"#
                if let r = try? NSRegularExpression(pattern: pat2),
                   let m = r.firstMatch(in: cleanForWallets, range: NSRange(location: 0, length: cleanForWallets.utf16.count)) {
                    let ns = cleanForWallets as NSString
                    destCandidate = ns.substring(with: m.range(at: 1))
                    sourceCandidate = ns.substring(with: m.range(at: 2))
                }
            }
            
            // Patrón 3: "a [destino]" sin origen explícito
            if destCandidate == nil {
                let pat3 = #"(?i)\b(?:a|hacia|al|para)\s+(?:mi\s+billetera\s+)?([a-zA-Z0-9\s]+)"#
                if let r = try? NSRegularExpression(pattern: pat3),
                   let m = r.firstMatch(in: cleanForWallets, range: NSRange(location: 0, length: cleanForWallets.utf16.count)) {
                    let ns = cleanForWallets as NSString
                    destCandidate = ns.substring(with: m.range(at: 1))
                }
            }
            
            let walletsList = wallets.map { "• " + $0.name }.joined(separator: "\n")
            
            // Validación de billetera receptora (destino)
            guard let rawDest = destCandidate?.trimmingCharacters(in: .whitespacesAndNewlines), !rawDest.isEmpty else {
                return .answer("⚠️ Por favor indica la billetera receptora de la transferencia. Tus billeteras son:\n\(walletsList)")
            }
            
            guard let destWallet = matchWallet(candidate: rawDest, in: wallets) else {
                let cleanDestName = rawDest.capitalized
                return .answer(
                    """
                    ⚠️ No encontré ninguna billetera llamada '**\(cleanDestName)**'.
                    
                    Tus billeteras disponibles son:
                    \(walletsList)
                    
                    Por favor, indica una de tus billeteras registradas para realizar la transferencia.
                    """
                )
            }
            
            // Validación de billetera emisora (origen)
            let sourceWallet: Wallet
            if let rawSrc = sourceCandidate?.trimmingCharacters(in: .whitespacesAndNewlines), !rawSrc.isEmpty {
                guard let foundSrc = matchWallet(candidate: rawSrc, in: wallets) else {
                    let cleanSrcName = rawSrc.capitalized
                    return .answer(
                        """
                        ⚠️ No encontré la billetera de origen '**\(cleanSrcName)**'.
                        
                        Tus billeteras disponibles son:
                        \(walletsList)
                        
                        Por favor, indica una de tus billeteras registradas.
                        """
                    )
                }
                sourceWallet = foundSrc
            } else {
                let fallbackId = effectiveWalletId ?? summary.activeWalletId
                if let w = wallets.first(where: { $0.id == fallbackId }), w.id != destWallet.id {
                    sourceWallet = w
                } else if let w = wallets.first(where: { $0.id != destWallet.id }) {
                    sourceWallet = w
                } else {
                    return .answer("⚠️ Por favor indica desde qué billetera deseas transferir hacia '**\(destWallet.name)**'.")
                }
            }
            
            if sourceWallet.id == destWallet.id {
                return .answer("⚠️ La billetera de origen y de destino no pueden ser la misma ('\(sourceWallet.name)'). Elige una billetera receptora diferente.")
            }
            
            // Calcular saldo de la billetera de origen
            let sourceTxs = allTransactions.filter { $0.walletId == sourceWallet.id }
            let sInc = sourceTxs.filter { $0.type == .income }.reduce(0.0) { $0 + $1.amount }
            let sExp = sourceTxs.filter { $0.type == .expense }.reduce(0.0) { $0 + $1.amount }
            let sourceBal = max(0.0, sourceWallet.initialBalance + sInc - sExp)
            
            if sourceBal < (amount - 0.001) {
                return .answer("⚠️ Saldo insuficiente en tu billetera '**\(sourceWallet.name)**'. Tu saldo disponible actual es de \(summary.currencySymbol) \(FormatHelper.formatCurrency(sourceBal)) y deseas transferir \(summary.currencySymbol) \(FormatHelper.formatCurrency(amount)).")
            }
            
            // Todo validado: Preguntar confirmación con MoneyBot
            let pendingState = PendingTransferVoiceState(
                sourceWalletId: sourceWallet.id,
                sourceWalletName: sourceWallet.name,
                destinationWalletId: destWallet.id,
                destinationWalletName: destWallet.name,
                amount: amount,
                detail: "Transferencia por voz con MoneyBot"
            )
            let question = "¿Estás seguro de que deseas transferir **\(summary.currencySymbol) \(FormatHelper.formatCurrency(amount))** de '**\(sourceWallet.name)**' a '**\(destWallet.name)**'?"
            return .askTransferConfirmation(pending: pendingState, message: question)
        }
        
        // 1. REGISTRO DIRECTO POR VOZ / TEXTO (Si tiene contexto financiero y números)
        if AiExpenseParser.hasFinancialContext(norm) {
            var parseResult = AiExpenseParser.parseLocallyResult(query)
            if case .emptyOrUnrecognized = parseResult, !EnvConfig.geminiApiKey.isEmpty {
                parseResult = await AiExpenseParser.parseNaturalLanguage(query)
            }
            if case .decimalMissingCon = parseResult {
                return .notUnderstood("Por favor, para saldos con decimales usa el termino “con”. Por ejemplo: 3 con 70.")
            }
            if case .success(let drafts) = parseResult, !drafts.isEmpty {
                let resolvedTargetWalletId = effectiveWalletId ?? summary.activeWalletId
                let resolvedWalletName: String
                if let w = wallets.first(where: { $0.id == resolvedTargetWalletId }) {
                    resolvedWalletName = w.name
                } else {
                    resolvedWalletName = wallets.first?.name ?? "Billetera Principal"
                }
                
                let cal = Calendar.current
                let now = Date()
                let yesterday = cal.date(byAdding: .day, value: -1, to: now) ?? now
                let dateHoyStr = FormatHelper.formatTransactionDateLong(Int64(now.timeIntervalSince1970 * 1000))
                let dateAyerStr = FormatHelper.formatTransactionDateLong(Int64(yesterday.timeIntervalSince1970 * 1000))
                let timeStr = FormatHelper.formatDeviceTimeAmPm(now)
                
                let readyDrafts = drafts.filter { !$0.faltaHora }
                let pendingDrafts = drafts.filter { $0.faltaHora }
                
                var confirmationParts: [String] = []
                
                if !readyDrafts.isEmpty {
                    let readyText = readyDrafts.map { d in
                        let tStr = d.type == .income ? "Ingreso" : "Gasto"
                        let icon = d.type == .income ? "💰" : "💸"
                        let dateLine = d.isYesterday ? "\(dateAyerStr) a las \(d.explicitHour ?? timeStr)" : "\(dateHoyStr) a las \(d.explicitHour ?? timeStr)"
                        return """
                        ✅ **\(tStr) Registrado** \(icon)
                        • Concepto: **\(d.title)**
                        • Monto: **\(summary.currencySymbol) \(FormatHelper.formatCurrency(d.amount))**
                        • Categoría: **\(d.category)**
                        • Fecha: **\(dateLine)**
                        • Billetera: **\(resolvedWalletName)**
                        """
                    }.joined(separator: "\n\n")
                    confirmationParts.append(readyText)
                }
                
                if let firstPending = pendingDrafts.first {
                    let cur = summary.currencySymbol
                    let mStr = FormatHelper.formatCurrency(firstPending.amount)
                    let question = "¿A qué hora exacta realizaste el gasto de \(cur) \(mStr) en \(firstPending.title) el día de ayer?"
                    confirmationParts.append(question)
                }
                
                let confirmationText = confirmationParts.joined(separator: "\n\n")
                return .registerMovement(drafts: readyDrafts, confirmationText: confirmationText, targetWalletId: resolvedTargetWalletId, pendingDrafts: pendingDrafts)
            }
        }
        
        // 1.5 CONSULTAS TEMPORALES DE GASTOS (HOY, AYER, SEMANA, MES, TOTAL) — OFFLINE INTEGRAL
        // A. Gastos de Hoy
        let isTodayExpensesQuery = (norm.contains("gaste") || norm.contains("gastado") || norm.contains("gastos") || norm.contains("cuanto fue") || norm.contains("que gaste")) &&
                                   (norm.contains("hoy") || norm.contains("el dia de hoy")) &&
                                   !norm.contains("ayer")
        if isTodayExpensesQuery {
            let cal = Calendar.current
            let todayExpenses = targetTransactions.filter { tx in
                tx.type == .expense && cal.isDateInToday(Date(timeIntervalSince1970: Double(tx.dateMillis) / 1000.0))
            }
            let totalToday = todayExpenses.reduce(0.0) { $0 + $1.amount }
            let sym = summary.currencySymbol
            
            if todayExpenses.isEmpty {
                return .answer("📅 **Gastos de Hoy (\(scopeText)):**\n\nHoy no has registrado ningún gasto todavía \(scopeText). ¡Excelente! Tu presupuesto se mantiene intacto.")
            }
            
            var response = "📅 **Gastos de Hoy (\(scopeText)):**\n\nHoy has gastado un total de **\(sym) \(FormatHelper.formatCurrency(totalToday))** en **\(todayExpenses.count) movimiento\(todayExpenses.count == 1 ? "" : "s")**:\n\n"
            for tx in todayExpenses.sorted(by: { $0.dateMillis > $1.dateMillis }) {
                let timeStr = FormatHelper.formatChatMessageTime(Date(timeIntervalSince1970: Double(tx.dateMillis) / 1000.0))
                response += "• **\(sym) \(FormatHelper.formatCurrency(tx.amount))** en \(tx.category) (*'\(tx.title)'* — \(timeStr))\n"
            }
            return .answer(response)
        }
        
        // B. Gastos de Ayer
        let isYesterdayExpensesQuery = (norm.contains("gaste") || norm.contains("gastado") || norm.contains("gastos") || norm.contains("que gaste")) &&
                                       (norm.contains("ayer") || norm.contains("el dia de ayer") || norm.contains("anoche"))
        if isYesterdayExpensesQuery {
            let cal = Calendar.current
            let yesterdayExpenses = targetTransactions.filter { tx in
                tx.type == .expense && cal.isDateInYesterday(Date(timeIntervalSince1970: Double(tx.dateMillis) / 1000.0))
            }
            let totalYesterday = yesterdayExpenses.reduce(0.0) { $0 + $1.amount }
            let sym = summary.currencySymbol
            
            if yesterdayExpenses.isEmpty {
                return .answer("📅 **Gastos de Ayer (\(scopeText)):**\n\nNo registraste ningún gasto el día de ayer \(scopeText).")
            }
            
            var response = "📅 **Gastos de Ayer (\(scopeText)):**\n\nEl día de ayer registraste un total de **\(sym) \(FormatHelper.formatCurrency(totalYesterday))** en **\(yesterdayExpenses.count) movimiento\(yesterdayExpenses.count == 1 ? "" : "s")**:\n\n"
            for tx in yesterdayExpenses.sorted(by: { $0.dateMillis > $1.dateMillis }) {
                let timeStr = FormatHelper.formatChatMessageTime(Date(timeIntervalSince1970: Double(tx.dateMillis) / 1000.0))
                response += "• **\(sym) \(FormatHelper.formatCurrency(tx.amount))** en \(tx.category) (*'\(tx.title)'* — \(timeStr))\n"
            }
            return .answer(response)
        }
        
        // C. Gastos de Esta Semana
        let isWeekExpensesQuery = (norm.contains("gaste") || norm.contains("gastado") || norm.contains("gastos")) &&
                                  (norm.contains("esta semana") || norm.contains("la semana") || norm.contains("semanal"))
        if isWeekExpensesQuery {
            let cal = Calendar.current
            let now = Date()
            let weekExpenses = targetTransactions.filter { tx in
                tx.type == .expense && cal.isDate(Date(timeIntervalSince1970: Double(tx.dateMillis) / 1000.0), equalTo: now, toGranularity: .weekOfYear)
            }
            let totalWeek = weekExpenses.reduce(0.0) { $0 + $1.amount }
            let sym = summary.currencySymbol
            
            if weekExpenses.isEmpty {
                return .answer("📅 **Gastos de Esta Semana (\(scopeText)):**\n\nNo tienes gastos registrados durante esta semana \(scopeText).")
            }
            
            var response = "📅 **Gastos de Esta Semana (\(scopeText)):**\n\nEn lo que va de la semana has gastado **\(sym) \(FormatHelper.formatCurrency(totalWeek))** en **\(weekExpenses.count) movimientos**.\n\n"
            for tx in weekExpenses.sorted(by: { $0.dateMillis > $1.dateMillis }).prefix(5) {
                let dStr = FormatHelper.formatDate(tx.dateMillis)
                response += "• **\(sym) \(FormatHelper.formatCurrency(tx.amount))** en \(tx.category) (*'\(tx.title)'* — \(dStr))\n"
            }
            return .answer(response)
        }
        
        // D. Gastos de Este Mes
        let isMonthExpensesQuery = (norm.contains("gaste") || norm.contains("gastado") || norm.contains("gastos")) &&
                                   (norm.contains("este mes") || norm.contains("el mes") || norm.contains("mensual") || norm.contains("del mes"))
        if isMonthExpensesQuery {
            let cal = Calendar.current
            let now = Date()
            let monthExpenses = targetTransactions.filter { tx in
                tx.type == .expense && cal.isDate(Date(timeIntervalSince1970: Double(tx.dateMillis) / 1000.0), equalTo: now, toGranularity: .month)
            }
            let totalMonth = monthExpenses.reduce(0.0) { $0 + $1.amount }
            let sym = summary.currencySymbol
            
            if monthExpenses.isEmpty {
                return .answer("📅 **Gastos de Este Mes (\(scopeText)):**\n\nNo tienes gastos registrados en este mes todavía \(scopeText).")
            }
            
            var grouped: [String: Double] = [:]
            for tx in monthExpenses {
                grouped[tx.category, default: 0.0] += tx.amount
            }
            let topCats = grouped.sorted { $0.value > $1.value }
            
            var response = "📅 **Gastos de Este Mes (\(scopeText)):**\n\nDurante este mes has gastado un total de **\(sym) \(FormatHelper.formatCurrency(totalMonth))** en **\(monthExpenses.count) movimientos**.\n\n"
            if !topCats.isEmpty {
                response += "📊 **Principales categorías del mes:**\n"
                for cat in topCats.prefix(3) {
                    let pct = totalMonth > 0 ? Int(round((cat.value / totalMonth) * 100)) : 0
                    response += "• **\(cat.key)**: \(sym) \(FormatHelper.formatCurrency(cat.value)) (\(pct)%)\n"
                }
            }
            return .answer(response)
        }
        
        // E. Total de Gastos Acumulado
        let isTotalExpensesQuery = (norm.contains("cuanto he gastado") || norm.contains("cuanto gaste en total") || norm.contains("total de gastos") || norm == "mis gastos" || norm == "gastos" || norm.contains("cuanto suman mis gastos")) &&
                                   !norm.contains("hoy") && !norm.contains("ayer") && !norm.contains("mes") && !norm.contains("semana")
        if isTotalExpensesQuery {
            let expenses = targetTransactions.filter { $0.type == .expense }
            let total = expenses.reduce(0.0) { $0 + $1.amount }
            let sym = summary.currencySymbol
            
            if expenses.isEmpty {
                return .answer("📊 **Total de Gastos (\(scopeText)):**\n\nNo registras ningún gasto aún \(scopeText).")
            }
            return .answer("📊 **Total de Gastos (\(scopeText)):**\n\nHas registrado un total acumulado de **\(sym) \(FormatHelper.formatCurrency(total))** en **\(expenses.count) movimientos**.")
        }
        
        // 1.6 CONSULTAS DE BILLETERAS, CUENTAS ACTIVAS Y NÚMERO DE CUENTAS
        let isWalletsQuery = norm.contains("que billeteras") ||
                             norm.contains("cuales son mis billeteras") ||
                             norm.contains("mis billeteras") ||
                             norm.contains("cuantas billeteras") ||
                             norm.contains("mis cuentas") ||
                             norm.contains("que cuentas") ||
                             norm.contains("cuales cuentas") ||
                             norm.contains("cuales son mis cuentas") ||
                             norm.contains("cuantas cuentas") ||
                             norm.contains("cuentas tengo activas") ||
                             norm.contains("cuentas activas") ||
                             norm.contains("cuentas tengo") ||
                             norm.contains("billeteras tengo") ||
                             norm.contains("numero de cuentas") ||
                             norm.contains("numero de billeteras") ||
                             norm.contains("nombre de las cuentas") ||
                             norm.contains("nombres de las cuentas") ||
                             norm.contains("nombre de mis cuentas") ||
                             norm.contains("nombres de mis cuentas") ||
                             norm.contains("nombre de las billeteras") ||
                             norm.contains("nombre de mis billeteras") ||
                             norm.contains("lista de billeteras") ||
                             norm.contains("lista de cuentas") ||
                             norm.contains("todas mis cuentas") ||
                             norm.contains("todas mis billeteras")
        if isWalletsQuery {
            let sym = summary.currencySymbol
            if wallets.isEmpty {
                return .answer("👛 **Tus Cuentas Activas:**\n\nNo tienes ninguna cuenta o billetera registrada todavía en la app.")
            }
            
            var response = "👛 **Tus Cuentas Activas (\(wallets.count)):**\n\n"
            var totalAll = 0.0
            for (idx, w) in wallets.enumerated() {
                let wTxs = allTransactions.filter { $0.walletId == w.id }
                let inc = wTxs.filter { $0.type == .income }.reduce(0.0) { $0 + $1.amount }
                let exp = wTxs.filter { $0.type == .expense }.reduce(0.0) { $0 + $1.amount }
                let bal = max(0.0, w.initialBalance + inc - exp)
                totalAll += bal
                let activeTag = (w.id == summary.activeWalletId) ? " *(Billetera activa)*" : ""
                response += "\(idx + 1). **\(w.name)**: **\(sym) \(FormatHelper.formatCurrency(bal))** (\(wTxs.count) movimientos)\(activeTag)\n"
            }
            response += "\n💰 **Saldo Total Combinado:** **\(sym) \(FormatHelper.formatCurrency(totalAll))**."
            return .answer(response)
        }
        
        // 1.6.5 CUENTAS MÁS USADAS / BILLETERAS CON MÁS MOVIMIENTO
        let isMostUsedWalletsQuery = norm.contains("cuentas mas usadas") ||
                                     norm.contains("cuenta mas usada") ||
                                     norm.contains("billeteras mas usadas") ||
                                     norm.contains("billetera mas usada") ||
                                     norm.contains("cuentas mas utilizadas") ||
                                     norm.contains("cuenta mas utilizada") ||
                                     norm.contains("las mas usadas") ||
                                     norm.contains("las mas utilizadas") ||
                                     norm.contains("que cuenta uso mas") ||
                                     norm.contains("cual cuenta uso mas") ||
                                     norm.contains("en que cuenta tengo mas") ||
                                     norm.contains("en que billetera tengo mas") ||
                                     norm.contains("cuenta con mas movimientos") ||
                                     norm.contains("billetera con mas movimientos") ||
                                     norm.contains("cuenta mas activa") ||
                                     norm.contains("billetera mas activa")
        if isMostUsedWalletsQuery {
            let sym = summary.currencySymbol
            if wallets.isEmpty {
                return .answer("👛 **Cuentas más usadas:**\n\nNo tienes cuentas registradas todavía en la app.")
            }
            
            let walletStats = wallets.map { w -> (wallet: Wallet, count: Int, volume: Double, balance: Double) in
                let wTxs = allTransactions.filter { $0.walletId == w.id }
                let inc = wTxs.filter { $0.type == .income }.reduce(0.0) { $0 + $1.amount }
                let exp = wTxs.filter { $0.type == .expense }.reduce(0.0) { $0 + $1.amount }
                let bal = max(0.0, w.initialBalance + inc - exp)
                let vol = wTxs.reduce(0.0) { $0 + $1.amount }
                return (wallet: w, count: wTxs.count, volume: vol, balance: bal)
            }.sorted { 
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.volume > $1.volume
            }
            
            if let top = walletStats.first, top.count > 0 {
                var response = "🏆 **Tu cuenta más usada es '\(top.wallet.name)'**:\n\n"
                response += "• **\(top.count) movimientos registrados** con un flujo total de **\(sym) \(FormatHelper.formatCurrency(top.volume))**.\n"
                response += "• Saldo actual en esta cuenta: **\(sym) \(FormatHelper.formatCurrency(top.balance))**.\n"
                
                if walletStats.count > 1 {
                    response += "\n📊 **Ranking de actividad de tus cuentas:**\n"
                    for (idx, stat) in walletStats.enumerated() {
                        let activeTag = (stat.wallet.id == summary.activeWalletId) ? " *(Activa)*" : ""
                        response += "\(idx + 1). **\(stat.wallet.name)**: \(stat.count) movimientos • Flujo: \(sym) \(FormatHelper.formatCurrency(stat.volume))\(activeTag)\n"
                    }
                }
                return .answer(response)
            } else {
                return .answer("👛 **Cuentas más usadas:**\n\nTus cuentas registradas no tienen movimientos acumulados todavía para establecer un ranking.")
            }
        }
        
        // 1.7 CONSULTAS DE GASTOS FIJOS
        let isFixedExpensesQuery = norm.contains("gastos fijos") ||
                                   norm.contains("gasto fijo") ||
                                   norm.contains("cuanto pago en gastos fijos") ||
                                   norm.contains("mis pagos fijos") ||
                                   norm.contains("pagos recurrentes")
        if isFixedExpensesQuery {
            let sym = summary.currencySymbol
            if fixedExpenses.isEmpty {
                return .answer("📌 **Gastos Fijos:**\n\nNo tienes ningún gasto fijo registrado todavía en MoneyDev.\n\nPuedes agregar servicios, suscripciones o alquileres desde la sección de **Gastos Fijos** para tenerlos siempre controlados.")
            }
            
            let totalFixed = fixedExpenses.reduce(0.0) { $0 + $1.amount }
            var response = "📌 **Tus Gastos Fijos (\(fixedExpenses.count)):**\n\n"
            for fe in fixedExpenses {
                let wName = wallets.first(where: { $0.id == fe.walletId })?.name ?? "Billetera"
                response += "• **\(fe.name)**: \(sym) \(FormatHelper.formatCurrency(fe.amount)) (*\(fe.frequency.displayName)* • \(fe.category) • \(wName))\n"
            }
            response += "\n**Total en gastos fijos:** **\(sym) \(FormatHelper.formatCurrency(totalFixed))**."
            return .answer(response)
        }
        
        // 1.8 CONSULTAS DE ÚLTIMOS MOVIMIENTOS Y GASTOS RECIENTES
        let isRecentTransactionsQuery = norm.contains("ultimos movimientos") ||
                                        norm.contains("ultimos gastos") ||
                                        norm.contains("ultimas compras") ||
                                        norm.contains("que fue lo ultimo") ||
                                        norm.contains("movimientos recientes") ||
                                        norm.contains("gastos recientes") ||
                                        norm.contains("ultimas transacciones")
        if isRecentTransactionsQuery {
            let sym = summary.currencySymbol
            if targetTransactions.isEmpty {
                return .answer("🕒 **Últimos Movimientos (\(scopeText)):**\n\nNo registras movimientos recientes todavía \(scopeText).")
            }
            
            let sorted = targetTransactions.sorted(by: { $0.dateMillis > $1.dateMillis }).prefix(5)
            var response = "🕒 **Últimos movimientos registrados (\(scopeText)):**\n\n"
            for tx in sorted {
                let dStr = FormatHelper.formatDate(tx.dateMillis)
                let tStr = tx.type == .income ? "Ingreso (+)" : "Gasto (-)"
                let icon = tx.type == .income ? "💰" : "💸"
                let wName = wallets.first(where: { $0.id == tx.walletId })?.name ?? "Billetera"
                response += "\(icon) **\(tStr)**: \(sym) \(FormatHelper.formatCurrency(tx.amount)) • *\(tx.title)*\n   ↳ \(tx.category) | \(dStr) | \(wName)\n"
            }
            return .answer(response)
        }
        
        // 2. CONSULTA ESPECÍFICA: ¿EN QUÉ CATEGORÍA GASTÉ MÁS? / CATEGORÍA LÍDER EN GASTOS
        let isTopCategoryQuery = norm.contains("en que categoria") ||
                                 (norm.contains("categoria") && (norm.contains("mas") || norm.contains("mayor") || norm.contains("lider") || norm.contains("alta") || norm.contains("altas"))) ||
                                 norm.contains("gaste mas") ||
                                 norm.contains("gastado mas") ||
                                 norm.contains("gasto mas") ||
                                 norm.contains("en que gasto mas") ||
                                 norm.contains("en que gaste mas") ||
                                 norm.contains("en que he gastado mas") ||
                                 norm.contains("categoria mas alta") ||
                                 norm.contains("categorias mas altas") ||
                                 norm.contains("ver las categorias") ||
                                 norm.contains("top categorias")
        if isTopCategoryQuery {
            let expenses = targetTransactions.filter { $0.type == .expense }
            let sym = summary.currencySymbol
            
            if expenses.isEmpty {
                return .answer(
                    """
                    📂 **Categorías de Gasto (\(scopeText)):**
                    
                    No registras ningún gasto todavía \(scopeText).
                    
                    En cuanto anotes tus primeros egresos, te mostraré aquí con exactitud qué categoría concentra la mayor parte de tu dinero.
                    """
                )
            }
            
            var grouped: [String: Double] = [:]
            var counts: [String: Int] = [:]
            for tx in expenses {
                grouped[tx.category, default: 0.0] += tx.amount
                counts[tx.category, default: 0] += 1
            }
            
            let totalExp = expenses.reduce(0.0) { $0 + $1.amount }
            let sorted = grouped.sorted { $0.value > $1.value }
            
            if let top = sorted.first {
                let pct = totalExp > 0 ? Int(round((top.value / totalExp) * 100)) : 0
                let topTxInCat = expenses.filter { $0.category.caseInsensitiveCompare(top.key) == .orderedSame }.max(by: { $0.amount < $1.amount })
                
                var response = """
                🏆 **Tu categoría con mayor gasto \(scopeText) es:**
                
                🏷️ **\(top.key.uppercased())**
                • Total gastado: **\(sym) \(FormatHelper.formatCurrency(top.value))**
                • Representa el **\(pct)%** de tus gastos en esta billetera.
                • Movimientos registrados: **\(counts[top.key] ?? 1) consumos**.
                """
                
                if let topTx = topTxInCat {
                    let dStr = FormatHelper.formatDate(topTx.dateMillis)
                    response += "\n• Mayor consumo en esta categoría: **\(sym) \(FormatHelper.formatCurrency(topTx.amount))** (*'\(topTx.title)'* — \(dStr)).\n"
                }
                
                if sorted.count > 1 {
                    response += "\n📊 **Otras categorías de gasto:**\n"
                    for (idx, item) in sorted.dropFirst().prefix(4).enumerated() {
                        let catPct = totalExp > 0 ? Int(round((item.value / totalExp) * 100)) : 0
                        response += "\(idx + 2). **\(item.key)**: \(sym) \(FormatHelper.formatCurrency(item.value)) (\(catPct)%)\n"
                    }
                }
                
                return .answer(response)
            }
        }
        
        // 2.5 CONSULTA ESPECÍFICA: ¿EN QUÉ GASTÉ MENOS? / CATEGORÍA CON MENOR GASTO
        let isLowestCategoryQuery = norm.contains("gaste menos") ||
                                    norm.contains("gastado menos") ||
                                    norm.contains("en que gasto menos") ||
                                    norm.contains("en que gaste menos") ||
                                    norm.contains("en que he gastado menos") ||
                                    norm.contains("categoria mas baja") ||
                                    norm.contains("categoria con menos") ||
                                    norm.contains("categoria con menor") ||
                                    norm.contains("menor gasto") ||
                                    norm.contains("gasto mas bajo") ||
                                    norm.contains("gasto mas chico") ||
                                    norm.contains("gasto mas pequeno") ||
                                    norm.contains("compra mas barata") ||
                                    norm.contains("compras mas baratas")
        if isLowestCategoryQuery {
            let expenses = targetTransactions.filter { $0.type == .expense }
            let sym = summary.currencySymbol
            
            if expenses.isEmpty {
                return .answer("📂 **Menores Gastos (\(scopeText)):**\n\nNo registras gastos todavía \(scopeText).")
            }
            
            var grouped: [String: Double] = [:]
            var counts: [String: Int] = [:]
            for tx in expenses {
                grouped[tx.category, default: 0.0] += tx.amount
                counts[tx.category, default: 0] += 1
            }
            
            let sortedAscending = grouped.sorted { $0.value < $1.value }
            let lowestIndividual = expenses.min(by: { $0.amount < $1.amount })
            
            if let lowest = sortedAscending.first {
                var response = "📉 **Categoría en la que menos gastas (\(scopeText)):**\n\n"
                response += "🏷️ **\(lowest.key.uppercased())**\n"
                response += "• Total acumulado: **\(sym) \(FormatHelper.formatCurrency(lowest.value))** (\(counts[lowest.key] ?? 1) movimientos).\n"
                
                if let minTx = lowestIndividual {
                    let dStr = FormatHelper.formatDate(minTx.dateMillis)
                    response += "\n• Tu compra individual más pequeña registrada es de **\(sym) \(FormatHelper.formatCurrency(minTx.amount))** (*'\(minTx.title)'* en \(minTx.category) — \(dStr)).\n"
                }
                
                if sortedAscending.count > 1 {
                    response += "\n📊 **Otras categorías de bajo consumo:**\n"
                    for (idx, item) in sortedAscending.dropFirst().prefix(3).enumerated() {
                        response += "\(idx + 2). **\(item.key)**: \(sym) \(FormatHelper.formatCurrency(item.value))\n"
                    }
                }
                return .answer(response)
            }
        }
        
        // 3. CONSULTAS DE SALDO Y BALANCE
        let isBalanceQuery = norm.contains("saldo") ||
                             norm.contains("balance") ||
                             norm.contains("cuanto tengo") ||
                             norm.contains("cuanta plata") ||
                             norm.contains("cuanto dinero") ||
                             norm.contains("plata tengo") ||
                             norm.contains("dinero tengo") ||
                             norm.contains("cuanto me queda") ||
                             norm.contains("cuanto hay") ||
                             norm.contains("mi dinero")
        if isBalanceQuery {
            let balFormatted = FormatHelper.formatCurrency(currentScopeBalance)
            let sym = summary.currencySymbol
            
            let wantsDetails = norm.contains("detalle") ||
                               norm.contains("completo") ||
                               norm.contains("detallado") ||
                               norm.contains("explicame") ||
                               norm.contains("mas informacion") ||
                               norm.contains("desglos") ||
                               norm.contains("resumen")
            
            // Si el usuario no solicitó un desglose detallado, responder de manera puntual y directa
            if !wantsDetails {
                return .answer("💰 **Saldo Disponible (\(scopeText)):**\n\nTu saldo actual es de **\(sym) \(balFormatted)**.")
            }
            
            let incomes = targetTransactions.filter { $0.type == .income }
            let expenses = targetTransactions.filter { $0.type == .expense }
            let totalInc = incomes.reduce(0.0) { $0 + $1.amount }
            let totalExp = expenses.reduce(0.0) { $0 + $1.amount }
            let netSavings = totalInc - totalExp
            
            var response = """
            💰 **Saldo Disponible (\(scopeText)):**
            
            Tu saldo actual es de **\(sym) \(balFormatted)**.
            
            📊 **Resumen detallado de movimientos:**
            • Total de ingresos: +\(sym) \(FormatHelper.formatCurrency(totalInc)) (\(incomes.count) entradas)
            • Total de gastos: -\(sym) \(FormatHelper.formatCurrency(totalExp)) (\(expenses.count) salidas)
            • Balance neto: **\(netSavings >= 0 ? "+" : "")\(sym) \(FormatHelper.formatCurrency(netSavings))**
            """
            
            if currentScopeBalance <= 0 {
                response += "\n\n⚠️ *Nota: Tu saldo disponible en esta billetera está en cero o agotado. Considera recargar fondos o transferir desde otra billetera.*"
            } else if currentScopeBalance < 50 {
                response += "\n\n⚠️ *Nota: Tu saldo se encuentra en un nivel ajustado. Te sugiero priorizar gastos esenciales.*"
            } else {
                response += "\n\n✅ *Tu saldo se encuentra en un estado saludable y disponible para tus operaciones.*"
            }
            
            return .answer(response)
        }
        
        // 4. CONSULTAS DE MAYORES GASTOS INDIVIDUALES Y TOP
        let isTopExpensesQuery = norm.contains("mayores gastos") ||
                                 norm.contains("mayor gasto") ||
                                 norm.contains("top gastos") ||
                                 norm.contains("gastos mas altos") ||
                                 norm.contains("gasto mas alto") ||
                                 norm.contains("gastos mas grandes") ||
                                 norm.contains("gasto mas grande") ||
                                 norm.contains("compras mas caras") ||
                                 norm.contains("compra mas cara") ||
                                 norm.contains("compras mas altas") ||
                                 norm.contains("cuales son los gastos mas altos") ||
                                 norm.contains("en que se va mi plata")
        if isTopExpensesQuery {
            let expenses = targetTransactions.filter { $0.type == .expense }
            let sym = summary.currencySymbol
            
            if expenses.isEmpty {
                return .answer("📊 **Mayores Gastos (\(scopeText)):**\n\nNo registras gastos todavía \(scopeText). ¡Excelente momento para mantener tu presupuesto intacto!")
            }
            
            let totalExp = expenses.reduce(0.0) { $0 + $1.amount }
            let sortedIndividual = expenses.sorted { $0.amount > $1.amount }
            
            var response = "💸 **Tus mayores gastos individuales (\(scopeText)):**\n\n"
            for (idx, tx) in sortedIndividual.prefix(4).enumerated() {
                let dStr = FormatHelper.formatDate(tx.dateMillis)
                response += "\(idx + 1). **\(sym) \(FormatHelper.formatCurrency(tx.amount))** • '\(tx.title)'\n   ↳ *Categoría: \(tx.category) | Fecha: \(dStr)*\n"
            }
            
            var grouped: [String: Double] = [:]
            for tx in expenses {
                grouped[tx.category, default: 0.0] += tx.amount
            }
            let sortedCats = grouped.sorted { $0.value > $1.value }
            
            if !sortedCats.isEmpty {
                response += "\n📂 **Categorías con mayor concentración:**\n"
                for cat in sortedCats.prefix(3) {
                    let pct = totalExp > 0 ? Int(round((cat.value / totalExp) * 100)) : 0
                    response += "• **\(cat.key)**: \(sym) \(FormatHelper.formatCurrency(cat.value)) (\(pct)%)\n"
                }
            }
            
            return .answer(response)
        }
        
        // 5. CONSEJOS Y TIPS DE AHORRO CON DATOS REALES
        let isSavingsQuery = norm.contains("consejo") ||
                             norm.contains("tip") ||
                             norm.contains("ahorrar") ||
                             norm.contains("como ahorro") ||
                             norm.contains("diagnostico") ||
                             norm.contains("recomendacion")
        if isSavingsQuery {
            let walletLabel: String
            if let effectiveWalletId, let targetWallet = wallets.first(where: { $0.id == effectiveWalletId }) {
                walletLabel = targetWallet.name
            } else {
                walletLabel = "Todas tus billeteras"
            }
            
            let expenses = targetTransactions.filter { $0.type == .expense }
            let incomes = targetTransactions.filter { $0.type == .income }
            let totalExp = expenses.reduce(0.0) { $0 + $1.amount }
            let totalInc = incomes.reduce(0.0) { $0 + $1.amount }
            let sym = summary.currencySymbol
            
            var advice = "💡 **Consejos financieros personalizados ('\(walletLabel)'):**\n\n"
            
            if totalInc > 0 && totalExp > totalInc {
                let deficit = totalExp - totalInc
                advice += "⚠️ **Alerta de déficit**: En '\(walletLabel)' tus gastos superan los ingresos por **\(sym) \(FormatHelper.formatCurrency(deficit))**. Es clave congelar consumos discrecionales durante los próximos días.\n\n"
            } else if totalInc > 0 {
                let savingsRate = Int(round(((totalInc - totalExp) / totalInc) * 100))
                advice += "🎯 **Tasa de ahorro en '\(walletLabel)'**: Estás reteniendo el **\(savingsRate)%** de lo ingresado. (La meta ideal recomendada es al menos el 20%).\n\n"
            }
            
            var grouped: [String: Double] = [:]
            for tx in expenses {
                grouped[tx.category, default: 0.0] += tx.amount
            }
            
            if let topCat = grouped.max(by: { $0.value < $1.value }), totalExp > 0 {
                let pct = Int(round((topCat.value / totalExp) * 100))
                if pct >= 35 {
                    advice += "1. **Atención focalizada en \(topCat.key)**: Concentra el **\(pct)%** de tus gastos en '\(walletLabel)'. Establece un tope semanal para esta categoría para liberar liquidez de inmediato.\n"
                } else {
                    advice += "1. **Aplica la regla 50/30/20**: Destina el 50% a necesidades básicas, 30% a gastos personales y 20% a tu fondo de ahorro.\n"
                }
            } else {
                advice += "1. **Fija una meta de ahorro**: Separa un porcentaje fijo apenas recibas un ingreso en '\(walletLabel)', antes de empezar a gastar.\n"
            }
            
            advice += "2. **Evita gastos hormiga**: Las pequeñas compras diarias (cafés, snacks, taxis no planificados) suelen sumar montos considerables a fin de mes.\n"
            advice += "3. **Aplica la regla de las 24 horas**: Ante compras no indispensables, espera un día antes de pagar para confirmar si realmente lo necesitas."
            
            return .answer(advice)
        }
        
        // 6. DETECCIÓN DE CONVERSACIÓN COTIDIANA (SALUDOS, PRESENTACIÓN, AFIRMACIONES, DESPEDIDAS)
        if let conversationalResponse = detectConversationalIntent(
            norm: norm,
            query: query,
            targetTransactions: targetTransactions,
            wallets: wallets,
            summary: summary,
            scopeText: scopeText,
            currentScopeBalance: currentScopeBalance
        ) {
            return conversationalResponse
        }
        
        // 7. SIMULACIÓN DE COMPRA / ¿ME ALCANZA PARA...?
        if norm.contains("alcanza") || norm.contains("puedo comprar") || norm.contains("puedo gastar") || norm.contains("tengo para") {
            if let amountToSpend = extractAmountFromText(query) {
                let bal = currentScopeBalance
                let sym = summary.currencySymbol
                let formattedAmt = FormatHelper.formatCurrency(amountToSpend)
                let formattedBal = FormatHelper.formatCurrency(bal)
                
                if bal >= amountToSpend {
                    let remaining = bal - amountToSpend
                    let formattedRem = FormatHelper.formatCurrency(remaining)
                    let safetyThreshold = bal * 0.20
                    
                    if remaining >= safetyThreshold {
                        return .answer(
                            """
                            ✅ **Sí, tienes saldo suficiente.**
                            
                            • Saldo disponible actual: **\(sym) \(formattedBal)**
                            • Compra estimada: **\(sym) \(formattedAmt)**
                            • Saldo restante luego de la compra: **\(sym) \(formattedRem)**
                            
                            Tu fondo de respaldo queda en un nivel saludable (mayor al 20% de tu saldo total).
                            """
                        )
                    } else {
                        return .answer(
                            """
                            ⚠️ **Puedes pagarlo, pero tu saldo quedará ajustado.**
                            
                            • Saldo disponible actual: **\(sym) \(formattedBal)**
                            • Compra estimada: **\(sym) \(formattedAmt)**
                            • Saldo restante: **\(sym) \(formattedRem)**
                            
                            Quedarías con menos del 20% de tu dinero disponible. Te sugiero evaluar si es un gasto indispensable o si puedes aplazarlo.
                            """
                        )
                    }
                } else {
                    let deficit = amountToSpend - bal
                    let formattedDeficit = FormatHelper.formatCurrency(deficit)
                    return .answer(
                        """
                        ❌ **Actualmente no tienes suficiente saldo.**
                        
                        • Saldo disponible: **\(sym) \(formattedBal)**
                        • Monto de la compra: **\(sym) \(formattedAmt)**
                        • Te faltan: **\(sym) \(formattedDeficit)**
                        
                        Considera transferir fondos desde otra billetera o priorizar tus gastos principales.
                        """
                    )
                }
            }
        }
        
        // 8. CONSULTAS DE CATEGORÍAS ESPECÍFICAS (Comida, Transporte, etc.)
        if let matchedCategory = detectSpecificCategoryQuery(norm) {
            let catTransactions = targetTransactions.filter { tx in
                tx.type == .expense && (CategoryHelper.normalize(tx.category).lowercased() == matchedCategory.lowercased() || CategoryHelper.normalize(tx.title).lowercased().contains(matchedCategory.lowercased()))
            }
            
            let totalCatExpense = catTransactions.reduce(0.0) { $0 + $1.amount }
            let sym = summary.currencySymbol
            
            if catTransactions.isEmpty {
                return .answer("No registras gastos en la categoría **\(matchedCategory.capitalized)** \(scopeText) hasta el momento.")
            }
            
            var detail = "📂 **Gastos en \(matchedCategory.capitalized) (\(scopeText)):**\n\n"
            detail += "• Total gastado: **\(sym) \(FormatHelper.formatCurrency(totalCatExpense))** en **\(catTransactions.count) movimientos**.\n\n"
            detail += "Movimientos recientes:\n"
            
            for tx in catTransactions.sorted(by: { $0.dateMillis > $1.dateMillis }).prefix(4) {
                let dStr = FormatHelper.formatDate(tx.dateMillis)
                detail += "• \(dStr): **\(sym) \(FormatHelper.formatCurrency(tx.amount))** ('\(tx.title)')\n"
            }
            return .answer(detail)
        }
        
        // 8.5 CONSULTA DE MAYOR INGRESO (GLOBAL O POR CUENTA)
        let isTopIncomeQuery = (norm.contains("mayor") || norm.contains("mas alto") || norm.contains("mas grande") || norm.contains("top")) &&
                               (norm.contains("ingreso") || norm.contains("sueldo") || norm.contains("salario") || norm.contains("cobro") || norm.contains("ganancia"))
        if isTopIncomeQuery {
            let incomes = targetTransactions.filter { $0.type == .income }
            let sym = summary.currencySymbol
            
            if incomes.isEmpty {
                let globalIncomes = allTransactions.filter { $0.type == .income }
                if let topGlobal = globalIncomes.max(by: { $0.amount < $1.amount }) {
                    let dStr = FormatHelper.formatDate(topGlobal.dateMillis)
                    let wName = wallets.first(where: { $0.id == topGlobal.walletId })?.name ?? "Billetera"
                    return .answer(
                        """
                        💰 **Mayor Ingreso:**
                        
                        No registras ingresos en \(scopeText).
                        
                        Sin embargo, tu mayor ingreso registrado en MoneyDev es de **\(sym) \(FormatHelper.formatCurrency(topGlobal.amount))** (*'\(topGlobal.title)'* — \(topGlobal.category)) en tu cuenta '**\(wName)**' el \(dStr).
                        """
                    )
                }
                return .answer("💰 **Mayor Ingreso (\(scopeText)):**\n\nNo registras ingresos aún \(scopeText).")
            }
            
            let sortedIncomes = incomes.sorted { $0.amount > $1.amount }
            if let topInc = sortedIncomes.first {
                let dStr = FormatHelper.formatDate(topInc.dateMillis)
                let wName = wallets.first(where: { $0.id == topInc.walletId })?.name ?? "Billetera"
                var response = "💰 **Tu mayor ingreso registrado \(scopeText) es:**\n\n"
                response += "• Monto: **\(sym) \(FormatHelper.formatCurrency(topInc.amount))**\n"
                response += "• Concepto: **'\(topInc.title)'**\n"
                response += "• Categoría: **\(topInc.category)**\n"
                response += "• Fecha: **\(dStr)**\n"
                response += "• Cuenta: **\(wName)**\n"
                
                if sortedIncomes.count > 1 {
                    response += "\n📈 **Otros ingresos destacados:**\n"
                    for (idx, inc) in sortedIncomes.dropFirst().prefix(3).enumerated() {
                        let iDate = FormatHelper.formatDate(inc.dateMillis)
                        response += "\(idx + 2). **\(sym) \(FormatHelper.formatCurrency(inc.amount))** • '\(inc.title)' (\(iDate))\n"
                    }
                }
                let totalAllInc = incomes.reduce(0.0) { $0 + $1.amount }
                response += "\n**Total acumulado de ingresos:** **\(sym) \(FormatHelper.formatCurrency(totalAllInc))**."
                return .answer(response)
            }
        }
        
        // 9. INGRESOS
        if norm.contains("ingreso") || norm.contains("gane") || norm.contains("ganancias") || norm.contains("sueldo") || norm.contains("salario") {
            let incomes = targetTransactions.filter { $0.type == .income }
            let totalInc = incomes.reduce(0.0) { $0 + $1.amount }
            
            if incomes.isEmpty {
                return .answer("No registras ingresos aún \(scopeText). Puedes registrar tu salario o transferencias tocando el botón de '+'.")
            }
            
            var response = "💰 **Resumen de Ingresos (\(scopeText)):**\n\n"
            response += "• Total generado: **\(summary.currencySymbol) \(FormatHelper.formatCurrency(totalInc))** en **\(incomes.count) entradas**.\n\n"
            response += "Ingresos recientes:\n"
            for tx in incomes.sorted(by: { $0.dateMillis > $1.dateMillis }).prefix(3) {
                response += "• **\(summary.currencySymbol) \(FormatHelper.formatCurrency(tx.amount))**: '\(tx.title)' (\(FormatHelper.formatDate(tx.dateMillis)))\n"
            }
            return .answer(response)
        }
        
        // 10. INTENTO CON GEMINI API (SI ESTÁ DISPONIBLE)
        var apiKey = EnvConfig.geminiApiKey
        if apiKey.isEmpty {
            apiKey = MoneyBotAIService.shared.apiKey
        }
        if !apiKey.isEmpty {
            do {
                let geminiAnswer = try await callGeminiAssistant(
                    query: query,
                    transactions: targetTransactions,
                    allTransactions: allTransactions,
                    wallets: wallets,
                    currentScopeBalance: currentScopeBalance,
                    currencySymbol: summary.currencySymbol,
                    scopeText: scopeText,
                    apiKey: apiKey
                )
                if !geminiAnswer.isEmpty {
                    // Limpieza estricta de asteriscos huérfanos o cuádruples
                    let cleanAnswer = geminiAnswer
                        .replacingOccurrences(of: "****", with: "")
                        .replacingOccurrences(of: "***", with: "**")
                    return .answer(cleanAnswer)
                }
            } catch {
                print("FinancialAiAssistantEngine: Fallo de Gemini API: \(error.localizedDescription)")
            }
        }
        
        // Fallback inteligente cuando la consulta no coincide con finanzas y Gemini no está disponible
        return .answer(
            """
            En este momento no pude conectar con el servicio de IA de Gemini (verifica tu conexión a internet o intenta de nuevo).

            ¡Sin embargo, puedo registrar tus gastos e ingresos al instante, hacer transferencias por voz y reportarte tus saldos y categorías en modo local! ¿En qué te puedo ayudar?
            """
        )
    }
    
    // MARK: - NLP Comprensivo para Expresiones Cotidianas y Fuera de la App
    private static func detectConversationalIntent(
        norm: String,
        query: String,
        targetTransactions: [Transaction],
        wallets: [Wallet],
        summary: FinancialSummary,
        scopeText: String,
        currentScopeBalance: Double
    ) -> FinancialAiResponse? {
        let words = Set(norm.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)).filter { !$0.isEmpty })
        
        // 0. CHISTES Y BROMAS ("DIME UN CHISTE", "CUÉNTAME UN CHISTE", "BROMA", ETC.)
        if norm.contains("chiste") || norm.contains("broma") || norm.contains("hazme reir") || norm.contains("cuentame un chiste") || norm.contains("dime un chiste") {
            // Si Gemini está disponible, permitir que Gemini genere un chiste único y fresco
            if !EnvConfig.geminiApiKey.isEmpty {
                return nil
            }
            
            // Catálogo variado de chistes para modo offline
            let offlineJokes = [
                "— Papá, ¿qué es la inflación?\n— Hijo, ¿te acuerdas de cuando eras pequeño y te daba 1 sol para comprar dulces?\n— Sí...\n— ¡Pues hoy ese sol solo alcanza para recordar cuando te daba 1 sol! 😂\n\n¡Pero no te preocupes, en MoneyDev tus finanzas están seguras! 📊",
                "¿Por qué los pájaros no usan bancos? ¡Porque tienen sus propios fondos en las ramas! 🐦😄",
                "— Amor, ¿cuánto me amas del 1 al 10?\n— Como mi saldo a fin de mes...\n— ¿Mucho?\n— ¡No, casi nada! 😭😂\n\n¡Menos mal aquí en MoneyDev tenemos tu saldo bajo control! 🚀",
                "Mi billetera es como una cebolla... ¡cada vez que la abro me dan ganas de llorar! 🧅😂",
                "— Doctor, tengo un problema con el dinero.\n— ¿Qué le pasa?\n— ¡Que entra por mis manos y sale volando! 💸💨\n\n¡Por eso es clave registrar cada movimiento aquí en MoneyDev! 😉",
                "— ¿Cuál es el colmo de un economista?\n— Perder el interés... ¡hasta por su propia pareja! 📈🤣"
            ]
            let joke = offlineJokes.randomElement() ?? offlineJokes[0]
            return .answer("😄 \(joke)")
        }
        
        // 0.1 SALUDOS A TERCEROS O AMIGOS ("MANDA SALUDOS A PEDRO", "QUIERO QUE MANDES SALUDOS A MI AMIGO MAURICIO", ETC.)
        let thirdPartyGreetingPattern = #"(?i)^.*?\b(?:manda(?:le)?\s+saludos|saluda|saludos|mandes?\s+saludos|un\s+saludo)\s+(?:a|al)\s+(?:mi\s+amig[oa]\s+|amig[oa]\s+)?"#
        if let regex = try? NSRegularExpression(pattern: thirdPartyGreetingPattern),
           let match = regex.firstMatch(in: query, options: [], range: NSRange(location: 0, length: (query as NSString).length)) {
            let prefixRange = match.range(at: 0)
            var friendName = (query as NSString).replacingCharacters(in: prefixRange, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            friendName = friendName.trimmingCharacters(in: CharacterSet(charactersIn: ".,:;!?¡¿\"'"))
            
            let friendLower = friendName.lowercased()
            let friend: String
            if friendName.isEmpty || friendLower == "mi amigo" || friendLower == "a mi amigo" {
                friend = "tu amigo"
            } else if friendLower == "mi amiga" || friendLower == "a mi amiga" {
                friend = "tu amiga"
            } else {
                friend = friendName
            }
            return .answer("¡Un gran saludo para \(friend)! 👋 Espero que tenga un excelente día. Y aquí seguimos cuidando tus finanzas en MoneyDev. 🚀")
        }
        
        // 0.2 CONVERSACIÓN ABIERTA ("CUÉNTAME", "DIME ALGO", "HÁBLAME")
        if norm == "cuentame" || norm == "cuéntame" || norm == "dime algo" || norm == "cuentame algo" || norm == "hablame" || norm == "habla" {
            return .answer("¡Con gusto! 😊 Puedo contarte un chiste, darte un tip para ahorrar este mes, o decirte exactamente cuánto saldo y qué gastos tienes registrados. ¿De qué te gustaría hablar?")
        }
        
        // 1. SALUDOS COTIDIANOS Y PRESENTACIÓN NATURAL ("HOLA", "BUENAS TARDES", "CÓMO ESTÁS", "QUÉ TAL", ETC.)
        let greetingWordSet: Set<String> = ["hola", "buenas", "hey", "alo", "wena", "wenas", "hi", "hello"]
        let hasGreetingWord = !words.isDisjoint(with: greetingWordSet)
        let isGreeting = hasGreetingWord ||
                         norm.contains("buen dia") || norm.contains("buenos dias") ||
                         norm.contains("buenas tardes") || norm.contains("buenas noches") ||
                         norm.contains("que tal") || norm.contains("como estas") ||
                         norm.contains("como te va") || norm.contains("como andas") ||
                         (words.contains("saludos") && !norm.contains("saludos a") && !norm.contains("manda saludos"))
        
        if isGreeting {
            let greetingWord: String
            if norm.contains("buenas tardes") {
                greetingWord = "¡Buenas tardes! 👋"
            } else if norm.contains("buenos dias") || norm.contains("buen dia") {
                greetingWord = "¡Buenos días! ☀️"
            } else if norm.contains("buenas noches") {
                greetingWord = "¡Buenas noches! 🌙"
            } else if norm.contains("que tal") {
                greetingWord = "¡Hola, qué tal! 👋"
            } else {
                greetingWord = "¡Hola! 👋"
            }
            
            let asksHowAreYou = norm.contains("como estas") || norm.contains("como te va") || norm.contains("como andas") || norm.contains("que tal estas")
            
            let statusText = asksHowAreYou ?
                "¡Todo excelente por aquí y listo para ayudarte! " :
                "¡Qué gusto saludarte! "
            
            let presentation = "\(greetingWord) \(statusText)Soy **MoneyBot**, tu asistente para registrar tus movimientos y consultar tus cuentas. ¿Qué deseas hacer hoy?"
            
            return .answer(presentation)
        }
        
        // 2. AFIRMACIONES Y CONFIRMACIONES ("SI", "SÍ", "CLARO", "DALE", ETC.)
        let affirmations = ["si", "sí", "claro", "por supuesto", "de acuerdo", "dale", "afirmativo", "exacto", "correcto", "ok", "okay", "vale", "listo", "yes", "sisi", "dale con todo", "seguro", "obvio", "va", "pos claro", "vamos", "procede", "confirmo", "afirmo", "de una"]
        if affirmations.contains(where: { norm == $0 || words.contains($0) }) {
            return .answer("¡Excelente! 👍 Dime qué movimiento quieres registrar o qué saldo deseas consultar.")
        }
        
        // 3. NEGACIONES Y DESPEDIDAS TEMPORALES ("NO", "LUEGO", ETC.)
        let negations = ["no", "nop", "para nada", "negativo", "luego", "despues", "nada", "no gracias", "por ahora no", "deja nomas", "ninguno", "jamas", "despues lo hago", "mas tarde", "otro dia", "descartar", "nel"]
        if negations.contains(where: { norm == $0 || words.contains($0) }) {
            return .answer("Entendido, sin problema 👍. Estaré por aquí cuando gustes registrar un movimiento o revisar tus cuentas.")
        }
        
        // 4. AGRADECIMIENTOS ("GRACIAS", ETC.)
        let gratitudes = ["gracias", "muchas gracias", "te lo agradezco", "mil gracias", "grx", "agradecido", "gracias bot", "gracias amigo", "muchisimas gracias", "genial gracias"]
        if gratitudes.contains(where: { norm.contains($0) }) || words.contains("gracias") || words.contains("grx") {
            return .answer("¡Con todo gusto! 🌟 Si necesitas registrar otro movimiento o consultar tu saldo, solo avísame.")
        }
        
        // 5. DE NADA / CORDIALIDAD
        let politeReturns = ["de nada", "no hay de que", "a la orden", "por nada", "un placer"]
        if politeReturns.contains(where: { norm.contains($0) }) {
            return .answer("¡Genial! Seguimos atentos a tus números y tu progreso financiero. 🚀")
        }
        
        // 6. DESPEDIDAS ("CHAU", "ADIOS", ETC.)
        let farewells = ["adios", "chau", "chao", "hasta luego", "nos vemos", "bye", "cuidate", "hasta mañana", "bye bye", "me voy", "hasta pronto", "buenas noches"]
        if farewells.contains(where: { norm == $0 || norm.contains($0) }) {
            return .answer(
                """
                ¡Hasta pronto! 👋 Tus movimientos y saldos quedan totalmente seguros y organizados aquí en MoneyDev.
                
                ¡Mucho éxito en tu día!
                """
            )
        }
        
        // 7. IDENTIDAD / PROPÓSITO
        if norm.contains("quien eres") || norm.contains("que haces") || norm.contains("para que sirves") ||
           norm.contains("como te llamas") || norm.contains("que eres") || norm.contains("como funcionas") ||
           norm.contains("quien te creo") {
            return .answer(
                """
                Soy **MoneyBot** 🤖, tu asistente financiero inteligente integrado en MoneyDev.
                
                🧠 **¿En qué puedo ayudarte?**
                • **Dictado por voz y texto**: Escribe o dicta con lenguaje natural (ej: *"Gasté 18 en taxi"* o *"Cobré 800 de honorarios"*).
                • **Control de saldos**: Consulta en tiempo real cuánto dinero tienes en cada billetera o en total.
                • **Análisis de gastos**: Te muestro en qué categorías gastas más y dónde se va tu dinero.
                • **Simulación de compras**: Dime *"¿Me alcanza para algo de 120 soles?"* y evalúo tu presupuesto.
                • **Tips de ahorro**: Pídeme consejos para ahorrar, salir de deudas o aplicar la regla 50/30/20.
                """
            )
        }
        
        // 8. ESTADO DE ÁNIMO Y CONVERSACIÓN DIARIA
        if norm.contains("como estas") || norm.contains("que tal tu dia") || norm.contains("como te va") || norm.contains("todo bien") {
            return .answer(
                """
                ¡Todo excelente por aquí! 🤖 Con los números al día y muchas ganas de ayudarte a alcanzar tus metas de ahorro.
                
                ¿Deseas consultar tu saldo o registrar algún gasto de hoy?
                """
            )
        }
        if norm.contains("triste") || norm.contains("bajoneado") || norm.contains("deprimido") || norm.contains("estresado") || norm.contains("cansado") || norm.contains("aburrido") {
            return .answer(
                """
                Te entiendo, hay días difíciles. Mantener el orden en tus finanzas y saber que tienes el control de tu dinero te dará mucha paz mental.
                
                ¡Respira profundo, da un paso a la vez y cuenta conmigo para facilitarte las cuentas! 💪
                """
            )
        }
        if norm.contains("feliz") || norm.contains("contento") || norm.contains("motivado") || norm.contains("alegre") {
            return .answer("¡Me alegra muchísimo saberlo! 🎉 La buena vibra y la constancia financiera te llevarán muy lejos.")
        }
        if norm.contains("hambre") || norm.contains("almorzar") || norm.contains("cenar") || norm.contains("desayunar") || norm.contains("que como") {
            return .answer(
                """
                ¡Buen provecho! 🍽️ Recuerda que luego puedes dictar tu consumo y lo guardaré al instante en **Alimentación**.
                """
            )
        }
        
        // 9. ELOGIOS A LA APP
        if norm.contains("buena app") || norm.contains("excelente app") || norm.contains("crack") || norm.contains("genial") || norm.contains("increible") || norm.contains("buen trabajo") || norm.contains("me gusta") || norm.contains("top") {
            return .answer("¡Muchas gracias por tu apoyo! ❤️ En MoneyDev seguimos trabajando para darte la app de finanzas más ágil y completa.")
        }
        
        // 10. FECHA Y HORA
        if norm.contains("que hora es") || norm.contains("que fecha es") || norm.contains("que dia es hoy") || norm.contains("fecha actual") {
            let df = DateFormatter()
            df.timeZone = FixedExpenseDateHelper.peruTimeZone
            df.dateStyle = .full
            df.timeStyle = .short
            let nowStr = df.string(from: Date())
            return .answer("🗓️ Actualmente es **\(nowStr)** (Hora de Perú). ¿Deseas consultar los movimientos de hoy?")
        }
        
        // 11. CHISTE FINANCIERO
        if norm.contains("chiste") || norm.contains("broma") || norm.contains("hazme reir") {
            return .answer(
                """
                😄 Aquí va un chiste financiero:
                — Papá, ¿qué es la inflación?
                — Hijo, ¿te acuerdas de cuando eras pequeño y te daba 1 sol para comprar dulces?
                — Sí...
                — ¡Pues hoy ese sol solo alcanza para recordar cuando te daba 1 sol! 😂
                
                ¡Pero no te preocupes, en MoneyDev tus ahorros y gastos están siempre bajo control! 📊
                """
            )
        }
        
        // 12. EDUCACIÓN FINANCIERA (50/30/20, deudas, fondo de emergencia, etc.)
        if norm.contains("50/30/20") || norm.contains("regla 50") || norm.contains("metodo 50") {
            return .answer(
                """
                📐 **La Regla 50/30/20:**
                
                Es una fórmula recomendada para organizar tus ingresos:
                • **50% Necesidades**: Comida, alquiler, servicios, transporte y salud.
                • **30% Deseos**: Salidas, compras personales, gustos y entretenimiento.
                • **20% Ahorro e Inversión**: Fondo de emergencias y crecimiento financiero.
                """
            )
        }
        if norm.contains("gasto hormiga") || norm.contains("gastos hormiga") {
            return .answer(
                """
                🐜 **¿Qué son los Gastos Hormiga?**
                
                Son consumos diarios pequeños (cafés, snacks, golosinas o suscripciones que no usas), que pueden sumar entre **S/ 150 y S/ 400 soles mensuales** sin darte cuenta.
                
                💡 **Consejo**: Anótalos todos en MoneyDev. Al ver la suma acumulada a fin de mes, podrás reducir fácilmente los que no necesitas.
                """
            )
        }
        if norm.contains("fondo de emergencia") || norm.contains("emergencia") {
            return .answer(
                """
                🛡️ **Fondo de Emergencia:**
                
                Es un colchón de dinero reservado únicamente para imprevistos (salud, reparaciones del hogar, desempleo).
                
                • **Meta ideal**: Guardar entre 3 y 6 meses de tus gastos fijos indispensables.
                • Puedes crear una billetera llamada *'Fondo de Emergencia'* en MoneyDev para separarlo de tu saldo diario.
                """
            )
        }
        if norm.contains("deuda") || norm.contains("deudas") || norm.contains("salir de deudas") {
            return .answer(
                """
                💳 **Estrategias para Salir de Deudas:**
                
                1. **Método Bola de Nieve**: Paga el mínimo de todas tus deudas y destina todo el dinero extra a liquidar la de menor saldo primero.
                2. **Método Avalancha**: Destina los pagos extras a la deuda con mayor tasa de interés (como tarjetas de crédito).
                3. **Evita endeudarte para gastos de consumo corriente**.
                """
            )
        }
        
        return nil
    }
    
    // MARK: - Helpers de Extracción y Detección
    private static func extractAmountFromText(_ text: String) -> Double? {
        let pattern = #"(?:S\/?|\$|€|soles|usd)?\s*(\d+(?:[.,]\d{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        for match in matches {
            if let range = Range(match.range(at: 1), in: text) {
                let sub = String(text[range]).replacingOccurrences(of: ",", with: ".")
                if let val = Double(sub), val > 0 {
                    return val
                }
            }
        }
        return nil
    }
    
    private static func detectSpecificCategoryQuery(_ query: String) -> String? {
        let lower = query.lowercased()
        if lower.contains("comida") || lower.contains("alimentacion") || lower.contains("almuerzo") || lower.contains("cena") || lower.contains("restaurante") || lower.contains("mercado") || lower.contains("supermercado") {
            return "Alimentación"
        }
        if lower.contains("transporte") || lower.contains("taxi") || lower.contains("uber") || lower.contains("pasaje") || lower.contains("gasolina") || lower.contains("combustible") {
            return "Transporte"
        }
        if lower.contains("servicio") || lower.contains("luz") || lower.contains("agua") || lower.contains("internet") || lower.contains("telefono") || lower.contains("recibo") {
            return "Servicios"
        }
        if lower.contains("salud") || lower.contains("farmacia") || lower.contains("medicina") || lower.contains("doctor") || lower.contains("consulta") {
            return "Salud"
        }
        if lower.contains("entretenimiento") || lower.contains("cine") || lower.contains("juegos") || lower.contains("salida") || lower.contains("fiesta") {
            return "Entretenimiento"
        }
        if lower.contains("ropa") || lower.contains("calzado") || lower.contains("compras") || lower.contains("tienda") {
            return "Compras"
        }
        if lower.contains("educacion") || lower.contains("curso") || lower.contains("universidad") || lower.contains("colegio") || lower.contains("libro") {
            return "Educación"
        }
        return nil
    }
    
    // MARK: - Evaluación Matemática y Cálculos Aritméticos
    private static func evaluateMathQuery(
        norm: String,
        query: String,
        activeWalletName: String,
        currencySymbol: String
    ) -> FinancialAiResponse? {
        let cleaned = norm
            .replacingOccurrences(of: "¿", with: "")
            .replacingOccurrences(of: "?", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Porcentajes: ej: "el 18% de 500", "cuánto es el 18 por ciento de 500", "calcula 10% de 200"
        let percentPattern = #"(?i)\b(?:cu[aá]nto\s+es\s+|calcula\s+|cu[aá]l\s+es\s+)?(?:el\s+)?([0-9]+(?:\.[0-9]+)?)\s*(?:%|por\s+ciento)\s*(?:de\s+)?([0-9]+(?:\.[0-9]+)?)\b"#
        if let regex = try? NSRegularExpression(pattern: percentPattern),
           let match = regex.firstMatch(in: cleaned, options: [], range: NSRange(location: 0, length: (cleaned as NSString).length)) {
            let nsStr = cleaned as NSString
            let pctStr = nsStr.substring(with: match.range(at: 1))
            let totalStr = nsStr.substring(with: match.range(at: 2))
            
            if let pct = Double(pctStr), let total = Double(totalStr) {
                let result = (pct / 100.0) * total
                let formattedResult: String = (result.truncatingRemainder(dividingBy: 1) == 0) ? "\(Int(result))" : String(format: "%.2f", result)
                let pctFormatted: String = (pct.truncatingRemainder(dividingBy: 1) == 0) ? "\(Int(pct))" : String(format: "%.2f", pct)
                let totalFormatted: String = (total.truncatingRemainder(dividingBy: 1) == 0) ? "\(Int(total))" : String(format: "%.2f", total)
                
                let text = "El \(pctFormatted)% de \(totalFormatted) es **\(formattedResult)**. ¿Deseas registrar este monto como un movimiento o consultar tu saldo en '\(activeWalletName)'?"
                return .answer(text)
            }
        }
        
        // 2. Operaciones Aritméticas Básicas: Suma, Resta, Multiplicación, División
        // Cubre: "cuánto es 5 x 45", "5 × 45", "5 * 45", "5 por 45", "5 + 35", "5 más 35", "100 - 25", "100 menos 25", "120 / 4", "120 entre 4"
        let mathPattern = #"(?i)\b(?:cu[aá]nto\s+es\s+|calcula\s+|cu[aá]l\s+es\s+|cu[aá]nto\s+ser[ií]a\s+)?([0-9]+(?:\.[0-9]+)?)\s*([\+\-\*\/xX×÷]|m[aá]s|menos|por|entre)\s*([0-9]+(?:\.[0-9]+)?)\b"#
        if let regex = try? NSRegularExpression(pattern: mathPattern),
           let match = regex.firstMatch(in: cleaned, options: [], range: NSRange(location: 0, length: (cleaned as NSString).length)) {
            let nsStr = cleaned as NSString
            let num1Str = nsStr.substring(with: match.range(at: 1))
            let opRaw = nsStr.substring(with: match.range(at: 2)).lowercased().trimmingCharacters(in: .whitespaces)
            let num2Str = nsStr.substring(with: match.range(at: 3))
            
            if let n1 = Double(num1Str), let n2 = Double(num2Str) {
                let result: Double
                let symbol: String
                
                if opRaw == "+" || opRaw.contains("mas") || opRaw.contains("más") {
                    result = n1 + n2
                    symbol = "+"
                } else if opRaw == "-" || opRaw.contains("menos") {
                    result = n1 - n2
                    symbol = "-"
                } else if opRaw == "*" || opRaw == "x" || opRaw == "×" || opRaw.contains("por") {
                    result = n1 * n2
                    symbol = "×"
                } else if opRaw == "/" || opRaw == "÷" || opRaw.contains("entre") {
                    guard n2 != 0 else {
                        return .answer("⚠️ No es posible dividir entre cero. ¿Deseas consultar tu saldo o registrar algún gasto?")
                    }
                    result = n1 / n2
                    symbol = "÷"
                } else {
                    return nil
                }
                
                let resStr: String = (result.truncatingRemainder(dividingBy: 1) == 0) ? "\(Int(result))" : String(format: "%.2f", result)
                let n1Str: String = (n1.truncatingRemainder(dividingBy: 1) == 0) ? "\(Int(n1))" : String(format: "%.2f", n1)
                let n2Str: String = (n2.truncatingRemainder(dividingBy: 1) == 0) ? "\(Int(n2))" : String(format: "%.2f", n2)
                
                let text = "\(n1Str) \(symbol) \(n2Str) es **\(resStr)**. ¿Deseas registrar este monto como un movimiento o consultar tu saldo en '\(activeWalletName)'?"
                return .answer(text)
            }
        }
        
        return nil
    }
    
    // MARK: - Gemini Assistant API
    private static func callGeminiAssistant(
        query: String,
        transactions: [Transaction],
        allTransactions: [Transaction] = [],
        wallets: [Wallet] = [],
        currentScopeBalance: Double,
        currencySymbol: String,
        scopeText: String,
        apiKey: String
    ) async throws -> String {
        let txSample = transactions.prefix(25).map { tx in
            "[\(tx.type.rawValue)] \(tx.category): \(tx.amount) - '\(tx.title)'"
        }.joined(separator: "\n")
        
        let walletsDesglose = wallets.map { w in
            let wTxs = allTransactions.filter { $0.walletId == w.id }
            let inc = wTxs.filter { $0.type == .income }.reduce(0.0) { $0 + $1.amount }
            let exp = wTxs.filter { $0.type == .expense }.reduce(0.0) { $0 + $1.amount }
            let bal = max(0.0, w.initialBalance + inc - exp)
            return "\(w.name): \(currencySymbol) \(FormatHelper.formatCurrency(bal)) (\(wTxs.count) movimientos)"
        }.joined(separator: ", ")
        
        let systemPrompt = """
        Eres MoneyBot, un asistente financiero inteligente, simpático, conciso y analítico para la app MoneyDev.
        El usuario está consultando \(scopeText).
        Saldo disponible en este alcance: \(currencySymbol) \(FormatHelper.formatCurrency(currentScopeBalance))
        Total de cuentas activas registradas: \(wallets.count) cuentas.
        Desglose de cuentas y saldos: [\(walletsDesglose)]
        Movimientos recientes:
        \(txSample)
        
        PAUTAS IMPORTANTES:
        1. Si el usuario te saluda (ej: 'hola', 'buenas tardes', 'buenos días', 'cómo estás', 'qué tal'), responde amablemente devolviendo el saludo correspondiente (ej: si dice buenas tardes, responde ¡Buenas tardes!), contesta cómo estás y preséntate brevemente como MoneyBot de forma muy natural.
        2. Si el usuario consulta sobre saldo o balance (ej: 'cuánto saldo tengo', 'cuánto dinero tengo'), responde de manera puntual y directa diciendo únicamente el saldo disponible. NO incluyas listas ni resúmenes no solicitados de ingresos o gastos a menos que el usuario pida expresamente 'más detalles' o 'resumen detallado'.
        3. Si el usuario consulta sobre gastos, categorías o compras, responde basándote ESTRICTAMENTE en los datos de \(scopeText).
        4. Responde en español con formato Markdown limpio, usando viñetas y negritas correctas (**palabra**). NUNCA generes secuencias vacías de asteriscos como **** o asteriscos huérfanos.
        5. Sé muy conversacional y conciso: responde en 1 a 3 oraciones claras, fluidas y directas, evitando textos excesivos, rodeos o listas abultadas, ideal para una experiencia auditiva fluida como en Gemini Live.
        6. PERSONALIDAD, PREGUNTAS GENERALES Y CONVERSACIÓN: Eres un asistente con inteligencia artificial avanzada. Si el usuario te hace cualquier pregunta general de ciencia, historia, geografía, cultura, matemáticas, curiosidades, chistes o saludos, respóndela de forma completa, precisa, elocuente y amigable. NO incluyas coletillas forzadas sobre finanzas si la pregunta no era financiera.
        7. CUENTAS ACTIVAS Y CUENTAS MÁS USADAS: Si el usuario pregunta cuántas cuentas tiene activas, sus nombres, sus saldos o cuál es su cuenta más usada, responde usando la lista de cuentas activas y menciona cuál tiene más movimientos y actividad.
        8. MAYOR INGRESO Y CATEGORÍAS MÁS ALTAS / BAJAS: Si pregunta cuál es su mayor ingreso en general o en una cuenta, o en qué categoría gasta más o menos, responde con los datos numéricos exactos de sus movimientos.
        """
        
        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "\(systemPrompt)\n\nPregunta del usuario: \"\(query)\""]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 800
            ]
        ]
        
        let httpBody = try JSONSerialization.data(withJSONObject: payload)
        var lastError: Error? = nil
        
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
                let rawText = textParts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !rawText.isEmpty else { continue }
                
                return rawText
            } catch {
                lastError = error
                continue
            }
        }
        
        if let lastError {
            throw lastError
        }
        return ""
    }
}
