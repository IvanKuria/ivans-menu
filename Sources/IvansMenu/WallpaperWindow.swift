import AppKit

final class WallpaperWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless],
                   backing: .buffered, defer: false)
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
    // Don't become key/main: clicks still register via the views' acceptsFirstMouse,
    // but the window never steals focus or activates the app — which was causing the
    // desktop to switch away and the cursor to flicker on interaction.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
