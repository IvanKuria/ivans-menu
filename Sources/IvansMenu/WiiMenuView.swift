import AppKit
import IvansMenuKit

@MainActor
final class WiiMenuView: NSView {
    var onLaunch: (Channel) -> Void = { _ in }
    var onWii: () -> Void = {}
    var onEditChannel: (Int, ChannelEdit) -> Void = { _, _ in }

    private let config: AppConfig
    private let renderer: BannerRenderer
    private let bottomBar = BottomBarView()
    private var currentPage = 0
    private let leftArrow = WiiArrowButton()
    private let rightArrow = WiiArrowButton()
    private let bgImageView = NSImageView()
    private var gridContainer = NSView()
    private var tiles: [ChannelTileView] = []

    init(config: AppConfig, renderer: BannerRenderer) {
        self.config = config; self.renderer = renderer
        super.init(frame: .zero)
        wantsLayer = true
        applyBackgroundGradient()
        if let bg = AssetLibrary.shared.image(.background) {
            bgImageView.image = bg
            bgImageView.imageScaling = .scaleAxesIndependently
            addSubview(bgImageView)
        }
        addSubview(gridContainer)
        addSubview(bottomBar)
        setupArrows()
        bottomBar.onWii = { [weak self] in self?.onWii() }
        rebuildGrid()
        setupCursorOverlay()
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { cursorTimer?.invalidate() }

    private func applyBackgroundGradient() {
        let g = CAGradientLayer()
        g.type = .radial
        g.colors = [NSColor.wiiBGCenter.cgColor, NSColor.wiiBGEdge.cgColor]
        g.startPoint = CGPoint(x: 0.5, y: 0.55)
        g.endPoint = CGPoint(x: 1.35, y: 1.35)   // push the darker edge outward (gentle vignette)
        layer = g
    }

    private func setupArrows() {
        leftArrow.pointingLeft = true
        leftArrow.target = self; leftArrow.action = #selector(prevPage)
        rightArrow.pointingLeft = false
        rightArrow.target = self; rightArrow.action = #selector(nextPage)
        addSubview(leftArrow); addSubview(rightArrow)
    }

    // Custom Wii hand cursor drawn as an overlay that follows the mouse, because a
    // non-key wallpaper window can't reliably override the system cursor via NSCursor.
    private let cursorView = PassthroughImageView()
    private nonisolated(unsafe) var cursorTimer: Timer?

    private func setupCursorOverlay() {
        guard let cimg = AssetLibrary.shared.image(.cursor) else { return }
        cursorView.image = cimg
        cursorView.imageScaling = .scaleProportionallyUpOrDown
        cursorView.frame = NSRect(x: 0, y: 0, width: 46, height: 46)
        cursorView.isHidden = true
        addSubview(cursorView, positioned: .above, relativeTo: nil)
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateCursorOverlay() }
        }
    }

    private var systemCursorHidden = false
    private func updateCursorOverlay() {
        guard let window = window else { return }
        let viewPt = convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        let inside = bounds.contains(viewPt)
        if inside {
            addSubview(cursorView, positioned: .above, relativeTo: nil) // keep on top
            cursorView.isHidden = false
            let w = cursorView.frame.width, h = cursorView.frame.height
            // hotspot = fingertip: ~0.34 from left, ~0.92 up from the bottom of the image
            cursorView.setFrameOrigin(NSPoint(x: viewPt.x - w * 0.34, y: viewPt.y - h * 0.92))
            if !systemCursorHidden { NSCursor.hide(); systemCursorHidden = true }
        } else if systemCursorHidden || !cursorView.isHidden {
            cursorView.isHidden = true
            if systemCursorHidden { NSCursor.unhide(); systemCursorHidden = false }
        }
    }

    @objc private func prevPage() { if currentPage > 0 { currentPage -= 1; rebuildGrid() } }
    @objc private func nextPage() {
        if currentPage < Theme.pageCount - 1 { currentPage += 1; rebuildGrid() }
    }

    private func rebuildGrid() {
        gridContainer.subviews.forEach { $0.removeFromSuperview() }
        tiles.removeAll()
        let start = currentPage * Theme.slotsPerPage
        for i in 0..<Theme.slotsPerPage {
            let slot = start + i
            let channel = config.channels.first(where: { $0.slot == slot }) ?? Channel(slot: slot)
            let img = renderer.image(for: channel, size: NSSize(width: 360, height: 198))
            let tile = ChannelTileView(channel: channel, image: img)
            tile.onLaunch = { [weak self] c in self?.onLaunch(c) }
            tile.onEdit = { [weak self] slot, kind in self?.onEditChannel(slot, kind) }
            gridContainer.addSubview(tile)
            tiles.append(tile)
        }
        updateArrowVisibility()
        needsLayout = true
    }

    private func updateArrowVisibility() {
        leftArrow.isHidden = currentPage == 0
        rightArrow.isHidden = currentPage == Theme.pageCount - 1
    }

    override func layout() {
        super.layout()
        bgImageView.frame = bounds
        // Size the bar to the real bar asset's aspect so it fills without distortion.
        let barH = min(bounds.height * 0.30, bounds.width / BottomBarView.aspect)
        bottomBar.frame = NSRect(x: 0, y: 0, width: bounds.width, height: barH)
        let gridArea = NSRect(x: 0, y: barH, width: bounds.width, height: bounds.height - barH)
        gridContainer.frame = gridArea

        let cols = Theme.columns, rows = Theme.rows
        let margin = bounds.width * 0.075
        let gutter = bounds.width * 0.02
        let cellW = (gridArea.width - margin*2 - gutter*CGFloat(cols-1)) / CGFloat(cols)
        let cellH = cellW / Theme.tileAspect
        let totalH = cellH*CGFloat(rows) + gutter*1.4*CGFloat(rows-1)
        let topY = (gridArea.height + totalH)/2 - cellH
        for (i, tile) in tiles.enumerated() {
            let r = i / cols, c = i % cols
            tile.frame = NSRect(x: margin + CGFloat(c)*(cellW+gutter),
                                y: topY - CGFloat(r)*(cellH + gutter*1.4),
                                width: cellW, height: cellH)
        }

        // Page arrows: pinned to the screen edges, centered on the grid area.
        let aW = bounds.width * 0.032, aH = gridArea.height * 0.14
        let aY = barH + (gridArea.height - aH)/2
        leftArrow.frame = NSRect(x: bounds.width * 0.012, y: aY, width: aW, height: aH)
        rightArrow.frame = NSRect(x: bounds.width - bounds.width * 0.012 - aW,
                                  y: aY, width: aW, height: aH)
    }
}

/// An image view that never intercepts mouse events (used for the cursor overlay
/// so it can sit on top of everything without blocking clicks).
@MainActor
final class PassthroughImageView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
