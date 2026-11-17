import AppIntents
import Foundation

public struct SelectWalletAppIntent: WidgetConfigurationIntent {
    public static var title: LocalizedStringResource = "Seleccionar Billetera"
    public static var description: IntentDescription = IntentDescription("Elige qué billetera deseas visualizar en el widget")
    
    @Parameter(title: "Billetera")
    public var wallet: WidgetWalletAppEntity?
    
    public init() {
        self.wallet = nil
    }
    
    public init(wallet: WidgetWalletAppEntity?) {
        self.wallet = wallet
    }
}

public struct WidgetWalletAppEntity: AppEntity {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Billetera"
    public static var defaultQuery = WidgetWalletQuery()
    
    public var id: String
    public var name: String
    
    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct WidgetWalletQuery: EntityQuery {
    public init() {}
    
    public func entities(for identifiers: [String]) async throws -> [WidgetWalletAppEntity] {
        let data = WidgetDataManager.loadData()
        let idSet = Set(identifiers)
        return data.wallets
            .filter { idSet.contains(String($0.id)) }
            .map { WidgetWalletAppEntity(id: String($0.id), name: $0.name) }
    }
    
    public func suggestedEntities() async throws -> [WidgetWalletAppEntity] {
        let data = WidgetDataManager.loadData()
        return data.wallets.map { WidgetWalletAppEntity(id: String($0.id), name: $0.name) }
    }
    
    public func defaultResult() async -> WidgetWalletAppEntity? {
        let data = WidgetDataManager.loadData()
        let active = WidgetDataManager.wallet(for: nil, in: data)
        return WidgetWalletAppEntity(id: String(active.id), name: active.name)
    }
}
