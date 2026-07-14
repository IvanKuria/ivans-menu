import AppKit
import IvansMenuKit

final class BannerRenderer {
    private let packIDs: Set<String>
    private let packImage: (String) -> NSImage?
    private let appIcon: (ChannelAction) -> NSImage?
    private var cache: [String: NSImage] = [:]

    init(packIDs: Set<String>,
         packImage: @escaping (String) -> NSImage?,
         appIcon: @escaping (ChannelAction) -> NSImage?) {
        self.packIDs = packIDs; self.packImage = packImage; self.appIcon = appIcon
    }

    func image(for channel: Channel, size: NSSize) -> NSImage {
        let plan = BannerPlan.resolve(channel, packIDs: packIDs)
        let key = "\(plan)-\(Int(size.width))x\(Int(size.height))-\(channel.id)"
        if let cached = cache[key] { return cached }
        let img: NSImage
        switch plan {
        case .pack(let id): img = packImage(id) ?? generated(channel, size: size)
        case .custom(let path):
            img = NSImage(contentsOfFile: path) ?? generated(channel, size: size)
        case .generated: img = generated(channel, size: size)
        }
        cache[key] = img
        return img
    }

    private func generated(_ channel: Channel, size: NSSize) -> NSImage {
        let icon = appIcon(channel.action)
        var bg = NSColor.wiiAccent
        if let cg = icon?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let c = DominantColor.average(of: cg)
            bg = NSColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: 1)
        }
        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        let radius = size.width * Theme.tileCornerFraction
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        bg.setFill(); path.fill()
        if let icon {
            let s = min(size.width, size.height) * 0.55
            let r = NSRect(x: (size.width - s)/2, y: (size.height - s)/2, width: s, height: s)
            icon.draw(in: r)
        }
        image.unlockFocus()
        return image
    }
}
