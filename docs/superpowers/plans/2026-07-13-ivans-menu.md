# Ivan's Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A native macOS app that turns the desktop into a faithful, interactive Wii Menu whose channel tiles launch real apps, URLs, files, and folders.

**Architecture:** A Swift Package with two targets — `IvansMenuKit` (pure, unit-tested logic: models, config store, launcher, banner rendering, formatters) and `IvansMenu` (the AppKit/SwiftUI agent app: desktop-level windows, Wii UI, onboarding, settings). The Kit is fully testable headlessly with `swift test`; the app target is compile-verified with `swift build` plus a manual verification checklist.

**Tech Stack:** Swift 6.2, Swift Package Manager (builds with Command Line Tools, opens in Xcode), AppKit + SwiftUI, Core Animation. No third-party dependencies.

## Global Constraints

- Swift tools version **6.0**; platform floor **macOS 14** (`.macOS(.v14)`).
- **No third-party dependencies** — Foundation/AppKit/SwiftUI/CoreAnimation/CoreImage only.
- Agent app: `LSUIElement = true` (no Dock icon, no ⌘-Tab entry).
- **No Nintendo trademarks/assets**: no "Nintendo"/"Wii" in the product name, no ripped fonts/sounds/textures. Product name is **"Ivan's Menu"**. All banner art, wave, and audio are original; bundled fonts are OFL (Asap, M PLUS Rounded 1c).
- Aesthetic constants (single source of truth in `Theme.swift`): accent `#3CB9E6`, bottom-bar `#D2D6DB`, clock/date text `#84868A`, background radial `#F4F4F4`→`#D0D2D9`, tile aspect `1.82:1`, grid 4×3, 4 pages, 48 slots.
- Disclaimer string shipped in README and About panel: *"Ivan's Menu is an unofficial, fan-made tribute. Not affiliated with, endorsed by, or sponsored by Nintendo. All Nintendo trademarks belong to their respective owners."*
- Config lives at `~/Library/Application Support/Ivan's Menu/config.json`.
- Every code change follows TDD where the unit is headlessly testable; commit after each task.

---

## File Structure

```
Package.swift
Sources/
  IvansMenuKit/
    Theme.swift                 # colors, metrics, layout constants
    ChannelAction.swift         # enum: empty/app/url/file/folder (Codable)
    BannerSource.swift          # enum: generated/pack/custom (Codable)
    Channel.swift               # struct: id, slot, action, banner, title
    AppSettings.swift           # struct: sound/music/hideIcons/menuDisplayID/hotkey
    AppConfig.swift             # struct: channels, settings, version (+ defaults)
    ConfigStore.swift           # load/save/corrupt-recovery to a fileURL
    Workspace.swift             # protocol abstracting NSWorkspace (mockable)
    Launcher.swift              # routes ChannelAction -> Workspace calls
    DominantColor.swift         # average color of a CGImage
    ClockFormatter.swift        # time (blink) + "Fri 19/6" date strings
    BannerPlan.swift            # pure resolution of BannerSource -> render recipe
  IvansMenu/
    main.swift                  # NSApplication bootstrap (agent app)
    AppDelegate.swift           # lifecycle, status item, icon hide/restore, hotkey
    StatusItemController.swift  # menu-bar escape hatch
    DesktopIcons.swift          # hide/restore Finder desktop icons
    GlobalHotKey.swift          # ⌥Space peek registration (Carbon)
    WallpaperWindow.swift       # NSWindow subclass at desktop level
    WallpaperWindowController.swift # one window per NSScreen, rebuild on change
    BannerRenderer.swift        # BannerPlan -> NSImage (pack/generated/custom)
    ChannelStoreVM.swift        # ObservableObject wrapper over ConfigStore
    WiiMenuView.swift           # paged 4x3 grid + bottom bar
    ChannelTileView.swift       # one tile: banner, hover glow, select zoom
    BottomBarView.swift         # Wii button, SD, clock/date, envelope
    WaveView.swift              # Core Animation animated wave
    OnboardingView.swift        # first-run wizard
    SettingsView.swift          # rebind/reorder/toggles
    AudioEngine.swift           # sound cues + ambient music
    Resources/
      Fonts/                    # Asap-*.ttf, MPLUSRounded1c-*.ttf (OFL)
      Banners/                  # bundled Channel Pack PNGs + manifest.json
      Sounds/                   # hover.caf, select.caf, back.caf, ambient.m4a
Tests/
  IvansMenuKitTests/
    ChannelCodecTests.swift
    ConfigStoreTests.swift
    LauncherTests.swift
    DominantColorTests.swift
    ClockFormatterTests.swift
    BannerPlanTests.swift
scripts/
  bundle.sh                     # assemble + codesign IvansMenu.app
README.md
LICENSE                         # MIT
```

---

## Task 1: Package scaffold

**Files:**
- Create: `Package.swift`, `Sources/IvansMenuKit/Theme.swift`, `Sources/IvansMenu/main.swift`, `Tests/IvansMenuKitTests/SmokeTests.swift`

**Interfaces:**
- Produces: package `IvansMenu` with library target `IvansMenuKit`, executable `IvansMenu`, test target `IvansMenuKitTests`. `Theme` enum with static color/metric constants.

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "IvansMenu",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "IvansMenuKit"),
        .executableTarget(
            name: "IvansMenu",
            dependencies: ["IvansMenuKit"],
            resources: [.copy("Resources")]
        ),
        .testTarget(name: "IvansMenuKitTests", dependencies: ["IvansMenuKit"]),
    ]
)
```

- [ ] **Step 2: Write `Sources/IvansMenuKit/Theme.swift`**

```swift
import Foundation

public enum Theme {
    // Colors as (r,g,b) 0...1 so Kit stays AppKit-free and testable.
    public static let accent = (r: 0.235, g: 0.725, b: 0.902)   // #3CB9E6
    public static let bottomBar = (r: 0.824, g: 0.839, b: 0.859) // #D2D6DB
    public static let clockText = (r: 0.518, g: 0.525, b: 0.541) // #84868A
    public static let bgCenter = (r: 0.957, g: 0.957, b: 0.957)  // #F4F4F4
    public static let bgEdge = (r: 0.816, g: 0.824, b: 0.851)    // #D0D2D9

    public static let columns = 4
    public static let rows = 3
    public static let pageCount = 4
    public static var slotsPerPage: Int { columns * rows }       // 12
    public static var totalSlots: Int { slotsPerPage * pageCount } // 48
    public static let tileAspect: Double = 1.82                  // width : height
    public static let tileCornerFraction: Double = 0.06
    public static let hoverScaleFrom: Double = 0.94
}
```

- [ ] **Step 3: Write `Sources/IvansMenu/main.swift` (temporary smoke bootstrap)**

```swift
import AppKit
import IvansMenuKit

// Replaced in Task 8 by full AppDelegate bootstrap.
print("Ivan's Menu — slots:", Theme.totalSlots)
```

- [ ] **Step 4: Write `Tests/IvansMenuKitTests/SmokeTests.swift`**

```swift
import XCTest
@testable import IvansMenuKit

final class SmokeTests: XCTestCase {
    func testSlotCounts() {
        XCTAssertEqual(Theme.slotsPerPage, 12)
        XCTAssertEqual(Theme.totalSlots, 48)
    }
}
```

- [ ] **Step 5: Build and test**

Run: `swift build && swift test`
Expected: build succeeds; `testSlotCounts` PASSES.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources Tests
git commit -m "feat: scaffold IvansMenu SPM package with Kit + app targets"
```

---

## Task 2: Channel model + Codable

**Files:**
- Create: `Sources/IvansMenuKit/ChannelAction.swift`, `Sources/IvansMenuKit/BannerSource.swift`, `Sources/IvansMenuKit/Channel.swift`
- Test: `Tests/IvansMenuKitTests/ChannelCodecTests.swift`

**Interfaces:**
- Produces: `ChannelAction` (Codable enum), `BannerSource` (Codable enum), `Channel` (Codable, Identifiable, Equatable) with fields `id: UUID, slot: Int, action: ChannelAction, banner: BannerSource, title: String?`.

- [ ] **Step 1: Write the failing test**

```swift
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
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter ChannelCodecTests`
Expected: FAIL — types not defined.

- [ ] **Step 3: Implement the models**

`ChannelAction.swift`:
```swift
import Foundation

public enum ChannelAction: Codable, Equatable, Sendable {
    case empty
    case app(path: String)
    case url(String)
    case file(path: String)
    case folder(path: String)
}
```

`BannerSource.swift`:
```swift
import Foundation

public enum BannerSource: Codable, Equatable, Sendable {
    case generated
    case pack(id: String)
    case custom(path: String)
}
```

`Channel.swift`:
```swift
import Foundation

public struct Channel: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var slot: Int
    public var action: ChannelAction
    public var banner: BannerSource
    public var title: String?

    public init(id: UUID = UUID(), slot: Int,
                action: ChannelAction = .empty,
                banner: BannerSource = .generated,
                title: String? = nil) {
        self.id = id; self.slot = slot; self.action = action
        self.banner = banner; self.title = title
    }

    public var isEmpty: Bool {
        if case .empty = action { return true }; return false
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter ChannelCodecTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/IvansMenuKit Tests/IvansMenuKitTests/ChannelCodecTests.swift
git commit -m "feat: add Channel/ChannelAction/BannerSource models with Codable"
```

---

## Task 3: AppSettings + AppConfig with defaults

**Files:**
- Create: `Sources/IvansMenuKit/AppSettings.swift`, `Sources/IvansMenuKit/AppConfig.swift`
- Test: extend `Tests/IvansMenuKitTests/ChannelCodecTests.swift` (add `AppConfigTests` file)

**Interfaces:**
- Consumes: `Channel`, `Theme`.
- Produces: `AppSettings` (Codable) with `soundEnabled, musicEnabled, hideDesktopIcons, menuDisplayID: String?, peekHotKeyEnabled`. `AppConfig` (Codable) with `version: Int, channels: [Channel], settings: AppSettings`, and `static func makeDefault() -> AppConfig` producing 48 empty channels (slots 0..47).

- [ ] **Step 1: Write the failing test** — `Tests/IvansMenuKitTests/AppConfigTests.swift`

```swift
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
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter AppConfigTests`
Expected: FAIL — types not defined.

- [ ] **Step 3: Implement**

`AppSettings.swift`:
```swift
import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var soundEnabled: Bool
    public var musicEnabled: Bool
    public var hideDesktopIcons: Bool
    public var menuDisplayID: String?
    public var peekHotKeyEnabled: Bool

    public init(soundEnabled: Bool = true, musicEnabled: Bool = false,
                hideDesktopIcons: Bool = true, menuDisplayID: String? = nil,
                peekHotKeyEnabled: Bool = true) {
        self.soundEnabled = soundEnabled; self.musicEnabled = musicEnabled
        self.hideDesktopIcons = hideDesktopIcons; self.menuDisplayID = menuDisplayID
        self.peekHotKeyEnabled = peekHotKeyEnabled
    }
}
```

`AppConfig.swift`:
```swift
import Foundation

public struct AppConfig: Codable, Equatable, Sendable {
    public var version: Int
    public var channels: [Channel]
    public var settings: AppSettings

    public init(version: Int = 1, channels: [Channel], settings: AppSettings = .init()) {
        self.version = version; self.channels = channels; self.settings = settings
    }

    public static func makeDefault() -> AppConfig {
        let channels = (0..<Theme.totalSlots).map { Channel(slot: $0) }
        return AppConfig(version: 1, channels: channels, settings: .init())
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter AppConfigTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/IvansMenuKit Tests/IvansMenuKitTests/AppConfigTests.swift
git commit -m "feat: add AppSettings/AppConfig with 48-slot default"
```

---

## Task 4: ConfigStore (load/save/corrupt-recovery)

**Files:**
- Create: `Sources/IvansMenuKit/ConfigStore.swift`
- Test: `Tests/IvansMenuKitTests/ConfigStoreTests.swift`

**Interfaces:**
- Consumes: `AppConfig`.
- Produces: `ConfigStore(fileURL: URL)` with `func load() -> AppConfig` (missing → default; corrupt → back up to `<file>.corrupt-<n>` and return default) and `func save(_:) throws`. `static var defaultFileURL: URL` = `~/Library/Application Support/Ivan's Menu/config.json`.

- [ ] **Step 1: Write the failing test**

```swift
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
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter ConfigStoreTests`
Expected: FAIL — `ConfigStore` not defined.

- [ ] **Step 3: Implement `ConfigStore.swift`**

```swift
import Foundation

public final class ConfigStore {
    private let fileURL: URL
    private let fm = FileManager.default

    public init(fileURL: URL = ConfigStore.defaultFileURL) { self.fileURL = fileURL }

    public static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        return base.appendingPathComponent("Ivan's Menu", isDirectory: true)
                   .appendingPathComponent("config.json")
    }

    public func load() -> AppConfig {
        guard let data = try? Data(contentsOf: fileURL) else { return .makeDefault() }
        if let cfg = try? JSONDecoder().decode(AppConfig.self, from: data) { return cfg }
        backupCorrupt(data)
        return .makeDefault()
    }

    public func save(_ config: AppConfig) throws {
        try fm.createDirectory(at: fileURL.deletingLastPathComponent(),
                               withIntermediateDirectories: true)
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(config).write(to: fileURL, options: .atomic)
    }

    private func backupCorrupt(_ data: Data) {
        var n = 0
        var dst: URL
        repeat {
            dst = fileURL.deletingPathExtension()
                .appendingPathExtension("corrupt-\(n).json"); n += 1
        } while fm.fileExists(atPath: dst.path)
        try? data.write(to: dst)
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter ConfigStoreTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/IvansMenuKit/ConfigStore.swift Tests/IvansMenuKitTests/ConfigStoreTests.swift
git commit -m "feat: add ConfigStore with default + corrupt-recovery"
```

---

## Task 5: Launcher + Workspace abstraction

**Files:**
- Create: `Sources/IvansMenuKit/Workspace.swift`, `Sources/IvansMenuKit/Launcher.swift`
- Test: `Tests/IvansMenuKitTests/LauncherTests.swift`

**Interfaces:**
- Consumes: `ChannelAction`.
- Produces: `protocol Workspace { func openApp(at: URL); func open(_ url: URL); func reveal(_ url: URL) }`. `Launcher(workspace:)` with `func launch(_ action: ChannelAction) -> Bool` (false for `.empty` or invalid). Routing: `.app`→openApp(fileURL), `.url`→open(URL), `.file`→open(fileURL), `.folder`→reveal(fileURL).

- [ ] **Step 1: Write the failing test**

```swift
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
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter LauncherTests`
Expected: FAIL.

- [ ] **Step 3: Implement**

`Workspace.swift`:
```swift
import Foundation

public protocol Workspace {
    func openApp(at url: URL)
    func open(_ url: URL)
    func reveal(_ url: URL)
}
```

`Launcher.swift`:
```swift
import Foundation

public struct Launcher {
    private let workspace: Workspace
    public init(workspace: Workspace) { self.workspace = workspace }

    @discardableResult
    public func launch(_ action: ChannelAction) -> Bool {
        switch action {
        case .empty: return false
        case .app(let path):
            guard !path.isEmpty else { return false }
            workspace.openApp(at: URL(fileURLWithPath: path)); return true
        case .url(let s):
            guard let url = URL(string: s), url.scheme != nil else { return false }
            workspace.open(url); return true
        case .file(let path):
            guard !path.isEmpty else { return false }
            workspace.open(URL(fileURLWithPath: path)); return true
        case .folder(let path):
            guard !path.isEmpty else { return false }
            workspace.reveal(URL(fileURLWithPath: path)); return true
        }
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter LauncherTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/IvansMenuKit/Workspace.swift Sources/IvansMenuKit/Launcher.swift Tests/IvansMenuKitTests/LauncherTests.swift
git commit -m "feat: add Launcher with mockable Workspace routing"
```

---

## Task 6: DominantColor sampling

**Files:**
- Create: `Sources/IvansMenuKit/DominantColor.swift`
- Test: `Tests/IvansMenuKitTests/DominantColorTests.swift`

**Interfaces:**
- Produces: `enum DominantColor { static func average(of image: CGImage) -> (r: Double, g: Double, b: Double) }` — downsamples and averages RGB, ignoring fully transparent pixels.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import CoreGraphics
@testable import IvansMenuKit

final class DominantColorTests: XCTestCase {
    private func solid(_ r: Int, _ g: Int, _ b: Int) -> CGImage {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8,
            bytesPerRow: 0, space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(red: CGFloat(r)/255, green: CGFloat(g)/255,
                         blue: CGFloat(b)/255, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        return ctx.makeImage()!
    }

    func testSolidRed() {
        let c = DominantColor.average(of: solid(255, 0, 0))
        XCTAssertEqual(c.r, 1.0, accuracy: 0.05)
        XCTAssertEqual(c.g, 0.0, accuracy: 0.05)
        XCTAssertEqual(c.b, 0.0, accuracy: 0.05)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter DominantColorTests`
Expected: FAIL.

- [ ] **Step 3: Implement `DominantColor.swift`**

```swift
import CoreGraphics
import Foundation

public enum DominantColor {
    public static func average(of image: CGImage) -> (r: Double, g: Double, b: Double) {
        let w = 16, h = 16
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: w * 4, space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return (0.5, 0.5, 0.5)
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        var rs = 0.0, gs = 0.0, bs = 0.0, count = 0.0
        for i in stride(from: 0, to: px.count, by: 4) {
            let a = Double(px[i + 3]) / 255
            if a < 0.1 { continue }
            rs += Double(px[i]) / 255; gs += Double(px[i+1]) / 255; bs += Double(px[i+2]) / 255
            count += 1
        }
        guard count > 0 else { return (0.5, 0.5, 0.5) }
        return (rs / count, gs / count, bs / count)
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter DominantColorTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/IvansMenuKit/DominantColor.swift Tests/IvansMenuKitTests/DominantColorTests.swift
git commit -m "feat: add DominantColor average sampling"
```

---

## Task 7: ClockFormatter

**Files:**
- Create: `Sources/IvansMenuKit/ClockFormatter.swift`
- Test: `Tests/IvansMenuKitTests/ClockFormatterTests.swift`

**Interfaces:**
- Produces: `enum ClockFormatter` with `static func time(hour: Int, minute: Int, blinkOn: Bool, twentyFourHour: Bool) -> String` (colon replaced by space when `blinkOn == false`) and `static func date(_ date: Date, calendar: Calendar) -> String` → e.g. `"Fri 19/6"` (weekday abbrev + day/month).

- [ ] **Step 1: Write the failing test**

```swift
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
        XCTAssertEqual(ClockFormatter.date(date, calendar: cal), "Fri 19/6")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter ClockFormatterTests`
Expected: FAIL.

- [ ] **Step 3: Implement `ClockFormatter.swift`**

```swift
import Foundation

public enum ClockFormatter {
    public static func time(hour: Int, minute: Int, blinkOn: Bool,
                            twentyFourHour: Bool) -> String {
        var h = hour
        if !twentyFourHour { h = hour % 12; if h == 0 { h = 12 } }
        let sep = blinkOn ? ":" : " "
        return String(format: "%02d%@%02d", h, sep, minute)
    }

    public static func date(_ date: Date, calendar: Calendar) -> String {
        let df = DateFormatter()
        df.calendar = calendar; df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = calendar.timeZone
        df.dateFormat = "EEE"
        let weekday = df.string(from: date)
        let c = calendar.dateComponents([.day, .month], from: date)
        return "\(weekday) \(c.day!)/\(c.month!)"
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter ClockFormatterTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/IvansMenuKit/ClockFormatter.swift Tests/IvansMenuKitTests/ClockFormatterTests.swift
git commit -m "feat: add ClockFormatter time-blink + Wii date string"
```

---

## Task 8: BannerPlan (pure banner resolution)

**Files:**
- Create: `Sources/IvansMenuKit/BannerPlan.swift`
- Test: `Tests/IvansMenuKitTests/BannerPlanTests.swift`

**Interfaces:**
- Consumes: `Channel`, `BannerSource`.
- Produces: `enum BannerPlan { case pack(id: String); case custom(path: String); case generated }` and `static func resolve(_ channel: Channel, packIDs: Set<String>) -> BannerPlan` — `.pack` only if id is in `packIDs`, else falls back to `.generated`; `.custom` passes through; `.generated` stays. (`BannerRenderer` in the app target consumes this to produce an `NSImage`.)

- [ ] **Step 1: Write the failing test**

```swift
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
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter BannerPlanTests`
Expected: FAIL.

- [ ] **Step 3: Implement `BannerPlan.swift`**

```swift
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
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter BannerPlanTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/IvansMenuKit/BannerPlan.swift Tests/IvansMenuKitTests/BannerPlanTests.swift
git commit -m "feat: add BannerPlan resolution with pack fallback"
```

---

> **Phase 2 — App shell (AppKit).** These targets touch AppKit/SwiftUI and a live window server, so they are **compile-verified** (`swift build`) plus a **manual verification checklist** at the end of each task rather than headless unit tests. Run manual steps by launching `.build/debug/IvansMenu`.

## Task 9: NSColor/Theme bridge + app bootstrap

**Files:**
- Create: `Sources/IvansMenu/ThemeUI.swift`, `Sources/IvansMenu/AppDelegate.swift`
- Modify: `Sources/IvansMenu/main.swift`

**Interfaces:**
- Consumes: `Theme`.
- Produces: `extension NSColor { static var wiiAccent/wiiBottomBar/wiiClock/wiiBGCenter/wiiBGEdge }`; `AppDelegate: NSObject, NSApplicationDelegate` created and retained from `main.swift` via `NSApplication.shared` with `.accessory` activation policy.

- [ ] **Step 1: Write `ThemeUI.swift`**

```swift
import AppKit
import IvansMenuKit

extension NSColor {
    private static func rgb(_ c: (r: Double, g: Double, b: Double)) -> NSColor {
        NSColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: 1)
    }
    static var wiiAccent: NSColor { rgb(Theme.accent) }
    static var wiiBottomBar: NSColor { rgb(Theme.bottomBar) }
    static var wiiClock: NSColor { rgb(Theme.clockText) }
    static var wiiBGCenter: NSColor { rgb(Theme.bgCenter) }
    static var wiiBGEdge: NSColor { rgb(Theme.bgEdge) }
}
```

- [ ] **Step 2: Write `AppDelegate.swift` (minimal; grown in later tasks)**

```swift
import AppKit
import IvansMenuKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ConfigStore()
    private(set) var config: AppConfig = .makeDefault()

    func applicationDidFinishLaunching(_ notification: Notification) {
        config = store.load()
        NSApp.setActivationPolicy(.accessory) // agent app, no Dock icon
    }
}
```

- [ ] **Step 3: Replace `main.swift`**

```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

- [ ] **Step 4: Build**

Run: `swift build`
Expected: build succeeds.

- [ ] **Step 5: Manual verification**

Run: `.build/debug/IvansMenu &` then `sleep 2; kill %1`
Expected: launches with no Dock icon, no crash. (Nothing visible yet.)

- [ ] **Step 6: Commit**

```bash
git add Sources/IvansMenu
git commit -m "feat: agent app bootstrap + NSColor theme bridge"
```

---

## Task 10: WallpaperWindow + WallpaperWindowController

**Files:**
- Create: `Sources/IvansMenu/WallpaperWindow.swift`, `Sources/IvansMenu/WallpaperWindowController.swift`
- Modify: `Sources/IvansMenu/AppDelegate.swift`

**Interfaces:**
- Produces: `WallpaperWindow: NSWindow` (borderless, desktop-icon level +1, all-spaces, becomes key for clicks). `WallpaperWindowController` with `func rebuild(content: (NSScreen) -> NSView)` creating one window per `NSScreen`, and observing `didChangeScreenParametersNotification`. `func setInteractive(_:)` toggles `ignoresMouseEvents`.

- [ ] **Step 1: Write `WallpaperWindow.swift`**

```swift
import AppKit

final class WallpaperWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless],
                   backing: .buffered, defer: false, screen: screen)
        let base = Int(CGWindowLevelForKey(.desktopIconWindow))
        self.level = NSWindow.Level(rawValue: base + 1)
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        self.isOpaque = true
        self.backgroundColor = .wiiBGCenter
        self.hasShadow = false
        self.isReleasedWhenClosed = false
        self.ignoresMouseEvents = false
        self.setFrame(screen.frame, display: true)
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
```

- [ ] **Step 2: Write `WallpaperWindowController.swift`**

```swift
import AppKit

final class WallpaperWindowController {
    private var windows: [WallpaperWindow] = []
    private var contentProvider: ((NSScreen) -> NSView)?

    init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    func rebuild(content: @escaping (NSScreen) -> NSView) {
        contentProvider = content
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map { screen in
            let w = WallpaperWindow(screen: screen)
            let view = content(screen)
            view.frame = w.contentView?.bounds ?? screen.frame
            view.autoresizingMask = [.width, .height]
            w.contentView?.addSubview(view)
            w.orderFront(nil)
            return w
        }
    }

    func setInteractive(_ interactive: Bool) {
        windows.forEach { $0.ignoresMouseEvents = !interactive }
    }

    @objc private func screensChanged() {
        if let content = contentProvider { rebuild(content: content) }
    }
}
```

- [ ] **Step 3: Wire a placeholder view in `AppDelegate.applicationDidFinishLaunching`**

Add property and call after `config = store.load()`:
```swift
    let windowController = WallpaperWindowController()
    // ... inside applicationDidFinishLaunching, after setActivationPolicy:
    windowController.rebuild { _ in
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.wiiBGCenter.cgColor
        return v
    }
```

- [ ] **Step 4: Build**

Run: `swift build`
Expected: succeeds.

- [ ] **Step 5: Manual verification**

Run: `.build/debug/IvansMenu &`; observe the desktop; then `kill %1`.
Expected: a solid near-white layer covers the desktop *below* the menu bar, sitting over the wallpaper. `kill` removes it.

- [ ] **Step 6: Commit**

```bash
git add Sources/IvansMenu
git commit -m "feat: desktop-level wallpaper window(s) per screen"
```

---

## Task 11: DesktopIcons hide/restore

**Files:**
- Create: `Sources/IvansMenu/DesktopIcons.swift`
- Modify: `Sources/IvansMenu/AppDelegate.swift`

**Interfaces:**
- Produces: `enum DesktopIcons { static func setHidden(_ hidden: Bool) }` — runs `defaults write com.apple.finder CreateDesktop -bool <false/true>` then `killall Finder`. `AppDelegate` calls `setHidden(true)` on launch when `config.settings.hideDesktopIcons`, and `setHidden(false)` on `applicationWillTerminate`.

- [ ] **Step 1: Write `DesktopIcons.swift`**

```swift
import Foundation

enum DesktopIcons {
    static func setHidden(_ hidden: Bool) {
        run("/usr/bin/defaults",
            ["write", "com.apple.finder", "CreateDesktop", "-bool", hidden ? "false" : "true"])
        run("/usr/bin/killall", ["Finder"])
    }

    private static func run(_ path: String, _ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        try? p.run(); p.waitUntilExit()
    }
}
```

- [ ] **Step 2: Wire into `AppDelegate`**

In `applicationDidFinishLaunching`, after loading config:
```swift
    if config.settings.hideDesktopIcons { DesktopIcons.setHidden(true) }
```
Add:
```swift
    func applicationWillTerminate(_ notification: Notification) {
        if config.settings.hideDesktopIcons { DesktopIcons.setHidden(false) }
    }
```

- [ ] **Step 3: Build**

Run: `swift build`
Expected: succeeds.

- [ ] **Step 4: Manual verification**

Run `.build/debug/IvansMenu &`; desktop icons disappear. `kill %1` won't run `applicationWillTerminate` cleanly — instead quit via the status item once Task 12 lands, OR manually run `defaults write com.apple.finder CreateDesktop -bool true; killall Finder` to restore now.
Expected: icons hide on launch; restore command brings them back.

- [ ] **Step 5: Commit**

```bash
git add Sources/IvansMenu
git commit -m "feat: hide/restore Finder desktop icons for immersion"
```

---

## Task 12: StatusItemController (escape hatch)

**Files:**
- Create: `Sources/IvansMenu/StatusItemController.swift`
- Modify: `Sources/IvansMenu/AppDelegate.swift`

**Interfaces:**
- Produces: `StatusItemController(onSettings:, onQuit:)` creating an `NSStatusItem` with a menu: "Open Settings…", "Reload Config", "Quit Ivan's Menu". `AppDelegate` owns it; Quit triggers `NSApp.terminate` (so `applicationWillTerminate` restores icons).

- [ ] **Step 1: Write `StatusItemController.swift`**

```swift
import AppKit

final class StatusItemController {
    private let item: NSStatusItem
    private let onSettings: () -> Void
    private let onQuit: () -> Void

    init(onSettings: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onSettings = onSettings; self.onQuit = onQuit
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "🎮"
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Settings…", action: #selector(settings), keyEquivalent: ",")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Ivan's Menu", action: #selector(quit), keyEquivalent: "q")
            .target = self
        item.menu = menu
    }
    @objc private func settings() { onSettings() }
    @objc private func quit() { onQuit() }
}
```

- [ ] **Step 2: Wire into `AppDelegate`**

Add property `var statusItem: StatusItemController?` and in `applicationDidFinishLaunching`:
```swift
    statusItem = StatusItemController(
        onSettings: { [weak self] in self?.showSettings() },
        onQuit: { NSApp.terminate(nil) })
```
Add a stub `func showSettings() {}` (implemented in Task 18).

- [ ] **Step 3: Build**

Run: `swift build`
Expected: succeeds.

- [ ] **Step 4: Manual verification**

Run `.build/debug/IvansMenu &`; a 🎮 icon appears in the menu bar; "Quit Ivan's Menu" terminates it and restores desktop icons.
Expected: quit path works and restores icons.

- [ ] **Step 5: Commit**

```bash
git add Sources/IvansMenu
git commit -m "feat: menu-bar status item escape hatch (settings/quit)"
```

---

## Task 13: WaveView (Core Animation wave)

**Files:**
- Create: `Sources/IvansMenu/WaveView.swift`
- Test (compile): referenced from BottomBar in Task 15.

**Interfaces:**
- Produces: `WaveView: NSView` drawing an animated blue sine wave along its top edge using a `CAShapeLayer` whose `path` is updated on a `CVDisplayLink`-free `Timer`/`CADisplayLink`-style loop (use a repeating `Timer` at ~30fps updating a phase and rebuilding the path). Color `NSColor.wiiAccent`.

- [ ] **Step 1: Write `WaveView.swift`**

```swift
import AppKit

final class WaveView: NSView {
    private let shape = CAShapeLayer()
    private var phase: CGFloat = 0
    private var timer: Timer?

    override init(frame: NSRect) {
        super.init(frame: frame); setup()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        wantsLayer = true
        shape.strokeColor = NSColor.wiiAccent.cgColor
        shape.fillColor = NSColor.clear.cgColor
        shape.lineWidth = 4
        layer?.addSublayer(shape)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/30, repeats: true) { [weak self] _ in
            self?.step()
        }
    }

    private func step() {
        phase += 0.06
        if phase > .pi * 2 { phase -= .pi * 2 }
        rebuild()
    }

    override func layout() { super.layout(); rebuild() }

    private func rebuild() {
        let w = bounds.width, h = bounds.height
        guard w > 0 else { return }
        let path = CGMutablePath()
        let midY = h * 0.6
        let amp = h * 0.18
        path.move(to: CGPoint(x: 0, y: midY))
        var x: CGFloat = 0
        while x <= w {
            let y = midY + sin((x / w) * .pi * 2 + phase) * amp
            path.addLine(to: CGPoint(x: x, y: y))
            x += 4
        }
        shape.path = path
    }

    deinit { timer?.invalidate() }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/IvansMenu/WaveView.swift
git commit -m "feat: Core Animation animated Wii wave view"
```

---

## Task 14: BottomBarView (clock/date + buttons + wave)

**Files:**
- Create: `Sources/IvansMenu/BottomBarView.swift`
- Modify: none

**Interfaces:**
- Consumes: `ClockFormatter`, `Theme`, `WaveView`, `NSColor` theme.
- Produces: `BottomBarView: NSView` hosting a `WaveView` along the top, a centered clock label (updates each second, colon blinks), a date label, a round "Wii" button (left, `onWii` closure) and envelope button (right, `onMail` closure). SD glyph shown near the Wii button.

- [ ] **Step 1: Write `BottomBarView.swift`**

```swift
import AppKit
import IvansMenuKit

final class BottomBarView: NSView {
    var onWii: () -> Void = {}
    var onMail: () -> Void = {}

    private let wave = WaveView()
    private let clock = NSTextField(labelWithString: "")
    private let dateLabel = NSTextField(labelWithString: "")
    private var timer: Timer?
    private var blinkOn = true

    override init(frame: NSRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.wiiBottomBar.cgColor
        addSubview(wave)

        clock.font = .monospacedDigitSystemFont(ofSize: 44, weight: .semibold)
        clock.textColor = .wiiClock
        clock.alignment = .center
        addSubview(clock)

        dateLabel.font = .systemFont(ofSize: 18, weight: .medium)
        dateLabel.textColor = .wiiClock
        dateLabel.alignment = .center
        addSubview(dateLabel)

        let wii = makeRoundButton(title: "Wii", action: #selector(wiiTapped))
        wii.tag = 1; addSubview(wii)
        let mail = makeRoundButton(title: "✉", action: #selector(mailTapped))
        mail.tag = 2; addSubview(mail)

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        tick()
    }

    private func makeRoundButton(title: String, action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .circular
        b.wantsLayer = true
        return b
    }

    private func tick() {
        blinkOn.toggle()
        let now = Date()
        let cal = Calendar.current
        let c = cal.dateComponents([.hour, .minute], from: now)
        clock.stringValue = ClockFormatter.time(hour: c.hour!, minute: c.minute!,
                                                blinkOn: blinkOn, twentyFourHour: true)
        dateLabel.stringValue = ClockFormatter.date(now, calendar: cal)
    }

    override func layout() {
        super.layout()
        let w = bounds.width, h = bounds.height
        wave.frame = NSRect(x: 0, y: h - 24, width: w, height: 24)
        clock.frame = NSRect(x: w/2 - 150, y: h/2 - 10, width: 300, height: 56)
        dateLabel.frame = NSRect(x: w/2 - 150, y: h/2 - 44, width: 300, height: 24)
        for v in subviews.compactMap({ $0 as? NSButton }) {
            if v.tag == 1 { v.frame = NSRect(x: 40, y: h/2 - 40, width: 80, height: 80) }
            if v.tag == 2 { v.frame = NSRect(x: w - 120, y: h/2 - 40, width: 80, height: 80) }
        }
    }

    @objc private func wiiTapped() { onWii() }
    @objc private func mailTapped() { onMail() }
    deinit { timer?.invalidate() }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/IvansMenu/BottomBarView.swift
git commit -m "feat: bottom bar with live clock, date, Wii + mail buttons, wave"
```

---

## Task 15: BannerRenderer (pack/generated/custom → NSImage)

**Files:**
- Create: `Sources/IvansMenu/BannerRenderer.swift`

**Interfaces:**
- Consumes: `BannerPlan`, `DominantColor`, `Theme`, `Channel`.
- Produces: `final class BannerRenderer` with `init(packIDs: Set<String>, packImage: (String) -> NSImage?, appIcon: (ChannelAction) -> NSImage?)` and `func image(for channel: Channel, size: NSSize) -> NSImage`. For `.generated`: sample dominant color of the app icon, draw a rounded Wii card in that hue with the icon centered. For `.pack`: return the pack image. For `.custom`: load the file. Caches by (source, size).

- [ ] **Step 1: Write `BannerRenderer.swift`**

```swift
import AppKit
import IvansMenuKit

final class BannerRenderer {
    private let packIDs: Set<String>
    private let packImage: (String) -> NSImage?
    private let appIcon: (ChannelAction) -> NSImage?
    private var cache: [String: NSImage] = [:]

    init(packIDs: Set<String>,
         packImage: @escaping (String) -> NSImage?,
         appIcon: @escaping (ChannelAction) -> NSImage?) {
        self.packIDs = packIDs; self.packImage = packImage; self.appIcon = appIcon
    }

    func image(for channel: Channel, size: NSSize) -> NSImage {
        let plan = BannerPlan.resolve(channel, packIDs: packIDs)
        let key = "\(plan)-\(Int(size.width))x\(Int(size.height))-\(channel.id)"
        if let cached = cache[key] { return cached }
        let img: NSImage
        switch plan {
        case .pack(let id): img = packImage(id) ?? generated(channel, size: size)
        case .custom(let path):
            img = NSImage(contentsOfFile: path) ?? generated(channel, size: size)
        case .generated: img = generated(channel, size: size)
        }
        cache[key] = img
        return img
    }

    private func generated(_ channel: Channel, size: NSSize) -> NSImage {
        let icon = appIcon(channel.action)
        var bg = NSColor.wiiAccent
        if let cg = icon?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let c = DominantColor.average(of: cg)
            bg = NSColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: 1)
        }
        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        let radius = size.width * Theme.tileCornerFraction
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        bg.setFill(); path.fill()
        if let icon {
            let s = min(size.width, size.height) * 0.55
            let r = NSRect(x: (size.width - s)/2, y: (size.height - s)/2, width: s, height: s)
            icon.draw(in: r)
        }
        image.unlockFocus()
        return image
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/IvansMenu/BannerRenderer.swift
git commit -m "feat: BannerRenderer (pack/custom/generated dominant-color card)"
```

---

## Task 16: ChannelTileView + WiiMenuView grid & paging

**Files:**
- Create: `Sources/IvansMenu/ChannelTileView.swift`, `Sources/IvansMenu/WiiMenuView.swift`
- Modify: `Sources/IvansMenu/AppDelegate.swift` (use real content)

**Interfaces:**
- Consumes: `BannerRenderer`, `Launcher`, `Channel`, `AppConfig`, `Theme`, `BottomBarView`.
- Produces: `ChannelTileView: NSView` (banner image, hover glow, click → `onLaunch(Channel)`, zoom animation). `WiiMenuView: NSView` laying out the current page's 12 tiles in a 4×3 grid + on-screen left/right page arrows + `BottomBarView`; owns `currentPage`. `AppDelegate` builds a `WiiMenuView` as window content.

- [ ] **Step 1: Write `ChannelTileView.swift`**

```swift
import AppKit
import IvansMenuKit

final class ChannelTileView: NSView {
    var onLaunch: (Channel) -> Void = { _ in }
    private let channel: Channel
    private let imageView = NSImageView()
    private var tracking: NSTrackingArea?

    init(channel: Channel, image: NSImage) {
        self.channel = channel
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.masksToBounds = true
        imageView.imageScaling = .scaleAxesIndependently
        imageView.image = image
        addSubview(imageView)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() { super.layout(); imageView.frame = bounds }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways],
                               owner: self, userInfo: nil)
        addTrackingArea(t); tracking = t
    }

    override func mouseEntered(with event: NSEvent) { setHover(true) }
    override func mouseExited(with event: NSEvent) { setHover(false) }

    private func setHover(_ on: Bool) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.4
            layer?.borderWidth = on ? 4 : 0
            layer?.borderColor = NSColor.white.cgColor
            let scale: CGFloat = on ? 1.0 : Theme.hoverScaleFrom
            animator().layer?.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard !channel.isEmpty else { return }
        onLaunch(channel)
    }
}
```

- [ ] **Step 2: Write `WiiMenuView.swift`**

```swift
import AppKit
import IvansMenuKit

final class WiiMenuView: NSView {
    var onLaunch: (Channel) -> Void = { _ in }
    var onWii: () -> Void = {}

    private let config: AppConfig
    private let renderer: BannerRenderer
    private let bottomBar = BottomBarView()
    private var currentPage = 0
    private let leftArrow = NSButton(title: "◀", target: nil, action: nil)
    private let rightArrow = NSButton(title: "▶", target: nil, action: nil)
    private var gridContainer = NSView()

    init(config: AppConfig, renderer: BannerRenderer) {
        self.config = config; self.renderer = renderer
        super.init(frame: .zero)
        wantsLayer = true
        applyBackgroundGradient()
        addSubview(gridContainer)
        addSubview(bottomBar)
        setupArrows()
        bottomBar.onWii = { [weak self] in self?.onWii() }
        rebuildGrid()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func applyBackgroundGradient() {
        let g = CAGradientLayer()
        g.type = .radial
        g.colors = [NSColor.wiiBGCenter.cgColor, NSColor.wiiBGEdge.cgColor]
        g.startPoint = CGPoint(x: 0.5, y: 0.5)
        g.endPoint = CGPoint(x: 1, y: 1)
        layer = g
    }

    private func setupArrows() {
        for (b, sel) in [(leftArrow, #selector(prevPage)), (rightArrow, #selector(nextPage))] {
            b.bezelStyle = .circular; b.target = self; b.action = sel; addSubview(b)
        }
    }

    @objc private func prevPage() { if currentPage > 0 { currentPage -= 1; rebuildGrid() } }
    @objc private func nextPage() {
        if currentPage < Theme.pageCount - 1 { currentPage += 1; rebuildGrid() }
    }

    private func rebuildGrid() {
        gridContainer.subviews.forEach { $0.removeFromSuperview() }
        let start = currentPage * Theme.slotsPerPage
        for i in 0..<Theme.slotsPerPage {
            let slot = start + i
            guard let channel = config.channels.first(where: { $0.slot == slot }) else { continue }
            let img = renderer.image(for: channel, size: NSSize(width: 320, height: 176))
            let tile = ChannelTileView(channel: channel, image: img)
            tile.onLaunch = { [weak self] c in self?.onLaunch(c) }
            gridContainer.addSubview(tile)
        }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let barH = bounds.height * 0.2
        bottomBar.frame = NSRect(x: 0, y: 0, width: bounds.width, height: barH)
        let gridArea = NSRect(x: 0, y: barH, width: bounds.width, height: bounds.height - barH)
        gridContainer.frame = gridArea

        let cols = Theme.columns, rows = Theme.rows
        let gutter: CGFloat = 24
        let margin: CGFloat = 60
        let cellW = (gridArea.width - margin*2 - gutter*CGFloat(cols-1)) / CGFloat(cols)
        let cellH = cellW / Theme.tileAspect
        let totalH = cellH*CGFloat(rows) + gutter*CGFloat(rows-1)
        let topY = (gridArea.height + totalH)/2 - cellH
        for (idx, tile) in gridContainer.subviews.enumerated() {
            let r = idx / cols, c = idx % cols
            tile.frame = NSRect(x: margin + CGFloat(c)*(cellW+gutter),
                                y: topY - CGFloat(r)*(cellH+gutter),
                                width: cellW, height: cellH)
        }
        leftArrow.frame = NSRect(x: 8, y: bounds.midY, width: 44, height: 60)
        rightArrow.frame = NSRect(x: bounds.width-52, y: bounds.midY, width: 44, height: 60)
    }
}
```

- [ ] **Step 3: Wire real content in `AppDelegate`**

Add a `Launcher` (with an `NSWorkspace` adapter — Task 17 provides `SystemWorkspace`; for now use a temporary inline adapter) and build `WiiMenuView`. Replace the placeholder `windowController.rebuild` block:
```swift
    let renderer = BannerRenderer(
        packIDs: [],
        packImage: { _ in nil },
        appIcon: { action in
            if case .app(let path) = action {
                return NSWorkspace.shared.icon(forFile: path)
            }
            return NSWorkspace.shared.icon(forFileType: "public.data")
        })
    windowController.rebuild { [weak self] _ in
        guard let self else { return NSView() }
        let menu = WiiMenuView(config: self.config, renderer: renderer)
        menu.onWii = { [weak self] in self?.showSettings() }
        menu.onLaunch = { [weak self] channel in self?.launch(channel) }
        return menu
    }
```
Add stub `func launch(_ channel: Channel) {}` (Task 17 implements).

- [ ] **Step 4: Build**

Run: `swift build`
Expected: succeeds.

- [ ] **Step 5: Manual verification**

Run `.build/debug/IvansMenu &`. Expected: near-white gradient desktop, a 4×3 grid of tiles (generated cards since no config yet — empty slots render as blank cards), bottom bar with live clock + wave, page arrows change pages. Quit via 🎮 menu.

- [ ] **Step 6: Commit**

```bash
git add Sources/IvansMenu
git commit -m "feat: Wii menu grid, tiles with hover, paging, bottom bar"
```

---

## Task 17: SystemWorkspace adapter + wire Launcher

**Files:**
- Create: `Sources/IvansMenu/SystemWorkspace.swift`
- Modify: `Sources/IvansMenu/AppDelegate.swift`

**Interfaces:**
- Consumes: `Workspace`, `Launcher`, `Channel`.
- Produces: `struct SystemWorkspace: Workspace` backed by `NSWorkspace.shared`. `AppDelegate.launch(_:)` uses `Launcher(workspace: SystemWorkspace())`.

- [ ] **Step 1: Write `SystemWorkspace.swift`**

```swift
import AppKit
import IvansMenuKit

struct SystemWorkspace: Workspace {
    func openApp(at url: URL) {
        NSWorkspace.shared.openApplication(at: url,
            configuration: NSWorkspace.OpenConfiguration())
    }
    func open(_ url: URL) { NSWorkspace.shared.open(url) }
    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
```

- [ ] **Step 2: Implement `AppDelegate.launch`**

```swift
    func launch(_ channel: Channel) {
        _ = Launcher(workspace: SystemWorkspace()).launch(channel.action)
    }
```

- [ ] **Step 3: Build**

Run: `swift build`
Expected: succeeds.

- [ ] **Step 4: Manual verification**

Temporarily set a channel in `config.json` (create `~/Library/Application Support/Ivan's Menu/config.json` with one `.app` action for Safari) and click that tile.
Expected: Safari launches.

- [ ] **Step 5: Commit**

```bash
git add Sources/IvansMenu
git commit -m "feat: wire real NSWorkspace launching on tile click"
```

---

## Task 18: SettingsView + window

**Files:**
- Create: `Sources/IvansMenu/ChannelStoreVM.swift`, `Sources/IvansMenu/SettingsView.swift`
- Modify: `Sources/IvansMenu/AppDelegate.swift`

**Interfaces:**
- Consumes: `ConfigStore`, `AppConfig`, `Channel`.
- Produces: `final class ChannelStoreVM: ObservableObject` wrapping `ConfigStore` with `@Published var config` and `func update(_:)`/`func save()`. `SettingsView: View` listing 48 slots; each row edits action (app picker via `NSOpenPanel`, URL text field), banner source, and title; toggles for sound/music/hideIcons. `AppDelegate.showSettings()` hosts it in an `NSWindow` (normal level, key).

- [ ] **Step 1: Write `ChannelStoreVM.swift`**

```swift
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
```

- [ ] **Step 2: Write `SettingsView.swift`**

```swift
import SwiftUI
import AppKit
import IvansMenuKit

struct SettingsView: View {
    @ObservedObject var vm: ChannelStoreVM

    var body: some View {
        TabView {
            channelsTab.tabItem { Text("Channels") }
            settingsTab.tabItem { Text("Settings") }
            aboutTab.tabItem { Text("About") }
        }
        .frame(width: 620, height: 520)
        .onDisappear { vm.save() }
    }

    private var channelsTab: some View {
        List(0..<Theme.totalSlots, id: \.self) { slot in
            if let idx = vm.binding(forSlot: slot) {
                ChannelRow(channel: $vm.config.channels[idx])
            }
        }
    }

    private var settingsTab: some View {
        Form {
            Toggle("Sound effects", isOn: $vm.config.settings.soundEnabled)
            Toggle("Ambient music", isOn: $vm.config.settings.musicEnabled)
            Toggle("Hide desktop icons", isOn: $vm.config.settings.hideDesktopIcons)
        }.padding()
    }

    private var aboutTab: some View {
        VStack(spacing: 12) {
            Text("Ivan's Menu").font(.title.bold())
            Text("An unofficial, fan-made tribute. Not affiliated with, endorsed by, or sponsored by Nintendo. All Nintendo trademarks belong to their respective owners.")
                .font(.footnote).multilineTextAlignment(.center).padding()
        }.padding()
    }
}

struct ChannelRow: View {
    @Binding var channel: Channel
    @State private var urlText: String = ""

    var body: some View {
        HStack {
            Text("Slot \(channel.slot)").frame(width: 60, alignment: .leading)
            Button("Choose App…") { pickApp() }
            TextField("https://…", text: $urlText, onCommit: {
                channel.action = .url(urlText)
            }).frame(width: 220)
            TextField("Title", text: Binding(
                get: { channel.title ?? "" },
                set: { channel.title = $0.isEmpty ? nil : $0 }))
        }
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        if panel.runModal() == .OK, let url = panel.url {
            channel.action = .app(path: url.path)
            if channel.title == nil {
                channel.title = url.deletingPathExtension().lastPathComponent
            }
        }
    }
}
```

- [ ] **Step 3: Implement `AppDelegate.showSettings`**

```swift
    var settingsWindow: NSWindow?
    lazy var settingsVM = ChannelStoreVM(store: store)

    func showSettings() {
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView(vm: settingsVM))
            let win = NSWindow(contentViewController: host)
            win.title = "Ivan's Menu"
            win.styleMask = [.titled, .closable]
            settingsWindow = win
        }
        NSApp.setActivationPolicy(.regular)
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
```
Add `import SwiftUI` at top of `AppDelegate.swift`.

- [ ] **Step 4: Build**

Run: `swift build`
Expected: succeeds.

- [ ] **Step 5: Manual verification**

Launch; click the Wii button (or 🎮 → Open Settings). Settings window opens; choose an app for a slot; close window; the tile updates on next rebuild.
Expected: settings edits persist to `config.json`.

- [ ] **Step 6: Commit**

```bash
git add Sources/IvansMenu
git commit -m "feat: SwiftUI settings (channels/settings/about) via Wii button"
```

---

## Task 19: Global hotkey (⌥Space peek)

**Files:**
- Create: `Sources/IvansMenu/GlobalHotKey.swift`
- Modify: `Sources/IvansMenu/AppDelegate.swift`

**Interfaces:**
- Produces: `final class GlobalHotKey` registering ⌥Space via Carbon `RegisterEventHotKey`, calling `onToggle: () -> Void`. `AppDelegate` uses it to toggle window visibility (peek desktop): `orderOut` on peek, `orderFront` on release/second press.

- [ ] **Step 1: Write `GlobalHotKey.swift`**

```swift
import AppKit
import Carbon.HIToolbox

final class GlobalHotKey {
    private var ref: EventHotKeyRef?
    private let onToggle: () -> Void
    private var handler: EventHandlerRef?

    init(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: OSType(kEventHotKeyPressed))
        let ptr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, ctx in
            let me = Unmanaged<GlobalHotKey>.fromOpaque(ctx!).takeUnretainedValue()
            me.onToggle()
            return noErr
        }, 1, &spec, ptr, &handler)

        var id = EventHotKeyID(signature: OSType(0x494D4E55), id: 1) // 'IMNU'
        RegisterEventHotKey(UInt32(kVK_Space), UInt32(optionKey),
                            id, GetApplicationEventTarget(), 0, &ref)
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
    }
}
```

- [ ] **Step 2: Wire into `AppDelegate`**

Add property and in `applicationDidFinishLaunching`:
```swift
    var hotKey: GlobalHotKey?
    var peeking = false
    // ...
    if config.settings.peekHotKeyEnabled {
        hotKey = GlobalHotKey { [weak self] in self?.togglePeek() }
    }
```
Add:
```swift
    func togglePeek() {
        peeking.toggle()
        windowController.setPeek(peeking)
    }
```
And add to `WallpaperWindowController`:
```swift
    func setPeek(_ peek: Bool) {
        windows.forEach { peek ? $0.orderOut(nil) : $0.orderFront(nil) }
    }
```

- [ ] **Step 3: Build**

Run: `swift build`
Expected: succeeds.

- [ ] **Step 4: Manual verification**

Launch; press ⌥Space → menu hides revealing real wallpaper; press again → returns. (Grant Accessibility/Input Monitoring if prompted.)
Expected: peek toggles.

- [ ] **Step 5: Commit**

```bash
git add Sources/IvansMenu
git commit -m "feat: ⌥Space global hotkey to peek the real desktop"
```

---

## Task 20: AudioEngine (sound cues + ambient music)

**Files:**
- Create: `Sources/IvansMenu/AudioEngine.swift`, placeholder `Sources/IvansMenu/Resources/Sounds/README.md`
- Modify: `ChannelTileView` (hover/select cues), `AppDelegate` (music toggle)

**Interfaces:**
- Consumes: `AppSettings`.
- Produces: `final class AudioEngine` with `static let shared`, `var soundEnabled/musicEnabled: Bool`, `func play(_ cue: Cue)` (`.hover/.select/.back`) using `NSSound`/`AVAudioPlayer` from bundled files, and `func startMusic()/stopMusic()`. Missing files → no-op (guards so build/run works before assets are added).

- [ ] **Step 1: Write `AudioEngine.swift`**

```swift
import AppKit
import AVFoundation

final class AudioEngine {
    static let shared = AudioEngine()
    var soundEnabled = true
    var musicEnabled = false
    private var music: AVAudioPlayer?

    enum Cue: String { case hover, select, back }

    func play(_ cue: Cue) {
        guard soundEnabled,
              let url = Bundle.module.url(forResource: cue.rawValue,
                                          withExtension: "caf", subdirectory: "Resources/Sounds")
        else { return }
        NSSound(contentsOf: url, byReference: true)?.play()
    }

    func startMusic() {
        guard musicEnabled, music == nil,
              let url = Bundle.module.url(forResource: "ambient", withExtension: "m4a",
                                          subdirectory: "Resources/Sounds")
        else { return }
        music = try? AVAudioPlayer(contentsOf: url)
        music?.numberOfLoops = -1; music?.volume = 0.4; music?.play()
    }

    func stopMusic() { music?.stop(); music = nil }
}
```

- [ ] **Step 2: Add cues in `ChannelTileView`**

In `setHover(true)` add `AudioEngine.shared.play(.hover)`; in `mouseDown` before `onLaunch` add `AudioEngine.shared.play(.select)`.

- [ ] **Step 3: Wire settings in `AppDelegate.applicationDidFinishLaunching`**

```swift
    AudioEngine.shared.soundEnabled = config.settings.soundEnabled
    AudioEngine.shared.musicEnabled = config.settings.musicEnabled
    AudioEngine.shared.startMusic()
```

- [ ] **Step 4: Build**

Run: `swift build`
Expected: succeeds (no audio files yet → cues are silent no-ops).

- [ ] **Step 5: Manual verification**

Launch; hover/click tiles — no crash with missing audio. (Audio becomes audible once original `.caf`/`.m4a` files are added to `Resources/Sounds`.)

- [ ] **Step 6: Commit**

```bash
git add Sources/IvansMenu
git commit -m "feat: AudioEngine cues + ambient music (guards missing assets)"
```

---

## Task 21: OnboardingView (first-run wizard)

**Files:**
- Create: `Sources/IvansMenu/OnboardingView.swift`
- Modify: `Sources/IvansMenu/AppDelegate.swift`

**Interfaces:**
- Consumes: `ChannelStoreVM`, `Channel`.
- Produces: `OnboardingView: View` — scans `/Applications`, shows a grid of installed apps (icon + name) to toggle-add, plus an "Add website" field; on Finish writes selected apps into the first open slots via `vm` and marks onboarding complete (`UserDefaults` key `didOnboard`). `AppDelegate` shows it on first launch (when `!didOnboard`).

- [ ] **Step 1: Write `OnboardingView.swift`**

```swift
import SwiftUI
import AppKit
import IvansMenuKit

struct OnboardingView: View {
    @ObservedObject var vm: ChannelStoreVM
    var onFinish: () -> Void
    @State private var selected: Set<String> = []
    @State private var website: String = ""

    private var apps: [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Applications"),
            includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "app" }.sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
    }

    var body: some View {
        VStack {
            Text("Pick your channels").font(.title2.bold())
            ScrollView {
                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 4)) {
                    ForEach(apps, id: \.path) { url in
                        appCell(url)
                    }
                }.padding()
            }
            HStack {
                TextField("Add a website (https://…)", text: $website)
                Button("Finish") { finish() }
            }.padding()
        }.frame(width: 640, height: 560)
    }

    private func appCell(_ url: URL) -> some View {
        let on = selected.contains(url.path)
        return VStack {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable().frame(width: 48, height: 48)
            Text(url.deletingPathExtension().lastPathComponent).font(.caption).lineLimit(1)
        }
        .padding(6)
        .background(on ? Color.accentColor.opacity(0.3) : Color.clear)
        .cornerRadius(8)
        .onTapGesture { if on { selected.remove(url.path) } else { selected.insert(url.path) } }
    }

    private func finish() {
        var slot = 0
        func nextSlot() -> Int? {
            while slot < Theme.totalSlots {
                let s = slot; slot += 1
                if let i = vm.binding(forSlot: s), vm.config.channels[i].isEmpty { return i }
            }
            return nil
        }
        for path in selected.sorted() {
            guard let i = nextSlot() else { break }
            vm.config.channels[i].action = .app(path: path)
            vm.config.channels[i].title = URL(fileURLWithPath: path)
                .deletingPathExtension().lastPathComponent
        }
        if let url = URL(string: website), url.scheme != nil, let i = nextSlot() {
            vm.config.channels[i].action = .url(website)
        }
        vm.save()
        UserDefaults.standard.set(true, forKey: "didOnboard")
        onFinish()
    }
}
```

- [ ] **Step 2: Show on first run in `AppDelegate`**

After building windows, add:
```swift
    if !UserDefaults.standard.bool(forKey: "didOnboard") {
        let host = NSHostingController(rootView:
            OnboardingView(vm: settingsVM) { [weak self] in
                self?.settingsWindow?.close()
                self?.reloadMenu()
            })
        let win = NSWindow(contentViewController: host)
        win.title = "Welcome to Ivan's Menu"
        win.styleMask = [.titled]
        NSApp.setActivationPolicy(.regular)
        win.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        self.settingsWindow = win
    }
```
Add `func reloadMenu()` that reloads `config = store.load()` and calls the same `windowController.rebuild { ... }` closure (extract that closure into a `buildMenuContent` method reused by launch and reload).

- [ ] **Step 3: Build**

Run: `swift build`
Expected: succeeds.

- [ ] **Step 4: Manual verification**

Delete the `didOnboard` default: `defaults delete <bundle-or-app-domain> didOnboard` (or run fresh). Launch; wizard appears; pick a few apps + a URL; Finish → tiles populate.
Expected: onboarding populates channels and doesn't reappear next launch.

- [ ] **Step 5: Commit**

```bash
git add Sources/IvansMenu
git commit -m "feat: first-run onboarding wizard populates channels"
```

---

## Task 22: Bundled fonts + Channel Pack scaffolding

**Files:**
- Create: `Sources/IvansMenu/Resources/Fonts/README.md`, `Sources/IvansMenu/Resources/Banners/manifest.json`, `Sources/IvansMenu/FontLoader.swift`
- Modify: `AppDelegate` (register fonts), `BannerRenderer` wiring (load pack)

**Interfaces:**
- Produces: `enum FontLoader { static func registerBundledFonts() }` registering any `.ttf` under `Resources/Fonts` via `CTFontManagerRegisterFontsForURL`. `manifest.json` maps pack ids → filenames (`[{"id":"youtube","file":"youtube.png"}]`), initially empty `[]`. `AppDelegate` builds `packIDs`/`packImage` from the manifest for `BannerRenderer`.

- [ ] **Step 1: Write `FontLoader.swift`**

```swift
import AppKit
import CoreText

enum FontLoader {
    static func registerBundledFonts() {
        guard let dir = Bundle.module.url(forResource: "Fonts", withExtension: nil,
                                          subdirectory: "Resources") else { return }
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil)) ?? []
        for url in urls where ["ttf", "otf"].contains(url.pathExtension.lowercased()) {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
```

- [ ] **Step 2: Write `Resources/Banners/manifest.json`**

```json
[]
```

- [ ] **Step 3: Write `Resources/Fonts/README.md`**

```markdown
Place OFL fonts here (not committed as binaries in the plan step):
- Asap (Regular, Medium, SemiBold) — SIL Open Font License
- M PLUS Rounded 1c (Regular, Bold) — SIL Open Font License
Download from Google Fonts. These are the Rodin NTLG substitutes.
```

- [ ] **Step 4: Wire pack + fonts in `AppDelegate`**

At start of `applicationDidFinishLaunching`: `FontLoader.registerBundledFonts()`.
Add a helper to load the manifest and build the `BannerRenderer` inputs:
```swift
    struct PackEntry: Decodable { let id: String; let file: String }
    func loadPack() -> (Set<String>, (String) -> NSImage?) {
        guard let url = Bundle.module.url(forResource: "manifest", withExtension: "json",
                                          subdirectory: "Resources/Banners"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([PackEntry].self, from: data)
        else { return ([], { _ in nil }) }
        let map = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0.file) })
        let image: (String) -> NSImage? = { id in
            guard let file = map[id],
                  let u = Bundle.module.url(forResource: file, withExtension: nil,
                                            subdirectory: "Resources/Banners")
            else { return nil }
            return NSImage(contentsOf: u)
        }
        return (Set(map.keys), image)
    }
```
Use it when constructing `BannerRenderer` in `buildMenuContent`.

- [ ] **Step 5: Build**

Run: `swift build`
Expected: succeeds (empty pack → all tiles use generated cards).

- [ ] **Step 6: Manual verification**

Launch; if OFL fonts are dropped into `Resources/Fonts`, apply `Asap` to the clock/tiles (font application is a follow-up polish; registration must not crash when the folder is empty).
Expected: no crash with empty fonts/banners.

- [ ] **Step 7: Commit**

```bash
git add Sources/IvansMenu
git commit -m "feat: font registration + Channel Pack manifest scaffolding"
```

---

## Task 23: App bundling + code signing script

**Files:**
- Create: `scripts/bundle.sh`, `Sources/IvansMenu/Info.plist`
- Modify: none

**Interfaces:**
- Produces: `scripts/bundle.sh` — `swift build -c release`, assemble `IvansMenu.app/Contents/{MacOS,Resources,Info.plist}`, copy the SPM resource bundle, and `codesign` (optional `DEVELOPER_ID` env var). `Info.plist` sets `LSUIElement = true`, bundle id `com.ivankuria.ivansmenu`, name "Ivan's Menu".

- [ ] **Step 1: Write `Sources/IvansMenu/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Ivan's Menu</string>
  <key>CFBundleIdentifier</key><string>com.ivankuria.ivansmenu</string>
  <key>CFBundleExecutable</key><string>IvansMenu</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key>
  <string>Unofficial fan tribute. Not affiliated with Nintendo.</string>
</dict>
</plist>
```

- [ ] **Step 2: Write `scripts/bundle.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
APP="IvansMenu.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Sources/IvansMenu/Info.plist "$APP/Contents/Info.plist"
cp .build/release/IvansMenu "$APP/Contents/MacOS/IvansMenu"

# Copy SPM resource bundle if present
BUNDLE=$(find .build/release -maxdepth 1 -name "*IvansMenu*.bundle" | head -1 || true)
if [ -n "${BUNDLE:-}" ]; then cp -R "$BUNDLE" "$APP/Contents/Resources/"; fi

if [ -n "${DEVELOPER_ID:-}" ]; then
  codesign --deep --force --options runtime \
    --sign "$DEVELOPER_ID" "$APP"
  echo "Signed with $DEVELOPER_ID"
else
  echo "Set DEVELOPER_ID to code-sign (e.g. 'Developer ID Application: Name (TEAMID)')."
fi
echo "Built $APP"
```

- [ ] **Step 3: Make executable + run**

Run: `chmod +x scripts/bundle.sh && ./scripts/bundle.sh`
Expected: `IvansMenu.app` created; prints signing hint (or signs if `DEVELOPER_ID` set).

- [ ] **Step 4: Manual verification**

Run: `open IvansMenu.app`
Expected: launches as the agent app (menu-bar 🎮, immersive menu), quits cleanly from the status item restoring desktop icons.

- [ ] **Step 5: Commit**

```bash
git add scripts/bundle.sh Sources/IvansMenu/Info.plist
git commit -m "build: .app bundling + code-signing script"
```

---

## Task 24: README, LICENSE, disclaimer, .gitignore polish

**Files:**
- Create: `README.md`, `LICENSE`
- Modify: `.gitignore`

**Interfaces:**
- Produces: MIT `LICENSE`; `README.md` with description, the mandatory Nintendo disclaimer, build-from-source (`swift build`, `./scripts/bundle.sh`), signing note, and asset/font (OFL) credits.

- [ ] **Step 1: Write `LICENSE`** (standard MIT text, copyright "2026 Ivan Kuria").

- [ ] **Step 2: Write `README.md`**

```markdown
# Ivan's Menu

Turn your Mac desktop into a faithful, interactive Wii-style channel menu.
Each channel launches a real app, website, file, or folder.

> **Disclaimer:** Ivan's Menu is an unofficial, fan-made tribute. Not
> affiliated with, endorsed by, or sponsored by Nintendo. All Nintendo
> trademarks belong to their respective owners. It ships **no** Nintendo
> assets — all art, sounds, and code are original; bundled fonts are OFL.

## Build from source

```bash
swift build            # debug
swift test             # run the Kit test suite
./scripts/bundle.sh    # assemble IvansMenu.app (set DEVELOPER_ID to sign)
open IvansMenu.app
```

## Usage
- First launch runs an onboarding wizard to pick your channels.
- The round **Wii** button (or the 🎮 menu-bar item) opens Settings.
- **⌥Space** peeks the real desktop.
- Quit from the 🎮 menu-bar item (restores your desktop icons).

## Credits
- Fonts: Asap, M PLUS Rounded 1c (SIL Open Font License).
- Inspired by the 2006 Wii Menu; all assets re-created originally.
```

- [ ] **Step 3: Build + test (final gate)**

Run: `swift build && swift test`
Expected: build succeeds; all Kit tests PASS.

- [ ] **Step 4: Commit**

```bash
git add README.md LICENSE .gitignore
git commit -m "docs: README, MIT license, disclaimer, credits"
```

---

## Self-Review (completed against spec)

- **Spec §2 aesthetic** → Theme constants (T1), grid/paging (T16), bottom bar/wave/clock (T13–14), fonts (T22). ✓
- **Spec §3 architecture units** → every unit has a task (AppDelegate T9/T12, windows T10, icons T11, WiiMenuView/tiles T16, wave T13, ConfigStore T4, Channel T2, BannerRenderer T15, Launcher T5, Onboarding T21, Settings T18). ✓
- **Spec §3.8 banner priority + dominant color** → T6 (color), T8 (plan), T15 (render). ✓
- **Spec §4 data flow** → ConfigStore↔VM↔views (T4/T18), click→Launcher (T17). ✓
- **Spec §5 audio** → T20. ✓
- **Spec §6 error handling** → corrupt recovery (T4), launch false-return (T5), missing assets guards (T20/T22), display rebuild (T10), icon-toggle best-effort (T11). ✓
- **Spec §8 distribution/legal** → bundling/sign (T23), README/LICENSE/disclaimer (T24). ✓
- **Spec §9 scope** → all v1 items covered; deferred items excluded. ✓
- **Type consistency** → `Workspace` (openApp/open/reveal) consistent T5↔T17; `BannerRenderer.image(for:size:)` consistent T15↔T16; `ChannelStoreVM.binding(forSlot:)` consistent T18↔T21. ✓
- **Placeholder scan** → all steps contain real code/commands. ✓
```
