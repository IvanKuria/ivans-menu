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
            onInstallTheme: { [weak self] in self?.installThemePack() },
            onRestoreIcons: { DesktopIcons.setHidden(false) },
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
        menu.onEditChannel = { [weak self] slot, kind in self?.editChannel(slot: slot, kind: kind) }
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

    func applySettings() {
        AudioEngine.shared.soundEnabled = config.settings.soundEnabled
        AudioEngine.shared.musicEnabled = config.settings.musicEnabled
        if AudioEngine.shared.musicEnabled {
            AudioEngine.shared.startMusic()
        } else {
            AudioEngine.shared.stopMusic()
        }
        DesktopIcons.setHidden(config.settings.hideDesktopIcons)
    }

    private func showOnboarding() {
        let host = NSHostingController(rootView:
            OnboardingView(vm: settingsVM) { [weak self] in
                self?.onboardingWindow?.close()
                self?.reloadMenu()
                self?.applySettings()
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
        if window === settingsWindow {
            settingsVM.save()
            reloadMenu()
            applySettings()
        }
        if window === settingsWindow || window === onboardingWindow {
            let otherStillVisible: Bool
            if window === settingsWindow {
                otherStillVisible = onboardingWindow?.isVisible ?? false
            } else {
                otherStillVisible = settingsWindow?.isVisible ?? false
            }
            if !otherStillVisible {
                NSApp.setActivationPolicy(.accessory)
            }
        }
        if window === onboardingWindow {
            onboardingWindow = nil
        }
    }

    func launch(_ channel: Channel) {
        _ = Launcher(workspace: SystemWorkspace()).launch(channel.action)
    }

    /// Configure a channel in place from its right-click menu, then refresh.
    func editChannel(slot: Int, kind: ChannelEdit) {
        NSApp.activate(ignoringOtherApps: true)
        guard let i = settingsVM.config.channels.firstIndex(where: { $0.slot == slot }) else { return }
        switch kind {
        case .app:
            let p = NSOpenPanel()
            p.directoryURL = URL(fileURLWithPath: "/Applications")
            p.allowedContentTypes = [.application]
            guard p.runModal() == .OK, let url = p.url else { return }
            settingsVM.config.channels[i].action = .app(path: url.path)
            if settingsVM.config.channels[i].title == nil {
                settingsVM.config.channels[i].title = url.deletingPathExtension().lastPathComponent
            }
        case .url:
            guard let s = promptText("Open website", placeholder: "https://…",
                                     initial: ""), !s.isEmpty else { return }
            settingsVM.config.channels[i].action = .url(s)
        case .thumbnail:
            let p = NSOpenPanel()
            p.message = "Choose a channel thumbnail (PNG, JPEG, or animated GIF)"
            p.allowedContentTypes = [.image, .gif, .png, .jpeg]
            guard p.runModal() == .OK, let url = p.url else { return }
            settingsVM.config.channels[i].banner = .custom(path: url.path)
        case .title:
            guard let s = promptText("Channel name", placeholder: "Name",
                                     initial: settingsVM.config.channels[i].title ?? "") else { return }
            settingsVM.config.channels[i].title = s.isEmpty ? nil : s
        case .clear:
            settingsVM.config.channels[i].action = .empty
            settingsVM.config.channels[i].banner = .generated
            settingsVM.config.channels[i].title = nil
        }
        settingsVM.save()
        reloadMenu()
    }

    private func promptText(_ title: String, placeholder: String, initial: String) -> String? {
        // Become a regular app so the alert's text field can take keyboard focus + paste.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = placeholder
        field.stringValue = initial
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        let response = alert.runModal()
        if settingsWindow?.isVisible != true, onboardingWindow?.isVisible != true {
            NSApp.setActivationPolicy(.accessory)
        }
        return response == .alertFirstButtonReturn ? field.stringValue : nil
    }

    /// Download the (third-party-hosted) Wii art pack into the user's theme
    /// folder, then refresh the menu with the real art. The public repo hosts
    /// none of these files — this is an opt-in fidelity upgrade.
    func installThemePack() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        ThemePackInstaller.install(progress: { _ in }) { [weak self] result in
            DispatchQueue.main.async {
                let alert = NSAlert()
                switch result {
                case .success(let count):
                    AssetLibrary.shared.reload()
                    self?.rebuildMenu()
                    alert.messageText = "Wii theme installed"
                    alert.informativeText = "\(count) assets installed. Your menu now uses the Wii art."
                case .failure(let error):
                    alert.alertStyle = .warning
                    alert.messageText = "Couldn't install the Wii theme"
                    alert.informativeText = "\(error)\n\nSet the pack URL in ThemePackInstaller, then try again."
                }
                alert.runModal()
                if self?.settingsWindow?.isVisible != true, self?.onboardingWindow?.isVisible != true {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
    }
}
