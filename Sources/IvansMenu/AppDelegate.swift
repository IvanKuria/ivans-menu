import AppKit
import SwiftUI
import IvansMenuKit
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store = ConfigStore()
    private(set) var config: AppConfig = .makeDefault()
    let windowController = WallpaperWindowController()
    var statusItem: StatusItemController?
    var settingsWindow: NSWindow?
    lazy var settingsVM = ChannelStoreVM(store: store)

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
                return NSWorkspace.shared.icon(for: UTType.data)
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

    func showSettings() {
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView(vm: settingsVM))
            let win = NSWindow(contentViewController: host)
            win.title = "Ivan's Menu"
            win.styleMask = [.titled, .closable]
            win.delegate = self
            settingsWindow = win
        }
        settingsWindow?.delegate = self
        NSApp.setActivationPolicy(.regular)
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === settingsWindow {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func launch(_ channel: Channel) {
        _ = Launcher(workspace: SystemWorkspace()).launch(channel.action)
    }
}
