import XCTest
import CoreGraphics
@testable import IvansMenuKit

final class DominantColorTests: XCTestCase {
    private func solid(_ r: Int, _ g: Int, _ b: Int) -> CGImage {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8,
            bytesPerRow: 0, space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(red: CGFloat(r)/255, green: CGFloat(g)/255,
                         blue: CGFloat(b)/255, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        return ctx.makeImage()!
    }

    func testSolidRed() {
        let c = DominantColor.average(of: solid(255, 0, 0))
        XCTAssertEqual(c.r, 1.0, accuracy: 0.05)
        XCTAssertEqual(c.g, 0.0, accuracy: 0.05)
        XCTAssertEqual(c.b, 0.0, accuracy: 0.05)
    }
}
