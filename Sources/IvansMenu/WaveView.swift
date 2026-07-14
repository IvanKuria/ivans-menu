import AppKit

/// The glowing cyan wavy divider between the channel area and the bottom bar.
/// A gentle, low-amplitude multi-hump sine with a bright core and soft glow.
@MainActor
final class WaveView: NSView {
    private let glow = CAShapeLayer()
    private let core = CAShapeLayer()
    private var phase: CGFloat = 0
    private nonisolated(unsafe) var timer: Timer?

    override init(frame: NSRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        wantsLayer = true
        // Soft wide glow underneath.
        glow.strokeColor = NSColor.wiiAccent.withAlphaComponent(0.45).cgColor
        glow.fillColor = NSColor.clear.cgColor
        glow.lineWidth = 7
        glow.lineCap = .round
        glow.shadowColor = NSColor.wiiAccent.cgColor
        glow.shadowRadius = 6
        glow.shadowOpacity = 0.9
        glow.shadowOffset = .zero
        layer?.addSublayer(glow)
        // Bright thin core line.
        core.strokeColor = NSColor(srgbRed: 0.42, green: 0.80, blue: 0.95, alpha: 1).cgColor
        core.fillColor = NSColor.clear.cgColor
        core.lineWidth = 2
        core.lineCap = .round
        layer?.addSublayer(core)

        timer = Timer.scheduledTimer(withTimeInterval: 1.0/30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.step() }
        }
    }

    private func step() {
        phase += 0.02
        if phase > .pi * 2 { phase -= .pi * 2 }
        rebuild()
    }

    override func layout() { super.layout(); rebuild() }

    private func rebuild() {
        let w = bounds.width, h = bounds.height
        guard w > 0 else { return }
        let path = CGMutablePath()
        let midY = h * 0.5
        let amp = h * 0.14            // low amplitude — a gentle undulation
        let humps: CGFloat = 4.5      // a handful of shallow waves across the width
        path.move(to: CGPoint(x: 0, y: midY))
        var x: CGFloat = 0
        while x <= w {
            let y = midY + sin((x / w) * .pi * humps + phase) * amp
            path.addLine(to: CGPoint(x: x, y: y))
            x += 3
        }
        glow.path = path
        core.path = path
    }

    deinit { timer?.invalidate() }
}
