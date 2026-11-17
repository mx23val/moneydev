import Foundation
import SwiftData

public enum FixedExpenseFrequency: String, Codable, CaseIterable, Sendable {
    case daily = "DAILY"
    case everyTwoDays = "EVERY_TWO_DAYS"
    case weekly = "WEEKLY"
    case monthly = "MONTHLY"
    case yearly = "YEARLY"
    
    public var displayName: String {
        switch self {
        case .daily: return "Diario"
        case .everyTwoDays: return "Interdiario"
        case .weekly: return "Semanal"
        case .monthly: return "Mensual"
        case .yearly: return "Anual"
        }
    }
}

public enum FixedExpenseNotifyTiming: String, Codable, CaseIterable, Sendable {
    case sameDay = "SAME_DAY"
    case oneDayBefore = "ONE_DAY_BEFORE"
    
    public var displayName: String {
        switch self {
        case .sameDay: return "El mismo día del pago"
        case .oneDayBefore: return "1 día antes del pago"
        }
    }
}

@Model
public final class FixedExpense {
    @Attribute(.unique) public var id: Int64
    public var name: String
    public var amount: Double
    public var category: String
    public var frequencyRaw: String
    public var dayOfWeek: Int
    public var dayOfMonth: Int
    public var monthOfYear: Int
    public var notifyTimingRaw: String
    public var notificationsEnabled: Bool
    public var walletId: Int64 = 1
    public var lastPaidDateMillis: Int64
    public var createdAt: Int64
    
    public var frequency: FixedExpenseFrequency {
        get { FixedExpenseFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }
    
    public var notifyTiming: FixedExpenseNotifyTiming {
        get { FixedExpenseNotifyTiming(rawValue: notifyTimingRaw) ?? .sameDay }
        set { notifyTimingRaw = newValue.rawValue }
    }
    
    public init(
        id: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        name: String,
        amount: Double,
        category: String = "Servicios",
        walletId: Int64 = 1,
        frequency: FixedExpenseFrequency = .monthly,
        dayOfWeek: Int = 1,
        dayOfMonth: Int = 1,
        monthOfYear: Int = 1,
        notifyTiming: FixedExpenseNotifyTiming = .sameDay,
        notificationsEnabled: Bool = true,
        lastPaidDateMillis: Int64 = 0,
        createdAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.category = category
        self.walletId = walletId
        self.frequencyRaw = frequency.rawValue
        self.dayOfWeek = dayOfWeek
        self.dayOfMonth = dayOfMonth
        self.monthOfYear = monthOfYear
        self.notifyTimingRaw = notifyTiming.rawValue
        self.notificationsEnabled = notificationsEnabled
        self.lastPaidDateMillis = lastPaidDateMillis
        self.createdAt = createdAt
    }
}
