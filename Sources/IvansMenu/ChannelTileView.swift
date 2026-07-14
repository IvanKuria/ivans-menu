import AppKit
import IvansMenuKit

/// Ways a channel can be reconfigured from its right-click menu.
enum ChannelEdit { case app, url, thumbnail, title, clear }

@MainActor
final class ChannelTileView: NSView {
    var onLaunch: (Channel) -> Void = { _ in }
    var onEdit: (Int, ChannelEdit) -> Void = { _, _ in }
    private let channel: Channel
    private let bannerView = NSImageView()
    private let maskLayer = CAShapeLayer()
    private let gloss = CAGradientLayer()
    private var hovered = false
    private var tracking: NSTrackingArea?

    init(channel: Channel, image: NSImage) {
        self.channel = channel
        super.init(frame: .zero)
        wantsLayer = true
        layer?.setAffineTransform(CGAffineTransform(scaleX: Theme.hoverScaleFrom,
                                                    y: Theme.hoverScaleFrom))
        bannerView.imageScaling = .scaleAxesIndependently
        bannerView.animates = true
        bannerView.wantsLayer = true
        bannerView.layer?.mask = maskLayer          // clip to the pillowed Wii shape
        if !channel.isEmpty {
            bannerView.image = image
        } else {
            // Empty slot: light card + a faint "Wii" watermark (the real texture,
            // drawn very lightly so it reads as a subtle watermark, not harsh noise).
            bannerView.layer?.backgroundColor =
                NSColor(srgbRed: 0.925, green: 0.933, blue: 0.941, alpha: 1).cgColor
            if let empty = AssetLibrary.shared.image(.emptyFrame) {
                bannerView.image = empty
                bannerView.alphaValue = 0.14
            }
        }
        gloss.colors = [NSColor.white.withAlphaComponent(0.28).cgColor,
                        NSColor.white.withAlphaComponent(0).cgColor]
        gloss.startPoint = CGPoint(x: 0.5, y: 1)
        gloss.endPoint = CGPoint(x: 0.5, y: 0.5)
        bannerView.layer?.addSublayer(gloss)
        addSubview(bannerView)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func cardRect() -> NSRect { bounds.insetBy(dx: bounds.width * 0.045, dy: bounds.height * 0.06) }

    override func draw(_ dirtyRect: NSRect) {
        let card = cardRect()
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
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.16)
            shadow.shadowBlurRadius = card.width * 0.02
            shadow.shadowOffset = NSSize(width: 0, height: -card.height * 0.02)
        }
        shadow.set()
        NSColor.white.setFill()
        pillow.fill()
        NSGraphicsContext.restoreGraphicsState()

        // Pillow-shaped border ring (the banner sits inset within it).
        if occupied || hovered {
            WiiPalette.accent.withAlphaComponent(hovered ? 1 : 0.75).setStroke()
            pillow.lineWidth = max(2, card.width * 0.012)
        } else {
            WiiPalette.cardBorder.setStroke()
            pillow.lineWidth = max(1, card.width * 0.006)
        }
        pillow.stroke()
    }

    override func layout() {
        super.layout()
        let card = cardRect()
        let interior = card.insetBy(dx: card.width * 0.03, dy: card.width * 0.03)
        bannerView.frame = interior
        let radius = interior.width * Theme.tileCornerFraction
        let path = WiiDraw.pillowPath(in: NSRect(origin: .zero, size: interior.size), radius: radius)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        maskLayer.path = path.cgPath
        gloss.frame = CGRect(x: 0, y: interior.height / 2, width: interior.width, height: interior.height / 2)
        CATransaction.commit()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

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

    /// Right-click a tile to configure it in place — no separate settings page.
    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        menu.addItem(withTitle: channel.isEmpty ? "Set App…" : "Change App…",
                     action: #selector(editApp), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Set Website…", action: #selector(editURL), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Set Thumbnail (image / GIF)…",
                     action: #selector(editThumb), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Rename…", action: #selector(editTitle), keyEquivalent: "").target = self
        if !channel.isEmpty {
            menu.addItem(.separator())
            menu.addItem(withTitle: "Clear Channel", action: #selector(editClear), keyEquivalent: "").target = self
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func editApp() { onEdit(channel.slot, .app) }
    @objc private func editURL() { onEdit(channel.slot, .url) }
    @objc private func editThumb() { onEdit(channel.slot, .thumbnail) }
    @objc private func editTitle() { onEdit(channel.slot, .title) }
    @objc private func editClear() { onEdit(channel.slot, .clear) }
}
