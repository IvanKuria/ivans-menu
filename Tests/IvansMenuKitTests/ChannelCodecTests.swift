import XCTest
@testable import IvansMenuKit

final class ChannelCodecTests: XCTestCase {
    func testRoundTrip() throws {
        let c = Channel(id: UUID(), slot: 5,
                        action: .url("https://youtube.com"),
                        banner: .generated, title: "YouTube")
        let data = try JSONEncoder().encode(c)
        let back = try JSONDecoder().decode(Channel.self, from: data)
        XCTAssertEqual(c, back)
    }

    func testActionCases() throws {
        let actions: [ChannelAction] = [
            .empty, .app(path: "/Applications/Safari.app"),
            .url("https://x.com"), .file(path: "/tmp/a.txt"),
            .folder(path: "/Users")
        ]
        for a in actions {
            let d = try JSONEncoder().encode(a)
            XCTAssertEqual(try JSONDecoder().decode(ChannelAction.self, from: d), a)
        }
    }
}
