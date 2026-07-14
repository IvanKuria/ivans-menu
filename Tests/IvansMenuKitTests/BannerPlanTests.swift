import XCTest
@testable import IvansMenuKit

final class BannerPlanTests: XCTestCase {
    func testPackFallsBackWhenMissing() {
        let c = Channel(slot: 0, banner: .pack(id: "unknown"))
        XCTAssertEqual(BannerPlan.resolve(c, packIDs: ["youtube"]), .generated)
    }
    func testPackKeptWhenPresent() {
        let c = Channel(slot: 0, banner: .pack(id: "youtube"))
        XCTAssertEqual(BannerPlan.resolve(c, packIDs: ["youtube"]), .pack(id: "youtube"))
    }
    func testCustomAndGenerated() {
        XCTAssertEqual(BannerPlan.resolve(Channel(slot: 0, banner: .custom(path: "/a.png")),
                                          packIDs: []), .custom(path: "/a.png"))
        XCTAssertEqual(BannerPlan.resolve(Channel(slot: 0, banner: .generated),
                                          packIDs: []), .generated)
    }
}
