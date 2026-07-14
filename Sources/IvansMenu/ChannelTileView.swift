import AppKit
import IvansMenuKit

@MainActor
final class ChannelTileView: NSView {
    var onLaunch: (Channel) -> Void = { _ in }
    private let channel: Channel
    private let bannerView = NSImageView()
    private let gloss = CAGradientLayer()
    private var hovered = false
    private var tracking: NSTrackingArea?

    init(channel: Channel, image: NSImage) {
        self.channel = channel
        super.init(frame: .zero)
        wantsLayer = true
        layer?.setAffineTransform(CGAffineTransform(scaleX: Theme.hoverScaleFrom,
                                                    y: Theme.hoverScaleFrom))
        bannerView.imageScaling = .scaleAxesIndependently  // fill edge-to-edge
        bannerView.animates = true                          // animate GIF thumbnails
        bannerView.wantsLayer = true
        bannerView.layer?.masksToBounds = true
        if !channel.isEmpty {
            bannerView.image = image
        } else {
            bannerView.layer?.backgroundColor =
                NSColor(srgbRed: 0.91, green: 0.92, blue: 0.93, alpha: 1).cgColor
        }
        // Laminated top-gloss sheen over the banner.
        gloss.colors = [NSColor.white.withAlphaComponent(0.34).cgColor,
                        NSColor.white.withAlphaComponent(0).cgColor]
        gloss.startPoint = CGPoint(x: 0.5, y: 1)
        gloss.endPoint = CGPoint(x: 0.5, y: 0.5)
        bannerView.layer?.addSublayer(gloss)
        addSubview(bannerView)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let card = bounds.insetBy(dx: bounds.width * 0.045, dy: bounds.height * 0.06)
        let radius = card.width * Theme.tileCornerFraction
        let pillow = WiiDraw.pillowPath(in: card, radius: radius)
        let occupied = !channel.isEmpty

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        if occupied || hovered {
            shadow.shadowColor = WiiPalette.accent.withAlphaComponent(hovered ? 0.95 : 0.5)
            shadow.shadowBlurRadius = hovered ? card.width * 0.05 : card.width * 0.03
            shadow.shadowOffset = .zero
        } else {
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
            shadow.shadowBlurRadius = card.width * 0.02
            shadow.shadowOffset = NSSize(width: 0, height: -card.height * 0.02)
        }
        shadow.set()
        NSColor.white.setFill()
        pillow.fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    override func layout() {
        super.layout()
        let card = bounds.insetBy(dx: bounds.width * 0.045, dy: bounds.height * 0.06)
        let interior = card.insetBy(dx: card.width * 0.02, dy: card.width * 0.02)
        let radius = interior.width * Theme.tileCornerFraction
        bannerView.frame = interior
        bannerView.layer?.cornerRadius = radius
        let occupied = !channel.isEmpty
        if occupied || hovered {
            bannerView.layer?.borderWidth = max(2, card.width * 0.012)
            bannerView.layer?.borderColor = WiiPalette.accent
                .withAlphaComponent(hovered ? 1 : 0.75).cgColor
        } else {
            bannerView.layer?.borderWidth = max(1, card.width * 0.006)
            bannerView.layer?.borderColor = WiiPalette.cardBorder.cgColor
        }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        gloss.frame = CGRect(x: 0, y: interior.height / 2, width: interior.width, height: interior.height / 2)
        CATransaction.commit()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways],
                               owner: self, userInfo: nil)
        addTrackingArea(t); tracking = t
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseEntered(with event: NSEvent) { setHover(true) }
    override func mouseExited(with event: NSEvent) { setHover(false) }

    private func setHover(_ on: Bool) {
        guard on != hovered else { return }
        hovered = on
        if on { AudioEngine.shared.play(.hover) }
        needsDisplay = true
        needsLayout = true
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
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
