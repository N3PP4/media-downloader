import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: generate-icon.swift /path/to/AppIcon.iconset\n", stderr)
    exit(2)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let outputs: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

func drawIcon(size: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [.alphaFirst],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "IconGenerator", code: 1)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext
    let context = graphicsContext.cgContext
    let scale = CGFloat(size) / 1024
    context.scaleBy(x: scale, y: scale)
    context.setShouldAntialias(true)
    context.setAllowsAntialiasing(true)

    let outerRect = CGRect(x: 52, y: 52, width: 920, height: 920)
    let outerPath = CGPath(
        roundedRect: outerRect,
        cornerWidth: 210,
        cornerHeight: 210,
        transform: nil
    )
    context.saveGState()
    context.addPath(outerPath)
    context.clip()
    let colors = [
        NSColor(calibratedRed: 0.35, green: 0.40, blue: 1.0, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.20, green: 0.47, blue: 0.96, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.08, green: 0.72, blue: 0.65, alpha: 1).cgColor
    ] as CFArray
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors,
        locations: [0, 0.52, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 120, y: 930),
        end: CGPoint(x: 900, y: 90),
        options: []
    )
    context.restoreGState()

    context.setFillColor(NSColor.white.withAlphaComponent(0.12).cgColor)
    context.fillEllipse(in: CGRect(x: 202, y: 202, width: 620, height: 620))

    context.setShadow(offset: CGSize(width: 0, height: -22), blur: 24, color: NSColor.black.withAlphaComponent(0.25).cgColor)
    context.setFillColor(NSColor.white.cgColor)
    context.addPath(CGPath(roundedRect: CGRect(x: 434, y: 396, width: 156, height: 390), cornerWidth: 78, cornerHeight: 78, transform: nil))
    context.fillPath()

    let arrow = CGMutablePath()
    arrow.move(to: CGPoint(x: 306, y: 582))
    arrow.addLine(to: CGPoint(x: 718, y: 582))
    arrow.addCurve(
        to: CGPoint(x: 748, y: 509),
        control1: CGPoint(x: 756, y: 582),
        control2: CGPoint(x: 775, y: 536)
    )
    arrow.addLine(to: CGPoint(x: 542, y: 303))
    arrow.addCurve(
        to: CGPoint(x: 482, y: 303),
        control1: CGPoint(x: 525, y: 286),
        control2: CGPoint(x: 499, y: 286)
    )
    arrow.addLine(to: CGPoint(x: 276, y: 509))
    arrow.addCurve(
        to: CGPoint(x: 306, y: 582),
        control1: CGPoint(x: 249, y: 536),
        control2: CGPoint(x: 268, y: 582)
    )
    arrow.closeSubpath()
    context.addPath(arrow)
    context.fillPath()

    context.addPath(CGPath(roundedRect: CGRect(x: 268, y: 172, width: 488, height: 92), cornerWidth: 46, cornerHeight: 46, transform: nil))
    context.fillPath()

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGenerator", code: 2)
    }
    return png
}

for (size, filename) in outputs {
    let data = try drawIcon(size: size)
    try data.write(to: outputDirectory.appendingPathComponent(filename), options: .atomic)
}
