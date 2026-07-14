import Foundation

public protocol Workspace {
    func openApp(at url: URL)
    func open(_ url: URL)
    func reveal(_ url: URL)
}
