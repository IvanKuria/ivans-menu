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
    /// Drawn crisp with rounded corners + gloss + glow (no low-res rip).
    static func chevron(in rect: NSRect, pointingLeft: Bool, hovered: Bool) {
        let d = min(rect.width, rect.height)
        let inset = rect.insetBy(dx: d * 0.22, dy: d * 0.16)
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
        let glow = NSShadow()
        glow.shadowColor = WiiPalette.accent.withAlphaComponent(hovered ? 0.95 : 0.55)
        glow.shadowBlurRadius = d * (hovered ? 0.16 : 0.09)
        glow.shadowOffset = .zero
        glow.set()
        // Round the corners by first stroking the outline thickly in the deep blue.
        WiiPalette.accentDeep.setStroke()
        tri.lineWidth = d * 0.16
        tri.stroke()
        NSGraphicsContext.restoreGraphicsState()

        // Glossy fill: lighter at the top.
        let grad = NSGradient(colors: [WiiPalette.accentLight, WiiPalette.accentDeep],
                              atLocations: [0, 1], colorSpace: .sRGB)!
        grad.draw(in: tri, angle: -90)
        // Bright top edge highlight.
        NSColor.white.withAlphaComponent(0.9).setStroke()
        tri.lineWidth = max(1.5, d * 0.025)
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

    /// A pillowed rounded rectangle like the Wii channel border: all four edges
    /// bow outward (convex), with rounded corners. `b` controls how "pillowy".
    static func pillowPath(in rect: NSRect, radius: CGFloat) -> NSBezierPath {
        let p = NSBezierPath()
        let r = radius
        let b = min(rect.width, rect.height) * 0.028   // edge bulge (subtle, like the real Wii)
        let w = rect.width, h = rect.height
        // bottom edge (convex down)
        p.move(to: NSPoint(x: rect.minX + r, y: rect.minY))
        p.curve(to: NSPoint(x: rect.maxX - r, y: rect.minY),
                controlPoint1: NSPoint(x: rect.minX + w * 0.33, y: rect.minY - b),
                controlPoint2: NSPoint(x: rect.minX + w * 0.67, y: rect.minY - b))
        // bottom-right corner
        p.curve(to: NSPoint(x: rect.maxX, y: rect.minY + r),
                controlPoint1: NSPoint(x: rect.maxX - r * 0.45, y: rect.minY),
                controlPoint2: NSPoint(x: rect.maxX, y: rect.minY + r * 0.45))
        // right edge (convex right)
        p.curve(to: NSPoint(x: rect.maxX, y: rect.maxY - r),
                controlPoint1: NSPoint(x: rect.maxX + b, y: rect.minY + h * 0.33),
                controlPoint2: NSPoint(x: rect.maxX + b, y: rect.minY + h * 0.67))
        // top-right corner
        p.curve(to: NSPoint(x: rect.maxX - r, y: rect.maxY),
                controlPoint1: NSPoint(x: rect.maxX, y: rect.maxY - r * 0.45),
                controlPoint2: NSPoint(x: rect.maxX - r * 0.45, y: rect.maxY))
        // top edge (convex up)
        p.curve(to: NSPoint(x: rect.minX + r, y: rect.maxY),
                controlPoint1: NSPoint(x: rect.minX + w * 0.67, y: rect.maxY + b),
                controlPoint2: NSPoint(x: rect.minX + w * 0.33, y: rect.maxY + b))
        // top-left corner
        p.curve(to: NSPoint(x: rect.minX, y: rect.maxY - r),
                controlPoint1: NSPoint(x: rect.minX + r * 0.45, y: rect.maxY),
                controlPoint2: NSPoint(x: rect.minX, y: rect.maxY - r * 0.45))
        // left edge (convex left)
        p.curve(to: NSPoint(x: rect.minX, y: rect.minY + r),
                controlPoint1: NSPoint(x: rect.minX - b, y: rect.minY + h * 0.67),
                controlPoint2: NSPoint(x: rect.minX - b, y: rect.minY + h * 0.33))
        // bottom-left corner
        p.curve(to: NSPoint(x: rect.minX + r, y: rect.minY),
                controlPoint1: NSPoint(x: rect.minX, y: rect.minY + r * 0.45),
                controlPoint2: NSPoint(x: rect.minX + r * 0.45, y: rect.minY))
        p.close()
        return p
    }

    /// Draw a 7-segment LCD clock centered in `rect`. In 12-hour mode the leading
    /// zero of the hour is blank and an AM/PM label follows the digits (like the Wii).
    static func sevenSegment(hour: Int, minute: Int, blinkOn: Bool,
                             twentyFourHour: Bool, in rect: NSRect, color: NSColor) {
        let isPM = hour >= 12
        var h = hour
        if !twentyFourHour { h = hour % 12; if h == 0 { h = 12 } }
        let hTens = h / 10, hOnes = h % 10
        let blankTens = !twentyFourHour && hTens == 0

        let ch = rect.height
        let cw = ch * 0.55
        let colonW = cw * 0.42
        let gap = cw * 0.20
        let ampmW = twentyFourHour ? 0 : cw * 1.05
        let total = cw * 4 + gap * 4 + colonW + ampmW
        var x = rect.midX - total / 2
        let y = rect.minY
        color.setFill()

        if !blankTens { drawDigit(hTens, x: x, y: y, w: cw, h: ch) }
        x += cw + gap
        drawDigit(hOnes, x: x, y: y, w: cw, h: ch); x += cw + gap
        if blinkOn { drawColon(x: x, y: y, w: colonW, h: ch, color: color) }
        x += colonW + gap
        drawDigit(minute / 10, x: x, y: y, w: cw, h: ch); x += cw + gap
        drawDigit(minute % 10, x: x, y: y, w: cw, h: ch); x += cw

        if !twentyFourHour {
            let label = NSAttributedString(string: isPM ? "PM" : "AM", attributes: [
                .font: roundedFont(ofSize: ch * 0.42, weight: .semibold),
                .foregroundColor: color,
            ])
            let ls = label.size()
            label.draw(at: NSPoint(x: x + gap * 1.5, y: y + (ch - ls.height) / 2))
        }
    }

    private static let segMap: [[Int]] = [
        [0,1,2,3,4,5], [1,2], [0,1,6,4,3], [0,1,6,2,3], [5,6,1,2],
        [0,5,6,2,3], [0,5,6,4,2,3], [0,1,2], [0,1,2,3,4,5,6], [0,1,2,3,5,6],
    ] // segments: 0=a top,1=b TR,2=c BR,3=d bottom,4=e BL,5=f TL,6=g mid

    private static func drawDigit(_ n: Int, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
        guard (0...9).contains(n) else { return }
        let t = h * 0.13
        let on = Set(segMap[n])
        func hseg(_ cy: CGFloat) {
            let r = NSRect(x: x + t * 0.6, y: cy - t/2, width: w - t * 1.2, height: t)
            NSBezierPath(roundedRect: r, xRadius: t*0.4, yRadius: t*0.4).fill()
        }
        func vseg(_ cx: CGFloat, _ y0: CGFloat) {
            let segH = (h - 3*t) / 2
            let r = NSRect(x: cx - t/2, y: y0, width: t, height: segH)
            NSBezierPath(roundedRect: r, xRadius: t*0.4, yRadius: t*0.4).fill()
        }
        if on.contains(0) { hseg(y + h - t/2) }            // a
        if on.contains(6) { hseg(y + h/2) }                // g
        if on.contains(3) { hseg(y + t/2) }                // d
        if on.contains(5) { vseg(x + t/2, y + h/2 + t/2) } // f
        if on.contains(1) { vseg(x + w - t/2, y + h/2 + t/2) } // b
        if on.contains(4) { vseg(x + t/2, y + t) }         // e
        if on.contains(2) { vseg(x + w - t/2, y + t) }     // c
    }

    private static func drawColon(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, color: NSColor) {
        let d = h * 0.14
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: x + w/2 - d/2, y: y + h*0.32, width: d, height: d)).fill()
        NSBezierPath(ovalIn: NSRect(x: x + w/2 - d/2, y: y + h*0.62, width: d, height: d)).fill()
    }

    static func roundedFont(ofSize size: CGFloat, weight: NSFont.Weight) -> NSFont {
        if let d = NSFont.systemFont(ofSize: size, weight: weight).fontDescriptor
            .withDesign(.rounded) {
            return NSFont(descriptor: d, size: size) ?? .systemFont(ofSize: size, weight: weight)
        }
        return .systemFont(ofSize: size, weight: weight)
    }
}

// MARK: - Cursor

/// The Wii hand pointer, built from the real cursor rip. Hotspot at the fingertip.
@MainActor
enum WiiCursor {
    static let shared: NSCursor? = {
        guard let img = AssetLibrary.shared.image(.cursor) else { return nil }
        let size = NSSize(width: 44, height: 44)
        let resized = NSImage(size: size)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        img.draw(in: NSRect(origin: .zero, size: size))
        resized.unlockFocus()
        return NSCursor(image: resized, hotSpot: NSPoint(x: 16, y: 3))
    }()
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

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        // The Wii button has a high-res rip; the mail button has none, so it's
        // drawn crisply in Core Graphics (a low-res rip would look worse).
        if symbol == .wii, let img = AssetLibrary.shared.image(.wiiButton) {
            if hovered { WiiDraw.orbGlow(in: bounds) }
            let rect = pressed ? bounds.insetBy(dx: bounds.width * 0.02, dy: bounds.height * 0.02) : bounds
            img.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            return
        }
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

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        // No high-res arrow rip exists, so draw a crisp vector chevron.
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
