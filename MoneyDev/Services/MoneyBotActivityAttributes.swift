import Foundation
import ActivityKit

public struct MoneyBotActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var statusText: String
        public var isSpeaking: Bool
        public var subtitle: String
        
        public init(statusText: String, isSpeaking: Bool, subtitle: String = "Money está escuchándote y hablando contigo") {
            self.statusText = statusText
            self.isSpeaking = isSpeaking
            self.subtitle = subtitle
        }
    }
    
    public var sessionTitle: String
    
    public init(sessionTitle: String = "MoneyBot Live") {
        self.sessionTitle = sessionTitle
    }
}
