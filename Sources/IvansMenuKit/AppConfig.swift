import Foundation

public struct AppConfig: Codable, Equatable, Sendable {
    public var version: Int
    public var channels: [Channel]
    public var settings: AppSettings

    public init(version: Int = 1, channels: [Channel], settings: AppSettings = .init()) {
        self.version = version; self.channels = channels; self.settings = settings
    }

    public static func makeDefault() -> AppConfig {
        let channels = (0..<Theme.totalSlots).map { Channel(slot: $0) }
        return AppConfig(version: 1, channels: channels, settings: .init())
    }
}
