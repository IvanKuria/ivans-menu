import Foundation

public struct Channel: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var slot: Int
    public var action: ChannelAction
    public var banner: BannerSource
    public var title: String?

    public init(id: UUID = UUID(), slot: Int,
                action: ChannelAction = .empty,
                banner: BannerSource = .generated,
                title: String? = nil) {
        self.id = id; self.slot = slot; self.action = action
        self.banner = banner; self.title = title
    }

    public var isEmpty: Bool {
        if case .empty = action { return true }; return false
    }
}
