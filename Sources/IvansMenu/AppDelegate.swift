import AppKit
import IvansMenuKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ConfigStore()
    private(set) var config: AppConfig = .makeDefault()

    func applicationDidFinishLaunching(_ notification: Notification) {
        config = store.load()
        NSApp.setActivationPolicy(.accessory) // agent app, no Dock icon
    }
}
