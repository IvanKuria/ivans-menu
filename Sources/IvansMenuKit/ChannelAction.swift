import Foundation

public enum ChannelAction: Codable, Equatable, Sendable {
    case empty
    case app(path: String)
    case url(String)
    case file(path: String)
    case folder(path: String)
}
