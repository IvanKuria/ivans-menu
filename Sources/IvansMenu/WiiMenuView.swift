import AppKit
import IvansMenuKit

@MainActor
final class WiiMenuView: NSView {
    var onLaunch: (Channel) -> Void = { _ in }
    var onWii: () -> Void = {}

    private let config: AppConfig
    private let renderer: BannerRenderer
    private let bottomBar = BottomBarView()
    private var currentPage = 0
    private let leftArrow = NSButton(title: "◀", target: nil, action: nil)
    private let rightArrow = NSButton(title: "▶", target: nil, action: nil)
    private var gridContainer = NSView()

    init(config: AppConfig, renderer: BannerRenderer) {
        self.config = config; self.renderer = renderer
        super.init(frame: .zero)
        wantsLayer = true
        applyBackgroundGradient()
        addSubview(gridContainer)
        addSubview(bottomBar)
        setupArrows()
        bottomBar.onWii = { [weak self] in self?.onWii() }
        rebuildGrid()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func applyBackgroundGradient() {
        let g = CAGradientLayer()
        g.type = .radial
        g.colors = [NSColor.wiiBGCenter.cgColor, NSColor.wiiBGEdge.cgColor]
        g.startPoint = CGPoint(x: 0.5, y: 0.5)
        g.endPoint = CGPoint(x: 1, y: 1)
        layer = g
    }

    private func setupArrows() {
        for (b, sel) in [(leftArrow, #selector(prevPage)), (rightArrow, #selector(nextPage))] {
            b.bezelStyle = .circular; b.target = self; b.action = sel; addSubview(b)
        }
    }

    @objc private func prevPage() { if currentPage > 0 { currentPage -= 1; rebuildGrid() } }
    @objc private func nextPage() {
        if currentPage < Theme.pageCount - 1 { currentPage += 1; rebuildGrid() }
    }

    private func rebuildGrid() {
        gridContainer.subviews.forEach { $0.removeFromSuperview() }
        let start = currentPage * Theme.slotsPerPage
        for i in 0..<Theme.slotsPerPage {
            let slot = start + i
            guard let channel = config.channels.first(where: { $0.slot == slot }) else { continue }
            let img = renderer.image(for: channel, size: NSSize(width: 320, height: 176))
            let tile = ChannelTileView(channel: channel, image: img)
            tile.onLaunch = { [weak self] c in self?.onLaunch(c) }
            gridContainer.addSubview(tile)
        }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let barH = bounds.height * 0.2
        bottomBar.frame = NSRect(x: 0, y: 0, width: bounds.width, height: barH)
        let gridArea = NSRect(x: 0, y: barH, width: bounds.width, height: bounds.height - barH)
        gridContainer.frame = gridArea

        let cols = Theme.columns, rows = Theme.rows
        let gutter: CGFloat = 24
        let margin: CGFloat = 60
        let cellW = (gridArea.width - margin*2 - gutter*CGFloat(cols-1)) / CGFloat(cols)
        let cellH = cellW / Theme.tileAspect
        let totalH = cellH*CGFloat(rows) + gutter*CGFloat(rows-1)
        let topY = (gridArea.height + totalH)/2 - cellH
        for (idx, tile) in gridContainer.subviews.enumerated() {
            let r = idx / cols, c = idx % cols
            tile.frame = NSRect(x: margin + CGFloat(c)*(cellW+gutter),
                                y: topY - CGFloat(r)*(cellH+gutter),
                                width: cellW, height: cellH)
        }
        leftArrow.frame = NSRect(x: 8, y: bounds.midY, width: 44, height: 60)
        rightArrow.frame = NSRect(x: bounds.width-52, y: bounds.midY, width: 44, height: 60)
    }
}
