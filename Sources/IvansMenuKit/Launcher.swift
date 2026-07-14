import Foundation

public struct Launcher {
    private let workspace: Workspace
    public init(workspace: Workspace) { self.workspace = workspace }

    @discardableResult
    public func launch(_ action: ChannelAction) -> Bool {
        switch action {
        case .empty: return false
        case .app(let path):
            guard !path.isEmpty else { return false }
            workspace.openApp(at: URL(fileURLWithPath: path)); return true
        case .url(let s):
            guard let url = URL(string: s), url.scheme != nil else { return false }
            workspace.open(url); return true
        case .file(let path):
            guard !path.isEmpty else { return false }
            workspace.open(URL(fileURLWithPath: path)); return true
        case .folder(let path):
            guard !path.isEmpty else { return false }
            workspace.reveal(URL(fileURLWithPath: path)); return true
        }
    }
}
