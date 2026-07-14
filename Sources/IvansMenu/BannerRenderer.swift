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
        // Dominant color of the app icon → a gentle tint (not a saturated block).
        var hue = NSColor.wiiAccent
        if let cg = icon?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let c = DominantColor.average(of: cg)
            hue = NSColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: 1)
        }
        // Blend the hue heavily toward white for a soft "channel art panel" wash.
        let top = hue.blended(withFraction: 0.72, of: .white) ?? .white
        let bottom = NSColor.white

        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        // Soft vertical wash: tinted at the top, white toward the label strip.
        let wash = NSGradient(colors: [top, bottom, bottom],
                              atLocations: [0, 0.82, 1], colorSpace: .sRGB)!
        wash.draw(in: rect, angle: -90)
        // A faint thin divider above the bottom "label" band, like a real channel.
        NSColor(srgbRed: 0.85, green: 0.86, blue: 0.88, alpha: 1).setStroke()
        let seam = NSBezierPath()
        seam.move(to: NSPoint(x: rect.width * 0.06, y: rect.height * 0.2))
        seam.line(to: NSPoint(x: rect.width * 0.94, y: rect.height * 0.2))
        seam.lineWidth = 1
        seam.stroke()
        // Big app icon centered in the art panel (upper region).
        if let icon {
            let s = min(size.width * 0.42, size.height * 0.66)
            let r = NSRect(x: (size.width - s)/2, y: rect.height * 0.2 + (rect.height*0.8 - s)/2,
                           width: s, height: s)
            icon.draw(in: r)
        }
        image.unlockFocus()
        return image
    }
}
