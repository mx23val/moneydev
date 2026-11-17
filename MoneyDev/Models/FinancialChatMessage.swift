import Foundation

public struct FinancialChatMessage: Identifiable, Equatable, Sendable, Codable {
    public var id: UUID
    public var text: String
    public var isUser: Bool
    public var timestamp: Date
    public var isThinking: Bool
    public var isRegisteredMovement: Bool

    public init(
        id: UUID = UUID(),
        text: String,
        isUser: Bool = false,
        timestamp: Date = Date(),
        isThinking: Bool = false,
        isRegisteredMovement: Bool = false
    ) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
        self.isThinking = isThinking
        self.isRegisteredMovement = isRegisteredMovement
    }
}
