import AppKit
import IvansMenuKit

@MainActor
final class BottomBarView: NSView {
    var onWii: () -> Void = {}
    var onMail: () -> Void = {}

    private var curHour = 0
    private var curMinute = 0
    private let dateLabel = NSTextField(labelWithString: "")
    private let wiiButton = WiiOrbButton()
    private let mailButton = WiiOrbButton()
    private nonisolated(unsafe) var timer: Timer?
    private var blinkOn = false

    override init(frame: NSRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    override var isFlipped: Bool { false }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor   // curved fill is drawn, not a rect

        dateLabel.font = WiiDraw.roundedFont(ofSize: 19, weight: .medium)
        dateLabel.textColor = .wiiClock
        dateLabel.alignment = .center
        addSubview(dateLabel)

        wiiButton.symbol = .wii
        wiiButton.target = self; wiiButton.action = #selector(wiiTapped)
        addSubview(wiiButton)

        mailButton.symbol = .envelope
        mailButton.target = self; mailButton.action = #selector(mailTapped)
        addSubview(mailButton)

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        tick()
    }

    override func draw(_ dirtyRect: NSRect) {
        drawBar()
        drawSDGlyph()
        drawClock()
    }

    /// The grey bottom panel with a smooth "bent bevel" top edge — high at both
    /// corners (around the round buttons), dipping into a broad central valley —
    /// and a clean glowing cyan line tracing that edge. Neutral grey, no blue wash.
    private func drawBar() {
        let W = bounds.width, H = bounds.height
        let base = H * 0.56, amp = H * 0.26
        func edge(_ x: CGFloat) -> CGFloat { base + amp * cos(2 * .pi * x / W) }

        let fill = NSBezierPath()
        fill.move(to: NSPoint(x: 0, y: 0))
        fill.line(to: NSPoint(x: 0, y: edge(0)))
        var x: CGFloat = 0
        while x <= W { fill.line(to: NSPoint(x: x, y: edge(x))); x += 2 }
        fill.line(to: NSPoint(x: W, y: 0)); fill.close()

        NSGraphicsContext.saveGraphicsState()
        fill.setClip()
        let g = NSGradient(colors: [
            NSColor(srgbRed: 0.933, green: 0.941, blue: 0.949, alpha: 1),   // lighter bottom
            NSColor(srgbRed: 0.859, green: 0.871, blue: 0.886, alpha: 1),   // darker near curve
        ], atLocations: [0, 1], colorSpace: .sRGB)!
        g.draw(in: bounds, angle: 90)
        NSGraphicsContext.restoreGraphicsState()

        // Glowing cyan edge line.
        let line = NSBezierPath()
        line.move(to: NSPoint(x: 0, y: edge(0)))
        x = 0
        while x <= W { line.line(to: NSPoint(x: x, y: edge(x))); x += 2 }
        line.lineWidth = max(2, H * 0.018)
        line.lineCapStyle = .round
        NSGraphicsContext.saveGraphicsState()
        let glow = NSShadow()
        glow.shadowColor = NSColor.wiiAccent.withAlphaComponent(0.75)
        glow.shadowBlurRadius = H * 0.05
        glow.shadowOffset = .zero
        glow.set()
        NSColor(srgbRed: 0.34, green: 0.76, blue: 0.93, alpha: 1).setStroke()
        line.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawClock() {
        let w = bounds.width, h = bounds.height
        let clockRect = NSRect(x: w/2 - 140, y: h * 0.38, width: 280, height: h * 0.34)
        WiiDraw.sevenSegment(hour: curHour, minute: curMinute, blinkOn: blinkOn,
                             twentyFourHour: true, in: clockRect, color: .wiiClock)
    }

    private func drawSDGlyph() {
        let d = bounds.height * 0.82
        if let sd = AssetLibrary.shared.image(.sdCard) {
            let sw = d * 0.34, sh = sw * 1.26
            sd.draw(in: NSRect(x: bounds.minX + bounds.width * 0.035 + d + d * 0.12,
                               y: bounds.midY - sh * 0.5, width: sw, height: sh),
                    from: .zero, operation: .sourceOver, fraction: 1)
            return
        }
        let sd = d * 0.30
        let sdRect = NSRect(x: bounds.minX + bounds.width * 0.035 + d + d * 0.14,
                            y: bounds.midY - sd * 0.65, width: sd, height: sd * 1.3)
        WiiDraw.sdCard(in: sdRect)
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
        dateLabel.frame = NSRect(x: w/2 - 200, y: h * 0.14, width: 400, height: 26)
        let d = h * 0.82
        let inset = w * 0.035
        wiiButton.frame = NSRect(x: inset, y: (h - d)/2, width: d, height: d)
        mailButton.frame = NSRect(x: w - inset - d, y: (h - d)/2, width: d, height: d)
        needsDisplay = true
    }

    @objc private func wiiTapped() { onWii() }
    @objc private func mailTapped() { onMail() }
    deinit { timer?.invalidate() }
}
