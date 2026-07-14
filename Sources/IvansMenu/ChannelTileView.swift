import AppKit
import IvansMenuKit

@MainActor
final class ChannelTileView: NSView {
    var onLaunch: (Channel) -> Void = { _ in }
    private let channel: Channel
    private let bannerImage: NSImage
    private var hovered = false
    private var tracking: NSTrackingArea?

    init(channel: Channel, image: NSImage) {
        self.channel = channel
        self.bannerImage = image
        super.init(frame: .zero)
        wantsLayer = true
        layer?.setAffineTransform(CGAffineTransform(scaleX: Theme.hoverScaleFrom,
                                                    y: Theme.hoverScaleFrom))
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let card = bounds.insetBy(dx: bounds.width * 0.045, dy: bounds.height * 0.06)
        let radius = card.width * Theme.tileCornerFraction
        let pillow = WiiDraw.pillowPath(in: card, radius: radius)
        let occupied = !channel.isEmpty

        // Drop shadow + (for occupied/hover) cyan halo.
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

        // Interior: banner art (occupied) or plain light-grey recess (empty).
        NSGraphicsContext.saveGraphicsState()
        let interior = card.insetBy(dx: card.width * 0.018, dy: card.width * 0.018)
        let clip = WiiDraw.pillowPath(in: interior, radius: radius * 0.9)
        clip.addClip()
        if occupied {
            bannerImage.draw(in: interior, from: .zero, operation: .sourceOver, fraction: 1)
        } else {
            NSColor(srgbRed: 0.90, green: 0.91, blue: 0.925, alpha: 1).setFill()
            interior.fill()
        }
        // Top gloss sweep — a laminated "under glass" sheen.
        let glossRect = NSRect(x: interior.minX, y: interior.midY,
                               width: interior.width, height: interior.height/2)
        let gloss = NSGradient(colors: [NSColor.white.withAlphaComponent(0.35),
                                        NSColor.white.withAlphaComponent(0.0)],
                               atLocations: [0, 1], colorSpace: .sRGB)!
        gloss.draw(in: glossRect, angle: -90)
        NSGraphicsContext.restoreGraphicsState()

        // Border: cyan for occupied/hover, soft grey for empty.
        if occupied || hovered {
            WiiPalette.accent.withAlphaComponent(hovered ? 1 : 0.75).setStroke()
            pillow.lineWidth = max(2, card.width * 0.012)
        } else {
            WiiPalette.cardBorder.setStroke()
            pillow.lineWidth = max(1, card.width * 0.006)
        }
        pillow.stroke()
    }

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
        guard on != hovered else { return }
        hovered = on
        if on { AudioEngine.shared.play(.hover) }
        needsDisplay = true
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
