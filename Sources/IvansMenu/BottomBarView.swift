import AppKit
import IvansMenuKit

@MainActor
final class BottomBarView: NSView {
    var onWii: () -> Void = {}
    var onMail: () -> Void = {}

    private let wave = WaveView()
    private let clock = NSTextField(labelWithString: "")
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
        layer?.backgroundColor = NSColor.wiiBottomBar.cgColor
        addSubview(wave)

        clock.font = WiiDraw.roundedFont(ofSize: 48, weight: .semibold)
        clock.textColor = .wiiClock
        clock.alignment = .center
        addSubview(clock)

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
        // Grey bar panel with a subtle top-lit gradient.
        let g = NSGradient(colors: [
            NSColor(srgbRed: 0.855, green: 0.867, blue: 0.882, alpha: 1),
            NSColor.wiiBottomBar,
        ], atLocations: [0, 1], colorSpace: .sRGB)!
        g.draw(in: bounds, angle: -90)
        // Small SD-card status glyph to the right of the Wii button.
        let d = bounds.height * 0.82
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
        clock.stringValue = ClockFormatter.time(hour: c.hour!, minute: c.minute!,
                                                blinkOn: blinkOn, twentyFourHour: true)
        dateLabel.stringValue = ClockFormatter.date(now, calendar: cal)
    }

    override func layout() {
        super.layout()
        let w = bounds.width, h = bounds.height
        wave.frame = NSRect(x: 0, y: h - 18, width: w, height: 36)
        clock.frame = NSRect(x: w/2 - 200, y: h * 0.42, width: 400, height: 60)
        dateLabel.frame = NSRect(x: w/2 - 200, y: h * 0.20, width: 400, height: 26)
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
