import Foundation
import WidgetKit

public struct WidgetWalletData: Codable, Identifiable, Sendable {
    public var id: Int64
    public var name: String
    public var balance: Double
    public var currencySymbol: String
    public var colorHex: String
    public var iconName: String
    public var monthlyIncome: Double
    public var monthlyExpense: Double
    
    public init(
        id: Int64,
        name: String,
        balance: Double,
        currencySymbol: String = "S/",
        colorHex: String = "#00D2FF",
        iconName: String = "wallet.pass.fill",
        monthlyIncome: Double = 0.0,
        monthlyExpense: Double = 0.0
    ) {
        self.id = id
        self.name = name
        self.balance = balance
        self.currencySymbol = currencySymbol
        self.colorHex = colorHex
        self.iconName = iconName
        self.monthlyIncome = monthlyIncome
        self.monthlyExpense = monthlyExpense
    }
}

public struct WidgetSharedData: Codable, Sendable {
    public var activeWalletId: Int64
    public var wallets: [WidgetWalletData]
    public var totalBalance: Double
    public var lastUpdated: Date
    
    public init(
        activeWalletId: Int64 = 1,
        wallets: [WidgetWalletData] = [],
        totalBalance: Double = 0.0,
        lastUpdated: Date = Date()
    ) {
        self.activeWalletId = activeWalletId
        self.wallets = wallets
        self.totalBalance = totalBalance
        self.lastUpdated = lastUpdated
    }
    
    public static var fallbackData: WidgetSharedData {
        let sample = WidgetWalletData(
            id: 1,
            name: "Billetera Principal",
            balance: 1450.0,
            currencySymbol: "S/",
            colorHex: "#00D2FF",
            iconName: "wallet.pass.fill",
            monthlyIncome: 3500.0,
            monthlyExpense: 2050.0
        )
        return WidgetSharedData(
            activeWalletId: 1,
            wallets: [sample],
            totalBalance: 1450.0,
            lastUpdated: Date()
        )
    }
}

public enum WidgetDataManager {
    public static let appGroupId = "group.max.MoneyDev"
    public static let sharedDefaultsKey = "key_moneydev_widget_shared_data"
    public static let sharedFileName = "moneydev_widget_data.json"
    
    public static var sharedContainerUrl: URL? {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
            return container
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    public static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupId) ?? UserDefaults.standard
    }
    
    public static nonisolated func loadData() -> WidgetSharedData {
        if let fileUrl = sharedContainerUrl?.appendingPathComponent(sharedFileName),
           let data = try? Data(contentsOf: fileUrl),
           let decoded = try? JSONDecoder().decode(WidgetSharedData.self, from: data) {
            return decoded
        }
        
        if let data = sharedDefaults.data(forKey: sharedDefaultsKey),
           let decoded = try? JSONDecoder().decode(WidgetSharedData.self, from: data) {
            return decoded
        }
        
        return WidgetSharedData.fallbackData
    }
    
    public static nonisolated func wallet(for id: Int64?, in data: WidgetSharedData) -> WidgetWalletData {
        if let id = id, let found = data.wallets.first(where: { $0.id == id }) {
            return found
        }
        if let active = data.wallets.first(where: { $0.id == data.activeWalletId }) {
            return active
        }
        return data.wallets.first ?? WidgetSharedData.fallbackData.wallets[0]
    }
}
