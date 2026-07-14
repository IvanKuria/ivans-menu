import AppKit

@MainActor
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
