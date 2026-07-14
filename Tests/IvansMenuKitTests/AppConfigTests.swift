import XCTest
@testable import IvansMenuKit

final class AppConfigTests: XCTestCase {
    func testDefaultHas48EmptySlots() {
        let cfg = AppConfig.makeDefault()
        XCTAssertEqual(cfg.channels.count, 48)
        XCTAssertEqual(Set(cfg.channels.map(\.slot)), Set(0..<48))
        XCTAssertTrue(cfg.channels.allSatisfy(\.isEmpty))
        XCTAssertEqual(cfg.version, 1)
    }

    func testRoundTrip() throws {
        let cfg = AppConfig.makeDefault()
        let data = try JSONEncoder().encode(cfg)
        XCTAssertEqual(try JSONDecoder().decode(AppConfig.self, from: data), cfg)
    }
}
