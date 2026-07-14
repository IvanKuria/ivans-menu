import Foundation

public enum BannerSource: Codable, Equatable, Sendable {
    case generated
    case pack(id: String)
    case custom(path: String)
}
