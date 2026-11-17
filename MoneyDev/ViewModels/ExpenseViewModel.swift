import Foundation
import SwiftUI
import Observation

public enum FilterType: String, CaseIterable, Sendable {
    case all = "Todos"
    case expense = "Gastos"
    case income = "Ingresos"
}

public enum DateFilter: String, CaseIterable, Sendable {
    case all = "ALL"
    case customRange = "CUSTOM_RANGE"
    case today = "TODAY"
    case yesterday = "YESTERDAY"
    case thisWeek = "THIS_WEEK"
    case thisMonth = "THIS_MONTH"
    
    public var label: String {
        switch self {
        case .all: return "Todos los períodos"
        case .customRange: return "Filtrar por fecha"
        case .today: return "Hoy"
        case .yesterday: return "Ayer"
        case .thisWeek: return "Esta semana"
        case .thisMonth: return "Este mes"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .all: return "Todos los registros históricos"
        case .customRange: return "Rango personalizado de fechas o meses"
        case .today: return "Registros de hoy"
        case .yesterday: return "Registros del día de ayer"
        case .thisWeek: return "Registros de la semana en curso"
        case .thisMonth: return "Registros del mes en curso"
        }
    }
}

public struct CustomDateRange: Hashable, Sendable {
    public let startMillis: Int64
    public let endMillis: Int64
    public let label: String
    
    public init(startMillis: Int64, endMillis: Int64, label: String) {
        self.startMillis = startMillis
        self.endMillis = endMillis
        self.label = label
    }
}

public enum ReportPeriod: String, CaseIterable, Sendable {
    case allTime = "ALL_TIME"
    case thisMonth = "THIS_MONTH"
    case lastMonth = "LAST_MONTH"
    case thisYear = "THIS_YEAR"
    case customRange = "CUSTOM_RANGE"
    
    public var displayName: String {
        switch self {
        case .allTime: return "Todo el tiempo"
        case .thisMonth: return "Este mes"
        case .lastMonth: return "Mes anterior"
        case .thisYear: return "Este año"
        case .customRange: return "Personalizado"
        }
    }
}

public enum StatsReportMode: String, CaseIterable, Sendable {
    case expenses = "Gastos"
    case incomes = "Ingresos"
    case comparative = "Comparativo"
}

public enum ChartType: String, CaseIterable, Sendable {
    case pie = "Dona"
    case bar = "Barras"
}

public struct VoiceTransactionNotification: Hashable, Sendable {
    public let type: TransactionType
    public let amount: Double
    public let currency: String
    public let category: String
    public let title: String
    public let walletName: String
}

public enum SettingsHighlightTarget: String, Sendable {
    case theme
    case appIcon
}

@Observable
@MainActor
public final class ExpenseViewModel {
    public typealias SettingsHighlightTarget = MoneyDev.SettingsHighlightTarget
    private let repository: ExpenseRepository
    
    // Core state
    public var financialSummary: FinancialSummary = FinancialSummary()
    public var wallets: [Wallet] = []
    public var activeWallet: Wallet? = nil
    public var transactions: [Transaction] = []
    public var filteredTransactions: [Transaction] = []
    public var expenseCategorySummaries: [CategorySummary] = []
    public var incomeCategorySummaries: [CategorySummary] = []
    public var walletBalances: [Int64: Double] = [:]
    public var fixedExpenses: [FixedExpense] = []
    
    // Deduplicación de seguridad para mensajes y movimientos por voz
    private var lastUserPrompt: String = ""
    private var lastPromptTimestamp: Date = Date.distantPast
    
    // UI controls
    public var isInitialized: Bool = false
    public var isBalanceHidden: Bool = false
    public var isMovementsHidden: Bool = false
    public var selectedFilter: FilterType = .all
    public var selectedDateFilter: DateFilter = .all
    public var customDateRange: CustomDateRange? = nil
    public var searchQuery: String = ""
    public var activeTab: Int = 0 // 0 = Movimientos, 1 = Estadísticas, 2 = Modo PRO, 3 = Ajustes
    
    // Disparador de Scroll Automático al movimiento más reciente
    public var scrollToTopTrigger: UUID = UUID()
    
    public func triggerScrollToTop() {
        scrollToTopTrigger = UUID()
    }
    
    // Dialogs & Sheets
    public var isAddEditSheetOpen: Bool = false
    public var addTransactionType: TransactionType = .expense
    public var editingTransaction: Transaction? = nil
    public var isSetBalanceDialogOpen: Bool = false
    public var isSettingsDialogOpen: Bool = false
    public var showProWelcomeDialog: Bool = false
    public var isTutorialOpen: Bool = false
    public var isFixedExpensesDialogOpen: Bool = false
    public var settingsHighlightTarget: SettingsHighlightTarget? = nil
    
    // Deep Linking desde Widgets y accesos directos
    public var shouldOpenVoiceDictation: Bool = false
    public var shouldOpenLiveVoice: Bool = false
    public var targetDictationWalletId: Int64? = nil
    
    public var isOnboardingCompleted: Bool {
        repository.isOnboardingCompletedCached()
    }
    
    // Transfers
    public var isTransferDialogOpen: Bool = false
    public var transferSuccessResult: TransferResult? = nil
    public var needsMoreWalletsForTransfer: Bool = false
    public var selectedTransferMovement: Transaction? = nil
    
    // Floating Notification Banner (Toast)
    public struct FloatingToastData: Identifiable, Equatable {
        public let id = UUID()
        public let title: String
        public let message: String
        public let isSuccess: Bool
        
        public init(title: String, message: String, isSuccess: Bool = true) {
            self.title = title
            self.message = message
            self.isSuccess = isSuccess
        }
    }
    
    public var floatingToast: FloatingToastData? = nil
    private var toastDismissTask: Task<Void, Never>? = nil
    
    // Statistics & Reports
    public var statsReportMode: StatsReportMode = .expenses
    public var statsPeriod: ReportPeriod = .allTime
    public var statsCustomRange: CustomDateRange? = nil
    public var statsChartType: ChartType = .pie
    
    // Voice & AI Chat
    public var isVoiceAssistantOpen: Bool = false
    public var voiceInputText: String = ""
    public var isAiProcessing: Bool = false
    private static let chatDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "es_ES")
        df.dateFormat = "yyyy-MM-dd (d 'de' MMMM, hh:mm a)"
        return df
    }()
    public var voiceSuccessMessage: String? = nil
    public var aiErrorMessage: String? = nil
    public var chatMessages: [FinancialChatMessage] = [
        FinancialChatMessage(
            text: "Hola, Soy Moneybot, tu asistente con inteligencia artificial destinado a registrar todos tus movimientos. ¿En qué te puedo ayudar?",
            isUser: false
        )
    ]
    public var pendingAiTransactions: [ExtractedTransaction] = []
    public var pendingAiTransaction: ExtractedTransaction? {
        get { pendingAiTransactions.first }
        set {
            if let val = newValue {
                if pendingAiTransactions.isEmpty {
                    pendingAiTransactions = [val]
                } else {
                    pendingAiTransactions[0] = val
                }
            } else {
                pendingAiTransactions.removeAll()
            }
        }
    }
    public var pendingVoiceTransfer: PendingTransferVoiceState? = nil
    public var editSuccessTransaction: Transaction? = nil
    
    public var isProUser: Bool {
        financialSummary.isProUser
    }
    
    public var activeTheme: AppColorTheme {
        AppColorTheme.fromId(financialSummary.themeColorId)
    }
    
    // MARK: - Comparative Stats & Financial Health Metrics
    public var statsTotalIncome: Double {
        incomeCategorySummaries.reduce(0.0) { $0 + $1.totalAmount }
    }
    
    public var statsTotalExpense: Double {
        expenseCategorySummaries.reduce(0.0) { $0 + $1.totalAmount }
    }
    
    public var statsNetBalance: Double {
        statsTotalIncome - statsTotalExpense
    }
    
    public var statsSavingsRate: Double {
        guard statsTotalIncome > 0 else {
            return statsTotalExpense > 0 ? -100.0 : 0.0
        }
        return ((statsTotalIncome - statsTotalExpense) / statsTotalIncome) * 100.0
    }
    
    public var statsExpenseRatio: Double {
        guard statsTotalIncome > 0 else {
            return statsTotalExpense > 0 ? 100.0 : 0.0
        }
        return min(300.0, (statsTotalExpense / statsTotalIncome) * 100.0)
    }
    
    public var statsFixedExpensesTotal: Double {
        fixedExpenses.reduce(0.0) { $0 + $1.amount }
    }
    
    public var statsFixedExpenseBurden: Double {
        guard statsTotalIncome > 0 else { return 0.0 }
        return min(100.0, (statsFixedExpensesTotal / statsTotalIncome) * 100.0)
    }
    
    public var financialHealthScore: Int {
        if statsTotalIncome <= 0 && statsTotalExpense <= 0 { return 50 }
        var score: Int
        if statsSavingsRate >= 30 {
            score = 95
        } else if statsSavingsRate >= 20 {
            score = 85
        } else if statsSavingsRate >= 10 {
            score = 72
        } else if statsSavingsRate >= 0 {
            score = 55
        } else if statsSavingsRate >= -20 {
            score = 35
        } else {
            score = 15
        }
        if statsFixedExpenseBurden > 55 {
            score = max(10, score - 10)
        }
        return min(100, max(5, score))
    }
    
    public var financialHealthBadgeTitle: String {
        if statsTotalIncome <= 0 && statsTotalExpense <= 0 { return "Sin Datos" }
        switch financialHealthScore {
        case 80...100: return "Excelente"
        case 65..<80: return "Saludable"
        case 45..<65: return "Ajustado"
        default: return "En Riesgo"
        }
    }
    
    public var financialHealthBadgeColorHex: String {
        if statsTotalIncome <= 0 && statsTotalExpense <= 0 { return "#64748B" }
        switch financialHealthScore {
        case 80...100: return "#10B981"
        case 65..<80: return "#34D399"
        case 45..<65: return "#F59E0B"
        default: return "#F43F5E"
        }
    }
    
    public var financialHealthAdvice: String {
        if statsTotalIncome <= 0 && statsTotalExpense <= 0 {
            return "Registra tus primeros movimientos en este período para analizar tu salud financiera."
        }
        if statsNetBalance < 0 {
            return "Tus gastos superan tus ingresos en \(financialSummary.currencySymbol) \(FormatHelper.formatCurrency(abs(statsNetBalance))). Te recomendamos moderar compras no esenciales y revisar tus gastos fijos para evitar endeudamiento."
        }
        if statsSavingsRate >= 0 && statsSavingsRate < 10 {
            return "Tu tasa de ahorro es de \(String(format: "%.1f", statsSavingsRate))%. Aunque mantienes saldo positivo, la regla 50/30/20 sugiere apartar al menos el 20% para tu fondo de imprevistos."
        }
        if statsSavingsRate >= 10 && statsSavingsRate < 25 {
            return "¡Buen ritmo! Estás ahorrando el \(String(format: "%.1f", statsSavingsRate))% de tus ingresos. Mantén la consistencia y destina el excedente a metas claras o fondos de emergencia."
        }
        return "¡Excelente salud financiera! Lograste una tasa de ahorro superior al \(String(format: "%.1f", statsSavingsRate))%. Tienes gran solvencia y capacidad para invertir o cumplir proyectos futuros."
    }
    
    public init(repository: ExpenseRepository) {
        self.repository = repository
        CategoryHelper.purgeInvalidCustomCategories()
        self.financialSummary = repository.getCachedInitialFinancialSummary()
        self.repository.ensureDefaultWallet()
        refreshData()
        loadChatHistory()
    }
    
    public func recomputeStats() {
        self.expenseCategorySummaries = repository.computeCategorySummaries(
            type: .expense,
            period: statsPeriod,
            customRange: statsCustomRange
        )
        self.incomeCategorySummaries = repository.computeCategorySummaries(
            type: .income,
            period: statsPeriod,
            customRange: statsCustomRange
        )
    }
    
    public func refreshData() {
        self.wallets = repository.getAllWalletsSync()
        self.activeWallet = repository.getActiveWalletSync()
        self.transactions = repository.getAllTransactionsSync()
        self.financialSummary = repository.computeFinancialSummary()
        self.walletBalances = repository.computeWalletBalances()
        self.fixedExpenses = repository.getAllFixedExpensesSync()
        recomputeStats()
        self.isInitialized = true
        applyFilters()
        
        // Sincronizar recordatorios inteligentes con la regla de 9 AM y 5 PM
        ReminderScheduler.updateDailyReminders(
            transactions: self.transactions,
            notificationsEnabled: self.financialSummary.notificationsEnabled
        )
        
        // Sincronizar datos compartidos para los Widgets Pequeño y Mediano
        syncWidgetsData()
    }
    
    public func syncWidgetsData() {
        let balances = repository.computeWalletBalances()
        let activeId = activeWallet?.id ?? financialSummary.activeWalletId
        
        let now = Date()
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        let walletItems: [WidgetWalletData] = wallets.map { w in
            let bal = balances[w.id] ?? w.initialBalance
            let monthTxs = transactions.filter { tx in
                guard tx.walletId == w.id else { return false }
                let txDate = Date(timeIntervalSince1970: TimeInterval(tx.dateMillis) / 1000.0)
                return calendar.component(.month, from: txDate) == currentMonth &&
                       calendar.component(.year, from: txDate) == currentYear
            }
            let income = monthTxs.filter { $0.type == .income }.reduce(0.0) { $0 + $1.amount }
            let expense = monthTxs.filter { $0.type == .expense }.reduce(0.0) { $0 + $1.amount }
            
            return WidgetWalletData(
                id: w.id,
                name: w.name,
                balance: bal,
                currencySymbol: w.currencySymbol,
                colorHex: w.colorHex,
                iconName: w.iconName,
                monthlyIncome: income,
                monthlyExpense: expense
            )
        }
        
        let shared = WidgetSharedData(
            activeWalletId: activeId,
            wallets: walletItems,
            totalBalance: financialSummary.currentBalance,
            lastUpdated: now
        )
        WidgetDataManager.saveData(shared)
    }
    
    private func applyFilters() {
        let activeWalletId = activeWallet?.id ?? financialSummary.activeWalletId
        let activeWalletTxs = transactions.filter { $0.walletId == activeWalletId }
        
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        
        filteredTransactions = activeWalletTxs.filter { tx in
            // Filter by Type
            let matchesType: Bool
            switch selectedFilter {
            case .all: matchesType = true
            case .expense: matchesType = tx.type == .expense
            case .income: matchesType = tx.type == .income
            }
            if !matchesType { return false }
            
            // Filter by Date
            let txDate = Date(timeIntervalSince1970: Double(tx.dateMillis) / 1000.0)
            let matchesDate: Bool
            switch selectedDateFilter {
            case .all:
                matchesDate = true
            case .customRange:
                if let range = customDateRange {
                    matchesDate = tx.dateMillis >= range.startMillis && tx.dateMillis <= range.endMillis
                } else {
                    matchesDate = true
                }
            case .today:
                matchesDate = cal.isDateInToday(txDate)
            case .yesterday:
                matchesDate = cal.isDateInYesterday(txDate)
            case .thisWeek:
                matchesDate = cal.isDate(txDate, equalTo: now, toGranularity: .weekOfYear)
            case .thisMonth:
                matchesDate = cal.isDate(txDate, equalTo: now, toGranularity: .month)
            }
            if !matchesDate { return false }
            
            // Filter by Search Query
            return CategoryHelper.matchesTransactionSearch(
                title: tx.title,
                category: tx.category,
                notes: tx.notes,
                query: searchQuery,
                type: tx.type
            )
        }.sorted {
            if $0.dateMillis == $1.dateMillis {
                return $0.id > $1.id
            }
            return $0.dateMillis > $1.dateMillis
        }
    }
    
    // MARK: - Actions
    
    public func toggleHideBalance() {
        isBalanceHidden.toggle()
    }
    
    public func toggleHideMovements() {
        isMovementsHidden.toggle()
    }
    
    public func openSettingsDialog() {
        setActiveTab(3)
    }
    
    public func openSettingsWithHighlight(_ target: SettingsHighlightTarget) {
        settingsHighlightTarget = target
        setActiveTab(3)
    }
    
    public func closeSettingsDialog() {
        setActiveTab(0)
    }
    
    public func setThemeColor(_ themeId: String) {
        repository.updateThemeColor(themeId)
        refreshData()
    }
    
    public func setSoundsEnabled(_ enabled: Bool) {
        repository.setSoundsEnabled(enabled)
        refreshData()
    }
    
    public func setNotificationsEnabled(_ enabled: Bool) {
        repository.updateNotificationsEnabled(enabled)
        refreshData()
    }
    
    public func selectWallet(_ walletId: Int64) {
        repository.switchActiveWallet(walletId)
        refreshData()
    }
    
    public var maxWalletsAllowed: Int {
        isProUser ? 10 : 3
    }
    
    public func canCreateWallet() -> Bool {
        wallets.count < maxWalletsAllowed
    }
    
    public func createWallet(name: String, initialBalance: Double, currency: String = "S/", colorHex: String = "#00D2FF") {
        guard canCreateWallet() else {
            let msg = isProUser ?
                "Límite alcanzado: Máximo 10 billeteras en Modo PRO." :
                "Límite alcanzado: Máximo 3 billeteras en Modo Básico. Activa Modo PRO para hasta 10 billeteras."
            showFloatingToast(title: "Límite de Billeteras", message: msg, isSuccess: false, duration: 4.0)
            return
        }
        _ = repository.createWallet(name: name, initialBalance: initialBalance, currency: currency, colorHex: colorHex)
        refreshData()
    }
    
    public func updateWallet(walletId: Int64, name: String, initialBalance: Double, currency: String = "S/", colorHex: String? = nil) {
        repository.updateWalletNameAndBalance(walletId: walletId, name: name, initialBalance: initialBalance, currency: currency, colorHex: colorHex)
        refreshData()
    }
    
    public func deleteWallet(walletId: Int64) {
        repository.deleteWallet(walletId: walletId)
        refreshData()
    }
    
    public func clearWalletTransactionsOnly(walletId: Int64) {
        repository.clearSpecificWalletTransactionsOnly(walletId)
        refreshData()
    }
    
    public func reorderWallets(from source: IndexSet, to destination: Int) {
        wallets.move(fromOffsets: source, toOffset: destination)
        let orderedIds = wallets.map { $0.id }
        repository.saveWalletOrder(orderedIds)
    }
    
    public func moveWallet(fromIndex: Int, toIndex: Int) {
        guard fromIndex >= 0 && fromIndex < wallets.count,
              toIndex >= 0 && toIndex < wallets.count,
              fromIndex != toIndex else { return }
        let item = wallets.remove(at: fromIndex)
        wallets.insert(item, at: toIndex)
        let orderedIds = wallets.map { $0.id }
        repository.saveWalletOrder(orderedIds)
    }
    
    public func setActiveTab(_ index: Int) {
        activeTab = index
    }
    
    public func setStatsReportMode(_ mode: StatsReportMode) {
        statsReportMode = mode
    }
    
    public func setStatsPeriod(_ period: ReportPeriod) {
        statsPeriod = period
        repository.saveStatsPeriod(period.rawValue)
        recomputeStats()
    }
    
    public func setStatsCustomPeriod(startMillis: Int64, endMillis: Int64, label: String) {
        statsCustomRange = CustomDateRange(startMillis: startMillis, endMillis: endMillis, label: label)
        statsPeriod = .customRange
        recomputeStats()
    }
    
    public func setStatsChartType(_ type: ChartType) {
        statsChartType = type
    }
    
    public func setFilter(_ filter: FilterType) {
        selectedFilter = filter
        applyFilters()
    }
    
    public func setDateFilter(_ dateFilter: DateFilter) {
        selectedDateFilter = dateFilter
        applyFilters()
    }
    
    public func setCustomDateFilter(startMillis: Int64, endMillis: Int64, label: String) {
        customDateRange = CustomDateRange(startMillis: startMillis, endMillis: endMillis, label: label)
        selectedDateFilter = .customRange
        applyFilters()
    }
    
    public func setSearchQuery(_ query: String) {
        searchQuery = query
        applyFilters()
    }
    
    public func openAddTransaction(defaultType: TransactionType = .expense) {
        editingTransaction = nil
        addTransactionType = defaultType
        isAddEditSheetOpen = true
    }
    
    public func openEditTransaction(_ transaction: Transaction) {
        if transaction.isIrrevocableMovement() {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                selectedTransferMovement = transaction
            }
            return
        }
        if transaction.isFixedExpensePayment() {
            showFloatingToast(
                title: "Gasto Fijo Pagado",
                message: "Este movimiento proviene de un gasto fijo. No se puede editar, solo eliminar.",
                isSuccess: false,
                duration: 3.5
            )
            return
        }
        editingTransaction = transaction
        isAddEditSheetOpen = true
    }
    
    public func closeAddEditSheet() {
        isAddEditSheetOpen = false
        editingTransaction = nil
    }
    
    public func openSetBalanceDialog() {
        isSetBalanceDialogOpen = true
    }
    
    public func closeSetBalanceDialog() {
        isSetBalanceDialogOpen = false
    }
    
    public func openTutorial() {
        isTutorialOpen = true
    }
    
    public func closeTutorial() {
        isTutorialOpen = false
    }
    
    public func openProWelcomeDialog() {
        showProWelcomeDialog = true
    }
    
    public func closeProWelcomeDialog() {
        showProWelcomeDialog = false
    }
    
    public func showFloatingToast(title: String = "¡Movimiento Registrado!", message: String, isSuccess: Bool = true, duration: Double = 3.0) {
        toastDismissTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            self.floatingToast = FloatingToastData(title: title, message: message, isSuccess: isSuccess)
        }
        toastDismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        self.floatingToast = nil
                    }
                }
            }
        }
    }
    
    public func dismissFloatingToast() {
        toastDismissTask?.cancel()
        withAnimation(.easeInOut(duration: 0.25)) {
            self.floatingToast = nil
        }
    }
    
    public func activateProWithCode(_ code: String) -> (success: Bool, message: String) {
        let res = repository.activateProMode(code: code)
        if res.success {
            refreshData()
        }
        return res
    }
    
    public func completeOnboarding(initialBalance: Double) {
        repository.saveInitialBalance(initialBalance)
        repository.setOnboardingCompleted(true)
        isTutorialOpen = false
        refreshData()
    }
    
    public func clearAllData() {
        repository.clearAll()
        repository.saveInitialBalance(0.0)
        
        // Purgar bloqueo de seguridad si estuviera configurado
        AppSecurityManager.shared.removeLock()
        
        // Restablecer ícono a básico
        Task {
            _ = await AppIconManager.setAppIcon(AppIconManager.iconBasic)
        }
        
        // Restablecer navegación y filtros al inicio
        selectedFilter = .all
        selectedDateFilter = .all
        customDateRange = nil
        searchQuery = ""
        activeTab = 0
        isSettingsDialogOpen = false
        
        refreshData()
        showFloatingToast(title: "Datos Restablecidos", message: "Se han borrado todos los registros y la app ha vuelto al inicio de fábrica.", isSuccess: true, duration: 4.0)
    }
    
    public func saveInitialBalance(amount: Double, currency: String? = nil) {
        repository.saveInitialBalance(amount, currency: currency)
        isSetBalanceDialogOpen = false
        refreshData()
    }
    
    public func saveTransaction(
        title: String,
        amount: Double,
        type: TransactionType,
        category: String,
        notes: String,
        dateMillis: Int64
    ) -> (success: Bool, message: String?) {
        let safeTitle = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))
        let safeNotes = String(notes.trimmingCharacters(in: .whitespacesAndNewlines).prefix(90))
        let safeDate = min(dateMillis, Int64(Date().timeIntervalSince1970 * 1000))
        
        let currentBal = financialSummary.currentBalance
        let balanceWithoutEditing: Double
        if let editing = editingTransaction {
            balanceWithoutEditing = (editing.type == .expense) ? currentBal + editing.amount : currentBal - editing.amount
        } else {
            balanceWithoutEditing = currentBal
        }
        
        if type == .expense {
            if balanceWithoutEditing <= 0.0 || amount > balanceWithoutEditing {
                closeAddEditSheet()
                return (false, "Ups, No te queda saldo para realizar este movimiento.")
            }
        }
        
        if let editing = editingTransaction {
            editing.title = safeTitle
            editing.amount = amount
            editing.type = type
            editing.category = category
            editing.notes = safeNotes
            editing.dateMillis = safeDate
            repository.updateTransaction(editing)
            editSuccessTransaction = editing
        } else {
            let newTx = Transaction(
                title: safeTitle,
                amount: amount,
                type: type,
                category: category,
                dateMillis: safeDate,
                notes: safeNotes,
                walletId: activeWallet?.id ?? financialSummary.activeWalletId
            )
            _ = repository.insertTransaction(newTx)
            SoundManager.shared.playSoundForType(type, isSoundEnabled: financialSummary.soundsEnabled)
            activeTab = 0
            triggerScrollToTop()
        }
        
        closeAddEditSheet()
        refreshData()
        return (true, nil)
    }
    
    public func deleteTransaction(_ transaction: Transaction) {
        guard !transaction.isIrrevocableMovement() else { return }
        repository.deleteTransaction(transaction)
        refreshData()
    }
    
    // Transfers
    public func openTransferDialog() {
        if wallets.count <= 1 {
            needsMoreWalletsForTransfer = true
        } else {
            isTransferDialogOpen = true
        }
    }
    
    public func closeTransferDialog() {
        isTransferDialogOpen = false
    }
    
    public func closeNeedsMoreWalletsForTransfer() {
        needsMoreWalletsForTransfer = false
    }
    
    public func closeTransferMovementDetails() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            selectedTransferMovement = nil
        }
    }
    
    public func dismissTransferSuccessDialog() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            transferSuccessResult = nil
        }
    }
    
    public func executeTransfer(
        sourceWalletId: Int64,
        destinationWalletId: Int64,
        amount: Double,
        detail: String = ""
    ) -> (success: Bool, message: String?) {
        let result = repository.transferBetweenWallets(sourceWalletId: sourceWalletId, destinationWalletId: destinationWalletId, amount: amount, detail: detail)
        switch result {
        case .success(let transferRes):
            isTransferDialogOpen = false
            transferSuccessResult = transferRes
            activeTab = 0
            triggerScrollToTop()
            refreshData()
            return (true, nil)
        case .failure(let error):
            return (false, error.localizedDescription)
        }
    }
    
    // Voice Assistant & MoneyBot Chat
    public func openVoiceAssistant(initialText: String = "") {
        if chatMessages.count <= 1 {
            loadChatHistory()
        }
        isVoiceAssistantOpen = true
        if chatMessages.isEmpty {
            chatMessages = [
                FinancialChatMessage(
                    text: "Hola, Soy Moneybot, tu asistente con inteligencia artificial destinado a registrar todos tus movimientos. ¿En qué te puedo ayudar?",
                    isUser: false
                )
            ]
            saveChatHistory()
        }
        if !initialText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sendUserChatMessage(prompt: initialText)
        }
    }
    
    public func closeVoiceAssistant() {
        isVoiceAssistantOpen = false
        isAiProcessing = false
    }
    
    /// Cierra de inmediato todas las pestañas modales y diálogos abiertos, restableciendo la navegación al inicio
    public func resetNavigationToHomeAndDismissAll() {
        activeTab = 0
        isAddEditSheetOpen = false
        editingTransaction = nil
        isSetBalanceDialogOpen = false
        isSettingsDialogOpen = false
        showProWelcomeDialog = false
        isTutorialOpen = false
        isFixedExpensesDialogOpen = false
        settingsHighlightTarget = nil
        isTransferDialogOpen = false
        transferSuccessResult = nil
        needsMoreWalletsForTransfer = false
        selectedTransferMovement = nil
        isVoiceAssistantOpen = false
        searchQuery = ""
    }
    
    public func clearChatHistory() {
        pendingAiTransaction = nil
        pendingVoiceTransfer = nil
        chatMessages = [
            FinancialChatMessage(
                text: "¡Conversación reiniciada! 🤖✨\n\nHola, Soy Moneybot, tu asistente con inteligencia artificial destinado a registrar todos tus movimientos. ¿En qué te puedo ayudar?",
                isUser: false
            )
        ]
        saveChatHistory()
    }
    
    public func deleteChatMessage(id: UUID) {
        chatMessages.removeAll { $0.id == id }
        if chatMessages.isEmpty {
            pendingAiTransaction = nil
            pendingVoiceTransfer = nil
            chatMessages = [
                FinancialChatMessage(
                    text: "Hola, Soy Moneybot, tu asistente con inteligencia artificial destinado a registrar todos tus movimientos. ¿En qué te puedo ayudar?",
                    isUser: false
                )
            ]
        }
        saveChatHistory()
    }
    
    public func sendUserChatMessage(prompt: String, targetWalletId: Int64? = nil, scopeToAllWallets: Bool = false, playAudioEffects: Bool = true) {
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPrompt.isEmpty else { return }
        
        let now = Date()
        if cleanPrompt == lastUserPrompt && now.timeIntervalSince(lastPromptTimestamp) < 0.4 {
            // Descartar peticiones duplicadas emitidas concurrentemente
            return
        }
        lastUserPrompt = cleanPrompt
        lastPromptTimestamp = now
        
        chatMessages.append(FinancialChatMessage(text: cleanPrompt, isUser: true))
        saveChatHistory()
        isAiProcessing = true
        
        Task {
            defer {
                isAiProcessing = false
            }
            let allTxs = repository.getAllTransactionsSync()
            let allW = repository.getAllWalletsSync()
            let summary = financialSummary
            
            let resolvedWalletId: Int64? = scopeToAllWallets ? nil : (targetWalletId ?? activeWallet?.id ?? summary.activeWalletId)
            let currentBalances = repository.computeWalletBalances()
            
            // Verificación previa inmediata de confirmación/cancelación de transferencia por voz
            if let pending = pendingVoiceTransfer {
                let normPrompt = CategoryHelper.normalize(cleanPrompt).lowercased()
                let affirmativeWords = ["si", "sí", "estoy seguro", "proceder", "confirmo", "confirmar", "dale", "hazlo", "claro", "por supuesto", "adelante", "ok", "correcto", "de acuerdo", "yes"]
                let negativeWords = ["no", "cancela", "cancelar", "no transferir", "detener", "ya no", "no gracias", "espera"]
                
                if affirmativeWords.contains(where: { CategoryHelper.hasWordOrPhrase(normText: normPrompt, normTarget: $0) || normPrompt == $0 }) {
                    let (success, errorMsg) = executeTransfer(
                        sourceWalletId: pending.sourceWalletId,
                        destinationWalletId: pending.destinationWalletId,
                        amount: pending.amount,
                        detail: pending.detail
                    )
                    pendingVoiceTransfer = nil
                    let confirmationText: String
                    if success {
                        confirmationText = "✅ **¡Transferencia realizada con éxito!**\n\nSe han transferido **\(summary.currencySymbol) \(FormatHelper.formatCurrency(pending.amount))** de '**\(pending.sourceWalletName)**' a '**\(pending.destinationWalletName)**'."
                    } else {
                        confirmationText = "⚠️ No se pudo completar la transferencia: \(errorMsg ?? "Error desconocido")."
                    }
                    chatMessages.append(FinancialChatMessage(text: confirmationText, isUser: false))
                    saveChatHistory()
                    isAiProcessing = false
                    return
                } else if negativeWords.contains(where: { CategoryHelper.hasWordOrPhrase(normText: normPrompt, normTarget: $0) || normPrompt == $0 }) {
                    pendingVoiceTransfer = nil
                    chatMessages.append(FinancialChatMessage(text: "Entendido, he cancelado la transferencia.", isUser: false))
                    saveChatHistory()
                    isAiProcessing = false
                    return
                }
            }
            
            let activeWalletName: String = {
                if scopeToAllWallets {
                    return "Todas las billeteras"
                } else if let wId = resolvedWalletId, let found = allW.first(where: { $0.id == wId }) {
                    return found.name
                } else {
                    return activeWallet?.name ?? "BCP"
                }
            }()
            
            let targetBalance: Double = {
                if scopeToAllWallets {
                    return summary.currentBalance
                } else if let wId = resolvedWalletId {
                    return currentBalances[wId] ?? 0.0
                } else {
                    return summary.currentBalance
                }
            }()
            
            let desgloseSaldos = allW.map { w in
                let b = currentBalances[w.id] ?? 0.0
                let txCount = allTxs.filter { $0.walletId == w.id }.count
                return "\(w.name): \(summary.currencySymbol) \(FormatHelper.formatCurrency(b)) (\(txCount) movimientos registrados)"
            }.joined(separator: ", ")
            
            var handledByAi = false
            
            // Contexto completo de movimientos reales para consultas analíticas
            let dfFull = Self.chatDateFormatter
            
            let resumenMovimientos: String = {
                if allTxs.isEmpty {
                    return "Sin movimientos registrados en la app."
                }
                
                if !scopeToAllWallets, let wId = resolvedWalletId {
                    let walletTxs = allTxs.filter { $0.walletId == wId }
                    let otherTxs = allTxs.filter { $0.walletId != wId }
                    
                    var lines: [String] = []
                    lines.append("--- MOVIMIENTOS DE LA BILLETERA SELECCIONADA (\(activeWalletName)) ---")
                    if walletTxs.isEmpty {
                        lines.append("No hay movimientos registrados en la billetera \(activeWalletName).")
                    } else {
                        for tx in walletTxs.prefix(100) {
                            let dStr = dfFull.string(from: Date(timeIntervalSince1970: Double(tx.dateMillis) / 1000.0))
                            let tipoStr = tx.type == .income ? "INGRESO" : "GASTO"
                            lines.append("- [\(dStr)]: \(tipoStr) de \(summary.currencySymbol) \(FormatHelper.formatCurrency(tx.amount)) en \(tx.category) (Concepto: '\(tx.title)') [Billetera: \(activeWalletName)]")
                        }
                    }
                    
                    if !otherTxs.isEmpty {
                        lines.append("\n--- MOVIMIENTOS EN OTRAS BILLETERAS ---")
                        for tx in otherTxs.prefix(50) {
                            let dStr = dfFull.string(from: Date(timeIntervalSince1970: Double(tx.dateMillis) / 1000.0))
                            let tipoStr = tx.type == .income ? "INGRESO" : "GASTO"
                            let wName = allW.first(where: { $0.id == tx.walletId })?.name ?? "Otra billetera"
                            lines.append("- [\(dStr)]: \(tipoStr) de \(summary.currencySymbol) \(FormatHelper.formatCurrency(tx.amount)) en \(tx.category) (Concepto: '\(tx.title)') [Billetera: \(wName)]")
                        }
                    }
                    return lines.joined(separator: "\n")
                } else {
                    return allTxs.prefix(120).map { tx in
                        let dStr = dfFull.string(from: Date(timeIntervalSince1970: Double(tx.dateMillis) / 1000.0))
                        let tipoStr = tx.type == .income ? "INGRESO" : "GASTO"
                        let wName = allW.first(where: { $0.id == tx.walletId })?.name ?? "Billetera"
                        return "- [\(dStr)]: \(tipoStr) de \(summary.currencySymbol) \(FormatHelper.formatCurrency(tx.amount)) en \(tx.category) (Concepto: '\(tx.title)') [Billetera: \(wName)]"
                    }.joined(separator: "\n")
                }
            }()
            
            // Contexto de gastos fijos
            let allFixed = repository.getAllFixedExpensesSync()
            let resumenGastosFijos: String = {
                if allFixed.isEmpty {
                    return "Sin gastos fijos registrados en la app."
                }
                return allFixed.map { fe in
                    let wName = allW.first(where: { $0.id == fe.walletId })?.name ?? "Billetera"
                    return "- Gasto fijo: '\(fe.name)', Monto: \(summary.currencySymbol) \(FormatHelper.formatCurrency(fe.amount)), Categoría: \(fe.category), Frecuencia: \(fe.frequency.displayName), Billetera: \(wName)"
                }.joined(separator: "\n")
            }()
            
            let temporalRef = MoneyBotAIService.generateTemporalReference()
            
            // 0. Vía Rápida Local Ultrarrápida (<5ms):
            // Si la consulta es un movimiento financiero con montos ("Gasté 20 soles en taxi", "Pagué 50 soles por Yape"),
            // una confirmación de transferencia ("Sí", "Confirmo"), una hora faltante de ayer ("a las 3pm"),
            // o una consulta directa de saldo/gastos, se procesa en el dispositivo de forma instantánea sin demora de red.
            let normPrompt = CategoryHelper.normalize(cleanPrompt).lowercased()
            let hasNumbers = !AiExpenseParser.extractNumbersFromText(AiExpenseParser.convertSpanishNumberWordsInText(cleanPrompt)).isEmpty
            let isQuickFinancialMovement = AiExpenseParser.hasFinancialContext(normPrompt) && hasNumbers
            let isPendingConfirmation = pendingVoiceTransfer != nil || (!pendingAiTransactions.isEmpty && FormatHelper.parseHourAndMinute(from: cleanPrompt) != nil)
            let isDirectTransferIntent = (normPrompt.contains("transfiere") || normPrompt.contains("transferir") || normPrompt.contains("pasa ") || normPrompt.contains("pasar ")) && hasNumbers
            
            let isFactualQuery = self.isFactualLocalDataQuery(normPrompt, cleanPrompt: cleanPrompt)
            let shouldProcessLocallyFirst = isQuickFinancialMovement || isPendingConfirmation || isDirectTransferIntent || isFactualQuery
            
            if shouldProcessLocallyFirst {
                let localResponse = await FinancialAiAssistantEngine.processQuery(
                    rawQuery: cleanPrompt,
                    allTransactions: allTxs,
                    wallets: allW,
                    summary: summary,
                    selectedWalletId: resolvedWalletId,
                    pendingTransfer: pendingVoiceTransfer,
                    pendingTransactions: pendingAiTransactions,
                    fixedExpenses: allFixed
                )
                
                handledByAi = applyLocalAssistantResponse(
                    localResponse,
                    cleanPrompt: cleanPrompt,
                    temporalRef: temporalRef,
                    targetWalletId: targetWalletId,
                    resolvedWalletId: resolvedWalletId,
                    activeWalletName: activeWalletName,
                    allW: allW,
                    summary: summary,
                    currentBalances: currentBalances,
                    playAudioEffects: playAudioEffects
                )
            }
            
            // 1. Procesamiento real con Gemini (MoneyBotAIService) para consultas conversacionales o complejas
            if !handledByAi {
                do {
                    let aiResponse = try await MoneyBotAIService.shared.processQuery(
                    prompt: cleanPrompt,
                    billeteraActiva: activeWalletName,
                    currentBalance: targetBalance,
                    currencySymbol: summary.currencySymbol,
                    wallets: allW,
                    fechaHoy: temporalRef.fechaHoy,
                    horaActual: temporalRef.horaActual,
                    fechaAyer: temporalRef.fechaAyer,
                    transaccionPendiente: pendingAiTransactions.first,
                    transaccionesPendientes: pendingAiTransactions,
                    resumenMovimientos: resumenMovimientos,
                    resumenGastosFijos: resumenGastosFijos,
                    desgloseSaldos: desgloseSaldos,
                    chatHistory: chatMessages
                )
                
                switch aiResponse.intencion {
                case .REGISTRAR_TRANSACCION, .COMPLETAR_DATO_FALTANTE:
                    let parsedCleanPromptHour = FormatHelper.parseHourAndMinute(from: cleanPrompt)
                    
                    // Detectar si el usuario está introduciendo un nuevo monto monetario explícito
                    let mentionsNewAmount: Bool = {
                        let lower = cleanPrompt.lowercased()
                        let pattern = #"(?:\b(?:s\/?|soles?|dolares?|dólares?|pesos?|euros?)|(?<!\w)[\$€])\s*\d+|\d+\s*(?:soles?|dolares?|dólares?|pesos?|euros?)\b"#
                        return lower.range(of: pattern, options: .regularExpression) != nil
                    }()
                    
                    let isCompletingPending = (aiResponse.intencion == .COMPLETAR_DATO_FALTANTE)
                        || (!pendingAiTransactions.isEmpty && parsedCleanPromptHour != nil && !mentionsNewAmount)
                    
                    // Si el usuario introduce un nuevo gasto/ingreso explícito, cualquier pendiente anterior se descarta
                    if !isCompletingPending && aiResponse.intencion == .REGISTRAR_TRANSACCION && mentionsNewAmount {
                        pendingAiTransactions.removeAll()
                    }
                    
                    // 1. Filtrar transacciones listas para guardar. Si alguna tiene faltaHora == true, NO se guarda aún
                    var transactionsToRegister = aiResponse.transacciones.filter { !$0.faltaHora }
                    
                    // VALIDACIÓN ESTRICTA PALABRA POR PALABRA DEL USUARIO:
                    // Si el usuario dijo "ayer" o "el día de ayer" y no indicó hora para ese movimiento,
                    // NUNCA registrarlo hoy ni con la hora actual: moverlo obligatoriamente a pendingAiTransactions.
                    let promptLower = cleanPrompt.lowercased()
                    if !isCompletingPending && (promptLower.contains("ayer") || promptLower.contains("anoche")) {
                        let clauses = AiExpenseParser.splitClauses(cleanPrompt)
                        var validatedToRegister: [ExtractedTransaction] = []
                        
                        for tx in transactionsToRegister {
                            let txWords = [tx.titulo.lowercased(), tx.concepto.lowercased()].filter { !$0.isEmpty && $0 != "movimiento" }
                            let txHasExplicitHour = (tx.hora != nil && FormatHelper.parseHourAndMinute(from: tx.hora!) != nil)
                                || FormatHelper.parseHourAndMinute(from: tx.concepto) != nil
                                || FormatHelper.parseHourAndMinute(from: tx.titulo) != nil
                                || FormatHelper.extractHour(forKeywords: txWords, from: cleanPrompt) != nil
                            
                            let txBelongsToYesterday: Bool = {
                                if tx.fecha == temporalRef.isoAyer || tx.fecha.lowercased().contains("ayer") {
                                    return true
                                }
                                if promptLower.contains("hoy") {
                                    for cl in clauses {
                                        let clNorm = CategoryHelper.normalize(cl).lowercased()
                                        if (clNorm.contains("ayer") || clNorm.contains("anoche")) && txWords.contains(where: { clNorm.contains($0) }) {
                                            return true
                                        }
                                    }
                                    return false
                                }
                                return true
                            }()
                            
                            if txBelongsToYesterday && !txHasExplicitHour {
                                var pendingTx = tx
                                pendingTx.fecha = temporalRef.isoAyer
                                pendingTx.hora = nil
                                pendingTx.faltaHora = true
                                pendingTx.concepto = cleanPrompt
                                let catFromTitle = CategoryHelper.resolveCategory(nameOrKeyword: pendingTx.titulo, type: pendingTx.tipo.toAppType)
                                if catFromTitle != "Otros" && catFromTitle != "Otros Ingresos" {
                                    pendingTx.categoria = catFromTitle
                                } else if pendingTx.categoria.isEmpty || pendingTx.categoria == "Otros" {
                                    pendingTx.categoria = CategoryHelper.resolveCategory(nameOrKeyword: "\(pendingTx.titulo) \(cleanPrompt)", type: pendingTx.tipo.toAppType)
                                }
                                if !pendingAiTransactions.contains(where: { $0.titulo.lowercased() == pendingTx.titulo.lowercased() && abs($0.monto - pendingTx.monto) < 0.01 }) {
                                    pendingAiTransactions.append(pendingTx)
                                }
                            } else {
                                var validTx = tx
                                if txBelongsToYesterday {
                                    validTx.fecha = temporalRef.isoAyer
                                }
                                validatedToRegister.append(validTx)
                            }
                        }
                        transactionsToRegister = validatedToRegister
                    }
                    
                    // Si se está completando pendiente y transactionsToRegister quedó vacía porque faltaHora era true en la IA:
                    if isCompletingPending, transactionsToRegister.isEmpty, let firstTx = aiResponse.transacciones.first {
                        transactionsToRegister = [firstTx]
                    }
                    
                    // Si transaccionesToRegister quedó vacía pero la IA devolvió transaccionEnEspera sin esperar al usuario:
                    if transactionsToRegister.isEmpty, let enEspera = aiResponse.transaccionEnEspera, !aiResponse.esperaRespuestaUsuario {
                        var fixed = enEspera
                        fixed.faltaHora = false
                        transactionsToRegister = [fixed]
                    }
                    
                    // Si se está completando un dato faltante real
                    if isCompletingPending, !pendingAiTransactions.isEmpty {
                        if !transactionsToRegister.isEmpty {
                            // Sincronizar atributos de las transacciones completadas con las pendientes en cola
                            transactionsToRegister = transactionsToRegister.enumerated().map { index, tx in
                                var fixed = tx
                                // Encontrar la transacción pendiente correspondiente por título, concepto o monto
                                let matchedPending: ExtractedTransaction = {
                                    // 1. Coincidencia por título o concepto
                                    let txWords = "\(tx.titulo) \(tx.concepto)".lowercased()
                                    if let match = pendingAiTransactions.first(where: { p in
                                        let pWords = "\(p.titulo) \(p.concepto)".lowercased()
                                        let normTx = CategoryHelper.normalize(txWords)
                                        let normP = CategoryHelper.normalize(pWords)
                                        return (!pWords.isEmpty && (txWords.contains(pWords) || pWords.contains(txWords))) ||
                                               (!normP.isEmpty && (normTx.contains(normP) || normP.contains(normTx)))
                                    }) {
                                        return match
                                    }
                                    // 2. Coincidencia por monto exacto
                                    if tx.monto > 0.01, let match = pendingAiTransactions.first(where: { abs($0.monto - tx.monto) < 0.01 }) {
                                        return match
                                    }
                                    // 3. Fallback por índice
                                    if index < pendingAiTransactions.count {
                                        return pendingAiTransactions[index]
                                    }
                                    return pendingAiTransactions.first ?? tx
                                }()
                                
                                fixed.tipo = matchedPending.tipo
                                if fixed.monto <= 0.01 {
                                    fixed.monto = matchedPending.monto
                                }
                                if !matchedPending.fecha.isEmpty {
                                    fixed.fecha = matchedPending.fecha
                                } else {
                                    fixed.fecha = temporalRef.isoAyer
                                }
                                
                                let userSaidOnlyHour = (parsedCleanPromptHour != nil && !mentionsNewAmount)
                                let isHourConcept = (fixed.concepto.count < 30 && FormatHelper.parseHourAndMinute(from: fixed.concepto) != nil)
                                    || fixed.concepto.caseInsensitiveCompare(cleanPrompt) == .orderedSame
                                    || fixed.concepto.isEmpty
                                    || fixed.concepto.lowercased() == "movimiento"
                                
                                if isHourConcept || userSaidOnlyHour || !matchedPending.concepto.isEmpty {
                                    fixed.concepto = (!matchedPending.concepto.isEmpty && matchedPending.concepto.lowercased() != "movimiento")
                                        ? matchedPending.concepto
                                        : (!matchedPending.titulo.isEmpty ? matchedPending.titulo : cleanPrompt)
                                }
                                
                                let isHourTitle = (fixed.titulo.count < 30 && FormatHelper.parseHourAndMinute(from: fixed.titulo) != nil)
                                    || fixed.titulo.caseInsensitiveCompare(cleanPrompt) == .orderedSame
                                    || fixed.titulo.isEmpty
                                    || fixed.titulo.lowercased() == "movimiento"
                                
                                if isHourTitle || userSaidOnlyHour {
                                    fixed.titulo = (!matchedPending.titulo.isEmpty && matchedPending.titulo.lowercased() != "movimiento")
                                        ? matchedPending.titulo
                                        : fixed.titulo
                                }
                                
                                let catFromTitle = CategoryHelper.resolveCategory(nameOrKeyword: fixed.titulo, type: fixed.tipo.toAppType)
                                if catFromTitle != "Otros" && catFromTitle != "Otros Ingresos" {
                                    fixed.categoria = catFromTitle
                                } else if !matchedPending.categoria.isEmpty && matchedPending.categoria != "Otros" && matchedPending.categoria != "Otros Ingresos" {
                                    fixed.categoria = matchedPending.categoria
                                } else {
                                    fixed.categoria = CategoryHelper.resolveCategory(nameOrKeyword: "\(fixed.titulo) \(fixed.concepto)", type: fixed.tipo.toAppType)
                                }
                                
                                // CRÍTICO: Resolver la hora individual de CADA transacción sin sobreescribir la de otras transacciones
                                if let txH = tx.hora, let hm = FormatHelper.parseHourAndMinute(from: txH) {
                                    // 1. Hora específica ya resuelta por la IA para este movimiento
                                    fixed.hora = String(format: "%02d:%02d", hm.hour, hm.minute)
                                } else if let hm = FormatHelper.parseHourAndMinute(from: tx.concepto) ?? FormatHelper.parseHourAndMinute(from: tx.titulo) {
                                    // 2. Hora encontrada en el concepto o título de esta transacción
                                    fixed.hora = String(format: "%02d:%02d", hm.hour, hm.minute)
                                } else if let hm = FormatHelper.extractHour(forKeywords: [tx.titulo, tx.concepto, matchedPending.titulo, matchedPending.concepto], from: cleanPrompt) {
                                    // 3. Extraer la hora asociada a esta transacción en la respuesta del usuario
                                    fixed.hora = String(format: "%02d:%02d", hm.hour, hm.minute)
                                } else {
                                    // 4. Si hay múltiples horas en el texto del usuario, asignar por orden
                                    let allHours = FormatHelper.parseAllHoursAndMinutes(from: cleanPrompt)
                                    if index < allHours.count {
                                        let hm = allHours[index]
                                        fixed.hora = String(format: "%02d:%02d", hm.hour, hm.minute)
                                    } else if transactionsToRegister.count == 1, let hm = parsedCleanPromptHour {
                                        fixed.hora = String(format: "%02d:%02d", hm.hour, hm.minute)
                                    }
                                }
                                fixed.faltaHora = false
                                return fixed
                            }
                        } else if pendingAiTransactions.count > 1 {
                            let allHours = FormatHelper.parseAllHoursAndMinutes(from: cleanPrompt)
                            if allHours.count >= pendingAiTransactions.count {
                                // El usuario respondió las horas de todas las transacciones pendientes a la vez
                                transactionsToRegister = pendingAiTransactions.enumerated().map { index, pending in
                                    var tx = pending
                                    tx.faltaHora = false
                                    if let hm = FormatHelper.extractHour(forKeywords: [pending.titulo, pending.concepto], from: cleanPrompt) {
                                        tx.hora = String(format: "%02d:%02d", hm.hour, hm.minute)
                                    } else if index < allHours.count {
                                        let hm = allHours[index]
                                        tx.hora = String(format: "%02d:%02d", hm.hour, hm.minute)
                                    }
                                    if tx.fecha.isEmpty { tx.fecha = temporalRef.isoAyer }
                                    let catFromTitle = CategoryHelper.resolveCategory(nameOrKeyword: tx.titulo, type: tx.tipo.toAppType)
                                    if catFromTitle != "Otros" && catFromTitle != "Otros Ingresos" {
                                        tx.categoria = catFromTitle
                                    }
                                    return tx
                                }
                            } else if let pending = pendingAiTransactions.first {
                                var completedTx = pending
                                completedTx.faltaHora = false
                                if let hm = FormatHelper.extractHour(forKeywords: [pending.titulo, pending.concepto], from: cleanPrompt) ?? parsedCleanPromptHour {
                                    completedTx.hora = String(format: "%02d:%02d", hm.hour, hm.minute)
                                } else if let h = aiResponse.hora, !h.isEmpty {
                                    completedTx.hora = h
                                } else {
                                    completedTx.hora = cleanPrompt
                                }
                                if completedTx.fecha.isEmpty { completedTx.fecha = temporalRef.isoAyer }
                                let catFromTitle = CategoryHelper.resolveCategory(nameOrKeyword: completedTx.titulo, type: completedTx.tipo.toAppType)
                                if catFromTitle != "Otros" && catFromTitle != "Otros Ingresos" {
                                    completedTx.categoria = catFromTitle
                                }
                                transactionsToRegister = [completedTx]
                            }
                        } else if let pending = pendingAiTransactions.first {
                            // Reconstruir la única transacción pendiente en cola con la hora dictada
                            var completedTx = pending
                            completedTx.faltaHora = false
                            if let hm = FormatHelper.extractHour(forKeywords: [pending.titulo, pending.concepto], from: cleanPrompt) ?? parsedCleanPromptHour {
                                completedTx.hora = String(format: "%02d:%02d", hm.hour, hm.minute)
                            } else if let h = aiResponse.hora, !h.isEmpty {
                                completedTx.hora = h
                            } else {
                                completedTx.hora = cleanPrompt
                            }
                            if !pending.fecha.isEmpty {
                                completedTx.fecha = pending.fecha
                            } else if let rFecha = aiResponse.fecha, !rFecha.isEmpty {
                                completedTx.fecha = rFecha
                            } else {
                                completedTx.fecha = temporalRef.isoAyer
                            }
                            let catFromTitle = CategoryHelper.resolveCategory(nameOrKeyword: completedTx.titulo, type: completedTx.tipo.toAppType)
                            if catFromTitle != "Otros" && catFromTitle != "Otros Ingresos" {
                                completedTx.categoria = catFromTitle
                            }
                            transactionsToRegister = [completedTx]
                        }
                    }
                    
                    // Fallback de rescate: Si Gemini indicó REGISTRAR_TRANSACCION pero no emitió transacciones en JSON,
                    // extraer automáticamente el monto y categoría de cleanPrompt para garantizar inserción en la billetera
                    if transactionsToRegister.isEmpty && aiResponse.intencion == .REGISTRAR_TRANSACCION && !aiResponse.esperaRespuestaUsuario {
                        let lower = cleanPrompt.lowercased()
                        let isIncome = lower.contains("ingreso") || lower.contains("cobr") || lower.contains("sueldo") || lower.contains("salario") || lower.contains("gan")
                        let txType: AITransactionType = isIncome ? .INGRESO : .GASTO
                        
                        var detectedAmount: Double = 0.0
                        let numPattern = #"(?:s\/?|\$)?\s*(\d+(?:[.,]\d+)?)"#
                        if let r = try? NSRegularExpression(pattern: numPattern, options: .caseInsensitive),
                           let m = r.firstMatch(in: cleanPrompt, range: NSRange(location: 0, length: cleanPrompt.utf16.count)) {
                            let ns = cleanPrompt as NSString
                            let numStr = ns.substring(with: m.range(at: 1)).replacingOccurrences(of: ",", with: ".")
                            detectedAmount = Double(numStr) ?? 0.0
                        }
                        
                        let parseRes = AiExpenseParser.parseLocallyResult(cleanPrompt)
                        if case .success(let drafts) = parseRes, let firstDraft = drafts.first {
                            let fallbackTx = ExtractedTransaction(
                                titulo: firstDraft.title,
                                concepto: cleanPrompt,
                                categoria: firstDraft.category,
                                monto: firstDraft.amount,
                                tipo: firstDraft.type == .income ? .INGRESO : .GASTO,
                                fecha: temporalRef.isoHoy,
                                hora: temporalRef.horaActual,
                                faltaHora: false,
                                billetera: activeWalletName
                            )
                            transactionsToRegister = [fallbackTx]
                        } else if detectedAmount > 0.0 {
                            let fallbackTx = ExtractedTransaction(
                                titulo: String(cleanPrompt.prefix(30)),
                                concepto: cleanPrompt,
                                categoria: isIncome ? "Otros Ingresos" : "Otros",
                                monto: detectedAmount,
                                tipo: txType,
                                fecha: temporalRef.isoHoy,
                                hora: temporalRef.horaActual,
                                faltaHora: false,
                                billetera: activeWalletName
                            )
                            transactionsToRegister = [fallbackTx]
                        }
                    }
                    
                    if !transactionsToRegister.isEmpty {
                        // Determinar billetera destino exacta si fue mencionada
                        let finalWalletId: Int64
                        if let wName = transactionsToRegister.compactMap({ $0.billetera }).first,
                           let foundW = allW.first(where: { CategoryHelper.normalize($0.name).localizedCaseInsensitiveContains(CategoryHelper.normalize(wName)) }) {
                            finalWalletId = foundW.id
                        } else {
                            finalWalletId = targetWalletId ?? resolvedWalletId ?? activeWallet?.id ?? summary.activeWalletId
                        }
                        
                        let targetWalletBal = currentBalances[finalWalletId] ?? summary.currentBalance
                        let totalIncome = transactionsToRegister.filter { $0.tipo == .INGRESO }.reduce(0.0) { $0 + $1.monto }
                        var runningBal = targetWalletBal + totalIncome
                        var hasInsufficient = false
                        
                        for tx in transactionsToRegister where tx.tipo == .GASTO {
                            if tx.monto > (runningBal + 0.001) {
                                hasInsufficient = true
                                break
                            }
                            runningBal -= tx.monto
                        }
                        
                        if hasInsufficient {
                            let targetWalletName = allW.first(where: { $0.id == finalWalletId })?.name ?? "tu billetera"
                            chatMessages.append(FinancialChatMessage(text: "Ups, No te queda saldo suficiente en \(targetWalletName) para realizar este movimiento.", isUser: false))
                            saveChatHistory()
                            isAiProcessing = false
                            return
                        }
                        
                        let cal = Calendar.current
                        let now = Date()
                        let noteForCompletedTx: String = {
                            if isCompletingPending, let pending = pendingAiTransaction, !pending.concepto.isEmpty {
                                return pending.concepto
                            }
                            return cleanPrompt
                        }()
                        
                        for tx in transactionsToRegister {
                            let txDateMillis: Int64 = {
                                // 1. Extraer hora y minuto si el usuario o la IA dictaron una hora explícita para este movimiento
                                let hourAndMinute = tx.hora.flatMap { FormatHelper.parseHourAndMinute(from: $0) }
                                    ?? FormatHelper.parseHourAndMinute(from: tx.concepto)
                                    ?? FormatHelper.parseHourAndMinute(from: tx.titulo)
                                    ?? FormatHelper.extractHour(forKeywords: [tx.titulo, tx.concepto], from: cleanPrompt)
                                    ?? (transactionsToRegister.count == 1 ? parsedCleanPromptHour : nil)
                                
                                // 2. Determinar si el movimiento pertenece a ayer de forma precisa por transacción
                                let txFechaLower = tx.fecha.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                let txConceptoLower = tx.concepto.lowercased()
                                let txTituloLower = tx.titulo.lowercased()
                                
                                let isYesterday: Bool
                                if txFechaLower == temporalRef.isoAyer || txFechaLower.contains("ayer") {
                                    isYesterday = true
                                } else if txFechaLower == temporalRef.isoHoy || txFechaLower.contains("hoy") {
                                    isYesterday = false
                                } else if isCompletingPending {
                                    isYesterday = (tx.fecha.contains("ayer") || tx.fecha == temporalRef.isoAyer || (pendingAiTransactions.first?.fecha.contains("ayer") ?? true))
                                } else if txConceptoLower.contains("ayer") && !txConceptoLower.contains("hoy") {
                                    isYesterday = true
                                } else if txTituloLower.contains("ayer") && !txTituloLower.contains("hoy") {
                                    isYesterday = true
                                } else {
                                    isYesterday = false
                                }
                                
                                if isYesterday {
                                    let yesterday = cal.date(byAdding: .day, value: -1, to: now) ?? now
                                    let (h, m): (Int, Int) = {
                                        if let hm = hourAndMinute {
                                            return (hm.hour, hm.minute)
                                        }
                                        return (cal.component(.hour, from: now), cal.component(.minute, from: now))
                                    }()
                                    let combined = cal.date(bySettingHour: h, minute: m, second: 0, of: yesterday) ?? yesterday
                                    return Int64(combined.timeIntervalSince1970 * 1000)
                                } else {
                                    // Es de HOY:
                                    if let hm = hourAndMinute {
                                        // Hora explícita dictada hoy (ej: "a las 8:15 am" o "14:00")
                                        let combined = cal.date(bySettingHour: hm.hour, minute: hm.minute, second: 0, of: now) ?? now
                                        return Int64(combined.timeIntervalSince1970 * 1000)
                                    } else {
                                        // NO se dictó hora: usar exactamente la fecha, hora y minuto actuales del dispositivo en tiempo real
                                        return Int64(now.timeIntervalSince1970 * 1000)
                                    }
                                }
                            }()
                            
                            let txTitle: String = {
                                let t = tx.titulo.trimmingCharacters(in: .whitespacesAndNewlines)
                                let isTValid = !t.isEmpty && t.lowercased() != "movimiento" && t.caseInsensitiveCompare(cleanPrompt) != .orderedSame && (t.count >= 25 || FormatHelper.parseHourAndMinute(from: t) == nil)
                                if isTValid {
                                    return String(t.prefix(30))
                                }
                                if isCompletingPending, let matched = pendingAiTransactions.first, !matched.titulo.isEmpty && matched.titulo.lowercased() != "movimiento" {
                                    return String(matched.titulo.prefix(30))
                                }
                                let c = tx.concepto.trimmingCharacters(in: .whitespacesAndNewlines)
                                let isCValid = !c.isEmpty && c.lowercased() != "movimiento" && c.caseInsensitiveCompare(cleanPrompt) != .orderedSame && (c.count >= 25 || FormatHelper.parseHourAndMinute(from: c) == nil)
                                if isCValid {
                                    return String(c.prefix(30))
                                }
                                return String(cleanPrompt.prefix(30))
                            }()
                            
                            let noteText: String = {
                                let c = tx.concepto.trimmingCharacters(in: .whitespacesAndNewlines)
                                let isCHour = (c.count < 25 && FormatHelper.parseHourAndMinute(from: c) != nil) || c.caseInsensitiveCompare(cleanPrompt) == .orderedSame
                                if !c.isEmpty && c.lowercased() != "movimiento" && !isCHour {
                                    return c
                                }
                                if isCompletingPending, let matched = pendingAiTransactions.first, !matched.concepto.isEmpty && matched.concepto.lowercased() != "movimiento" {
                                    return matched.concepto
                                }
                                let t = tx.titulo.trimmingCharacters(in: .whitespacesAndNewlines)
                                let isTHour = (t.count < 25 && FormatHelper.parseHourAndMinute(from: t) != nil) || t.caseInsensitiveCompare(cleanPrompt) == .orderedSame
                                if !t.isEmpty && t.lowercased() != "movimiento" && !isTHour {
                                    return t
                                }
                                return cleanPrompt
                            }()
                            let formattedNote = AiExpenseParser.formatSpokenNoteToDigits(noteText)
                            let finalCategory: String = {
                                let catFromTitle = CategoryHelper.resolveCategory(nameOrKeyword: txTitle, type: tx.tipo.toAppType)
                                if catFromTitle != "Otros" && catFromTitle != "Otros Ingresos" {
                                    return catFromTitle
                                }
                                let catFromTx = CategoryHelper.resolveCategory(nameOrKeyword: tx.categoria, type: tx.tipo.toAppType)
                                if catFromTx != "Otros" && catFromTx != "Otros Ingresos" {
                                    return catFromTx
                                }
                                return CategoryHelper.resolveCategory(nameOrKeyword: "\(txTitle) \(noteText)", type: tx.tipo.toAppType)
                            }()
                            let newTx = Transaction(
                                title: txTitle,
                                amount: tx.monto,
                                type: tx.tipo.toAppType,
                                category: finalCategory,
                                dateMillis: txDateMillis,
                                notes: String(formattedNote.prefix(250)),
                                walletId: finalWalletId
                            )
                            _ = repository.insertTransaction(newTx)
                            if playAudioEffects {
                                SoundManager.shared.playSoundForType(tx.tipo.toAppType, isSoundEnabled: summary.soundsEnabled)
                            }
                        }
                        
                        var confirmationText: String
                        if !aiResponse.razonamiento.isEmpty {
                            confirmationText = aiResponse.razonamiento
                        } else {
                            let cur = summary.currencySymbol
                            let desc = transactionsToRegister.map { t in
                                let tipoStr = t.tipo == .INGRESO ? "Ingreso" : "Gasto"
                                let catResolved = CategoryHelper.resolveCategory(nameOrKeyword: t.categoria, type: t.tipo.toAppType)
                                return "\(tipoStr) de \(cur) \(FormatHelper.formatCurrency(t.monto)) en \(catResolved) ('\(t.titulo)')"
                            }.joined(separator: ", ")
                            confirmationText = "¡Movimiento registrado con éxito! \(desc)"
                        }
                        
                        // Si se estaba completando un ingreso pendiente, sanitizar para que nunca diga "tu gasto"
                        if isCompletingPending, let pending = pendingAiTransaction, pending.tipo == .INGRESO {
                            confirmationText = confirmationText
                                .replacingOccurrences(of: "tu gasto", with: "tu ingreso")
                                .replacingOccurrences(of: "tu Gasto", with: "tu Ingreso")
                                .replacingOccurrences(of: "el gasto", with: "el ingreso")
                        }
                        
                        // Actualizar la cola de transacciones pendientes en espera
                        if aiResponse.esperaRespuestaUsuario {
                            if !aiResponse.transaccionesEnEspera.isEmpty {
                                pendingAiTransactions = aiResponse.transaccionesEnEspera.map { tx in
                                    var fixed = tx
                                    if fixed.fecha.isEmpty { fixed.fecha = temporalRef.isoAyer }
                                    fixed.concepto = cleanPrompt
                                    let catFromTitle = CategoryHelper.resolveCategory(nameOrKeyword: fixed.titulo, type: fixed.tipo.toAppType)
                                    if catFromTitle != "Otros" && catFromTitle != "Otros Ingresos" {
                                        fixed.categoria = catFromTitle
                                    } else if fixed.categoria.isEmpty || fixed.categoria == "Otros" {
                                        fixed.categoria = CategoryHelper.resolveCategory(nameOrKeyword: "\(fixed.titulo) \(cleanPrompt)", type: fixed.tipo.toAppType)
                                    }
                                    return fixed
                                }
                            } else if let single = aiResponse.transaccionEnEspera {
                                var fixed = single
                                if fixed.fecha.isEmpty { fixed.fecha = temporalRef.isoAyer }
                                fixed.concepto = cleanPrompt
                                let catFromTitle = CategoryHelper.resolveCategory(nameOrKeyword: fixed.titulo, type: fixed.tipo.toAppType)
                                if catFromTitle != "Otros" && catFromTitle != "Otros Ingresos" {
                                    fixed.categoria = catFromTitle
                                } else if fixed.categoria.isEmpty || fixed.categoria == "Otros" {
                                    fixed.categoria = CategoryHelper.resolveCategory(nameOrKeyword: "\(fixed.titulo) \(cleanPrompt)", type: fixed.tipo.toAppType)
                                }
                                pendingAiTransactions = [fixed]
                            } else {
                                // Si la IA no devolvió arreglo pero sigue esperando, descontar las transacciones registradas de nuestra cola
                                for reg in transactionsToRegister {
                                    if let idx = pendingAiTransactions.firstIndex(where: { $0.titulo.lowercased() == reg.titulo.lowercased() || abs($0.monto - reg.monto) < 0.01 }) {
                                        pendingAiTransactions.remove(at: idx)
                                    } else if !pendingAiTransactions.isEmpty {
                                        pendingAiTransactions.removeFirst()
                                    }
                                }
                            }
                        } else if isCompletingPending {
                            // Se completaron transacciones y no hay más en espera según la IA
                            for reg in transactionsToRegister {
                                if let idx = pendingAiTransactions.firstIndex(where: { $0.titulo.lowercased() == reg.titulo.lowercased() || abs($0.monto - reg.monto) < 0.01 }) {
                                    pendingAiTransactions.remove(at: idx)
                                } else if !pendingAiTransactions.isEmpty {
                                    pendingAiTransactions.removeFirst()
                                }
                            }
                        } else {
                            pendingAiTransactions.removeAll()
                        }
                        
                        // Si aún quedan transacciones pendientes en la cola y el texto de confirmación no pregunta por la siguiente, añadir la pregunta
                        if let nextPending = pendingAiTransactions.first,
                           !confirmationText.contains(nextPending.titulo) && !confirmationText.contains(String(format: "%.0f", nextPending.monto)) {
                            let nextName = !nextPending.titulo.isEmpty && nextPending.titulo.lowercased() != "movimiento" ? nextPending.titulo : "gasto"
                            confirmationText += " ¿A qué hora exacta realizaste el gasto de \(summary.currencySymbol) \(FormatHelper.formatCurrency(nextPending.monto)) en \(nextName) el día de ayer?"
                        }
                        
                        // Sincronizar billetera activa para que muestre la billetera donde se guardó el movimiento
                        if let activeW = self.activeWallet, activeW.id != finalWalletId {
                            repository.switchActiveWallet(finalWalletId)
                        }
                        
                        // Restablecer filtros para que el movimiento nuevo aparezca inmediatamente
                        self.selectedFilter = .all
                        self.selectedDateFilter = .all
                        self.searchQuery = ""
                        
                        chatMessages.append(FinancialChatMessage(text: confirmationText, isUser: false, isRegisteredMovement: true))
                        saveChatHistory()
                        activeTab = 0
                        triggerScrollToTop()
                        refreshData()
                        handledByAi = true
                    } else {
                        // Caso donde no hay movimientos listos porque todos están en espera de hora
                        if aiResponse.esperaRespuestaUsuario {
                            if !aiResponse.transaccionesEnEspera.isEmpty {
                                pendingAiTransactions = aiResponse.transaccionesEnEspera.map { tx in
                                    var fixed = tx
                                    if fixed.fecha.isEmpty { fixed.fecha = temporalRef.isoAyer }
                                    fixed.concepto = cleanPrompt
                                    let catFromTitle = CategoryHelper.resolveCategory(nameOrKeyword: fixed.titulo, type: fixed.tipo.toAppType)
                                    if catFromTitle != "Otros" && catFromTitle != "Otros Ingresos" {
                                        fixed.categoria = catFromTitle
                                    } else if fixed.categoria.isEmpty || fixed.categoria == "Otros" {
                                        fixed.categoria = CategoryHelper.resolveCategory(nameOrKeyword: "\(fixed.titulo) \(cleanPrompt)", type: fixed.tipo.toAppType)
                                    }
                                    return fixed
                                }
                            } else if let single = aiResponse.transaccionEnEspera {
                                var fixed = single
                                if fixed.fecha.isEmpty { fixed.fecha = temporalRef.isoAyer }
                                fixed.concepto = cleanPrompt
                                let catFromTitle = CategoryHelper.resolveCategory(nameOrKeyword: fixed.titulo, type: fixed.tipo.toAppType)
                                if catFromTitle != "Otros" && catFromTitle != "Otros Ingresos" {
                                    fixed.categoria = catFromTitle
                                } else if fixed.categoria.isEmpty || fixed.categoria == "Otros" {
                                    fixed.categoria = CategoryHelper.resolveCategory(nameOrKeyword: "\(fixed.titulo) \(cleanPrompt)", type: fixed.tipo.toAppType)
                                }
                                pendingAiTransactions = [fixed]
                            }
                        } else if pendingAiTransactions.isEmpty {
                            pendingAiTransactions.removeAll()
                        }
                        
                        var reasonMsg = aiResponse.razonamiento
                        if (reasonMsg.isEmpty || !reasonMsg.contains("¿A qué hora")) && !pendingAiTransactions.isEmpty, let p = pendingAiTransactions.first {
                            let nextName = !p.titulo.isEmpty && p.titulo.lowercased() != "movimiento" ? p.titulo : "gasto"
                            reasonMsg = "¿A qué hora exacta realizaste el gasto de \(summary.currencySymbol) \(FormatHelper.formatCurrency(p.monto)) en \(nextName) el día de ayer?"
                        }
                        if !reasonMsg.isEmpty {
                            chatMessages.append(FinancialChatMessage(text: reasonMsg, isUser: false))
                            saveChatHistory()
                            handledByAi = true
                        }
                    }
                    
                case .TRANSFERIR_DINERO:
                    if let transfer = aiResponse.transferencia,
                       let monto = transfer.monto, monto > 0 {
                        let sourceName = transfer.origen ?? activeWalletName
                        let destName = transfer.destino ?? ""
                        
                        let foundDest = allW.first(where: { 
                            let n = CategoryHelper.normalize($0.name).lowercased()
                            let dn = CategoryHelper.normalize(destName).lowercased()
                            return n == dn || n.contains(dn) || dn.contains(n)
                        })
                        
                        guard let destWallet = foundDest else {
                            let availableList = allW.map { "• " + $0.name }.joined(separator: "\n")
                            let msg = "⚠️ No encontré una billetera llamada '**\(destName.capitalized)**'.\n\nTus billeteras disponibles son:\n\(availableList)\n\nPor favor, indica una de tus billeteras registradas para transferir."
                            chatMessages.append(FinancialChatMessage(text: msg, isUser: false))
                            saveChatHistory()
                            handledByAi = true
                            break
                        }
                        
                        let foundSource = allW.first(where: { 
                            let n = CategoryHelper.normalize($0.name).lowercased()
                            let sn = CategoryHelper.normalize(sourceName).lowercased()
                            return n == sn || n.contains(sn) || sn.contains(n)
                        }) ?? (allW.first(where: { $0.id == (resolvedWalletId ?? summary.activeWalletId) }) ?? allW.first)
                        
                        guard let sourceWallet = foundSource else {
                            let msg = "⚠️ No se pudo determinar la billetera de origen."
                            chatMessages.append(FinancialChatMessage(text: msg, isUser: false))
                            saveChatHistory()
                            handledByAi = true
                            break
                        }
                        
                        if sourceWallet.id == destWallet.id {
                            let msg = "⚠️ La billetera de origen y destino no pueden ser la misma ('\(sourceWallet.name)'). Elige otra billetera receptora."
                            chatMessages.append(FinancialChatMessage(text: msg, isUser: false))
                            saveChatHistory()
                            handledByAi = true
                            break
                        }
                        
                        let sourceBal = currentBalances[sourceWallet.id] ?? 0.0
                        if sourceBal < (monto - 0.001) {
                            let msg = "⚠️ Saldo insuficiente en tu billetera '**\(sourceWallet.name)**'. Tu saldo disponible es de \(summary.currencySymbol) \(FormatHelper.formatCurrency(sourceBal)) y deseas transferir \(summary.currencySymbol) \(FormatHelper.formatCurrency(monto))."
                            chatMessages.append(FinancialChatMessage(text: msg, isUser: false))
                            saveChatHistory()
                            handledByAi = true
                            break
                        }
                        
                        pendingVoiceTransfer = PendingTransferVoiceState(
                            sourceWalletId: sourceWallet.id,
                            sourceWalletName: sourceWallet.name,
                            destinationWalletId: destWallet.id,
                            destinationWalletName: destWallet.name,
                            amount: monto,
                            detail: "Transferencia por voz con MoneyBot"
                        )
                        let confirmQuestion = "¿Estás seguro de que deseas transferir **\(summary.currencySymbol) \(FormatHelper.formatCurrency(monto))** de '**\(sourceWallet.name)**' a '**\(destWallet.name)**'?"
                        chatMessages.append(FinancialChatMessage(text: confirmQuestion, isUser: false))
                        saveChatHistory()
                        handledByAi = true
                    } else {
                        if !aiResponse.razonamiento.isEmpty {
                            chatMessages.append(FinancialChatMessage(text: aiResponse.razonamiento, isUser: false))
                            saveChatHistory()
                            handledByAi = true
                        }
                    }

                case .CONFIRMAR_TRANSFERENCIA:
                    if let pending = pendingVoiceTransfer {
                        let (success, errorMsg) = executeTransfer(
                            sourceWalletId: pending.sourceWalletId,
                            destinationWalletId: pending.destinationWalletId,
                            amount: pending.amount,
                            detail: pending.detail
                        )
                        pendingVoiceTransfer = nil
                        let textMsg: String
                        if success {
                            textMsg = "✅ **¡Transferencia realizada con éxito!**\n\nSe han transferido **\(summary.currencySymbol) \(FormatHelper.formatCurrency(pending.amount))** de '**\(pending.sourceWalletName)**' a '**\(pending.destinationWalletName)**'."
                        } else {
                            textMsg = "⚠️ No se pudo completar la transferencia: \(errorMsg ?? "Error desconocido")."
                        }
                        chatMessages.append(FinancialChatMessage(text: textMsg, isUser: false))
                        saveChatHistory()
                        handledByAi = true
                    } else {
                        if !aiResponse.razonamiento.isEmpty {
                            chatMessages.append(FinancialChatMessage(text: aiResponse.razonamiento, isUser: false))
                            saveChatHistory()
                            handledByAi = true
                        }
                    }

                case .CONSULTAR_BALANCE, .SOLICITAR_CONSEJO, .CONSULTA_ANALITICA, .CONSULTA_GASTOS_FIJOS, .CONVERSACIONAL, .DESCONOCIDA:
                    let replyText = !aiResponse.razonamiento.isEmpty ? aiResponse.razonamiento : "Listo, he procesado tu solicitud."
                    chatMessages.append(FinancialChatMessage(text: replyText, isUser: false))
                    saveChatHistory()
                    handledByAi = true
                }
            } catch {
                print("MoneyBot AIService fallo: \(error.localizedDescription)")
            }
        }
            
        // 2. Fallback local final si la IA remota no pudo responder
        if !handledByAi {
            let fallbackResponse = await FinancialAiAssistantEngine.processQuery(
                rawQuery: cleanPrompt,
                allTransactions: allTxs,
                wallets: allW,
                summary: summary,
                selectedWalletId: resolvedWalletId,
                pendingTransfer: pendingVoiceTransfer,
                pendingTransactions: pendingAiTransactions,
                fixedExpenses: allFixed
            )
            let handled = applyLocalAssistantResponse(
                fallbackResponse,
                cleanPrompt: cleanPrompt,
                temporalRef: temporalRef,
                targetWalletId: targetWalletId,
                resolvedWalletId: resolvedWalletId,
                activeWalletName: activeWalletName,
                allW: allW,
                summary: summary,
                currentBalances: currentBalances,
                playAudioEffects: playAudioEffects
            )
            if !handled {
                let fallbackText = "No logré entender tu consulta. Puedes preguntarme por tu saldo, cuánto has gastado hoy o dictar un gasto."
                chatMessages.append(FinancialChatMessage(text: fallbackText, isUser: false))
                saveChatHistory()
            }
        }
            isAiProcessing = false
        }
    }
    
    private func isFactualLocalDataQuery(_ norm: String, cleanPrompt: String) -> Bool {
        // Excluir si pide consejo o asesoría abierta que amerite análisis profundo de IA
        if norm.contains("consejo") || norm.contains("recomiend") || norm.contains("estrategia") ||
           norm.contains("como puedo") || norm.contains("cómo puedo") || norm.contains("opina") ||
           norm.contains("analiz") || norm.contains("explica") || norm.contains("evalua") ||
           norm.contains("evalúa") || norm.contains("sugier") || norm.contains("tip") ||
           norm.contains("plan") {
            return false
        }
        
        // 1. Saldo y Balances (cuánto tengo, saldo disponible, cuánto hay, etc.)
        if norm.contains("saldo") || norm.contains("balance") || norm.contains("cuanto tengo") || norm.contains("cuánto tengo") ||
           norm.contains("dinero tengo") || norm.contains("plata tengo") || norm.contains("cuanto me queda") || norm.contains("cuánto me queda") ||
           norm.contains("cuanto hay") || norm.contains("cuánto hay") || norm.contains("mi dinero") || norm.contains("mis fondos") {
            return true
        }
        
        // 2. Categorías de Gasto ("ver las categorías más altas", "en qué gasté más", "categoría con más gasto", "en qué gasto menos", etc.)
        if norm.contains("categoria") || norm.contains("categoría") ||
           norm.contains("en que gaste") || norm.contains("en qué gasté") ||
           norm.contains("en que gasto") || norm.contains("en qué gasto") ||
           norm.contains("en que he gastado") || norm.contains("en qué he gastado") ||
           norm.contains("gaste mas") || norm.contains("gasté más") ||
           norm.contains("gasto mas") || norm.contains("gasto más") ||
           norm.contains("gaste menos") || norm.contains("gasté menos") ||
           norm.contains("gasto menos") || norm.contains("gasto menos") ||
           norm.contains("mas alto") || norm.contains("más alto") ||
           norm.contains("mas alta") || norm.contains("más alta") ||
           norm.contains("mas bajo") || norm.contains("más bajo") ||
           norm.contains("mas baja") || norm.contains("más baja") ||
           norm.contains("mayor gasto") || norm.contains("menor gasto") {
            return true
        }
        
        // 3. Gastos Temporales (Gastos de hoy, ayer, esta semana, este mes, total acumulado de gastos)
        let hasGastoWord = norm.contains("gaste") || norm.contains("gasté") || norm.contains("gasto") || norm.contains("gastos") || norm.contains("gastado") || norm.contains("compras")
        if hasGastoWord && (norm.contains("hoy") || norm.contains("ayer") || norm.contains("semana") || norm.contains("mes") || norm.contains("total") || norm.contains("cuanto") || norm.contains("cuánto") || norm.contains("mis")) {
            return true
        }
        if norm == "mis gastos" || norm == "gastos" {
            return true
        }
        
        // 4. Cuentas y Billeteras (cuántas cuentas tengo, cuáles son mis cuentas, cuenta más usada)
        if norm.contains("mis cuentas") || norm.contains("mis billeteras") ||
           norm.contains("cuantas cuentas") || norm.contains("cuántas cuentas") ||
           norm.contains("cuantas billeteras") || norm.contains("cuántas billeteras") ||
           norm.contains("cuentas activas") || norm.contains("billeteras activas") ||
           norm.contains("numero de cuentas") || norm.contains("número de cuentas") ||
           norm.contains("nombres de mis cuentas") || norm.contains("nombre de mis cuentas") ||
           norm.contains("nombres de las cuentas") || norm.contains("nombre de las cuentas") ||
           norm.contains("cuenta mas usada") || norm.contains("cuenta más usada") ||
           norm.contains("billetera mas usada") || norm.contains("billetera más usada") ||
           norm.contains("cuenta con mas") || norm.contains("billetera con mas") {
            return true
        }
        
        // 5. Gastos Fijos (cuánto pago en gastos fijos, mis gastos fijos)
        if norm.contains("gasto fijo") || norm.contains("gastos fijos") || norm.contains("pagos fijos") || norm.contains("pagos recurrentes") || norm.contains("cuanto pago en gastos fijos") {
            return true
        }
        
        // 6. Últimos Movimientos (últimos movimientos, últimos gastos, compras recientes)
        if norm.contains("ultimos movimientos") || norm.contains("últimos movimientos") ||
           norm.contains("ultimos gastos") || norm.contains("últimos gastos") ||
           norm.contains("ultimas compras") || norm.contains("últimas compras") ||
           norm.contains("movimientos recientes") || norm.contains("transacciones recientes") ||
           norm.contains("que fue lo ultimo") || norm.contains("qué fue lo último") {
            return true
        }
        
        // 7. Ingresos (mayor ingreso, mis ingresos, cuánto gané)
        if norm.contains("mayor ingreso") || norm.contains("mis ingresos") || norm.contains("total de ingresos") ||
           norm.contains("cuanto gane") || norm.contains("cuánto gané") || norm.contains("mis ganancias") ||
           norm.contains("mi sueldo") || norm.contains("mi salario") {
            return true
        }
        
        // 8. Menú / Ayuda
        if norm == "menu" || norm == "ayuda" || norm.contains("que puedes hacer") || norm.contains("qué puedes hacer") {
            return true
        }
        
        // 9. Operaciones Matemáticas directas ("cuánto es 5 x 45", "18% de 500")
        let mathPattern = #"(?i)\b(?:cu[aá]nto\s+es\s+|calcula\s+|cu[aá]l\s+es\s+)?([0-9]+(?:\.[0-9]+)?)\s*([\+\-\*\/xX×÷%]|m[aá]s|menos|por|entre|por\s+ciento)\s*([0-9]+(?:\.[0-9]+)?)\b"#
        if let regex = try? NSRegularExpression(pattern: mathPattern),
           regex.firstMatch(in: cleanPrompt, range: NSRange(location: 0, length: (cleanPrompt as NSString).length)) != nil {
            return true
        }
        
        return false
    }

    @discardableResult
    private func applyLocalAssistantResponse(
        _ response: FinancialAiResponse,
        cleanPrompt: String,
        temporalRef: (fechaHoy: String, horaActual: String, fechaAyer: String, isoHoy: String, isoAyer: String),
        targetWalletId: Int64?,
        resolvedWalletId: Int64?,
        activeWalletName: String,
        allW: [Wallet],
        summary: FinancialSummary,
        currentBalances: [Int64: Double],
        playAudioEffects: Bool
    ) -> Bool {
        switch response {
        case .askTransferConfirmation(let pending, let message):
            self.pendingVoiceTransfer = pending
            chatMessages.append(FinancialChatMessage(text: message, isUser: false))
            saveChatHistory()
            return true

        case .executeTransferVoice(let pending, _):
            let (success, errorMsg) = executeTransfer(
                sourceWalletId: pending.sourceWalletId,
                destinationWalletId: pending.destinationWalletId,
                amount: pending.amount,
                detail: pending.detail
            )
            self.pendingVoiceTransfer = nil
            let msg: String
            if success {
                msg = "✅ **¡Transferencia realizada con éxito!**\n\nSe han transferido **\(summary.currencySymbol) \(FormatHelper.formatCurrency(pending.amount))** de '**\(pending.sourceWalletName)**' a '**\(pending.destinationWalletName)**'."
            } else {
                msg = "⚠️ No se pudo completar la transferencia: \(errorMsg ?? "Error desconocido")."
            }
            chatMessages.append(FinancialChatMessage(text: msg, isUser: false))
            saveChatHistory()
            return true

        case .registerMovement(let drafts, let confirmationText, let targetWalletIdFromAi, let pendingDrafts):
            let finalWalletId = targetWalletIdFromAi ?? targetWalletId ?? resolvedWalletId ?? activeWallet?.id ?? summary.activeWalletId
            let targetWalletBal = currentBalances[finalWalletId] ?? summary.currentBalance
            let totalIncomeInDrafts = drafts.filter { $0.type == .income }.reduce(0.0) { $0 + $1.amount }
            var runningBal = targetWalletBal + totalIncomeInDrafts
            var hasInsufficient = false
            
            for d in drafts where d.type == .expense {
                if d.amount > (runningBal + 0.001) {
                    hasInsufficient = true
                    break
                }
                runningBal -= d.amount
            }
            
            if hasInsufficient {
                let targetWalletName = allW.first(where: { $0.id == finalWalletId })?.name ?? "tu billetera"
                chatMessages.append(FinancialChatMessage(text: "Ups, No te queda saldo suficiente en \(targetWalletName) para realizar este movimiento.", isUser: false))
                saveChatHistory()
                return true
            }
            
            // Si hay transacciones pendientes del día de ayer esperando hora exacta:
            if !pendingDrafts.isEmpty {
                let resolvedWalletName = allW.first(where: { $0.id == finalWalletId })?.name ?? "Billetera Principal"
                self.pendingAiTransactions = pendingDrafts.map { p in
                    ExtractedTransaction(
                        titulo: p.title,
                        concepto: p.notes.isEmpty ? cleanPrompt : p.notes,
                        categoria: p.category,
                        monto: p.amount,
                        tipo: p.type == .income ? .INGRESO : .GASTO,
                        fecha: temporalRef.isoAyer,
                        hora: nil,
                        faltaHora: true,
                        billetera: resolvedWalletName
                    )
                }
            } else if !drafts.isEmpty {
                self.pendingAiTransactions.removeAll()
            }
            
            let cal = Calendar.current
            let now = Date()
            let yesterday = cal.date(byAdding: .day, value: -1, to: now) ?? now
            
            for d in drafts {
                let formattedNote = AiExpenseParser.formatSpokenNoteToDigits(d.notes.isEmpty ? cleanPrompt : d.notes)
                let finalCategory: String = {
                    let catFromDraft = CategoryHelper.resolveCategory(nameOrKeyword: d.category, type: d.type)
                    if catFromDraft != "Otros" && catFromDraft != "Otros Ingresos" {
                        return catFromDraft
                    }
                    let catFromTitle = CategoryHelper.resolveCategory(nameOrKeyword: d.title, type: d.type)
                    if catFromTitle != "Otros" && catFromTitle != "Otros Ingresos" {
                        return catFromTitle
                    }
                    return CategoryHelper.resolveCategory(nameOrKeyword: "\(d.title) \(d.notes)", type: d.type)
                }()
                
                let txDateMillis: Int64
                if d.isYesterday {
                    let (h, m): (Int, Int) = {
                        if let hStr = d.explicitHour, let hm = FormatHelper.parseHourAndMinute(from: hStr) {
                            return (hm.hour, hm.minute)
                        }
                        return (cal.component(.hour, from: now), cal.component(.minute, from: now))
                    }()
                    let combined = cal.date(bySettingHour: h, minute: m, second: 0, of: yesterday) ?? yesterday
                    txDateMillis = Int64(combined.timeIntervalSince1970 * 1000)
                } else {
                    if let hStr = d.explicitHour, let hm = FormatHelper.parseHourAndMinute(from: hStr) {
                        let combined = cal.date(bySettingHour: hm.hour, minute: hm.minute, second: 0, of: now) ?? now
                        txDateMillis = Int64(combined.timeIntervalSince1970 * 1000)
                    } else {
                        txDateMillis = Int64(now.timeIntervalSince1970 * 1000)
                    }
                }
                
                let newTx = Transaction(
                    title: String(d.title.prefix(30)),
                    amount: d.amount,
                    type: d.type,
                    category: finalCategory,
                    dateMillis: txDateMillis,
                    notes: String(formattedNote.prefix(250)),
                    walletId: finalWalletId
                )
                _ = repository.insertTransaction(newTx)
                if playAudioEffects {
                    SoundManager.shared.playSoundForType(d.type, isSoundEnabled: summary.soundsEnabled)
                }
            }
            
            chatMessages.append(FinancialChatMessage(text: confirmationText, isUser: false, isRegisteredMovement: !drafts.isEmpty))
            saveChatHistory()
            activeTab = 0
            triggerScrollToTop()
            refreshData()
            return true
            
        case .answer(let text):
            chatMessages.append(FinancialChatMessage(text: text, isUser: false))
            saveChatHistory()
            return true
            
        case .notUnderstood:
            return false
        }
    }
    
    public func processDirectVoiceTransaction(spokenText: String) async -> (success: Bool, message: String) {
        let clean = spokenText.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { 
            return (false, "No se logró entender ningún tipo de gasto ni ingreso, por favor intente de nuevo.") 
        }
        
        let allWallets = repository.getAllWalletsSync()
        let walletBalances = repository.computeWalletBalances()
        let summary = financialSummary
        let cur = summary.currencySymbol
        
        // 1. Intentar procesar primero con Gemini (MoneyBotAIService)
        do {
            let temporalRef = MoneyBotAIService.generateTemporalReference()
            let aiResponse = try await MoneyBotAIService.shared.processQuery(
                prompt: clean,
                billeteraActiva: activeWallet?.name ?? "BCP",
                currentBalance: summary.currentBalance,
                currencySymbol: cur,
                wallets: allWallets,
                fechaHoy: temporalRef.fechaHoy,
                horaActual: temporalRef.horaActual,
                fechaAyer: temporalRef.fechaAyer,
                chatHistory: chatMessages
            )
            
            if aiResponse.esperaRespuestaUsuario && aiResponse.transacciones.isEmpty {
                let msg = !aiResponse.razonamiento.isEmpty ? aiResponse.razonamiento : "¿A qué hora exacta realizaste el movimiento de ayer?"
                return (false, msg)
            }
            
            if (aiResponse.intencion == .REGISTRAR_TRANSACCION || aiResponse.intencion == .COMPLETAR_DATO_FALTANTE) && !aiResponse.transacciones.isEmpty {
                // Registrar siempre en la billetera activa actual sin verificar ni desviar a otras billeteras
                let finalTargetWalletId = activeWallet?.id ?? summary.activeWalletId
                let targetBalance = walletBalances[finalTargetWalletId] ?? summary.currentBalance
                let totalIncome = aiResponse.transacciones.filter { $0.tipo == .INGRESO }.reduce(0.0) { $0 + $1.monto }
                
                var runningBalance = targetBalance + totalIncome
                for tx in aiResponse.transacciones where tx.tipo == .GASTO {
                    if tx.monto > (runningBalance + 0.001) {
                        let wName = activeWallet?.name ?? "tu billetera"
                        return (false, "Ups, No te queda saldo suficiente en \(wName) para realizar este movimiento.")
                    }
                    runningBalance -= tx.monto
                }
                
                for tx in aiResponse.transacciones {
                    let now = Date()
                    let cal = Calendar.current
                    
                    let txDateMillis: Int64 = {
                        let hourAndMinute = tx.hora.flatMap { FormatHelper.parseHourAndMinute(from: $0) }
                            ?? FormatHelper.parseHourAndMinute(from: tx.concepto)
                            ?? FormatHelper.parseHourAndMinute(from: tx.titulo)
                            ?? FormatHelper.extractHour(forKeywords: [tx.titulo, tx.concepto], from: clean)
                            ?? (aiResponse.transacciones.count == 1 ? FormatHelper.parseHourAndMinute(from: clean) : nil)
                        
                        let txFechaLower = tx.fecha.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        let txConceptoLower = tx.concepto.lowercased()
                        let txTituloLower = tx.titulo.lowercased()
                        
                        let isYesterday: Bool
                        if txFechaLower == temporalRef.isoAyer || txFechaLower.contains("ayer") {
                            isYesterday = true
                        } else if txFechaLower == temporalRef.isoHoy || txFechaLower.contains("hoy") {
                            isYesterday = false
                        } else if txConceptoLower.contains("ayer") && !txConceptoLower.contains("hoy") {
                            isYesterday = true
                        } else if txTituloLower.contains("ayer") && !txTituloLower.contains("hoy") {
                            isYesterday = true
                        } else {
                            isYesterday = false
                        }
                        
                        if isYesterday {
                            let yesterday = cal.date(byAdding: .day, value: -1, to: now) ?? now
                            let (h, m): (Int, Int) = {
                                if let hm = hourAndMinute {
                                    return (hm.hour, hm.minute)
                                }
                                return (cal.component(.hour, from: now), cal.component(.minute, from: now))
                            }()
                            let combined = cal.date(bySettingHour: h, minute: m, second: 0, of: yesterday) ?? yesterday
                            return Int64(combined.timeIntervalSince1970 * 1000)
                        } else {
                            if let hm = hourAndMinute {
                                let combined = cal.date(bySettingHour: hm.hour, minute: hm.minute, second: 0, of: now) ?? now
                                return Int64(combined.timeIntervalSince1970 * 1000)
                            } else {
                                return Int64(now.timeIntervalSince1970 * 1000)
                            }
                        }
                    }()
                    
                    let txTitle: String = {
                        let t = tx.titulo.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !t.isEmpty && t.lowercased() != "movimiento" {
                            return String(t.prefix(30))
                        }
                        let c = tx.concepto.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !c.isEmpty && c.lowercased() != "movimiento" {
                            return String(c.prefix(30))
                        }
                        return String(clean.prefix(30))
                    }()
                    
                    let noteText: String = {
                        if aiResponse.transacciones.count > 1 {
                            return !tx.concepto.isEmpty ? tx.concepto : (!tx.titulo.isEmpty ? tx.titulo : clean)
                        }
                        return clean
                    }()
                    let formattedNote = AiExpenseParser.formatSpokenNoteToDigits(noteText)
                    let finalCategory = CategoryHelper.resolveCategory(nameOrKeyword: tx.categoria, type: tx.tipo.toAppType)
                    let newTx = Transaction(
                        title: txTitle,
                        amount: tx.monto,
                        type: tx.tipo.toAppType,
                        category: finalCategory,
                        dateMillis: txDateMillis,
                        notes: String(formattedNote.prefix(120)),
                        walletId: finalTargetWalletId
                    )
                    _ = repository.insertTransaction(newTx)
                    SoundManager.shared.playSoundForType(tx.tipo.toAppType, isSoundEnabled: summary.soundsEnabled)
                }
                
                self.selectedFilter = .all
                self.selectedDateFilter = .all
                self.searchQuery = ""
                
                activeTab = 0
                triggerScrollToTop()
                refreshData()
                
                let successMessage: String
                if !aiResponse.razonamiento.isEmpty {
                    successMessage = aiResponse.razonamiento
                } else {
                    let desc = aiResponse.transacciones.map { d in
                        let t = d.tipo == .INGRESO ? "Ingreso" : "Gasto"
                        let catResolved = CategoryHelper.resolveCategory(nameOrKeyword: d.categoria, type: d.tipo.toAppType)
                        return "\(t) de \(cur) \(FormatHelper.formatCurrency(d.monto)) en \(catResolved) ('\(d.titulo)')"
                    }.joined(separator: ", ")
                    successMessage = "¡Registrado con éxito! \(desc)"
                }
                
                return (true, successMessage)
            }
        } catch {
            // Fallback silencioso al diccionario y analizador local habitual
        }
        
        // 2. Fallback silencioso al diccionario y analizador local habitual
        let parseResult = await AiExpenseParser.parseNaturalLanguage(clean)
        switch parseResult {
        case .success(let drafts):
            guard !drafts.isEmpty else {
                return (false, "No se logró entender ningún tipo de gasto ni ingreso, por favor intente de nuevo.")
            }
            
            // Registrar siempre en la billetera activa actual sin verificar ni desviar a otras billeteras
            let finalTargetWalletId = activeWallet?.id ?? summary.activeWalletId
            let targetBalance = walletBalances[finalTargetWalletId] ?? summary.currentBalance
            let totalIncomeInDrafts = drafts.filter { $0.type == .income }.reduce(0.0) { $0 + $1.amount }
            
            var runningBalance = targetBalance + totalIncomeInDrafts
            for d in drafts where d.type == .expense {
                if d.amount > (runningBalance + 0.001) {
                    let wName = activeWallet?.name ?? "tu billetera"
                    return (false, "Ups, No te queda saldo suficiente en \(wName) para realizar este movimiento.")
                }
                runningBalance -= d.amount
            }
            
            let cal = Calendar.current
            let now = Date()
            let yesterday = cal.date(byAdding: .day, value: -1, to: now) ?? now
            
            for d in drafts {
                let formattedNote = AiExpenseParser.formatSpokenNoteToDigits(d.notes.isEmpty ? clean : d.notes)
                let finalCategory = CategoryHelper.resolveCategory(nameOrKeyword: d.category, type: d.type)
                
                let txDateMillis: Int64
                if d.isYesterday {
                    let (h, m): (Int, Int) = {
                        if let hStr = d.explicitHour, let hm = FormatHelper.parseHourAndMinute(from: hStr) {
                            return (hm.hour, hm.minute)
                        }
                        return (cal.component(.hour, from: now), cal.component(.minute, from: now))
                    }()
                    let combined = cal.date(bySettingHour: h, minute: m, second: 0, of: yesterday) ?? yesterday
                    txDateMillis = Int64(combined.timeIntervalSince1970 * 1000)
                } else {
                    if let hStr = d.explicitHour, let hm = FormatHelper.parseHourAndMinute(from: hStr) {
                        let combined = cal.date(bySettingHour: hm.hour, minute: hm.minute, second: 0, of: now) ?? now
                        txDateMillis = Int64(combined.timeIntervalSince1970 * 1000)
                    } else {
                        txDateMillis = Int64(now.timeIntervalSince1970 * 1000)
                    }
                }
                
                let tx = Transaction(
                    title: String(d.title.prefix(30)),
                    amount: d.amount,
                    type: d.type,
                    category: finalCategory,
                    dateMillis: txDateMillis,
                    notes: String(formattedNote.prefix(120)),
                    walletId: finalTargetWalletId
                )
                _ = repository.insertTransaction(tx)
                SoundManager.shared.playSoundForType(d.type, isSoundEnabled: summary.soundsEnabled)
            }
            
            activeTab = 0
            triggerScrollToTop()
            refreshData()
            
            let desc = drafts.map { d in
                let t = d.type == .income ? "Ingreso" : "Gasto"
                let catResolved = CategoryHelper.resolveCategory(nameOrKeyword: d.category, type: d.type)
                return "\(t) de \(cur) \(FormatHelper.formatCurrency(d.amount)) en \(catResolved) ('\(d.title)')"
            }.joined(separator: ", ")
            
            return (true, "¡Registrado con éxito! \(desc)")
            
        case .decimalMissingCon:
            return (false, "Por favor, para saldos con decimales usa el termino “con”. Por ejemplo: 3 con 70.")
            
        case .noMovementType:
            return (false, "No se logró entender ningún tipo de gasto ni ingreso, por favor intente de nuevo.")
            
        case .emptyOrUnrecognized:
            return (false, "No se logró entender ningún tipo de gasto ni ingreso, por favor intente de nuevo.")
        }
    }
    
    // Fixed Expenses
    public func openFixedExpensesDialog() {
        isFixedExpensesDialogOpen = true
    }
    
    public func closeFixedExpensesDialog() {
        isFixedExpensesDialogOpen = false
    }
    
    public func addFixedExpense(_ expense: FixedExpense) -> (success: Bool, message: String) {
        let result = repository.addFixedExpense(expense)
        switch result {
        case .success:
            refreshData()
            return (true, "Gasto fijo guardado con éxito")
        case .failure(let err):
            return (false, err.localizedDescription)
        }
    }
    
    public func updateFixedExpense(_ expense: FixedExpense) -> (success: Bool, message: String) {
        let result = repository.updateFixedExpense(expense)
        switch result {
        case .success:
            refreshData()
            return (true, "Gasto fijo actualizado con éxito")
        case .failure(let err):
            return (false, err.localizedDescription)
        }
    }
    
    public func deleteFixedExpense(_ id: Int64) -> (success: Bool, message: String) {
        let result = repository.deleteFixedExpense(id)
        switch result {
        case .success:
            refreshData()
            return (true, "Gasto fijo eliminado con éxito")
        case .failure(let err):
            return (false, err.localizedDescription)
        }
    }
    
    public func registerFixedExpensePayment(_ expense: FixedExpense) -> (success: Bool, message: String) {
        let result = repository.registerFixedExpensePayment(expense: expense, walletId: expense.walletId)
        switch result {
        case .success:
            SoundManager.shared.playExpenseSound(isSoundEnabled: financialSummary.soundsEnabled)
            refreshData()
            return (true, "¡Pago de \(expense.name) registrado como gasto!")
        case .failure(let err):
            return (false, err.localizedDescription)
        }
    }
    
    // MARK: - Persistencia Local de Chat de MoneyBot
    private let chatHistoryStorageKey = "key_moneydev_moneybot_chat_history"
    
    public func saveChatHistory() {
        if let data = try? JSONEncoder().encode(chatMessages) {
            UserDefaults.standard.set(data, forKey: chatHistoryStorageKey)
        }
    }
    
    public func loadChatHistory() {
        if let data = UserDefaults.standard.data(forKey: chatHistoryStorageKey),
           let loaded = try? JSONDecoder().decode([FinancialChatMessage].self, from: data),
           !loaded.isEmpty {
            self.chatMessages = loaded
        }
    }
    
    // MARK: - Backup JSON & Restauración
    public func getExportDataJson() -> String {
        return repository.exportDataAsJson(chatMessages: financialSummary.isProUser ? chatMessages : nil)
    }
    
    public func importDataJson(_ json: String) -> (success: Bool, message: String?) {
        let result = repository.importDataFromJson(json)
        switch result {
        case .success(let importedChat):
            refreshData()
            if financialSummary.isProUser, let importedChat, !importedChat.isEmpty {
                self.chatMessages = importedChat
                saveChatHistory()
            }
            return (true, nil)
        case .failure(let err):
            return (false, err.localizedDescription)
        }
    }
}
