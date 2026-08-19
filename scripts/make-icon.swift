// Draws the app icon and writes the .iconset that iconutil turns into an .icns.
// The design lives in code so it stays editable without Xcode's Icon Composer.

import AppKit

// MARK: - Color

/// Converts OKLCh to an sRGB color, so the palette below can be written in OKLCh directly.
/// - Parameters:
///   - lightness: Lightness, 0 through 1.
///   - chroma: Chroma. Zero is achromatic.
///   - hue: Hue in degrees.
func oklch(_ lightness: Double, _ chroma: Double, _ hue: Double) -> NSColor {
    let radians = hue * .pi / 180
    let a = chroma * cos(radians)
    let b = chroma * sin(radians)

    let lRoot = lightness + 0.3963377774 * a + 0.2158037573 * b
    let mRoot = lightness - 0.1055613458 * a - 0.0638541728 * b
    let sRoot = lightness - 0.0894841775 * a - 1.2914855480 * b

    let l = lRoot * lRoot * lRoot
    let m = mRoot * mRoot * mRoot
    let s = sRoot * sRoot * sRoot

    let red = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    let green = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    let blue = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

    /// Gamma-encodes a linear component and clamps it to 0 through 1.
    func encode(_ value: Double) -> CGFloat {
        let clamped = min(max(value, 0), 1)
        let encoded = clamped <= 0.0031308
            ? 12.92 * clamped
            : 1.055 * pow(clamped, 1 / 2.4) - 0.055
        return CGFloat(min(max(encoded, 0), 1))
    }

    return NSColor(srgbRed: encode(red), green: encode(green), blue: encode(blue), alpha: 1)
}

/// One color scheme for the icon.
struct Palette {
    let backgroundTop: NSColor
    let backgroundBottom: NSColor
    let glyph: NSColor
}

enum Variant: String {
    /// White glyph on a deep indigo ground.
    case dark
    /// Navy glyph on a light ground.
    case light

    var palette: Palette {
        switch self {
        case .dark:
            return Palette(
                backgroundTop: oklch(0.44, 0.078, 264),
                backgroundBottom: oklch(0.24, 0.055, 264),
                glyph: oklch(0.98, 0.004, 264)
            )
        case .light:
            return Palette(
                backgroundTop: oklch(0.97, 0.006, 264),
                backgroundBottom: oklch(0.86, 0.016, 264),
                glyph: oklch(0.33, 0.070, 264)
            )
        }
    }
}

// MARK: - Drawing

/// The side of the reference canvas. Every output size is scaled down from this.
let canvas: CGFloat = 1024
/// macOS icons leave a margin on all four sides and sit in a rounded square.
let bodyInset: CGFloat = 100
let cornerRadius: CGFloat = 185

/// Builds lucide's monitor-off in its native 24×24 coordinate space, notch included.
/// The notch has to let the background through, so the glyph is drawn on its own layer
/// and composited afterwards.
func makeGlyph(color: NSColor) -> CGImage? {
    let side = Int(canvas)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: rep)?.cgContext else { return nil }

    let glyphWidth: CGFloat = 540
    let scale = glyphWidth / 24
    let offset = (canvas - glyphWidth) / 2

    context.translateBy(x: offset, y: offset)
    context.scaleBy(x: scale, y: scale)
    // lucide uses a top-left origin, so flip the axis and write its coordinates verbatim.
    context.translateBy(x: 0, y: 24)
    context.scaleBy(x: 1, y: -1)

    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setStrokeColor(color.cgColor)

    let stroke: CGFloat = 2.1

    let screen = CGPath(
        roundedRect: CGRect(x: 2, y: 3, width: 20, height: 14),
        cornerWidth: 2.4, cornerHeight: 2.4, transform: nil
    )
    let stand = CGMutablePath()
    stand.move(to: CGPoint(x: 12, y: 17))
    stand.addLine(to: CGPoint(x: 12, y: 20.6))
    stand.move(to: CGPoint(x: 8, y: 20.6))
    stand.addLine(to: CGPoint(x: 16, y: 20.6))

    context.setLineWidth(stroke)
    context.addPath(screen)
    context.addPath(stand)
    context.strokePath()

    let slash = CGMutablePath()
    slash.move(to: CGPoint(x: 3.2, y: 3.2))
    slash.addLine(to: CGPoint(x: 20.8, y: 20.8))

    // Carve out the path of the slash first, leaving a gap on either side of it.
    // This is how lucide draws its *-off variants.
    context.setBlendMode(.destinationOut)
    context.setLineWidth(stroke * 2.6)
    context.addPath(slash)
    context.strokePath()

    context.setBlendMode(.normal)
    context.setLineWidth(stroke)
    context.addPath(slash)
    context.strokePath()

    return context.makeImage()
}

/// Renders one icon at the given size and returns PNG data.
func render(size: CGFloat, variant: Variant) -> Data? {
    let side = Int(size)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: rep)?.cgContext else { return nil }

    context.scaleBy(x: size / canvas, y: size / canvas)
    context.interpolationQuality = .high

    let palette = variant.palette
    let body = CGRect(
        x: bodyInset, y: bodyInset,
        width: canvas - bodyInset * 2, height: canvas - bodyInset * 2
    )
    let shape = CGPath(
        roundedRect: body, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil
    )

    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -14), blur: 34,
        color: NSColor.black.withAlphaComponent(0.30).cgColor
    )
    context.addPath(shape)
    context.setFillColor(NSColor.black.cgColor)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(shape)
    context.clip()
    if let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [palette.backgroundTop.cgColor, palette.backgroundBottom.cgColor] as CFArray,
        locations: [0, 1]
    ) {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: canvas), end: CGPoint(x: 0, y: 0), options: []
        )
    }
    context.restoreGState()

    if let glyph = makeGlyph(color: palette.glyph) {
        context.draw(glyph, in: CGRect(x: 0, y: 0, width: canvas, height: canvas))
    }

    return rep.representation(using: .png, properties: [:])
}

// MARK: - Output

guard CommandLine.arguments.count >= 3,
      let variant = Variant(rawValue: CommandLine.arguments[1]) else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <dark|light> <output.iconset>\n".utf8))
    exit(64)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[2])
try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

/// The file names and pixel sizes iconutil expects to find in an .iconset.
let entries: [(name: String, pixels: CGFloat)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

for entry in entries {
    guard let data = render(size: entry.pixels, variant: variant) else {
        FileHandle.standardError.write(Data("failed to render \(entry.name)\n".utf8))
        exit(1)
    }
    try data.write(to: outputDirectory.appendingPathComponent(entry.name))
}

print("wrote \(entries.count) images to \(outputDirectory.path)")
