// Renders the Deye Monitor app icon (Deye-blue tile, sun with a bolt).
// Usage: swift make_icon.swift <out-dir>   → icon-ios-1024.png, icon-mac-1024.png
import AppKit
import CoreGraphics

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!

/// Draws the artwork into `rect` (top-left origin context).
func artwork(_ c: CGContext, _ r: CGRect) {
    let s = r.width / 1024
    func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * s, y: r.minY + y * s) }

    // Deye blue gradient
    let bg = CGGradient(colorsSpace: space, colors: [rgb(0x2A8CE8), rgb(0x0B5CB8), rgb(0x063F86)] as CFArray,
                        locations: [0, 0.55, 1])!
    c.drawLinearGradient(bg, start: P(200, 0), end: P(824, 1024), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    // Soft glow behind the sun
    let glow = CGGradient(colorsSpace: space, colors: [rgb(0xFFFFFF, 0.28), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    c.drawRadialGradient(glow, startCenter: P(512, 440), startRadius: 0, endCenter: P(512, 440), endRadius: 400 * s, options: [])

    // Rays
    c.setStrokeColor(rgb(0xFFFFFF))
    c.setLineCap(.round)
    c.setLineWidth(46 * s)
    for i in 0..<12 {
        let a = CGFloat(i) * .pi / 6
        c.move(to: P(512 + cos(a) * 232, 440 + sin(a) * 232))
        c.addLine(to: P(512 + cos(a) * 300, 440 + sin(a) * 300))
    }
    c.strokePath()

    // Sun disc
    c.setFillColor(rgb(0xFFFFFF))
    c.fillEllipse(in: CGRect(origin: P(512 - 182, 440 - 182), size: CGSize(width: 364 * s, height: 364 * s)))

    // Bolt cut into the sun, in Deye blue
    let bolt = CGMutablePath()
    bolt.move(to: P(548, 300))
    bolt.addLine(to: P(430, 462))
    bolt.addLine(to: P(506, 462))
    bolt.addLine(to: P(474, 582))
    bolt.addLine(to: P(596, 412))
    bolt.addLine(to: P(518, 412))
    bolt.closeSubpath()
    c.addPath(bolt)
    c.setFillColor(rgb(0x0B5CB8))
    c.fillPath()

    // Horizon: two flowing bars (energy flow)
    c.setStrokeColor(rgb(0xFFFFFF))
    c.setLineWidth(40 * s)
    for (y, alpha) in [(812.0, 1.0), (888.0, 0.55)] {
        c.setStrokeColor(rgb(0xFFFFFF, CGFloat(alpha)))
        c.move(to: P(196, CGFloat(y)))
        c.addCurve(to: P(828, CGFloat(y)), control1: P(400, CGFloat(y) - 46), control2: P(624, CGFloat(y) + 46))
        c.strokePath()
    }
}

func render(_ name: String, mac: Bool) {
    let n = 1024
    let c = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                      bitmapInfo: mac ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue)!
    // top-left origin
    c.translateBy(x: 0, y: CGFloat(n)); c.scaleBy(x: 1, y: -1)
    if mac {
        // macOS template: 824pt tile centred in 1024 with a soft drop shadow.
        let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
        let shape = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
        c.saveGState()
        c.setShadow(offset: CGSize(width: 0, height: 10), blur: 28, color: rgb(0x000000, 0.35))
        c.addPath(shape); c.setFillColor(rgb(0x0B5CB8)); c.fillPath()
        c.restoreGState()
        c.saveGState(); c.addPath(shape); c.clip()
        artwork(c, tile)
        c.restoreGState()
    } else {
        artwork(c, CGRect(x: 0, y: 0, width: n, height: n))   // iOS masks the corners itself
    }
    let rep = NSBitmapImageRep(cgImage: c.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/\(name)"))
}

render("icon-ios-1024.png", mac: false)
render("icon-mac-1024.png", mac: true)
print("ok")
