import AppKit
import IvansMenuKit

@MainActor
final class ChannelTileView: NSView {
    var onLaunch: (Channel) -> Void = { _ in }
    private let channel: Channel
    private let imageView = NSImageView()
    private var tracking: NSTrackingArea?

    init(channel: Channel, image: NSImage) {
        self.channel = channel
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.masksToBounds = true
        imageView.imageScaling = .scaleAxesIndependently
        imageView.image = image
        addSubview(imageView)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() { super.layout(); imageView.frame = bounds }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways],
                               owner: self, userInfo: nil)
        addTrackingArea(t); tracking = t
    }

    override func mouseEntered(with event: NSEvent) { setHover(true) }
    override func mouseExited(with event: NSEvent) { setHover(false) }

    private func setHover(_ on: Bool) {
        if on { AudioEngine.shared.play(.hover) }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.4
            layer?.borderWidth = on ? 4 : 0
            layer?.borderColor = NSColor.white.cgColor
            let scale: CGFloat = on ? 1.0 : Theme.hoverScaleFrom
            layer?.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard !channel.isEmpty else { return }
        AudioEngine.shared.play(.select)
        onLaunch(channel)
    }
}
