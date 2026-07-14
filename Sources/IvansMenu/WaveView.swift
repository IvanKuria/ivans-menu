import AppKit

@MainActor
final class WaveView: NSView {
    private let shape = CAShapeLayer()
    private var phase: CGFloat = 0
    private nonisolated(unsafe) var timer: Timer?

    override init(frame: NSRect) {
        super.init(frame: frame); setup()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        wantsLayer = true
        shape.strokeColor = NSColor.wiiAccent.cgColor
        shape.fillColor = NSColor.clear.cgColor
        shape.lineWidth = 4
        layer?.addSublayer(shape)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.step()
            }
        }
    }

    private func step() {
        phase += 0.06
        if phase > .pi * 2 { phase -= .pi * 2 }
        rebuild()
    }

    override func layout() { super.layout(); rebuild() }

    private func rebuild() {
        let w = bounds.width, h = bounds.height
        guard w > 0 else { return }
        let path = CGMutablePath()
        let midY = h * 0.6
        let amp = h * 0.18
        path.move(to: CGPoint(x: 0, y: midY))
        var x: CGFloat = 0
        while x <= w {
            let y = midY + sin((x / w) * .pi * 2 + phase) * amp
            path.addLine(to: CGPoint(x: x, y: y))
            x += 4
        }
        shape.path = path
    }

    deinit { timer?.invalidate() }
}
