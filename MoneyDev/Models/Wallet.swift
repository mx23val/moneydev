import Foundation
import SwiftData

@Model
public final class Wallet {
    @Attribute(.unique) public var id: Int64
    public var name: String
    public var initialBalance: Double
    public var currencySymbol: String
    public var colorHex: String
    public var iconName: String
    public var isDefault: Bool
    public var createdAt: Int64
    
    public init(
        id: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        name: String,
        initialBalance: Double = 0.0,
        currencySymbol: String = "S/",
        colorHex: String = "#00D2FF",
        iconName: String = "wallet",
        isDefault: Bool = false,
        createdAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.id = id
        self.name = name
        self.initialBalance = initialBalance
        self.currencySymbol = currencySymbol
        self.colorHex = colorHex
        self.iconName = iconName
        self.isDefault = isDefault
        self.createdAt = createdAt
    }
}

public struct PendingTransferVoiceState: Codable, Sendable {
    public var sourceWalletId: Int64
    public var sourceWalletName: String
    public var destinationWalletId: Int64
    public var destinationWalletName: String
    public var amount: Double
    public var detail: String
    
    public init(
        sourceWalletId: Int64,
        sourceWalletName: String,
        destinationWalletId: Int64,
        destinationWalletName: String,
        amount: Double,
        detail: String = ""
    ) {
        self.sourceWalletId = sourceWalletId
        self.sourceWalletName = sourceWalletName
        self.destinationWalletId = destinationWalletId
        self.destinationWalletName = destinationWalletName
        self.amount = amount
        self.detail = detail
    }
}
