import Foundation
import SwiftData

@MainActor
public final class ExpenseRepository {
    public static let official20ProCodes: Set<String> = [
        "MON-EYD-EVX",
        "PRO-FIN-ANZ",
        "PRE-MIU-MOK",
        "DEV-MAS-TER",
        "SUP-ERP-ROA",
        "VIP-ACC-ESS",
        "LIF-ETI-MEZ",
        "WAL-LET-TEN",
        "COL-ORT-HEM",
        "VOI-CEI-AAI",
        "EXC-LUS-IVE",
        "MON-EYP-ROB",
        "APP-SUP-POR",
        "CRE-ATO-RPL",
        "FIN-ANC-EPR",
        "ULT-IMA-TEK",
        "GOL-DEN-KEY",
        "PRO-VER-SIO",
        "BES-TUS-ERX",
        "MND-EVT-EAM"
    ]
    
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }
    
    private let defaults = UserDefaults.standard
    
    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        migrateTransactionsCategoriesIfNeeded()
    }
    
    /// Migra transacciones existentes en base de datos con categorías no canónicas (ej: "Comida") a su categoría predefinida oficial ("Alimentación")
    public func migrateTransactionsCategoriesIfNeeded() {
        CategoryHelper.purgeInvalidCustomCategories()
        let descriptor = FetchDescriptor<Transaction>()
        guard let allTransactions = try? modelContext.fetch(descriptor) else { return }
        var hasChanges = false
        for tx in allTransactions {
            let canonical = CategoryHelper.resolveCategory(nameOrKeyword: tx.category, type: tx.type)
            if tx.category != canonical {
                tx.category = canonical
                hasChanges = true
            }
        }
        if hasChanges {
            try? modelContext.save()
        }
    }
    
    // MARK: - UserDefaults Caching (Equivalent to Android SharedPreferences)
    
    public func isProUserCached() -> Bool {
        defaults.bool(forKey: "key_is_pro_user")
    }
    
    public func setProUserCached(_ isPro: Bool) {
        defaults.set(isPro, forKey: "key_is_pro_user")
    }
    
    public func isWalletsExpanded() -> Bool {
        if defaults.object(forKey: "key_wallets_expanded") == nil { return true }
        return defaults.bool(forKey: "key_wallets_expanded")
    }
    
    public func setWalletsExpanded(_ expanded: Bool) {
        defaults.set(expanded, forKey: "key_wallets_expanded")
    }
    
    public func isMainActionsExpanded() -> Bool {
        if defaults.object(forKey: "key_main_actions_expanded") == nil { return true }
        return defaults.bool(forKey: "key_main_actions_expanded")
    }
    
    public func setMainActionsExpanded(_ expanded: Bool) {
        defaults.set(expanded, forKey: "key_main_actions_expanded")
    }
    
    public func isSettingsExpanded() -> Bool {
        if defaults.object(forKey: "key_settings_expanded") == nil { return true }
        return defaults.bool(forKey: "key_settings_expanded")
    }
    
    public func setSettingsExpanded(_ expanded: Bool) {
        defaults.set(expanded, forKey: "key_settings_expanded")
    }
    
    public func isOnboardingCompletedCached() -> Bool {
        defaults.bool(forKey: "key_has_completed_onboarding")
    }
    
    public func setOnboardingCompletedCached(_ completed: Bool) {
        defaults.set(completed, forKey: "key_has_completed_onboarding")
    }
    
    public func getCachedThemeColorId() -> String {
        defaults.string(forKey: "key_cached_theme_color_id") ?? "electric_blue"
    }
    
    public func saveCachedThemeColorId(_ themeId: String) {
        defaults.set(themeId, forKey: "key_cached_theme_color_id")
    }
    
    public func getSoundsEnabled() -> Bool {
        if defaults.object(forKey: "key_sounds_enabled") == nil { return true }
        return defaults.bool(forKey: "key_sounds_enabled")
    }
    
    public func setSoundsEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: "key_sounds_enabled")
    }
    
    public func getSavedStatsPeriod() -> String? {
        defaults.string(forKey: "key_stats_period")
    }
    
    public func saveStatsPeriod(_ periodName: String) {
        defaults.set(periodName, forKey: "key_stats_period")
    }
    
    public func getCachedInitialFinancialSummary() -> FinancialSummary {
        let theme = getCachedThemeColorId()
        let currency = defaults.string(forKey: "key_cached_currency") ?? "S/"
        let initial = defaults.double(forKey: "key_cached_initial_balance")
        let current = defaults.object(forKey: "key_cached_current_balance") != nil ? defaults.double(forKey: "key_cached_current_balance") : initial
        let walletName = defaults.string(forKey: "key_cached_wallet_name") ?? "Billetera Principal"
        let walletId = defaults.object(forKey: "key_cached_wallet_id") != nil ? Int64(defaults.integer(forKey: "key_cached_wallet_id")) : 1
        let configured = defaults.bool(forKey: "key_cached_configured_initial")
        let completedOnboarding = isOnboardingCompletedCached()
        let isPro = isProUserCached()
        let soundsEnabled = getSoundsEnabled()
        
        return FinancialSummary(
            initialBalance: initial,
            totalIncome: 0.0,
            totalExpense: 0.0,
            currentBalance: current,
            hasConfiguredInitial: configured,
            currencySymbol: currency,
            hasCompletedOnboarding: completedOnboarding,
            activeWalletName: walletName,
            activeWalletId: walletId,
            themeColorId: theme,
            notificationsEnabled: true,
            isProUser: isPro,
            soundsEnabled: soundsEnabled
        )
    }
    
    private func cacheFinancialSummary(_ summary: FinancialSummary) {
        defaults.set(summary.themeColorId, forKey: "key_cached_theme_color_id")
        defaults.set(summary.currencySymbol, forKey: "key_cached_currency")
        defaults.set(summary.initialBalance, forKey: "key_cached_initial_balance")
        defaults.set(summary.currentBalance, forKey: "key_cached_current_balance")
        defaults.set(summary.activeWalletName, forKey: "key_cached_wallet_name")
        defaults.set(Int(summary.activeWalletId), forKey: "key_cached_wallet_id")
        defaults.set(summary.hasConfiguredInitial, forKey: "key_cached_configured_initial")
        defaults.set(summary.hasCompletedOnboarding, forKey: "key_has_completed_onboarding")
        defaults.set(summary.isProUser, forKey: "key_is_pro_user")
        defaults.set(summary.soundsEnabled, forKey: "key_sounds_enabled")
    }
    
    // MARK: - PRO Mode Validation
    
    public func activateProMode(code: String) -> (success: Bool, message: String) {
        let raw = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().replacingOccurrences(of: " ", with: "")
        
        // 1. Validate that NO numbers are present
        if raw.contains(where: { $0.isNumber }) {
            return (false, "Código inválido: no debe contener números.")
        }
        
        // 2. Extract uppercase letters only (strictly 9 letters)
        let lettersOnly = raw.filter { $0 >= "A" && $0 <= "Z" }
        if lettersOnly.count != 9 {
            return (false, "El código debe tener exactamente 9 letras mayúsculas.")
        }
        
        // 3. Normalize into XXX-XXX-XXX with hyphens
        let start1 = lettersOnly.startIndex
        let end1 = lettersOnly.index(start1, offsetBy: 3)
        let end2 = lettersOnly.index(end1, offsetBy: 3)
        let end3 = lettersOnly.index(end2, offsetBy: 3)
        
        let p1 = String(lettersOnly[start1..<end1])
        let p2 = String(lettersOnly[end1..<end2])
        let p3 = String(lettersOnly[end2..<end3])
        let formattedCode = "\(p1)-\(p2)-\(p3)"
        
        // 4. Check if already active
        if isProUserCached() {
            return (true, "¡El Modo PRO ya se encuentra activado en tu dispositivo! 👑")
        }
        
        // 5. Strictly verify against the official 20 activation codes only
        let isValid = Self.official20ProCodes.contains(formattedCode) || Self.official20ProCodes.contains(lettersOnly)
        
        if isValid {
            setProUserCached(true)
            let profile = getUserProfileSync()
            if let profile {
                profile.isProUser = true
            } else {
                let newProfile = UserProfile(id: 1, isProUser: true)
                modelContext.insert(newProfile)
            }
            try? modelContext.save()
            return (true, "¡Código verificado con éxito! Modo PRO activado.")
        } else {
            return (false, "Código incorrecto. Por favor verifica e intenta de nuevo.")
        }
    }
    
    // MARK: - Setup and Initialization
    
    public func ensureDefaultWallet() {
        let wallets = getAllWalletsSync()
        let currentProfile = getUserProfileSync()
        let isAlreadyCompleted = currentProfile?.hasCompletedOnboarding ?? isOnboardingCompletedCached()
        let isPro = currentProfile?.isProUser ?? isProUserCached()
        
        if wallets.isEmpty {
            let initial = currentProfile?.initialBalance ?? 0.0
            let currency = currentProfile?.currencySymbol ?? "S/"
            let defaultWallet = Wallet(
                id: 1,
                name: "Billetera Principal",
                initialBalance: initial,
                currencySymbol: currency,
                colorHex: "#00D2FF",
                iconName: "wallet",
                isDefault: true
            )
            modelContext.insert(defaultWallet)
            
            if let profile = currentProfile {
                profile.activeWalletId = 1
                profile.initialBalance = initial
                profile.currencySymbol = currency
                profile.hasCompletedOnboarding = isAlreadyCompleted
                profile.isProUser = isPro
            } else {
                let profile = UserProfile(
                    id: 1,
                    initialBalance: initial,
                    currencySymbol: currency,
                    hasConfiguredInitial: false,
                    hasCompletedOnboarding: isAlreadyCompleted,
                    activeWalletId: 1,
                    isProUser: isPro
                )
                modelContext.insert(profile)
            }
            try? modelContext.save()
        } else if currentProfile == nil {
            let firstWallet = wallets.first
            let profile = UserProfile(
                id: 1,
                initialBalance: firstWallet?.initialBalance ?? 0.0,
                currencySymbol: firstWallet?.currencySymbol ?? "S/",
                hasConfiguredInitial: false,
                hasCompletedOnboarding: isAlreadyCompleted,
                activeWalletId: firstWallet?.id ?? 1,
                isProUser: isPro
            )
            modelContext.insert(profile)
            try? modelContext.save()
        }
    }
    
    // MARK: - UserProfile Operations
    
    public func getUserProfileSync() -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>(predicate: #Predicate { $0.id == 1 })
        return (try? modelContext.fetch(descriptor))?.first
    }
    
    public func updateThemeColor(_ themeColorId: String) {
        saveCachedThemeColorId(themeColorId)
        let profile = getUserProfileSync()
        if let profile {
            profile.themeColorId = themeColorId
        } else {
            let newProfile = UserProfile(themeColorId: themeColorId)
            modelContext.insert(newProfile)
        }
        try? modelContext.save()
    }
    
    public func updateNotificationsEnabled(_ enabled: Bool) {
        let profile = getUserProfileSync()
        if let profile {
            profile.notificationsEnabled = enabled
        } else {
            let newProfile = UserProfile(notificationsEnabled: enabled)
            modelContext.insert(newProfile)
        }
        try? modelContext.save()
    }
    
    public func saveInitialBalance(_ balance: Double, currency: String? = nil) {
        setOnboardingCompletedCached(true)
        let profile = getUserProfileSync()
        let activeWalletId = profile?.activeWalletId ?? 1
        let activeWallet = getWalletByIdSync(activeWalletId)
        let resolvedCurrency = currency ?? activeWallet?.currencySymbol ?? profile?.currencySymbol ?? "S/"
        
        if let activeWallet {
            activeWallet.initialBalance = balance
            activeWallet.currencySymbol = resolvedCurrency
        }
        
        if let profile {
            profile.initialBalance = balance
            profile.currencySymbol = resolvedCurrency
            profile.hasConfiguredInitial = true
            profile.hasCompletedOnboarding = true
        } else {
            let newProfile = UserProfile(
                initialBalance: balance,
                currencySymbol: resolvedCurrency,
                hasConfiguredInitial: true,
                hasCompletedOnboarding: true,
                activeWalletId: activeWalletId
            )
            modelContext.insert(newProfile)
        }
        try? modelContext.save()
    }
    
    public func setOnboardingCompleted(_ completed: Bool) {
        setOnboardingCompletedCached(completed)
        if let profile = getUserProfileSync() {
            profile.hasCompletedOnboarding = completed
            try? modelContext.save()
        }
    }
    
    // MARK: - Wallet Operations
    
    public func getAllWalletsSync() -> [Wallet] {
        let descriptor = FetchDescriptor<Wallet>(sortBy: [SortDescriptor(\.id, order: .forward)])
        let list = (try? modelContext.fetch(descriptor)) ?? []
        if let savedOrder = UserDefaults.standard.array(forKey: "wallet_custom_order") as? [NSNumber] {
            let int64Order = savedOrder.map { $0.int64Value }
            return list.sorted { w1, w2 in
                let idx1 = int64Order.firstIndex(of: w1.id) ?? Int.max
                let idx2 = int64Order.firstIndex(of: w2.id) ?? Int.max
                if idx1 == idx2 {
                    return w1.id < w2.id
                }
                return idx1 < idx2
            }
        }
        return list
    }
    
    public func saveWalletOrder(_ orderedIds: [Int64]) {
        let nsNumbers = orderedIds.map { NSNumber(value: $0) }
        UserDefaults.standard.set(nsNumbers, forKey: "wallet_custom_order")
    }
    
    public func getWalletByIdSync(_ id: Int64) -> Wallet? {
        let descriptor = FetchDescriptor<Wallet>(predicate: #Predicate { $0.id == id })
        return (try? modelContext.fetch(descriptor))?.first
    }
    
    public func getActiveWalletSync() -> Wallet? {
        let profile = getUserProfileSync()
        let activeId = profile?.activeWalletId ?? 1
        return getWalletByIdSync(activeId) ?? getAllWalletsSync().first
    }
    
    public func createWallet(name: String, initialBalance: Double, currency: String = "S/", colorHex: String = "#00D2FF") -> Int64 {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        let safeName = trimmed.isEmpty ? "Nueva Billetera" : trimmed
        let newId = Int64(Date().timeIntervalSince1970 * 1000)
        let newWallet = Wallet(
            id: newId,
            name: safeName,
            initialBalance: initialBalance,
            currencySymbol: currency,
            colorHex: colorHex,
            isDefault: false
        )
        modelContext.insert(newWallet)
        try? modelContext.save()
        switchActiveWallet(newId)
        return newId
    }
    
    public func updateWallet(_ wallet: Wallet) {
        try? modelContext.save()
    }
    
    public func updateWalletNameAndBalance(walletId: Int64, name: String, initialBalance: Double, currency: String = "S/", colorHex: String? = nil) {
        if let existing = getWalletByIdSync(walletId) {
            let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
            existing.name = trimmed.isEmpty ? existing.name : trimmed
            existing.initialBalance = initialBalance
            existing.currencySymbol = currency
            if let colorHex { existing.colorHex = colorHex }
            
            let profile = getUserProfileSync()
            if profile?.activeWalletId == walletId {
                profile?.initialBalance = initialBalance
                profile?.currencySymbol = currency
            }
            try? modelContext.save()
        }
    }
    
    public func deleteWallet(walletId: Int64) {
        let allWallets = getAllWalletsSync()
        guard let firstWallet = allWallets.first, firstWallet.id != walletId else { return }
        guard let toDelete = getWalletByIdSync(walletId), !toDelete.isDefault else { return }
        
        clearSpecificWalletTransactionsOnly(walletId)
        modelContext.delete(toDelete)
        try? modelContext.save()
        
        let profile = getUserProfileSync()
        if profile?.activeWalletId == walletId {
            if let remainingFirst = getAllWalletsSync().first {
                switchActiveWallet(remainingFirst.id)
            }
        }
    }
    
    public func switchActiveWallet(_ walletId: Int64) {
        let profile = getUserProfileSync()
        let targetWallet = getWalletByIdSync(walletId)
        let newCurrency = targetWallet?.currencySymbol ?? profile?.currencySymbol ?? "S/"
        let newInitial = targetWallet?.initialBalance ?? profile?.initialBalance ?? 0.0
        
        if let profile {
            profile.activeWalletId = walletId
            profile.initialBalance = newInitial
            profile.currencySymbol = newCurrency
        }
        try? modelContext.save()
    }
    
    // MARK: - Transaction Operations
    
    public func getAllTransactionsSync() -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(sortBy: [
            SortDescriptor(\.dateMillis, order: .reverse),
            SortDescriptor(\.id, order: .reverse)
        ])
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    public func getTransactionsByWalletSync(_ walletId: Int64) -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.walletId == walletId },
            sortBy: [
                SortDescriptor(\.dateMillis, order: .reverse),
                SortDescriptor(\.id, order: .reverse)
            ]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    public func insertTransaction(_ transaction: Transaction) -> Int64 {
        transaction.category = CategoryHelper.resolveCategory(nameOrKeyword: transaction.category, type: transaction.type)
        let profile = getUserProfileSync()
        let activeWalletId = profile?.activeWalletId ?? 1
        if transaction.walletId == 0 || transaction.walletId == 1 {
            transaction.walletId = activeWalletId
        }
        modelContext.insert(transaction)
        try? modelContext.save()
        return transaction.id
    }
    
    public func updateTransaction(_ transaction: Transaction) {
        transaction.category = CategoryHelper.resolveCategory(nameOrKeyword: transaction.category, type: transaction.type)
        try? modelContext.save()
    }
    
    public func deleteTransaction(_ transaction: Transaction) {
        if transaction.isFixedExpensePayment() {
            let fixedExpenses = getAllFixedExpensesSync()
            if let fe = fixedExpenses.first(where: { $0.name.lowercased() == transaction.title.lowercased() }) {
                fe.lastPaidDateMillis = 0
            }
        }
        modelContext.delete(transaction)
        try? modelContext.save()
    }
    
    public func deleteTransactionById(_ id: Int64) {
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == id })
        if let tx = (try? modelContext.fetch(descriptor))?.first {
            if tx.isFixedExpensePayment() {
                let fixedExpenses = getAllFixedExpensesSync()
                if let fe = fixedExpenses.first(where: { $0.name.lowercased() == tx.title.lowercased() }) {
                    fe.lastPaidDateMillis = 0
                }
            }
            modelContext.delete(tx)
            try? modelContext.save()
        }
    }
    
    public func clearSpecificWalletTransactionsOnly(_ walletId: Int64) {
        let txs = getTransactionsByWalletSync(walletId)
        for tx in txs {
            modelContext.delete(tx)
        }
        try? modelContext.save()
    }
    
    public func clearSpecificWalletData(_ walletId: Int64) {
        clearSpecificWalletTransactionsOnly(walletId)
        if let target = getWalletByIdSync(walletId) {
            target.initialBalance = 0.0
            try? modelContext.save()
        }
    }
    
    public func clearAll() {
        // 1. Borrar todas las transacciones
        let allTxs = getAllTransactionsSync()
        for tx in allTxs {
            modelContext.delete(tx)
        }
        
        // 2. Borrar todos los gastos fijos
        let allFEs = getAllFixedExpensesSync()
        for fe in allFEs {
            modelContext.delete(fe)
        }
        
        // 3. Borrar todas las billeteras existentes y dejar únicamente la predeterminada en 0
        let wallets = getAllWalletsSync()
        for w in wallets {
            modelContext.delete(w)
        }
        let defaultWallet = Wallet(
            id: 1,
            name: "Principal",
            initialBalance: 0.0,
            currencySymbol: "S/",
            colorHex: "#00D2FF",
            iconName: "wallet",
            isDefault: true,
            createdAt: Int64(Date().timeIntervalSince1970 * 1000)
        )
        modelContext.insert(defaultWallet)
        
        // 4. Restablecer perfil y preferencias por defecto
        let profile = getUserProfileSync()
        if let profile {
            profile.themeColorId = "ocean_cyan"
            profile.activeWalletId = 1
            profile.notificationsEnabled = false
            profile.hasCompletedOnboarding = true
        }
        
        defaults.set("ocean_cyan", forKey: "key_theme_color_id")
        defaults.set(0.0, forKey: "key_initial_balance")
        defaults.set(true, forKey: "key_sounds_enabled")
        
        try? modelContext.save()
    }
    
    // MARK: - Transfers Between Wallets
    
    public func transferBetweenWallets(
        sourceWalletId: Int64,
        destinationWalletId: Int64,
        amount: Double,
        detail: String = ""
    ) -> Result<TransferResult, Error> {
        if sourceWalletId == destinationWalletId {
            return .failure(NSError(domain: "MoneyDev", code: 400, userInfo: [NSLocalizedDescriptionKey: "La cuenta emisora y receptora deben ser diferentes."]))
        }
        if amount <= 0.0 {
            return .failure(NSError(domain: "MoneyDev", code: 400, userInfo: [NSLocalizedDescriptionKey: "El monto a transferir debe ser mayor a 0."]))
        }
        
        guard let sourceWallet = getWalletByIdSync(sourceWalletId) else {
            return .failure(NSError(domain: "MoneyDev", code: 404, userInfo: [NSLocalizedDescriptionKey: "Billetera emisora no encontrada."]))
        }
        guard let destWallet = getWalletByIdSync(destinationWalletId) else {
            return .failure(NSError(domain: "MoneyDev", code: 404, userInfo: [NSLocalizedDescriptionKey: "Billetera receptora no encontrada."]))
        }
        
        let sourceTxs = getTransactionsByWalletSync(sourceWalletId)
        let inc = sourceTxs.filter { $0.type == .income }.reduce(0.0) { $0 + $1.amount }
        let exp = sourceTxs.filter { $0.type == .expense }.reduce(0.0) { $0 + $1.amount }
        let currentBal = max(0.0, sourceWallet.initialBalance + inc - exp)
        
        if currentBal <= 0.0 || amount > currentBal {
            return .failure(NSError(domain: "MoneyDev", code: 400, userInfo: [NSLocalizedDescriptionKey: "Ups, No te queda saldo para realizar este movimiento."]))
        }
        
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let cleanDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let expenseNote = cleanDetail.isEmpty ? "Transferencia enviada a \(destWallet.name)" : cleanDetail
        let incomeNote = cleanDetail.isEmpty ? "Transferencia recibida desde \(sourceWallet.name)" : cleanDetail
        
        // 1. Movimiento en la billetera emisora: Gasto, categoría Transferencia, irrevocable
        let expenseTx = Transaction(
            id: now,
            title: "Transferencia a \(destWallet.name)",
            amount: amount,
            type: .expense,
            category: "Transferencia",
            dateMillis: now,
            notes: expenseNote,
            walletId: sourceWalletId,
            isIrrevocable: true
        )
        modelContext.insert(expenseTx)
        
        // 2. Movimiento en la billetera receptora: Ingreso, categoría Transferencia, irrevocable
        let incomeTx = Transaction(
            id: now + 1,
            title: "Transferencia de \(sourceWallet.name)",
            amount: amount,
            type: .income,
            category: "Transferencia",
            dateMillis: now,
            notes: incomeNote,
            walletId: destinationWalletId,
            isIrrevocable: true
        )
        modelContext.insert(incomeTx)
        try? modelContext.save()
        
        return .success(
            TransferResult(
                sourceWalletName: sourceWallet.name,
                destinationWalletName: destWallet.name,
                amount: amount,
                currencySymbol: sourceWallet.currencySymbol,
                timestamp: now
            )
        )
    }
    
    // MARK: - Fixed Expenses (Modo PRO)
    
    public func getAllFixedExpensesSync() -> [FixedExpense] {
        let descriptor = FetchDescriptor<FixedExpense>(sortBy: [SortDescriptor(\.id, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    public func getFixedExpenseByIdSync(_ id: Int64) -> FixedExpense? {
        let descriptor = FetchDescriptor<FixedExpense>(predicate: #Predicate { $0.id == id })
        return (try? modelContext.fetch(descriptor))?.first
    }
    
    public func addFixedExpense(_ expense: FixedExpense) -> Result<Int64, Error> {
        let currentCount = getAllFixedExpensesSync().count
        if currentCount >= 30 {
            return .failure(NSError(domain: "MoneyDev", code: 400, userInfo: [NSLocalizedDescriptionKey: "Has alcanzado el límite máximo de 30 gastos fijos permitidos."]))
        }
        if expense.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .failure(NSError(domain: "MoneyDev", code: 400, userInfo: [NSLocalizedDescriptionKey: "El nombre del gasto fijo no puede estar vacío."]))
        }
        if expense.amount <= 0.0 {
            return .failure(NSError(domain: "MoneyDev", code: 400, userInfo: [NSLocalizedDescriptionKey: "El monto debe ser mayor a 0."]))
        }
        
        modelContext.insert(expense)
        try? modelContext.save()
        return .success(expense.id)
    }
    
    public func updateFixedExpense(_ expense: FixedExpense) -> Result<Void, Error> {
        if expense.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .failure(NSError(domain: "MoneyDev", code: 400, userInfo: [NSLocalizedDescriptionKey: "El nombre del gasto fijo no puede estar vacío."]))
        }
        if expense.amount <= 0.0 {
            return .failure(NSError(domain: "MoneyDev", code: 400, userInfo: [NSLocalizedDescriptionKey: "El monto debe ser mayor a 0."]))
        }
        try? modelContext.save()
        return .success(())
    }
    
    public func deleteFixedExpense(_ id: Int64) -> Result<Void, Error> {
        if let expense = getFixedExpenseByIdSync(id) {
            modelContext.delete(expense)
            try? modelContext.save()
        }
        return .success(())
    }
    
    public func registerFixedExpensePayment(expense: FixedExpense, walletId: Int64?) -> Result<Int64, Error> {
        // 1. Validación de período: verificar si ya fue pagado para el ciclo actual
        if FixedExpenseDateHelper.isPaidForCurrentPeriod(expense: expense) {
            let nextDue = FixedExpenseDateHelper.getNextDueDate(expense: expense)
            let nextDateStr = DateFormatter.localizedString(from: nextDue, dateStyle: .medium, timeStyle: .none)
            return .failure(NSError(domain: "MoneyDev", code: 400, userInfo: [NSLocalizedDescriptionKey: "Este gasto fijo ya fue pagado para este período. El próximo pago vence el \(nextDateStr)."]))
        }
        
        // 2. Billetera de débito asignada al gasto fijo
        let targetWalletId = (expense.walletId > 0 ? expense.walletId : (walletId ?? getUserProfileSync()?.activeWalletId ?? 1))
        let targetWallet = getWalletByIdSync(targetWalletId)
        let profile = getUserProfileSync()
        let initial = targetWallet?.initialBalance ?? profile?.initialBalance ?? 0.0
        let txs = getTransactionsByWalletSync(targetWalletId)
        let currentBal = initial + txs.filter { $0.type == .income }.reduce(0.0) { $0 + $1.amount } - txs.filter { $0.type == .expense }.reduce(0.0) { $0 + $1.amount }
        
        let walletName = targetWallet?.name ?? "la billetera seleccionada"
        if currentBal <= 0.0 || expense.amount > currentBal {
            return .failure(NSError(domain: "MoneyDev", code: 400, userInfo: [NSLocalizedDescriptionKey: "Ups, No te queda saldo suficiente en '\(walletName)' para realizar este pago."]))
        }
        
        // 3. Registrar el movimiento descontando de la billetera escogida
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let newTx = Transaction(
            id: now,
            title: expense.name,
            amount: expense.amount,
            type: .expense,
            category: expense.category,
            dateMillis: now,
            notes: "Pago de gasto fijo (\(expense.frequency.displayName)) descontado de \(walletName)",
            walletId: targetWalletId
        )
        modelContext.insert(newTx)
        expense.lastPaidDateMillis = now
        try? modelContext.save()
        
        return .success(newTx.id)
    }
    
    // MARK: - Balance & Summary Computations
    
    public func computeFinancialSummary() -> FinancialSummary {
        let profile = getUserProfileSync()
        let activeW = getActiveWalletSync()
        let activeWalletId = activeW?.id ?? profile?.activeWalletId ?? 1
        let transactions = getTransactionsByWalletSync(activeWalletId)
        
        let initial = activeW?.initialBalance ?? profile?.initialBalance ?? 0.0
        let configured = profile?.hasConfiguredInitial ?? false
        let currency = activeW?.currencySymbol ?? profile?.currencySymbol ?? "S/"
        let onboardingCompleted = profile?.hasCompletedOnboarding ?? isOnboardingCompletedCached()
        let walletName = activeW?.name ?? "Billetera Principal"
        let themeColor = profile?.themeColorId ?? getCachedThemeColorId()
        let notifEnabled = profile?.notificationsEnabled ?? true
        let isPro = profile?.isProUser ?? isProUserCached()
        let soundsOn = getSoundsEnabled()
        
        var incomeSum = 0.0
        var expenseSum = 0.0
        
        for tx in transactions {
            if tx.type == .income {
                incomeSum += tx.amount
            } else {
                expenseSum += tx.amount
            }
        }
        
        let currentBalance = max(0.0, initial + incomeSum - expenseSum)
        
        let summary = FinancialSummary(
            initialBalance: initial,
            totalIncome: incomeSum,
            totalExpense: expenseSum,
            currentBalance: currentBalance,
            hasConfiguredInitial: configured,
            currencySymbol: currency,
            hasCompletedOnboarding: onboardingCompleted,
            activeWalletName: walletName,
            activeWalletId: activeWalletId,
            themeColorId: themeColor,
            notificationsEnabled: notifEnabled,
            isProUser: isPro,
            soundsEnabled: soundsOn
        )
        cacheFinancialSummary(summary)
        return summary
    }
    
    public func computeWalletBalances() -> [Int64: Double] {
        let wallets = getAllWalletsSync()
        let transactions = getAllTransactionsSync()
        var balances: [Int64: Double] = [:]
        
        for w in wallets {
            let wTxs = transactions.filter { $0.walletId == w.id }
            let inc = wTxs.filter { $0.type == .income }.reduce(0.0) { $0 + $1.amount }
            let exp = wTxs.filter { $0.type == .expense }.reduce(0.0) { $0 + $1.amount }
            balances[w.id] = max(0.0, w.initialBalance + inc - exp)
        }
        return balances
    }
    
    public func computeCategorySummaries(
        type: TransactionType,
        period: ReportPeriod = .allTime,
        customRange: CustomDateRange? = nil
    ) -> [CategorySummary] {
        let profile = getUserProfileSync()
        let activeWalletId = profile?.activeWalletId ?? 1
        var transactions = getTransactionsByWalletSync(activeWalletId).filter { $0.type == type }
        
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        
        switch period {
        case .allTime:
            break
        case .thisMonth:
            if let start = cal.date(from: cal.dateComponents([.year, .month], from: now)),
               let end = cal.date(byAdding: DateComponents(month: 1, second: -1), to: start) {
                let startM = Int64(start.timeIntervalSince1970 * 1000)
                let endM = Int64(end.timeIntervalSince1970 * 1000)
                transactions = transactions.filter { $0.dateMillis >= startM && $0.dateMillis <= endM }
            }
        case .lastMonth:
            if let startOfThis = cal.date(from: cal.dateComponents([.year, .month], from: now)),
               let startOfLast = cal.date(byAdding: .month, value: -1, to: startOfThis),
               let endOfLast = cal.date(byAdding: DateComponents(second: -1), to: startOfThis) {
                let startM = Int64(startOfLast.timeIntervalSince1970 * 1000)
                let endM = Int64(endOfLast.timeIntervalSince1970 * 1000)
                transactions = transactions.filter { $0.dateMillis >= startM && $0.dateMillis <= endM }
            }
        case .thisYear:
            if let start = cal.date(from: cal.dateComponents([.year], from: now)),
               let end = cal.date(byAdding: DateComponents(year: 1, second: -1), to: start) {
                let startM = Int64(start.timeIntervalSince1970 * 1000)
                let endM = Int64(end.timeIntervalSince1970 * 1000)
                transactions = transactions.filter { $0.dateMillis >= startM && $0.dateMillis <= endM }
            }
        case .customRange:
            if let range = customRange {
                transactions = transactions.filter { $0.dateMillis >= range.startMillis && $0.dateMillis <= range.endMillis }
            }
        }
        
        let totalAmount = transactions.reduce(0.0) { $0 + $1.amount }
        if totalAmount <= 0.0 { return [] }
        
        var grouped: [String: (total: Double, count: Int)] = [:]
        for tx in transactions {
            let canonical = CategoryHelper.resolveCategory(nameOrKeyword: tx.category, type: type)
            let current = grouped[canonical] ?? (0.0, 0)
            grouped[canonical] = (current.total + tx.amount, current.count + 1)
        }
        
        return grouped.map { cat, data in
            CategorySummary(
                categoryName: cat,
                totalAmount: data.total,
                percentage: Float(data.total / totalAmount),
                transactionCount: data.count,
                type: type
            )
        }.sorted { $0.totalAmount > $1.totalAmount }
    }
    
    // MARK: - JSON Export & Import (1:1 Android Compatibility)
    
    public func exportDataAsJson(chatMessages: [FinancialChatMessage]? = nil) -> String {
        let wallets = getAllWalletsSync()
        let transactions = getAllTransactionsSync()
        let profile = getUserProfileSync()
        let fixedExpenses = getAllFixedExpensesSync()
        let isPro = profile?.isProUser ?? isProUserCached()
        
        var root: [String: Any] = [
            "version": 1,
            "app": "MoneyDev",
            "exportedAt": Int64(Date().timeIntervalSince1970 * 1000),
            "activeWalletId": profile?.activeWalletId ?? 1,
            "themeColorId": profile?.themeColorId ?? getCachedThemeColorId(),
            "isProUser": isPro
        ]
        
        let walletsArray = wallets.map { w -> [String: Any] in
            [
                "id": w.id,
                "name": w.name,
                "initialBalance": w.initialBalance,
                "currencySymbol": w.currencySymbol,
                "colorHex": w.colorHex,
                "iconName": w.iconName,
                "isDefault": w.isDefault,
                "createdAt": w.createdAt
            ]
        }
        root["wallets"] = walletsArray
        
        let txArray = transactions.map { t -> [String: Any] in
            [
                "id": t.id,
                "title": t.title,
                "amount": t.amount,
                "type": t.type.rawValue,
                "category": t.category,
                "dateMillis": t.dateMillis,
                "notes": t.notes,
                "walletId": t.walletId,
                "isIrrevocable": t.isIrrevocable
            ]
        }
        root["transactions"] = txArray
        
        let feArray = fixedExpenses.map { fe -> [String: Any] in
            [
                "id": fe.id,
                "name": fe.name,
                "amount": fe.amount,
                "category": fe.category,
                "walletId": fe.walletId,
                "frequency": fe.frequency.rawValue,
                "dayOfWeek": fe.dayOfWeek,
                "dayOfMonth": fe.dayOfMonth,
                "monthOfYear": fe.monthOfYear,
                "notifyTiming": fe.notifyTiming.rawValue,
                "notificationsEnabled": fe.notificationsEnabled,
                "lastPaidDateMillis": fe.lastPaidDateMillis,
                "createdAt": fe.createdAt
            ]
        }
        root["fixedExpenses"] = feArray
        
        // Incluir historial de conversación de MoneyBot si la cuenta es PRO
        if isPro, let chatMessages, !chatMessages.isEmpty {
            let chatArray = chatMessages.map { msg -> [String: Any] in
                [
                    "id": msg.id.uuidString,
                    "text": msg.text,
                    "isUser": msg.isUser,
                    "timestamp": Int64(msg.timestamp.timeIntervalSince1970 * 1000),
                    "isRegisteredMovement": msg.isRegisteredMovement
                ]
            }
            root["moneyBotChatMessages"] = chatArray
        }
        
        if let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted]),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }
    
    public func importDataFromJson(_ jsonString: String) -> Result<[FinancialChatMessage]?, Error> {
        let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["wallets"] != nil || json["transactions"] != nil) else {
            return .failure(NSError(domain: "MoneyDev", code: 400, userInfo: [NSLocalizedDescriptionKey: "No se detectó el formato correcto. Por favor intente de nuevo."]))
        }
        
        // Parse wallets
        var walletsList: [Wallet] = []
        if let wArr = json["wallets"] as? [[String: Any]] {
            for (index, wObj) in wArr.enumerated() {
                let id = (wObj["id"] as? NSNumber)?.int64Value ?? Int64(index + 1)
                let name = wObj["name"] as? String ?? "Billetera"
                let initial = (wObj["initialBalance"] as? NSNumber)?.doubleValue ?? 0.0
                let currency = wObj["currencySymbol"] as? String ?? "S/"
                let colorHex = wObj["colorHex"] as? String ?? "#00D2FF"
                let icon = wObj["iconName"] as? String ?? "wallet"
                let isDef = wObj["isDefault"] as? Bool ?? (index == 0)
                let createdAt = (wObj["createdAt"] as? NSNumber)?.int64Value ?? Int64(Date().timeIntervalSince1970 * 1000)
                
                walletsList.append(
                    Wallet(
                        id: id,
                        name: name,
                        initialBalance: initial,
                        currencySymbol: currency,
                        colorHex: colorHex,
                        iconName: icon,
                        isDefault: isDef,
                        createdAt: createdAt
                    )
                )
            }
        }
        
        let themeColorId = json["themeColorId"] as? String ?? "electric_blue"
        
        // Parse Fixed Expenses
        var fixedExpensesList: [FixedExpense] = []
        if let feArr = json["fixedExpenses"] as? [[String: Any]] {
            for feObj in feArr {
                let id = (feObj["id"] as? NSNumber)?.int64Value ?? 0
                let name = feObj["name"] as? String ?? "Gasto Fijo"
                let amount = (feObj["amount"] as? NSNumber)?.doubleValue ?? 0.0
                let category = feObj["category"] as? String ?? "Servicios"
                let frequencyStr = feObj["frequency"] as? String ?? "MONTHLY"
                let freq = FixedExpenseFrequency(rawValue: frequencyStr) ?? .monthly
                let dayOfWeek = (feObj["dayOfWeek"] as? NSNumber)?.intValue ?? 1
                let dayOfMonth = (feObj["dayOfMonth"] as? NSNumber)?.intValue ?? 1
                let monthOfYear = (feObj["monthOfYear"] as? NSNumber)?.intValue ?? 1
                let notifyStr = feObj["notifyTiming"] as? String ?? "SAME_DAY"
                let notify = FixedExpenseNotifyTiming(rawValue: notifyStr) ?? .sameDay
                let notifEnabled = feObj["notificationsEnabled"] as? Bool ?? true
                let walletId = (feObj["walletId"] as? NSNumber)?.int64Value ?? 1
                let lastPaid = (feObj["lastPaidDateMillis"] as? NSNumber)?.int64Value ?? 0
                let createdAt = (feObj["createdAt"] as? NSNumber)?.int64Value ?? Int64(Date().timeIntervalSince1970 * 1000)
                
                fixedExpensesList.append(
                    FixedExpense(
                        id: id,
                        name: name,
                        amount: amount,
                        category: category,
                        walletId: walletId,
                        frequency: freq,
                        dayOfWeek: dayOfWeek,
                        dayOfMonth: dayOfMonth,
                        monthOfYear: monthOfYear,
                        notifyTiming: notify,
                        notificationsEnabled: notifEnabled,
                        lastPaidDateMillis: lastPaid,
                        createdAt: createdAt
                    )
                )
            }
        }
        
        // Check PRO requirements:
        let isCurrentDevicePro = isProUserCached()
        let backupIsPro = json["isProUser"] as? Bool ?? false
        let hasMoreThanThreeWallets = walletsList.count > 3
        let hasFixedExpenses = !fixedExpensesList.isEmpty
        let proThemeColors: Set<String> = ["electric_green", "electric_gray", "electric_red", "electric_purple"]
        let usesProColor = proThemeColors.contains(themeColorId.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
        
        if !isCurrentDevicePro && (hasMoreThanThreeWallets || usesProColor || hasFixedExpenses || backupIsPro) {
            return .failure(NSError(
                domain: "MoneyDev",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Esta copia de seguridad se realizó desde una cuenta con Modo PRO activo. Por favor, actualiza a Modo PRO para restaurar tus datos."]
            ))
        }
        
        // Parse Transactions
        var txList: [Transaction] = []
        if let tArr = json["transactions"] as? [[String: Any]] {
            for tObj in tArr {
                let id = (tObj["id"] as? NSNumber)?.int64Value ?? Int64(Date().timeIntervalSince1970 * 1000)
                let title = tObj["title"] as? String ?? "Movimiento"
                let amount = (tObj["amount"] as? NSNumber)?.doubleValue ?? 0.0
                let typeStr = tObj["type"] as? String ?? "EXPENSE"
                let type: TransactionType = typeStr.caseInsensitiveCompare("INCOME") == .orderedSame ? .income : .expense
                let category = tObj["category"] as? String ?? "Otros"
                let dateMillis = (tObj["dateMillis"] as? NSNumber)?.int64Value ?? Int64(Date().timeIntervalSince1970 * 1000)
                let notes = tObj["notes"] as? String ?? ""
                let walletId = (tObj["walletId"] as? NSNumber)?.int64Value ?? 1
                let isIrrevocable = tObj["isIrrevocable"] as? Bool ?? false
                
                txList.append(
                    Transaction(
                        id: id,
                        title: title,
                        amount: amount,
                        type: type,
                        category: category,
                        dateMillis: dateMillis,
                        notes: notes,
                        walletId: walletId,
                        isIrrevocable: isIrrevocable
                    )
                )
            }
        }
        
        // Clear old data and insert imported
        clearAll()
        for w in getAllWalletsSync() {
            modelContext.delete(w)
        }
        for fe in getAllFixedExpensesSync() {
            modelContext.delete(fe)
        }
        
        if !walletsList.isEmpty {
            for w in walletsList { modelContext.insert(w) }
        } else {
            let defW = Wallet(id: 1, name: "Billetera Principal", initialBalance: 0.0, currencySymbol: "S/", isDefault: true)
            modelContext.insert(defW)
        }
        
        for tx in txList { modelContext.insert(tx) }
        for fe in fixedExpensesList { modelContext.insert(fe) }
        
        let activeWalletId = (json["activeWalletId"] as? NSNumber)?.int64Value ?? walletsList.first?.id ?? 1
        let currency = walletsList.first(where: { $0.id == activeWalletId })?.currencySymbol ?? "S/"
        let initialBal = walletsList.first(where: { $0.id == activeWalletId })?.initialBalance ?? 0.0
        
        let finalIsPro = isCurrentDevicePro || backupIsPro
        setProUserCached(finalIsPro)
        saveCachedThemeColorId(themeColorId)
        setOnboardingCompletedCached(true)
        
        if let profile = getUserProfileSync() {
            profile.initialBalance = initialBal
            profile.currencySymbol = currency
            profile.hasConfiguredInitial = true
            profile.hasCompletedOnboarding = true
            profile.activeWalletId = activeWalletId
            profile.themeColorId = themeColorId
            profile.isProUser = finalIsPro
        } else {
            let newProfile = UserProfile(
                id: 1,
                initialBalance: initialBal,
                currencySymbol: currency,
                hasConfiguredInitial: true,
                hasCompletedOnboarding: true,
                activeWalletId: activeWalletId,
                themeColorId: themeColorId,
                notificationsEnabled: true,
                isProUser: finalIsPro
            )
            modelContext.insert(newProfile)
        }
        
        try? modelContext.save()
        
        // Deserializar conversación de MoneyBot si la cuenta es PRO y el respaldo contiene mensajes
        var importedChatMessages: [FinancialChatMessage]? = nil
        if finalIsPro, let chatArr = json["moneyBotChatMessages"] as? [[String: Any]] {
            var msgs: [FinancialChatMessage] = []
            for cObj in chatArr {
                let idStr = cObj["id"] as? String ?? UUID().uuidString
                let id = UUID(uuidString: idStr) ?? UUID()
                let text = cObj["text"] as? String ?? ""
                let isUser = cObj["isUser"] as? Bool ?? false
                let timeMillis = (cObj["timestamp"] as? NSNumber)?.int64Value ?? Int64(Date().timeIntervalSince1970 * 1000)
                let isReg = cObj["isRegisteredMovement"] as? Bool ?? false
                
                msgs.append(FinancialChatMessage(
                    id: id,
                    text: text,
                    isUser: isUser,
                    timestamp: Date(timeIntervalSince1970: TimeInterval(timeMillis) / 1000.0),
                    isThinking: false,
                    isRegisteredMovement: isReg
                ))
            }
            if !msgs.isEmpty {
                importedChatMessages = msgs
            }
        }
        
        return .success(importedChatMessages)
    }
}
