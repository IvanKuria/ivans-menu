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

    /// The bottom panel. Uses the real Wii bar texture (the left half of the
    /// symmetric bent-bevel curve, mirrored for the right) drawn in its natural
    /// shading, with a cyan edge line produced by a cyan copy peeking behind it.
    /// Falls back to a drawn curve only if the texture is missing.
    private func drawBar() {
        guard let bar = AssetLibrary.shared.image(.bottombar) else { drawBarFallback(); return }
        let cyan = bar.tinted(with: NSColor(srgbRed: 0.30, green: 0.74, blue: 0.93, alpha: 1))
        let lineOffset = max(2, bounds.height * 0.02)
        if let cyan { drawBarHalves(cyan, dy: lineOffset) }   // cyan edge peeks above…
        drawBarHalves(bar, dy: 0)                             // …the natural bar on top
    }

    private func drawBarHalves(_ image: NSImage, dy: CGFloat) {
        let halfW = bounds.width / 2
        image.draw(in: NSRect(x: 0, y: dy, width: halfW, height: bounds.height),
                   from: .zero, operation: .sourceOver, fraction: 1)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        ctx.translateBy(x: bounds.width, y: 0)
        ctx.scaleBy(x: -1, y: 1)
        image.draw(in: NSRect(x: 0, y: dy, width: halfW, height: bounds.height),
                   from: .zero, operation: .sourceOver, fraction: 1)
        ctx.restoreGState()
    }

    private func drawBarFallback() {
        let W = bounds.width, H = bounds.height
        let base = H * 0.56, amp = H * 0.26
        func edge(_ x: CGFloat) -> CGFloat { base + amp * cos(2 * .pi * x / W) }
        let fill = NSBezierPath()
        fill.move(to: NSPoint(x: 0, y: 0)); fill.line(to: NSPoint(x: 0, y: edge(0)))
        var x: CGFloat = 0
        while x <= W { fill.line(to: NSPoint(x: x, y: edge(x))); x += 2 }
        fill.line(to: NSPoint(x: W, y: 0)); fill.close()
        NSGraphicsContext.saveGraphicsState(); fill.setClip()
        NSColor(srgbRed: 0.90, green: 0.91, blue: 0.92, alpha: 1).setFill(); bounds.fill()
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
