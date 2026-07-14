import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var soundEnabled: Bool
    public var musicEnabled: Bool
    public var hideDesktopIcons: Bool
    public var menuDisplayID: String?
    public var peekHotKeyEnabled: Bool

    public init(soundEnabled: Bool = true, musicEnabled: Bool = true,
                hideDesktopIcons: Bool = true, menuDisplayID: String? = nil,
                peekHotKeyEnabled: Bool = true) {
        self.soundEnabled = soundEnabled; self.musicEnabled = musicEnabled
        self.hideDesktopIcons = hideDesktopIcons; self.menuDisplayID = menuDisplayID
        self.peekHotKeyEnabled = peekHotKeyEnabled
    }
}
