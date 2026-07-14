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
        // Background (gradient + scanlines) is drawn in draw(_:); no image layer,
        // which would otherwise cover the scanlines.
        addSubview(gridContainer)
        addSubview(bottomBar)
        setupArrows()
        bottomBar.onWii = { [weak self] in self?.onWii() }
        rebuildGrid()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        // Radial gradient background.
        let grad = NSGradient(colors: [NSColor.wiiBGCenter, NSColor.wiiBGEdge],
                              atLocations: [0, 1], colorSpace: .sRGB)!
        grad.draw(in: bounds, relativeCenterPosition: NSPoint(x: 0, y: 0.05))
        // Horizontal "static" scanlines across the whole background, matching the bar.
        let period: CGFloat = 6
        let line = NSBezierPath()
        line.lineWidth = 1
        var y = bounds.height.truncatingRemainder(dividingBy: period)
        while y < bounds.height {
            line.move(to: NSPoint(x: 0, y: y + 0.5))
            line.line(to: NSPoint(x: bounds.width, y: y + 0.5))
            y += period
        }
        NSColor(white: 0.66, alpha: 0.14).setStroke()
        line.stroke()
    }

    private func setupArrows() {
        leftArrow.pointingLeft = true
        leftArrow.target = self; leftArrow.action = #selector(prevPage)
        rightArrow.pointingLeft = false
        rightArrow.target = self; rightArrow.action = #selector(nextPage)
        addSubview(leftArrow); addSubview(rightArrow)
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
