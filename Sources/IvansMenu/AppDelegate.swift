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
    var onboardingWindow: NSWindow?
    lazy var settingsVM = ChannelStoreVM(store: store)
    var hotKey: GlobalHotKey?
    var peeking = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        FontLoader.registerBundledFonts()
        config = store.load()
        NSApp.setActivationPolicy(.accessory) // agent app, no Dock icon

        rebuildMenu()

        if config.settings.hideDesktopIcons { DesktopIcons.setHidden(true) }

        statusItem = StatusItemController(
            onSettings: { [weak self] in self?.showSettings() },
            onQuit: { NSApp.terminate(nil) })

        if config.settings.peekHotKeyEnabled {
            hotKey = GlobalHotKey { [weak self] in self?.togglePeek() }
        }

        AudioEngine.shared.soundEnabled = config.settings.soundEnabled
        AudioEngine.shared.musicEnabled = config.settings.musicEnabled
        AudioEngine.shared.startMusic()

        if !UserDefaults.standard.bool(forKey: "didOnboard") {
            showOnboarding()
        }
    }

    private func buildMenuContent(_ screen: NSScreen) -> NSView {
        let (packIDs, packImage) = loadPack()
        let renderer = BannerRenderer(
            packIDs: packIDs,
            packImage: packImage,
            appIcon: { action in
                if case .app(let path) = action {
                    return NSWorkspace.shared.icon(forFile: path)
                }
                return NSWorkspace.shared.icon(for: UTType.data)
            })
        let menu = WiiMenuView(config: self.config, renderer: renderer)
        menu.onWii = { [weak self] in self?.showSettings() }
        menu.onLaunch = { [weak self] channel in self?.launch(channel) }
        return menu
    }

    struct PackEntry: Decodable { let id: String; let file: String }
    func loadPack() -> (Set<String>, (String) -> NSImage?) {
        guard let url = Bundle.module.url(forResource: "manifest", withExtension: "json",
                                          subdirectory: "Resources/Banners"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([PackEntry].self, from: data)
        else { return ([], { _ in nil }) }
        let map = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0.file) })
        let image: (String) -> NSImage? = { id in
            guard let file = map[id],
                  let u = Bundle.module.url(forResource: file, withExtension: nil,
                                            subdirectory: "Resources/Banners")
            else { return nil }
            return NSImage(contentsOf: u)
        }
        return (Set(map.keys), image)
    }

    private func rebuildMenu() {
        windowController.rebuild { [weak self] screen in
            guard let self else { return NSView() }
            return self.buildMenuContent(screen)
        }
    }

    func reloadMenu() {
        config = store.load()
        rebuildMenu()
    }

    private func showOnboarding() {
        let host = NSHostingController(rootView:
            OnboardingView(vm: settingsVM) { [weak self] in
                self?.onboardingWindow?.close()
                self?.reloadMenu()
            })
        let win = NSWindow(contentViewController: host)
        win.title = "Welcome to Ivan's Menu"
        win.styleMask = [.titled]
        win.delegate = self
        NSApp.setActivationPolicy(.regular)
        win.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = win
    }

    func togglePeek() {
        peeking.toggle()
        windowController.setPeek(peeking)
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
        if window === settingsWindow || window === onboardingWindow {
            NSApp.setActivationPolicy(.accessory)
        }
        if window === onboardingWindow {
            onboardingWindow = nil
        }
    }

    func launch(_ channel: Channel) {
        _ = Launcher(workspace: SystemWorkspace()).launch(channel.action)
    }
}
