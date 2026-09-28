import AppKit

// Composes a 2880×1800 Mac App Store screenshot from a popover capture.
// usage: compose <popover.png> <output.png> <headline> <subline> [sheet.png]
let args = CommandLine.arguments
let (W, H) = (2880, 1800)
let body = CGRect(x: 25, y: 25, width: 801, height: 922)   // popover body in capture pixels
let scale: CGFloat = 1.5

func load(_ path: String) -> CGImage {
    NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: path)))!.cgImage!
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let ns = NSGraphicsContext(bitmapImageRep: rep)!
let cg = ns.cgContext
cg.translateBy(x: 0, y: CGFloat(H)); cg.scaleBy(x: 1, y: -1)          // top-left origin
NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)

// Background: deep indigo to teal with a soft glow behind the popover.
let space = CGColorSpaceCreateDeviceRGB()
let bg = CGGradient(colorsSpace: space, colors: [
    CGColor(red: 0.12, green: 0.11, blue: 0.29, alpha: 1),
    CGColor(red: 0.07, green: 0.30, blue: 0.36, alpha: 1)] as CFArray, locations: [0, 1])!
cg.drawLinearGradient(bg, start: .zero, end: CGPoint(x: W, y: H), options: [])
let glow = CGGradient(colorsSpace: space, colors: [
    CGColor(red: 0.45, green: 0.55, blue: 1, alpha: 0.35), CGColor(red: 0.45, green: 0.55, blue: 1, alpha: 0)] as CFArray,
    locations: [0, 1])!
cg.drawRadialGradient(glow, startCenter: CGPoint(x: 2080, y: 800), startRadius: 0,
                      endCenter: CGPoint(x: 2080, y: 800), endRadius: 1100, options: [])

// Menu bar with the LinkShelf status item highlighted.
let barHeight: CGFloat = 74
cg.setFillColor(CGColor(gray: 0, alpha: 0.35)); cg.fill(CGRect(x: 0, y: 0, width: CGFloat(W), height: barHeight))
let popW = body.width * scale, popH = body.height * scale
let popX = CGFloat(W) - popW - 230, popY = barHeight + 44
let arrowX = popX + 320 * scale
cg.setFillColor(CGColor(gray: 1, alpha: 0.22))
cg.addPath(CGPath(roundedRect: CGRect(x: arrowX - 38, y: 11, width: 76, height: 52), cornerWidth: 12, cornerHeight: 12, transform: nil)); cg.fillPath()
if let symbol = NSImage(systemSymbolName: "link", accessibilityDescription: nil)?
    .withSymbolConfiguration(.init(pointSize: 34, weight: .semibold)) {
    let tinted = NSImage(size: symbol.size, flipped: false) { rect in
        symbol.draw(in: rect); NSColor.white.set(); rect.fill(using: .sourceAtop); return true }
    tinted.draw(in: CGRect(x: arrowX - tinted.size.width / 2, y: 37 - tinted.size.height / 2,
                           width: tinted.size.width, height: tinted.size.height))
}

// Popover: shadow, arrow, clipped body, border.
let radius: CGFloat = 40 * scale
let popRect = CGRect(x: popX, y: popY, width: popW, height: popH)
let shape = CGMutablePath()
shape.addRoundedRect(in: popRect, cornerWidth: radius, cornerHeight: radius)
shape.move(to: CGPoint(x: arrowX - 34, y: popY + 1)); shape.addLine(to: CGPoint(x: arrowX, y: popY - 30))
shape.addLine(to: CGPoint(x: arrowX + 34, y: popY + 1)); shape.closeSubpath()
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: 40), blur: 110, color: CGColor(gray: 0, alpha: 0.6))
cg.setFillColor(CGColor(red: 0.184, green: 0.184, blue: 0.184, alpha: 1)); cg.addPath(shape); cg.fillPath()
cg.restoreGState()

func drawCapture(_ image: CGImage, crop: CGRect, into rect: CGRect) {
    guard let part = image.cropping(to: crop) else { return }
    cg.saveGState()
    cg.translateBy(x: rect.minX, y: rect.maxY); cg.scaleBy(x: 1, y: -1)   // CGImage draws bottom-up
    cg.interpolationQuality = .high
    cg.draw(part, in: CGRect(origin: .zero, size: rect.size))
    cg.restoreGState()
}
cg.saveGState()
cg.addPath(CGPath(roundedRect: popRect, cornerWidth: radius, cornerHeight: radius, transform: nil)); cg.clip()
drawCapture(load(args[1]), crop: body.insetBy(dx: 2, dy: 2), into: popRect)
if args.count > 5 {
    let sheet = load(args[5])
    // Dim the popover behind the sheet, as macOS does.
    cg.setFillColor(CGColor(gray: 0, alpha: 0.25)); cg.fill(popRect)
    let sheetRect = CGRect(x: popX, y: popY + (140 - body.minY) * scale,
                           width: CGFloat(sheet.width) * scale, height: CGFloat(sheet.height) * scale)
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: 16), blur: 50, color: CGColor(gray: 0, alpha: 0.5))
    cg.setFillColor(CGColor(gray: 0.12, alpha: 1)); cg.fill(sheetRect)
    cg.restoreGState()
    drawCapture(sheet, crop: CGRect(x: 0, y: 0, width: sheet.width, height: sheet.height), into: sheetRect)
}
cg.restoreGState()
cg.setStrokeColor(CGColor(gray: 1, alpha: 0.14)); cg.setLineWidth(3)
cg.addPath(CGPath(roundedRect: popRect.insetBy(dx: 1.5, dy: 1.5), cornerWidth: radius, cornerHeight: radius, transform: nil))
cg.strokePath()

// Headline and subline, vertically centred on the left.
let textWidth = popX - 200 - 160
let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 8
let headline = NSAttributedString(string: args[3], attributes: [
    .font: NSFont.systemFont(ofSize: 128, weight: .bold), .foregroundColor: NSColor.white, .paragraphStyle: paragraph])
let subline = NSAttributedString(string: args[4], attributes: [
    .font: NSFont.systemFont(ofSize: 60, weight: .regular),
    .foregroundColor: NSColor.white.withAlphaComponent(0.78), .paragraphStyle: paragraph])
let hSize = headline.boundingRect(with: CGSize(width: textWidth, height: 2000), options: [.usesLineFragmentOrigin])
let sSize = subline.boundingRect(with: CGSize(width: textWidth, height: 2000), options: [.usesLineFragmentOrigin])
let top = (CGFloat(H) + barHeight - hSize.height - 56 - sSize.height) / 2
headline.draw(with: CGRect(x: 200, y: top, width: textWidth, height: hSize.height), options: [.usesLineFragmentOrigin])
subline.draw(with: CGRect(x: 200, y: top + hSize.height + 56, width: textWidth, height: sSize.height), options: [.usesLineFragmentOrigin])

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
print("wrote \(args[2]) \(rep.pixelsWide)x\(rep.pixelsHigh)")
