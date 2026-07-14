import Foundation
import IvansMenuKit
import Combine

@MainActor
final class ChannelStoreVM: ObservableObject {
    @Published var config: AppConfig
    private let store: ConfigStore

    init(store: ConfigStore) { self.store = store; self.config = store.load() }

    func binding(forSlot slot: Int) -> Int? {
        config.channels.firstIndex(where: { $0.slot == slot })
    }
    func save() { try? store.save(config) }
}
