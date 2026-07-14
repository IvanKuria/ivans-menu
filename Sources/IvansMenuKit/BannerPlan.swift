import Foundation

public enum BannerPlan: Equatable, Sendable {
    case pack(id: String)
    case custom(path: String)
    case generated

    public static func resolve(_ channel: Channel, packIDs: Set<String>) -> BannerPlan {
        switch channel.banner {
        case .pack(let id): return packIDs.contains(id) ? .pack(id: id) : .generated
        case .custom(let path): return .custom(path: path)
        case .generated: return .generated
        }
    }
}
