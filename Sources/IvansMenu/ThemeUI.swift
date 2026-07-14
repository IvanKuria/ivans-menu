import AppKit
import SwiftUI
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

extension Color {
    private static func rgb(_ c: (r: Double, g: Double, b: Double)) -> Color {
        Color(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: 1)
    }
    static var wiiAccent: Color { rgb(Theme.accent) }
    static var wiiBottomBar: Color { rgb(Theme.bottomBar) }
    static var wiiClock: Color { rgb(Theme.clockText) }
    static var wiiBGCenter: Color { rgb(Theme.bgCenter) }
    static var wiiBGEdge: Color { rgb(Theme.bgEdge) }
}
