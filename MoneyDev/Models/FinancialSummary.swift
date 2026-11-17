import Foundation

public struct CategorySummary: Identifiable, Hashable, Sendable {
    public var id: String { "\(categoryName)_\(type.rawValue)" }
    public let categoryName: String
    public let totalAmount: Double
    public let percentage: Float
    public let transactionCount: Int
    public let type: TransactionType
    
    public init(
        categoryName: String,
        totalAmount: Double,
        percentage: Float,
        transactionCount: Int,
        type: TransactionType
    ) {
        self.categoryName = categoryName
        self.totalAmount = totalAmount
        self.percentage = percentage
        self.transactionCount = transactionCount
        self.type = type
    }
}

public struct FinancialSummary: Hashable, Sendable {
    public var initialBalance: Double
    public var totalIncome: Double
    public var totalExpense: Double
    public var currentBalance: Double
    public var hasConfiguredInitial: Bool
    public var currencySymbol: String
    public var hasCompletedOnboarding: Bool
    public var activeWalletName: String
    public var activeWalletId: Int64
    public var themeColorId: String
    public var notificationsEnabled: Bool
    public var isProUser: Bool
    public var soundsEnabled: Bool
    
    public init(
        initialBalance: Double = 0.0,
        totalIncome: Double = 0.0,
        totalExpense: Double = 0.0,
        currentBalance: Double = 0.0,
        hasConfiguredInitial: Bool = false,
        currencySymbol: String = "S/",
        hasCompletedOnboarding: Bool = true,
        activeWalletName: String = "Billetera Principal",
        activeWalletId: Int64 = 1,
        themeColorId: String = "electric_blue",
        notificationsEnabled: Bool = true,
        isProUser: Bool = false,
        soundsEnabled: Bool = true
    ) {
        self.initialBalance = initialBalance
        self.totalIncome = totalIncome
        self.totalExpense = totalExpense
        self.currentBalance = currentBalance
        self.hasConfiguredInitial = hasConfiguredInitial
        self.currencySymbol = currencySymbol
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.activeWalletName = activeWalletName
        self.activeWalletId = activeWalletId
        self.themeColorId = themeColorId
        self.notificationsEnabled = notificationsEnabled
        self.isProUser = isProUser
        self.soundsEnabled = soundsEnabled
    }
}

public struct TransferResult: Hashable, Sendable {
    public let sourceWalletName: String
    public let destinationWalletName: String
    public let amount: Double
    public let currencySymbol: String
    public let timestamp: Int64
    
    public init(
        sourceWalletName: String,
        destinationWalletName: String,
        amount: Double,
        currencySymbol: String,
        timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.sourceWalletName = sourceWalletName
        self.destinationWalletName = destinationWalletName
        self.amount = amount
        self.currencySymbol = currencySymbol
        self.timestamp = timestamp
    }
}
