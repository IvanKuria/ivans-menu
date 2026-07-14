import XCTest
@testable import IvansMenuKit

final class SmokeTests: XCTestCase {
    func testSlotCounts() {
        XCTAssertEqual(Theme.slotsPerPage, 12)
        XCTAssertEqual(Theme.totalSlots, 48)
    }
}
