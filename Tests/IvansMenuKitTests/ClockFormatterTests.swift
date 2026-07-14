import XCTest
@testable import IvansMenuKit

final class ClockFormatterTests: XCTestCase {
    func testTimeBlink() {
        XCTAssertEqual(ClockFormatter.time(hour: 16, minute: 35, blinkOn: true, twentyFourHour: true), "16:35")
        XCTAssertEqual(ClockFormatter.time(hour: 16, minute: 35, blinkOn: false, twentyFourHour: true), "16 35")
        XCTAssertEqual(ClockFormatter.time(hour: 9, minute: 5, blinkOn: true, twentyFourHour: true), "09:05")
    }

    func testDateFormat() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        var comps = DateComponents(); comps.year = 2020; comps.month = 6; comps.day = 19
        let date = cal.date(from: comps)!  // 2020-06-19 is a Friday
        XCTAssertEqual(ClockFormatter.date(date, calendar: cal), "Fri 6/19")
    }
}
