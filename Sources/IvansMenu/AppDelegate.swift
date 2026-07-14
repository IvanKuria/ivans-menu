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

        if config.settings.hideDesktopIcons { DesktopIcons.setHidden(true) }

        statusItem = StatusItemController(
            onSettings: { [weak self] in self?.showSettings() },
            onQuit: { NSApp.terminate(nil) })
    }

    func applicationWillTerminate(_ notification: Notification) {
        if config.settings.hideDesktopIcons { DesktopIcons.setHidden(false) }
    }

    func showSettings() {}

    func launch(_ channel: Channel) {}
}
