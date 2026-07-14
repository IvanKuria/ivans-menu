import AppKit

/// Loads optional real Wii art. Two sources, checked in order:
///  1. the user's writable theme folder (`~/Library/Application Support/Ivan's Menu/Wii`)
///     — where the first-run theme-pack download lands;
///  2. the bundled `Resources/Wii` folder — used for local development.
/// When an asset is present it is used for maximum fidelity; when absent the
/// views fall back to the Core-Graphics drawing in `WiiControls`, so the app
/// always builds and runs even with no art installed.
@MainActor
enum WiiAsset: String, CaseIterable {
    case background
    case bottombar
    case wave
    case channelFrame = "channel_frame"
    case frameCyan = "frame_cyan"
    case frameGray = "frame_gray"
    case emptyCard = "empty_card"
    case emptyFrame = "empty_frame"
    case wiiButton = "wii_button"
    case mailButton = "mail_button"
    case sdCard = "sd_card"
    case arrowLeft = "arrow_left"
    case arrowRight = "arrow_right"
    case cursor
}

@MainActor
final class AssetLibrary {
    static let shared = AssetLibrary()
    private var cache: [String: NSImage?] = [:]

    /// User-writable theme directory (survives app updates; where downloads land).
    nonisolated static var userThemeDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        return base.appendingPathComponent("Ivan's Menu", isDirectory: true)
                   .appendingPathComponent("Wii", isDirectory: true)
    }

    func image(_ asset: WiiAsset) -> NSImage? {
        if let cached = cache[asset.rawValue] { return cached }
        let img = loadImage(named: asset.rawValue)
        cache[asset.rawValue] = img
        return img
    }

    private func loadImage(named name: String) -> NSImage? {
        // 1. user theme dir
        let userURL = AssetLibrary.userThemeDir.appendingPathComponent("\(name).png")
        if FileManager.default.fileExists(atPath: userURL.path),
           let img = NSImage(contentsOf: userURL) {
            return img
        }
        // 2. bundled dev copy
        if let url = Bundle.module.url(forResource: name, withExtension: "png",
                                       subdirectory: "Resources/Wii"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        return nil
    }

    /// Drop cached lookups (call after a theme pack is installed).
    func reload() { cache.removeAll() }

    /// True if any real Wii art is installed (used to pick asset vs. drawn look).
    var hasArt: Bool { image(.background) != nil || image(.channelFrame) != nil }
}

extension NSImage {
    /// Returns a copy recolored to `color`, preserving the original alpha shape.
    func tinted(with color: NSColor) -> NSImage? {
        let img = NSImage(size: size)
        img.lockFocus()
        color.set()
        let rect = NSRect(origin: .zero, size: size)
        draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        rect.fill(using: .sourceAtop)
        img.unlockFocus()
        return img
    }
}
