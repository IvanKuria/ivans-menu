import AppKit
import IvansMenuKit

// Core-Graphics drawing of the Wii Menu's signature components, matched to the
// original System Menu sprite art: glossy white "orb" buttons, blue glossy page
// chevrons, pillowed channel cards, and the wavy divider. All drawing is done in
// `draw(_:)` so it renders identically on screen and in the offscreen harness.

enum WiiPalette {
    static let accent = NSColor(srgbRed: 0.235, green: 0.725, blue: 0.902, alpha: 1)   // #3CB9E6
    static let accentDeep = NSColor(srgbRed: 0.129, green: 0.651, blue: 0.867, alpha: 1) // #21A6DD
    static let accentLight = NSColor(srgbRed: 0.435, green: 0.816, blue: 0.949, alpha: 1) // #6FD0F2
    static let glyph = NSColor(srgbRed: 0.482, green: 0.514, blue: 0.553, alpha: 1)      // #7B838D
    static let orbTop = NSColor.white
    static let orbMid = NSColor(srgbRed: 0.933, green: 0.945, blue: 0.957, alpha: 1)     // #EEF1F4
    static let orbBottom = NSColor(srgbRed: 0.812, green: 0.831, blue: 0.855, alpha: 1)  // #CFD4DA
    static let orbRim = NSColor(srgbRed: 0.725, green: 0.745, blue: 0.773, alpha: 1)     // #B9BEC5
    static let cardBorder = NSColor(srgbRed: 0.792, green: 0.808, blue: 0.827, alpha: 1) // #CACDD3
}

enum WiiDraw {
    /// A glossy white sphere ("orb") button base, filling `rect` (assumed square-ish).
    static func orb(in rect: NSRect, pressed: Bool = false) {
        let d = min(rect.width, rect.height)
        let circleRect = NSRect(x: rect.midX - d/2, y: rect.midY - d/2, width: d, height: d)
            .insetBy(dx: d * 0.06, dy: d * 0.06)

        // Soft drop shadow under the orb.
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
        shadow.shadowBlurRadius = d * 0.06
        shadow.shadowOffset = NSSize(width: 0, height: -d * 0.03)
        shadow.set()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: circleRect).fill()
        NSGraphicsContext.restoreGraphicsState()

        // Base radial gradient: bright upper area falling to light grey at the bottom.
        let base = NSGradient(colors: [WiiPalette.orbTop, WiiPalette.orbMid, WiiPalette.orbBottom],
                              atLocations: [0, 0.55, 1], colorSpace: .sRGB)!
        let body = NSBezierPath(ovalIn: circleRect)
        base.draw(in: body, relativeCenterPosition: NSPoint(x: -0.15, y: 0.35))

        // Thin rim.
        WiiPalette.orbRim.setStroke()
        let rim = NSBezierPath(ovalIn: circleRect.insetBy(dx: d * 0.012, dy: d * 0.012))
        rim.lineWidth = max(1, d * 0.012)
        rim.stroke()

        // Upper glossy highlight (the specular "shine").
        let hi = NSRect(x: circleRect.minX + d * 0.14, y: circleRect.midY + d * 0.02,
                        width: circleRect.width - d * 0.28, height: circleRect.height * 0.44)
        let gloss = NSGradient(colors: [NSColor.white.withAlphaComponent(0.95),
                                        NSColor.white.withAlphaComponent(0.0)],
                               atLocations: [0, 1], colorSpace: .sRGB)!
        let glossPath = NSBezierPath(ovalIn: hi)
        gloss.draw(in: glossPath, angle: -90)

        if pressed {
            NSColor.black.withAlphaComponent(0.08).setFill()
            body.fill()
        }
    }

    /// Blue selection/hover glow ring around a circular button in `rect`.
    static func orbGlow(in rect: NSRect) {
        let d = min(rect.width, rect.height)
        let ring = NSBezierPath(ovalIn: rect.insetBy(dx: d * 0.04, dy: d * 0.04))
        NSGraphicsContext.saveGraphicsState()
        let glow = NSShadow()
        glow.shadowColor = WiiPalette.accent.withAlphaComponent(0.9)
        glow.shadowBlurRadius = d * 0.10
        glow.shadowOffset = .zero
        glow.set()
        WiiPalette.accent.setStroke()
        ring.lineWidth = max(2, d * 0.05)
        ring.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    /// The "Wii" wordmark in the orb glyph grey, centered in `rect`.
    static func wiiWordmark(in rect: NSRect) {
        let size = min(rect.width, rect.height) * 0.34
        let style = NSMutableParagraphStyle(); style.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: roundedFont(ofSize: size, weight: .bold),
            .foregroundColor: WiiPalette.glyph,
            .paragraphStyle: style,
        ]
        let s = NSAttributedString(string: "Wii", attributes: attrs)
        let h = s.size().height
        s.draw(in: NSRect(x: rect.minX, y: rect.midY - h/2, width: rect.width, height: h))
    }

    /// A line-art envelope glyph centered in `rect`, in orb glyph grey.
    static func envelope(in rect: NSRect) {
        let w = min(rect.width, rect.height) * 0.52
        let h = w * 0.68
        let r = NSRect(x: rect.midX - w/2, y: rect.midY - h/2, width: w, height: h)
        let body = NSBezierPath(roundedRect: r, xRadius: w * 0.06, yRadius: w * 0.06)
        WiiPalette.glyph.setStroke()
        body.lineWidth = max(1.5, w * 0.045)
        body.stroke()
        let flap = NSBezierPath()
        flap.move(to: NSPoint(x: r.minX + w * 0.06, y: r.maxY - h * 0.08))
        flap.line(to: NSPoint(x: r.midX, y: r.midY + h * 0.02))
        flap.line(to: NSPoint(x: r.maxX - w * 0.06, y: r.maxY - h * 0.08))
        flap.lineWidth = max(1.5, w * 0.045)
        flap.lineJoinStyle = .round
        flap.stroke()
    }

    /// A blue glossy page chevron pointing left or right, filling `rect`.
    static func chevron(in rect: NSRect, pointingLeft: Bool, hovered: Bool) {
        let d = min(rect.width, rect.height)
        let inset = rect.insetBy(dx: d * 0.18, dy: d * 0.12)
        let tri = NSBezierPath()
        if pointingLeft {
            tri.move(to: NSPoint(x: inset.minX, y: inset.midY))
            tri.line(to: NSPoint(x: inset.maxX, y: inset.maxY))
            tri.line(to: NSPoint(x: inset.maxX, y: inset.minY))
        } else {
            tri.move(to: NSPoint(x: inset.maxX, y: inset.midY))
            tri.line(to: NSPoint(x: inset.minX, y: inset.maxY))
            tri.line(to: NSPoint(x: inset.minX, y: inset.minY))
        }
        tri.close()
        tri.lineJoinStyle = .round

        NSGraphicsContext.saveGraphicsState()
        if hovered {
            let glow = NSShadow()
            glow.shadowColor = WiiPalette.accent.withAlphaComponent(0.9)
            glow.shadowBlurRadius = d * 0.12
            glow.shadowOffset = .zero
            glow.set()
        }
        let grad = NSGradient(colors: [WiiPalette.accentLight, WiiPalette.accentDeep],
                              atLocations: [0, 1], colorSpace: .sRGB)!
        grad.draw(in: tri, angle: -90)
        NSGraphicsContext.restoreGraphicsState()
        NSColor.white.withAlphaComponent(0.85).setStroke()
        tri.lineWidth = max(1.5, d * 0.03)
        tri.stroke()
    }

    /// A small SD-card glyph (decorative status indicator), in `rect`.
    static func sdCard(in rect: NSRect) {
        let w = min(rect.width, rect.height * 1.3)
        let h = w * 1.3
        let r = NSRect(x: rect.midX - w/2, y: rect.midY - h/2, width: w, height: h)
        let p = NSBezierPath()
        let cut = w * 0.32
        p.move(to: NSPoint(x: r.minX, y: r.minY))
        p.line(to: NSPoint(x: r.maxX, y: r.minY))
        p.line(to: NSPoint(x: r.maxX, y: r.maxY - cut))
        p.line(to: NSPoint(x: r.maxX - cut, y: r.maxY))
        p.line(to: NSPoint(x: r.minX, y: r.maxY))
        p.close()
        // Grey when no card is inserted (status indicator, decorative here).
        NSColor(srgbRed: 0.70, green: 0.73, blue: 0.77, alpha: 1).setFill()
        p.fill()
        NSColor.white.withAlphaComponent(0.7).setStroke()
        p.lineWidth = 1
        p.stroke()
        // Contact pins across the top.
        NSColor.white.withAlphaComponent(0.75).setFill()
        NSBezierPath(rect: NSRect(x: r.minX + w*0.14, y: r.maxY - h*0.24,
                                  width: w*0.6, height: h*0.12)).fill()
    }

    /// A pillowed (barrel-sided) rounded rectangle path, like the Wii channel border.
    static func pillowPath(in rect: NSRect, radius: CGFloat) -> NSBezierPath {
        let p = NSBezierPath()
        let r = radius
        let bulge = min(rect.width, rect.height) * 0.02
        p.move(to: NSPoint(x: rect.minX + r, y: rect.minY))
        p.line(to: NSPoint(x: rect.maxX - r, y: rect.minY))
        p.curve(to: NSPoint(x: rect.maxX, y: rect.minY + r),
                controlPoint1: NSPoint(x: rect.maxX - r*0.45, y: rect.minY),
                controlPoint2: NSPoint(x: rect.maxX, y: rect.minY + r*0.45))
        p.curve(to: NSPoint(x: rect.maxX, y: rect.maxY - r),
                controlPoint1: NSPoint(x: rect.maxX + bulge, y: rect.midY),
                controlPoint2: NSPoint(x: rect.maxX, y: rect.maxY - r*0.45 - bulge))
        p.curve(to: NSPoint(x: rect.maxX - r, y: rect.maxY),
                controlPoint1: NSPoint(x: rect.maxX, y: rect.maxY - r*0.45),
                controlPoint2: NSPoint(x: rect.maxX - r*0.45, y: rect.maxY))
        p.line(to: NSPoint(x: rect.minX + r, y: rect.maxY))
        p.curve(to: NSPoint(x: rect.minX, y: rect.maxY - r),
                controlPoint1: NSPoint(x: rect.minX + r*0.45, y: rect.maxY),
                controlPoint2: NSPoint(x: rect.minX, y: rect.maxY - r*0.45))
        p.curve(to: NSPoint(x: rect.minX, y: rect.minY + r),
                controlPoint1: NSPoint(x: rect.minX - bulge, y: rect.midY),
                controlPoint2: NSPoint(x: rect.minX, y: rect.minY + r*0.45 + bulge))
        p.curve(to: NSPoint(x: rect.minX + r, y: rect.minY),
                controlPoint1: NSPoint(x: rect.minX, y: rect.minY + r*0.45),
                controlPoint2: NSPoint(x: rect.minX + r*0.45, y: rect.minY))
        p.close()
        return p
    }

    static func roundedFont(ofSize size: CGFloat, weight: NSFont.Weight) -> NSFont {
        if let d = NSFont.systemFont(ofSize: size, weight: weight).fontDescriptor
            .withDesign(.rounded) {
            return NSFont(descriptor: d, size: size) ?? .systemFont(ofSize: size, weight: weight)
        }
        return .systemFont(ofSize: size, weight: weight)
    }
}

// MARK: - Controls

/// A glossy Wii orb button with a glyph and hover glow.
@MainActor
final class WiiOrbButton: NSControl {
    enum Symbol { case wii, envelope }
    var symbol: Symbol = .wii { didSet { needsDisplay = true } }
    private var hovered = false { didSet { needsDisplay = true } }
    private var pressed = false { didSet { needsDisplay = true } }
    private var tracking: NSTrackingArea?

    override func draw(_ dirtyRect: NSRect) {
        if hovered { WiiDraw.orbGlow(in: bounds) }
        WiiDraw.orb(in: bounds, pressed: pressed)
        let inner = bounds.insetBy(dx: bounds.width * 0.2, dy: bounds.height * 0.2)
        switch symbol {
        case .wii: WiiDraw.wiiWordmark(in: inner)
        case .envelope: WiiDraw.envelope(in: inner)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways],
                               owner: self, userInfo: nil)
        addTrackingArea(t); tracking = t
    }
    override func mouseEntered(with event: NSEvent) { hovered = true }
    override func mouseExited(with event: NSEvent) { hovered = false; pressed = false }
    override func mouseDown(with event: NSEvent) { pressed = true }
    override func mouseUp(with event: NSEvent) {
        pressed = false
        if bounds.contains(convert(event.locationInWindow, from: nil)) { sendAction(action, to: target) }
    }
}

/// A blue glossy Wii page-navigation chevron button.
@MainActor
final class WiiArrowButton: NSControl {
    var pointingLeft = true { didSet { needsDisplay = true } }
    private var hovered = false { didSet { needsDisplay = true } }
    private var tracking: NSTrackingArea?

    override func draw(_ dirtyRect: NSRect) {
        WiiDraw.chevron(in: bounds, pointingLeft: pointingLeft, hovered: hovered)
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways],
                               owner: self, userInfo: nil)
        addTrackingArea(t); tracking = t
    }
    override func mouseEntered(with event: NSEvent) { hovered = true }
    override func mouseExited(with event: NSEvent) { hovered = false }
    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) { sendAction(action, to: target) }
    }
}
