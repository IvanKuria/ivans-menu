import AppKit
import IvansMenuKit

/// Offscreen screenshot harness for design iteration.
/// Usage: `IvansMenu --render <output.png> [width height]`
/// Renders the Wii menu to a PNG without creating the desktop window or
/// hiding Finder icons, so we can inspect the UI visually and iterate.
@MainActor
enum RenderHarness {
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let idx = args.firstIndex(of: "--render") else { return false }
        let outPath = (idx + 1 < args.count) ? args[idx + 1] : "wii-render.png"
        var width: CGFloat = 1440, height: CGFloat = 900
        if idx + 3 < args.count, let w = Double(args[idx + 2]), let h = Double(args[idx + 3]) {
            width = w; height = h
        }

        // Initialize AppKit enough to draw, but stay invisible.
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)

        let config = sampleConfig()
        let renderer = BannerRenderer(
            packIDs: [],
            packImage: { _ in nil },
            appIcon: { action in
                if case .app(let path) = action { return NSWorkspace.shared.icon(forFile: path) }
                return NSWorkspace.shared.icon(for: .applicationBundle)
            })

        let view = WiiMenuView(config: config, renderer: renderer)
        view.frame = NSRect(x: 0, y: 0, width: width, height: height)

        // Host in an offscreen window so layer-backed content composites correctly.
        let window = NSWindow(contentRect: view.frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.contentView = view
        window.setFrameOrigin(NSPoint(x: -10000, y: -10000)) // offscreen
        window.orderFrontRegardless()
        view.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4)) // let layers settle

        guard let png = pngData(of: view) else {
            FileHandle.standardError.write(Data("render: failed to capture image\n".utf8))
            exit(2)
        }
        do {
            try png.write(to: URL(fileURLWithPath: outPath))
            FileHandle.standardError.write(Data("render: wrote \(outPath) (\(Int(width))x\(Int(height)))\n".utf8))
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("render: write failed: \(error)\n".utf8))
            exit(2)
        }
    }

    /// Capture a view (including CALayer content) to PNG via its window backing store.
    private static func pngData(of view: NSView) -> Data? {
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep.representation(using: .png, properties: [:])
    }

    /// A representative config: a mix of real system apps + a website + empty slots,
    /// so screenshots show occupied and empty tiles like a real menu page.
    private static func sampleConfig() -> AppConfig {
        var cfg = AppConfig.makeDefault()
        let apps: [(Int, String)] = [
            (0, "/System/Applications/Safari.app"),
            (1, "/System/Applications/Music.app"),
            (2, "/System/Applications/Messages.app"),
            (3, "/System/Applications/Photos.app"),
            (4, "/System/Applications/Maps.app"),
            (5, "/System/Applications/Notes.app"),
            (6, "/System/Applications/Calendar.app"),
            (7, "/System/Applications/Mail.app"),
        ]
        for (slot, path) in apps where FileManager.default.fileExists(atPath: path) {
            if let i = cfg.channels.firstIndex(where: { $0.slot == slot }) {
                cfg.channels[i].action = .app(path: path)
            }
        }
        return cfg
    }
}
