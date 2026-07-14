import AppKit
import IvansMenuKit

struct SystemWorkspace: Workspace {
    func openApp(at url: URL) {
        NSWorkspace.shared.openApplication(at: url,
            configuration: NSWorkspace.OpenConfiguration())
    }
    func open(_ url: URL) { NSWorkspace.shared.open(url) }
    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
