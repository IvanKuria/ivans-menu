import AppKit

@MainActor
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

    func setPeek(_ peek: Bool) {
        windows.forEach { peek ? $0.orderOut(nil) : $0.orderFront(nil) }
    }

    @objc private func screensChanged() {
        if let content = contentProvider { rebuild(content: content) }
    }
}
