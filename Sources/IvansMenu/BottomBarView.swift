import AppKit
import IvansMenuKit

/// A transparent clickable region over a baked-in bar button, with a hover glow.
@MainActor
final class ClickRegion: NSView {
    var onClick: () -> Void = {}
    private var hovered = false { didSet { needsDisplay = true } }
    private var tracking: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways],
                               owner: self, userInfo: nil)
        addTrackingArea(t); tracking = t
    }

    override func draw(_ dirtyRect: NSRect) {
        guard hovered else { return }
        // The bar asset already draws a blue ring around this button. The region is
        // sized to the button diameter, so we light that ring up in place: a soft
        // white lift inside + a glowing cyan stroke laid right on the asset ring.
        let d = min(bounds.width, bounds.height)
        let circle = NSRect(x: bounds.midX - d/2, y: bounds.midY - d/2, width: d, height: d)
            .insetBy(dx: d * 0.03, dy: d * 0.03)
        NSColor.white.withAlphaComponent(0.30).setFill()
        NSBezierPath(ovalIn: circle.insetBy(dx: d * 0.06, dy: d * 0.06)).fill()
        NSGraphicsContext.saveGraphicsState()
        let glow = NSShadow()
        glow.shadowColor = WiiPalette.accent.withAlphaComponent(0.9)
        glow.shadowBlurRadius = d * 0.06
        glow.shadowOffset = .zero
        glow.set()
        WiiPalette.accent.setStroke()
        let ring = NSBezierPath(ovalIn: circle)
        ring.lineWidth = max(2, d * 0.035)
        ring.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    override func mouseEntered(with event: NSEvent) { hovered = true; AudioEngine.shared.play(.hover) }
    override func mouseExited(with event: NSEvent) { hovered = false }
    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick() }
    }
}

@MainActor
final class BottomBarView: NSView {
    /// Bar asset aspect ratio (bar_full.png is 2000×346).
    static let aspect: CGFloat = 2000.0 / 346.0

    var onWii: () -> Void = {}
    var onMail: () -> Void = {}

    private var curHour = 0
    private var curMinute = 0
    private let dateLabel = NSTextField(labelWithString: "")
    private let wiiRegion = ClickRegion()
    private let mailRegion = ClickRegion()
    private nonisolated(unsafe) var timer: Timer?
    private var blinkOn = false

    override init(frame: NSRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    override var isFlipped: Bool { false }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        dateLabel.font = WiiDraw.roundedFont(ofSize: 38, weight: .medium)
        dateLabel.textColor = .wiiClock
        dateLabel.alignment = .center
        addSubview(dateLabel)

        wiiRegion.onClick = { [weak self] in self?.onWii() }
        mailRegion.onClick = { [weak self] in self?.onMail() }
        addSubview(wiiRegion)
        addSubview(mailRegion)

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        tick()
    }

    override func draw(_ dirtyRect: NSRect) {
        if let bar = AssetLibrary.shared.image(.barFull) {
            bar.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
        } else {
            NSColor.wiiBottomBar.setFill(); bounds.fill()
        }
        drawClock()
    }

    private func drawClock() {
        let w = bounds.width, h = bounds.height
        // The bevel's central valley is at 0.434*h from the bottom; the clock sits
        // ABOVE that line, in the white pocket the dip creates.
        let clockRect = NSRect(x: w/2 - 170, y: h * 0.50, width: 340, height: h * 0.30)
        WiiDraw.sevenSegment(hour: curHour, minute: curMinute, blinkOn: blinkOn,
                             twentyFourHour: false, in: clockRect, color: .wiiClock)
    }

    private func tick() {
        blinkOn.toggle()
        let now = Date()
        let cal = Calendar.current
        let c = cal.dateComponents([.hour, .minute], from: now)
        curHour = c.hour ?? 0
        curMinute = c.minute ?? 0
        dateLabel.stringValue = ClockFormatter.date(now, calendar: cal)
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        let w = bounds.width, h = bounds.height
        dateLabel.frame = NSRect(x: w/2 - 250, y: h * 0.20, width: 500, height: 50)
        // Click regions sit exactly over the baked-in Wii (left) and mail (right)
        // buttons. Centers + diameter measured from the bar asset's own blue rings
        // (clean-edge derivation): Wii cx=0.0912, mail cx=0.9097, cy=0.40 from bottom,
        // ring diameter = 0.0885·barWidth. Region is a square of that diameter so the
        // hover ring lands on the asset ring instead of floating above-left of it.
        let d = w * 0.0885
        let cy = h * 0.40
        wiiRegion.frame = NSRect(x: w * 0.0912 - d/2, y: cy - d/2, width: d, height: d)
        mailRegion.frame = NSRect(x: w * 0.9097 - d/2, y: cy - d/2, width: d, height: d)
        needsDisplay = true
    }

    deinit { timer?.invalidate() }
}
