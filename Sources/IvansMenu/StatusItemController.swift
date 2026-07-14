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
        item.button?.title = "🎮"
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
    @objc private func settings() { onSettings() }
    @objc private func installTheme() { onInstallTheme() }
    @objc private func restoreIcons() { onRestoreIcons() }
    @objc private func quit() { onQuit() }
}
