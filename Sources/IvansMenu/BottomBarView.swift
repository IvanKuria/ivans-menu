import AppKit
import IvansMenuKit

/// A transparent clickable region (used over the baked-in Wii/mail buttons).
@MainActor
final class ClickRegion: NSView {
    var onClick: () -> Void = {}
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func cursorUpdate(with event: NSEvent) { WiiCursor.shared?.set() }
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

        dateLabel.font = WiiDraw.roundedFont(ofSize: 19, weight: .medium)
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
        // The bevel's central valley is at 0.434*h from the bottom (measured from
        // the asset); keep the whole clock below it, in the grey dip.
        let clockRect = NSRect(x: w/2 - 150, y: h * 0.12, width: 300, height: h * 0.25)
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
        dateLabel.frame = NSRect(x: w/2 - 200, y: h * 0.005, width: 400, height: 22)
        // Click regions over the baked-in Wii (left) and mail (right) buttons.
        let bw = w * 0.14, bh = h * 0.62
        wiiRegion.frame = NSRect(x: w * 0.095 - bw/2, y: h * 0.306 - bh/2, width: bw, height: bh)
        mailRegion.frame = NSRect(x: w * 0.9075 - bw/2, y: h * 0.306 - bh/2, width: bw, height: bh)
        needsDisplay = true
    }

    deinit { timer?.invalidate() }
}
