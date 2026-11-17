import WidgetKit
import SwiftUI

@main
public struct MoneyDevWidgetsBundle: WidgetBundle {
    public init() {}
    
    public var body: some Widget {
        SmallWalletWidget()
        MediumWalletWidget()
        MoneyBotLiveActivityWidget()
    }
}
