import AppKit
import IvansMenuKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ConfigStore()
    private(set) var config: AppConfig = .makeDefault()
    let windowController = WallpaperWindowController()
    var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        config = store.load()
        NSApp.setActivationPolicy(.accessory) // agent app, no Dock icon

        windowController.rebuild { _ in
            let v = NSView()
            v.wantsLayer = true
            v.layer?.backgroundColor = NSColor.wiiBGCenter.cgColor
            return v
        }

        if config.settings.hideDesktopIcons { DesktopIcons.setHidden(true) }

        statusItem = StatusItemController(
            onSettings: { [weak self] in self?.showSettings() },
            onQuit: { NSApp.terminate(nil) })
    }

    func applicationWillTerminate(_ notification: Notification) {
        if config.settings.hideDesktopIcons { DesktopIcons.setHidden(false) }
    }

    func showSettings() {}
}
