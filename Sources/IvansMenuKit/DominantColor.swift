import CoreGraphics
import Foundation

public enum DominantColor {
    public static func average(of image: CGImage) -> (r: Double, g: Double, b: Double) {
        let w = 16, h = 16
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: w * 4, space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return (0.5, 0.5, 0.5)
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        var rs = 0.0, gs = 0.0, bs = 0.0, count = 0.0
        for i in stride(from: 0, to: px.count, by: 4) {
            let a = Double(px[i + 3]) / 255
            if a < 0.1 { continue }
            rs += Double(px[i]) / 255; gs += Double(px[i+1]) / 255; bs += Double(px[i+2]) / 255
            count += 1
        }
        guard count > 0 else { return (0.5, 0.5, 0.5) }
        return (rs / count, gs / count, bs / count)
    }
}
