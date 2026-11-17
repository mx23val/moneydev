import Foundation
import SwiftData

@Model
public final class UserProfile {
    @Attribute(.unique) public var id: Int
    public var initialBalance: Double
    public var currencySymbol: String
    public var hasConfiguredInitial: Bool
    public var hasCompletedOnboarding: Bool
    public var activeWalletId: Int64
    public var themeColorId: String
    public var notificationsEnabled: Bool
    public var isProUser: Bool
    
    public init(
        id: Int = 1,
        initialBalance: Double = 0.0,
        currencySymbol: String = "S/",
        hasConfiguredInitial: Bool = false,
        hasCompletedOnboarding: Bool = false,
        activeWalletId: Int64 = 1,
        themeColorId: String = "electric_blue",
        notificationsEnabled: Bool = true,
        isProUser: Bool = false
    ) {
        self.id = id
        self.initialBalance = initialBalance
        self.currencySymbol = currencySymbol
        self.hasConfiguredInitial = hasConfiguredInitial
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.activeWalletId = activeWalletId
        self.themeColorId = themeColorId
        self.notificationsEnabled = notificationsEnabled
        self.isProUser = isProUser
    }
}
