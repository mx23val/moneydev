import Foundation

public enum TransactionType: String, Codable, CaseIterable, Sendable {
    case expense = "EXPENSE"
    case income = "INCOME"
    
    public var displayName: String {
        switch self {
        case .expense: return "Gasto"
        case .income: return "Ingreso"
        }
    }
}
