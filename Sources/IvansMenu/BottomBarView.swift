import AppKit
import IvansMenuKit

@MainActor
final class BottomBarView: NSView {
    var onWii: () -> Void = {}
    var onMail: () -> Void = {}

    private let wave = WaveView()
    private let clock = NSTextField(labelWithString: "")
    private let dateLabel = NSTextField(labelWithString: "")
    private nonisolated(unsafe) var timer: Timer?
    private var blinkOn = true

    override init(frame: NSRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.wiiBottomBar.cgColor
        addSubview(wave)

        clock.font = .monospacedDigitSystemFont(ofSize: 44, weight: .semibold)
        clock.textColor = .wiiClock
        clock.alignment = .center
        addSubview(clock)

        dateLabel.font = .systemFont(ofSize: 18, weight: .medium)
        dateLabel.textColor = .wiiClock
        dateLabel.alignment = .center
        addSubview(dateLabel)

        let wii = makeRoundButton(title: "Wii", action: #selector(wiiTapped))
        wii.tag = 1; addSubview(wii)
        let mail = makeRoundButton(title: "✉", action: #selector(mailTapped))
        mail.tag = 2; addSubview(mail)

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        tick()
    }

    private func makeRoundButton(title: String, action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .circular
        b.wantsLayer = true
        return b
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
        wave.frame = NSRect(x: 0, y: h - 24, width: w, height: 24)
        clock.frame = NSRect(x: w/2 - 150, y: h/2 - 10, width: 300, height: 56)
        dateLabel.frame = NSRect(x: w/2 - 150, y: h/2 - 44, width: 300, height: 24)
        for v in subviews.compactMap({ $0 as? NSButton }) {
            if v.tag == 1 { v.frame = NSRect(x: 40, y: h/2 - 40, width: 80, height: 80) }
            if v.tag == 2 { v.frame = NSRect(x: w - 120, y: h/2 - 40, width: 80, height: 80) }
        }
    }

    @objc private func wiiTapped() { onWii() }
    @objc private func mailTapped() { onMail() }
    deinit { timer?.invalidate() }
}
