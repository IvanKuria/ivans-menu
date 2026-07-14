import AppKit

@MainActor
final class StatusItemController {
    private let item: NSStatusItem
    private let onSettings: () -> Void
    private let onInstallTheme: () -> Void
    private let onRestoreIcons: () -> Void
    private let onQuit: () -> Void

    init(onSettings: @escaping () -> Void, onInstallTheme: @escaping () -> Void,
         onRestoreIcons: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onSettings = onSettings; self.onInstallTheme = onInstallTheme
        self.onRestoreIcons = onRestoreIcons; self.onQuit = onQuit
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = Self.menuBarGlyph()
        item.button?.imagePosition = .imageOnly
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Settings…", action: #selector(settings), keyEquivalent: ",")
            .target = self
        menu.addItem(withTitle: "Install Wii Theme…", action: #selector(installTheme), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Restore Desktop Icons", action: #selector(restoreIcons), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Ivan's Menu", action: #selector(quit), keyEquivalent: "q")
            .target = self
        item.menu = menu
    }
    /// The Wii "double-i" mark as a monochrome template glyph so the menu bar
    /// tints it for light/dark automatically. Echoes the app icon's two figures.
    private static func menuBarGlyph() -> NSImage {
        let size = NSSize(width: 17, height: 15)
        let img = NSImage(size: size, flipped: false) { _ in
            let stemW: CGFloat = 2.6
            let stemH: CGFloat = 6.4
            let headR: CGFloat = 1.7
            let baseY: CGFloat = 2.6
            let gap: CGFloat = 3.0           // half-distance between the two figures
            NSColor.black.setFill()
            for (cx, lean) in [(size.width/2 - gap, 6.0), (size.width/2 + gap, -6.0)] {
                let t = NSAffineTransform()
                t.translateX(by: cx, yBy: baseY); t.rotate(byDegrees: lean)
                t.translateX(by: -cx, yBy: -baseY)
                NSGraphicsContext.saveGraphicsState(); t.concat()
                // Body (rounded stem).
                let body = NSRect(x: cx - stemW/2, y: baseY, width: stemW, height: stemH)
                NSBezierPath(roundedRect: body, xRadius: stemW/2, yRadius: stemW/2).fill()
                // Head (dot) floating above, Wii-style.
                let head = NSRect(x: cx - headR, y: body.maxY + 1.1, width: headR*2, height: headR*2)
                NSBezierPath(ovalIn: head).fill()
                NSGraphicsContext.restoreGraphicsState()
            }
            return true
        }
        img.isTemplate = true   // let the menu bar tint for light/dark
        return img
    }

    @objc private func settings() { onSettings() }
    @objc private func installTheme() { onInstallTheme() }
    @objc private func restoreIcons() { onRestoreIcons() }
    @objc private func quit() { onQuit() }
}
