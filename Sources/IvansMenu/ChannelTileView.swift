import AppKit
import IvansMenuKit

/// Ways a channel can be reconfigured from its right-click menu.
enum ChannelEdit { case app, url, thumbnail, title, clear }

/// Draws a clean, uniform pillow-shaped border on top of the banner (pass-through
/// so it never blocks clicks).
@MainActor
final class PillowBorderView: NSView {
    var strokeColor: NSColor = .gray
    var lineWidth: CGFloat = 2
    var radiusFraction: CGFloat = 0.045
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
        let path = WiiDraw.pillowPath(in: r, radius: r.width * radiusFraction)
        strokeColor.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }
}

@MainActor
final class ChannelTileView: NSView {
    var onLaunch: (Channel) -> Void = { _ in }
    var onEdit: (Int, ChannelEdit) -> Void = { _, _ in }
    private let channel: Channel
    private let bannerView = NSImageView()      // channel art (occupied) or empty card
    private let maskLayer = CAShapeLayer()       // clip banner to the pillow shape
    private let borderView = PillowBorderView()  // clean pillow border on top
    private let populated: Bool
    private var hovered = false
    private var tracking: NSTrackingArea?

    private static let cornerFraction = CGFloat(Theme.tileCornerFraction)

    init(channel: Channel, image: NSImage) {
        self.channel = channel
        let hasCustomThumb: Bool = { if case .custom = channel.banner { return true }; return false }()
        self.populated = !channel.isEmpty || hasCustomThumb
        super.init(frame: .zero)
        wantsLayer = true
        layer?.setAffineTransform(CGAffineTransform(scaleX: Theme.hoverScaleFrom,
                                                    y: Theme.hoverScaleFrom))
        bannerView.imageScaling = .scaleAxesIndependently   // fill edge-to-edge
        bannerView.animates = true                           // animate GIF thumbnails
        bannerView.wantsLayer = true
        bannerView.layer?.mask = maskLayer                   // clip to the pillow shape

        if populated {
            bannerView.image = image
            borderView.strokeColor = NSColor(srgbRed: 0.78, green: 0.79, blue: 0.81, alpha: 1)
        } else {
            bannerView.image = AssetLibrary.shared.image(.emptyCard)
                ?? AssetLibrary.shared.image(.emptyFrame)
            borderView.strokeColor = NSColor(srgbRed: 0.84, green: 0.85, blue: 0.87, alpha: 1)
        }
        addSubview(bannerView)
        addSubview(borderView)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func cardRect() -> NSRect { bounds.insetBy(dx: bounds.width * 0.05, dy: bounds.height * 0.06) }

    override func draw(_ dirtyRect: NSRect) {
        // Soft drop shadow behind the pillow-shaped tile.
        let card = cardRect()
        let pillow = WiiDraw.pillowPath(in: card, radius: card.width * Self.cornerFraction)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(hovered ? 0.22 : 0.14)
        shadow.shadowBlurRadius = card.width * (hovered ? 0.03 : 0.02)
        shadow.shadowOffset = NSSize(width: 0, height: -card.height * 0.02)
        shadow.set()
        NSColor.white.setFill()
        pillow.fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    override func layout() {
        super.layout()
        let card = cardRect()
        bannerView.frame = card
        let localPillow = WiiDraw.pillowPath(in: NSRect(origin: .zero, size: card.size),
                                             radius: card.width * Self.cornerFraction)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        maskLayer.path = localPillow.cgPath
        CATransaction.commit()
        borderView.frame = card
        borderView.lineWidth = max(1, card.width * 0.014)
        borderView.radiusFraction = Self.cornerFraction
        borderView.needsDisplay = true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let t = NSTrackingArea(rect: bounds,
                               options: [.mouseEnteredAndExited, .activeAlways],
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
