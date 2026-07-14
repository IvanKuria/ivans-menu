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
        // Highlight the round button under this region: soft white lift + cyan ring.
        let d = min(bounds.width, bounds.height)
        let circle = NSRect(x: bounds.midX - d/2, y: bounds.midY - d/2, width: d, height: d)
            .insetBy(dx: d * 0.06, dy: d * 0.06)
        NSColor.white.withAlphaComponent(0.35).setFill()
        NSBezierPath(ovalIn: circle).fill()
        NSGraphicsContext.saveGraphicsState()
        let glow = NSShadow()
        glow.shadowColor = WiiPalette.accent.withAlphaComponent(0.9)
        glow.shadowBlurRadius = d * 0.06
        glow.shadowOffset = .zero
        glow.set()
        WiiPalette.accent.setStroke()
        let ring = NSBezierPath(ovalIn: circle)
        ring.lineWidth = max(2, d * 0.03)
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

        dateLabel.font = WiiDraw.roundedFont(ofSize: 26, weight: .medium)
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
        dateLabel.frame = NSRect(x: w/2 - 200, y: h * 0.26, width: 400, height: 34)
        // Click regions over the baked-in Wii (left) and mail (right) buttons.
        // Centers measured from the bar asset: Wii x=0.089, mail x=0.917, y~0.54 from bottom.
        let bw = w * 0.12, bh = h * 0.68
        wiiRegion.frame = NSRect(x: w * 0.089 - bw/2, y: h * 0.52 - bh/2, width: bw, height: bh)
        mailRegion.frame = NSRect(x: w * 0.917 - bw/2, y: h * 0.52 - bh/2, width: bw, height: bh)
        needsDisplay = true
    }

    deinit { timer?.invalidate() }
}
