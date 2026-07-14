import AppKit
import IvansMenuKit

extension NSColor {
    private static func rgb(_ c: (r: Double, g: Double, b: Double)) -> NSColor {
        NSColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: 1)
    }
    static var wiiAccent: NSColor { rgb(Theme.accent) }
    static var wiiBottomBar: NSColor { rgb(Theme.bottomBar) }
    static var wiiClock: NSColor { rgb(Theme.clockText) }
    static var wiiBGCenter: NSColor { rgb(Theme.bgCenter) }
    static var wiiBGEdge: NSColor { rgb(Theme.bgEdge) }
}
