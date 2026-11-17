import Foundation
import SwiftData

@Model
public final class Transaction {
    @Attribute(.unique) public var id: Int64
    public var title: String
    public var amount: Double
    public var typeRaw: String
    public var category: String
    public var dateMillis: Int64
    public var notes: String
    public var walletId: Int64
    public var isIrrevocable: Bool
    
    public var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }
    
    public init(
        id: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        title: String,
        amount: Double,
        type: TransactionType,
        category: String,
        dateMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        notes: String = "",
        walletId: Int64 = 1,
        isIrrevocable: Bool = false
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.typeRaw = type.rawValue
        self.category = category
        self.dateMillis = dateMillis
        self.notes = notes
        self.walletId = walletId
        self.isIrrevocable = isIrrevocable
    }
    
    public func isIrrevocableMovement() -> Bool {
        return isIrrevocable ||
            category.caseInsensitiveCompare("Transferencia") == .orderedSame ||
            title.lowercased().hasPrefix("transferencia")
    }
    
    public func isFixedExpensePayment() -> Bool {
        return notes.hasPrefix("[Gasto Fijo]") ||
            notes.localizedCaseInsensitiveContains("Pago de gasto fijo") ||
            notes.localizedCaseInsensitiveContains("Pago registrado de gasto fijo") ||
            notes.localizedCaseInsensitiveContains("gasto fijo")
    }
}
