import XCTest
@testable import IvansMenuKit

final class ConfigStoreTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("config.json")
    }

    func testLoadMissingReturnsDefault() {
        let store = ConfigStore(fileURL: tempURL())
        XCTAssertEqual(store.load().channels.count, 48)
    }

    func testSaveThenLoadRoundTrips() throws {
        let url = tempURL()
        let store = ConfigStore(fileURL: url)
        var cfg = AppConfig.makeDefault()
        cfg.channels[0].action = .url("https://a.com")
        try store.save(cfg)
        XCTAssertEqual(store.load().channels[0].action, .url("https://a.com"))
    }

    func testCorruptBacksUpAndReturnsDefault() throws {
        let url = tempURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{not json".utf8).write(to: url)
        let store = ConfigStore(fileURL: url)
        XCTAssertEqual(store.load().channels.count, 48) // recovered to default
        let dir = url.deletingLastPathComponent()
        let backups = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.contains("corrupt") }
        XCTAssertFalse(backups.isEmpty)
    }
}
