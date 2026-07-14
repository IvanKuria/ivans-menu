import XCTest
@testable import IvansMenuKit

final class LauncherTests: XCTestCase {
    final class MockWorkspace: Workspace {
        var openedApps: [URL] = []; var opened: [URL] = []; var revealed: [URL] = []
        func openApp(at url: URL) { openedApps.append(url) }
        func open(_ url: URL) { opened.append(url) }
        func reveal(_ url: URL) { revealed.append(url) }
    }

    func testRouting() {
        let ws = MockWorkspace()
        let l = Launcher(workspace: ws)
        XCTAssertTrue(l.launch(.app(path: "/Applications/Safari.app")))
        XCTAssertTrue(l.launch(.url("https://x.com")))
        XCTAssertTrue(l.launch(.folder(path: "/Users")))
        XCTAssertFalse(l.launch(.empty))
        XCTAssertFalse(l.launch(.url("")))
        XCTAssertEqual(ws.openedApps.map(\.path), ["/Applications/Safari.app"])
        XCTAssertEqual(ws.opened.map(\.absoluteString), ["https://x.com"])
        XCTAssertEqual(ws.revealed.map(\.path), ["/Users"])
    }
}
