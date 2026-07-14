#!/usr/bin/env swift
// Renders the app icon: a play on the Wii logo — the signature "double-i"
// (two people / two remotes) as glossy blue figures on the app's own silver
// menu backdrop and round "Wii button" disc.
//
// Usage: swift scripts/make_icon.swift <out.png>   (renders a 1024×1024 PNG)
import AppKit

let S: CGFloat = 1024
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

func srgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}

// A convex "squircle" like macOS app icons (continuous-ish rounded corners).
func squircle(in rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

let image = NSImage(size: NSSize(width: S, height: S))
image.lockFocus()
let ctx = NSGraphicsContext.current!
ctx.imageInterpolation = .high

// ---- Rounded-rect canvas (macOS content grid: ~824 within 1024) ----
let margin: CGFloat = 100
let card = NSRect(x: margin, y: margin, width: S - margin*2, height: S - margin*2)
let cardRadius = card.width * 0.225
let cardPath = squircle(in: card, radius: cardRadius)

// Soft ambient shadow under the whole icon.
NSGraphicsContext.saveGraphicsState()
let sh = NSShadow()
sh.shadowColor = NSColor.black.withAlphaComponent(0.28)
sh.shadowBlurRadius = 42
sh.shadowOffset = NSSize(width: 0, height: -18)
sh.set()
srgb(0.90, 0.91, 0.93).setFill()
cardPath.fill()
NSGraphicsContext.restoreGraphicsState()

// Clip everything else to the card.
NSGraphicsContext.saveGraphicsState()
cardPath.addClip()

// Silver radial menu backdrop (matches app's wiiBGCenter/wiiBGEdge).
let bg = NSGradient(colors: [srgb(0.965, 0.968, 0.972), srgb(0.80, 0.815, 0.845)],
                    atLocations: [0, 1], colorSpace: .sRGB)!
bg.draw(in: card, relativeCenterPosition: NSPoint(x: 0, y: 0.15))

// Faint horizontal "static" scanlines, like the Wii menu background.
let line = NSBezierPath(); line.lineWidth = 2
var y = card.minY
while y < card.maxY { line.move(to: NSPoint(x: card.minX, y: y)); line.line(to: NSPoint(x: card.maxX, y: y)); y += 12 }
srgb(0.66, 0.66, 0.66, 0.10).setStroke(); line.stroke()

// ---- Round "Wii button" disc, centered ----
let d = card.width * 0.66
let disc = NSRect(x: card.midX - d/2, y: card.midY - d/2 + card.height*0.01, width: d, height: d)
NSGraphicsContext.saveGraphicsState()
let discShadow = NSShadow()
discShadow.shadowColor = NSColor.black.withAlphaComponent(0.16)
discShadow.shadowBlurRadius = 30
discShadow.shadowOffset = NSSize(width: 0, height: -10)
discShadow.set()
let discGrad = NSGradient(colors: [srgb(1, 1, 1), srgb(0.90, 0.915, 0.94)],
                          atLocations: [0, 1], colorSpace: .sRGB)!
discGrad.draw(in: NSBezierPath(ovalIn: disc), angle: -90)
NSGraphicsContext.restoreGraphicsState()
// Subtle inner ring / bevel.
let ring = NSBezierPath(ovalIn: disc.insetBy(dx: 3, dy: 3))
srgb(0.78, 0.80, 0.83).setStroke(); ring.lineWidth = 3; ring.stroke()
// Top gloss on the disc.
NSGraphicsContext.saveGraphicsState()
NSBezierPath(ovalIn: disc).addClip()
let gloss = NSGradient(colors: [NSColor.white.withAlphaComponent(0.55), NSColor.white.withAlphaComponent(0.0)],
                       atLocations: [0, 1], colorSpace: .sRGB)!
gloss.draw(in: NSRect(x: disc.minX, y: disc.midY, width: disc.width, height: disc.height/2), angle: -90)
NSGraphicsContext.restoreGraphicsState()

// ---- The "double-i" hero: two glossy blue figures leaning together ----
// Each figure = a rounded stem (body) + a dot (head), tilted toward the other.
func figure(centerX cx: CGFloat, lean: CGFloat) {
    let stemW = d * 0.13
    let stemH = d * 0.34
    let baseY = disc.midY - stemH*0.42
    let headR = stemW * 0.62
    let bodyGrad = NSGradient(colors: [srgb(0.36, 0.78, 0.96), srgb(0.13, 0.50, 0.80)],
                              atLocations: [0, 1], colorSpace: .sRGB)!

    NSGraphicsContext.saveGraphicsState()
    // Lean: rotate around the figure's base.
    let t = NSAffineTransform()
    t.translateX(by: cx, yBy: baseY)
    t.rotate(byDegrees: lean)
    t.translateX(by: -cx, yBy: -baseY)
    t.concat()

    // Body (rounded pill).
    let body = NSRect(x: cx - stemW/2, y: baseY, width: stemW, height: stemH)
    let bodyPath = NSBezierPath(roundedRect: body, xRadius: stemW/2, yRadius: stemW/2)
    bodyGrad.draw(in: bodyPath, angle: -90)
    // Head (dot) floating above the body, Wii-style.
    let head = NSRect(x: cx - headR, y: body.maxY + stemW*0.30, width: headR*2, height: headR*2)
    bodyGrad.draw(in: NSBezierPath(ovalIn: head), angle: -90)
    // Highlight on body for a glossy read.
    NSColor.white.withAlphaComponent(0.28).setFill()
    NSBezierPath(roundedRect: body.insetBy(dx: stemW*0.28, dy: stemH*0.10),
                 xRadius: stemW*0.18, yRadius: stemW*0.18).fill()
    NSGraphicsContext.restoreGraphicsState()
}

let gap = d * 0.135
figure(centerX: disc.midX - gap, lean: 7)    // left figure leans right
figure(centerX: disc.midX + gap, lean: -7)   // right figure leans left

NSGraphicsContext.restoreGraphicsState() // end card clip

// Crisp edge highlight on the card rim.
NSColor.white.withAlphaComponent(0.5).setStroke()
let rim = squircle(in: card.insetBy(dx: 1, dy: 1), radius: cardRadius)
rim.lineWidth = 2; rim.stroke()

image.unlockFocus()

// ---- Write PNG ----
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("Failed to encode PNG\n".data(using: .utf8)!)
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath)")
