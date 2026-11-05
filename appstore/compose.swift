// Builds App Store screenshots from the raw captures in appstore/raw.
// Usage: swift appstore/compose.swift   (run from the repo root)
// Output: appstore/iphone/*.png (1320×2868), appstore/iphone-6.3/*.png (1206×2622) and appstore/mac/*.png (2880×1800)
import AppKit
import CoreText

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("appstore")
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func load(_ path: String) -> CGImage {
    let url = root.appendingPathComponent(path)
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { fatalError("missing \(path)") }
    return img
}

/// Canvas with a top-left origin.
func canvas(_ w: Int, _ h: Int) -> CGContext {
    let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let g = CGGradient(colorsSpace: space, colors: [rgb(0x2A8CE8), rgb(0x0B5CB8), rgb(0x063F86)] as CFArray,
                       locations: [0, 0.55, 1])!
    c.drawLinearGradient(g, start: .zero, end: CGPoint(x: w, y: h),
                         options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    // soft sun glow
    let glow = CGGradient(colorsSpace: space, colors: [rgb(0xFFFFFF, 0.22), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    c.drawRadialGradient(glow, startCenter: CGPoint(x: CGFloat(w) * 0.85, y: CGFloat(h) * 0.92), startRadius: 0,
                         endCenter: CGPoint(x: CGFloat(w) * 0.85, y: CGFloat(h) * 0.92), endRadius: CGFloat(w) * 0.6, options: [])
    c.translateBy(x: 0, y: CGFloat(h)); c.scaleBy(x: 1, y: -1)
    return c
}

/// Draws text (top-left origin) inside `rect`; returns the used height.
@discardableResult
func text(_ c: CGContext, _ s: String, _ rect: CGRect, size: CGFloat, weight: NSFont.Weight,
          color: CGColor = rgb(0xFFFFFF), align: NSTextAlignment = .center) -> CGFloat {
    let para = NSMutableParagraphStyle(); para.alignment = align; para.lineSpacing = size * 0.08
    let attr = NSAttributedString(string: s, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: NSColor(cgColor: color)!, .paragraphStyle: para])
    let fs = CTFramesetterCreateWithAttributedString(attr)
    let fit = CTFramesetterSuggestFrameSizeWithConstraints(fs, CFRange(), nil, CGSize(width: rect.width, height: .greatestFiniteMagnitude), nil)
    c.saveGState()
    // CoreText draws bottom-up: flip locally.
    c.translateBy(x: rect.minX, y: rect.minY + fit.height); c.scaleBy(x: 1, y: -1)
    let frame = CTFramesetterCreateFrame(fs, CFRange(), CGPath(rect: CGRect(x: 0, y: 0, width: rect.width, height: fit.height), transform: nil), nil)
    CTFrameDraw(frame, c)
    c.restoreGState()
    return fit.height
}

func image(_ c: CGContext, _ img: CGImage, _ rect: CGRect, radius: CGFloat, shadow: CGFloat = 40, border: Bool = false) {
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: shadow / 3), blur: shadow, color: rgb(0x000000, 0.35))
    c.addPath(path); c.setFillColor(rgb(0xFFFFFF)); c.fillPath()
    c.restoreGState()
    c.saveGState()
    c.addPath(path); c.clip()
    // image drawing in a flipped context: flip around the rect
    c.translateBy(x: rect.minX, y: rect.maxY); c.scaleBy(x: 1, y: -1)
    c.draw(img, in: CGRect(origin: .zero, size: rect.size))
    c.restoreGState()
    if border {
        c.addPath(path); c.setStrokeColor(rgb(0x000000, 0.12)); c.setLineWidth(2); c.strokePath()
    }
}

func save(_ c: CGContext, _ path: String) {
    let url = root.appendingPathComponent(path)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let rep = NSBitmapImageRep(cgImage: c.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
    print("wrote", path)
}

// MARK: iPhone 6.9" — 1320 × 2868

let phone: [(String, String, String)] = [
    ("ios-1-main", "Your solar system\nat a glance", "Live solar, battery, home load and grid"),
    ("ios-3-widgets", "Widgets on your\nHome Screen", "Battery, solar and grid without opening the app"),
    ("ios-2-params", "Show exactly\nwhat you need", "Every inverter value — even raw registers"),
    ("ios-5-settings", "Straight to\nyour inverter", "Connects to the Solarman Wi‑Fi logger on your home network. No cloud, no account."),
]
for (W, H, folder) in [(1320, 2868, "iphone"), (1206, 2622, "iphone-6.3")] {
  let k = CGFloat(W) / 1320                        // layout is designed at 1320 wide
  for (i, (file, title, sub)) in phone.enumerated() {
    let c = canvas(W, H)
    var y: CGFloat = 170 * k
    y += text(c, title, CGRect(x: 80 * k, y: y, width: CGFloat(W) - 160 * k, height: 0), size: 112 * k, weight: .bold) + 36 * k
    y += text(c, sub, CGRect(x: 110 * k, y: y, width: CGFloat(W) - 220 * k, height: 0), size: 50 * k, weight: .medium, color: rgb(0xFFFFFF, 0.85))
    let shot = load("raw/\(file).png")
    let shotW: CGFloat = 1030 * k
    let shotH = shotW * CGFloat(shot.height) / CGFloat(shot.width)
    let top = max(y + 90 * k, CGFloat(H) - shotH + 120 * k)   // let the phone run off the bottom edge
    image(c, shot, CGRect(x: (CGFloat(W) - shotW) / 2, y: top, width: shotW, height: shotH), radius: 120 * k, shadow: 60 * k)
    save(c, "\(folder)/\(i + 1)-\(file.replacingOccurrences(of: "ios-", with: "").dropFirst(2)).png")
  }
}

// MARK: Mac — 2880 × 1800

func menuBar(_ c: CGContext, width: CGFloat) {
    c.setFillColor(rgb(0xFFFFFF, 0.55)); c.fill(CGRect(x: 0, y: 0, width: width, height: 64))
    let label = load("raw/mac/mac-menubar.png")   // template image (black on clear)
    let h: CGFloat = 40, w = h * CGFloat(label.width) / CGFloat(label.height)
    let x = width - w - 260
    c.saveGState(); c.translateBy(x: x, y: 12 + h); c.scaleBy(x: 1, y: -1)
    c.draw(label, in: CGRect(x: 0, y: 0, width: w, height: h)); c.restoreGState()
    // highlight + caret for the open item
    c.setFillColor(rgb(0x000000, 0.12))
    c.addPath(CGPath(roundedRect: CGRect(x: x - 14, y: 8, width: w + 28, height: 48), cornerWidth: 10, cornerHeight: 10, transform: nil)); c.fillPath()
}

do { // 1: menu bar panel + widgets
    let W = 2880, H = 1800, c = canvas(W, H)
    menuBar(c, width: CGFloat(W))
    text(c, "Your solar system\nin the menu bar", CGRect(x: 140, y: 330, width: 1150, height: 0), size: 120, weight: .bold, align: .left)
    text(c, "Pick any values for the menu bar — battery, load, grid on/off — and see the details in one click. Desktop widgets included.",
         CGRect(x: 140, y: 680, width: 1050, height: 0), size: 48, weight: .medium, color: rgb(0xFFFFFF, 0.85), align: .left)
    let panel = load("raw/mac/mac-panel.png")
    let pw: CGFloat = 930, ph = pw * CGFloat(panel.height) / CGFloat(panel.width)
    image(c, panel, CGRect(x: 1700, y: 90, width: pw, height: ph), radius: 30, shadow: 50)
    let med = load("raw/mac/mac-widget-medium.png"), sm = load("raw/mac/mac-widget-small.png")
    image(c, med, CGRect(x: 140, y: 1130, width: 820, height: 820 * CGFloat(med.height) / CGFloat(med.width)), radius: 48, shadow: 40)
    image(c, sm, CGRect(x: 1010, y: 1130, width: 385, height: 385), radius: 48, shadow: 40)
    save(c, "mac/1-menubar.png")
}

do { // 2: parameters window
    let W = 2880, H = 1800, c = canvas(W, H)
    menuBar(c, width: CGFloat(W))
    text(c, "Choose exactly\nwhat you see", CGRect(x: 140, y: 420, width: 1100, height: 0), size: 120, weight: .bold, align: .left)
    text(c, "Every value the inverter reports — power, voltages, temperatures, daily energy and raw registers. Tick it for the menu bar or the panel.",
         CGRect(x: 140, y: 770, width: 1000, height: 0), size: 48, weight: .medium, color: rgb(0xFFFFFF, 0.85), align: .left)
    let win = load("raw/mac/mac-parameters.png")
    let ww: CGFloat = 1380, wh = ww * CGFloat(win.height) / CGFloat(win.width)
    // window with a title bar
    let frame = CGRect(x: 1340, y: 170, width: ww, height: wh + 72)
    c.saveGState(); c.setShadow(offset: CGSize(width: 0, height: 20), blur: 60, color: rgb(0x000000, 0.35))
    c.addPath(CGPath(roundedRect: frame, cornerWidth: 28, cornerHeight: 28, transform: nil)); c.setFillColor(rgb(0xF4F4F6)); c.fillPath()
    c.restoreGState()
    for (k, col) in [0xFF5F57, 0xFEBC2E, 0x28C840].enumerated() {
        c.setFillColor(rgb(UInt32(col))); c.fillEllipse(in: CGRect(x: frame.minX + 30 + CGFloat(k) * 44, y: frame.minY + 24, width: 26, height: 26))
    }
    text(c, "Solar Glance Parameters", CGRect(x: frame.minX, y: frame.minY + 18, width: ww, height: 40), size: 30, weight: .semibold, color: rgb(0x000000, 0.8))
    image(c, win, CGRect(x: frame.minX, y: frame.minY + 72, width: ww, height: wh), radius: 0, shadow: 0)
    save(c, "mac/2-parameters.png")
}

// MARK: App Store header (product page banner) — 3840×1646 and 5244×2950

func header(_ W: Int, _ H: Int, _ name: String) {
    let c = canvas(W, H)
    let s = CGFloat(H) / 1646                         // scale from the 3840×1646 layout
    let icon = load("../packaging/icon/icon-ios-1024.png")
    let iconSize = 300 * s
    let left = CGFloat(W) * 0.12
    let midY = CGFloat(H) / 2
    image(c, icon, CGRect(x: left, y: midY - 330 * s, width: iconSize, height: iconSize), radius: 68 * s, shadow: 40 * s)
    text(c, "Solar Glance", CGRect(x: left, y: midY + 10 * s, width: min(1500 * s, CGFloat(W) * 0.42), height: 0), size: 150 * s, weight: .bold, align: .left)
    text(c, "Your solar inverter at a glance — live solar, battery, home load and grid.\nWidgets for the Home Screen, Lock Screen and Mac menu bar.",
         CGRect(x: left, y: midY + 200 * s, width: min(1450 * s, CGFloat(W) * 0.40), height: 0), size: 52 * s, weight: .medium, color: rgb(0xFFFFFF, 0.85), align: .left)
    // two phones on the right, slightly overlapping, running off the bottom
    let shots = [load("raw/ios-3-widgets.png"), load("raw/ios-1-main.png")]
    let pw = min(640 * s, CGFloat(W) * 0.165), ph = pw * CGFloat(shots[0].height) / CGFloat(shots[0].width)
    let right = CGFloat(W) * 0.88
    image(c, shots[0], CGRect(x: right - pw * 1.75, y: 260 * s, width: pw, height: ph), radius: 80 * s, shadow: 60 * s)
    image(c, shots[1], CGRect(x: right - pw, y: 160 * s, width: pw, height: ph), radius: 80 * s, shadow: 60 * s)
    save(c, "header/\(name)")
}
header(3840, 1646, "header-3840x1646.png")
header(5244, 2950, "header-5244x2950.png")
