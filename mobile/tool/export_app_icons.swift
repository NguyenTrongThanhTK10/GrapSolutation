// Run from the repository root:
// swift -module-cache-path /private/tmp/grap-icon-module-cache mobile/tool/export_app_icons.swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let output = root.appendingPathComponent("docs/design/app-icons/v1")
let files = FileManager.default
let colorSpace = CGColorSpaceCreateDeviceRGB()

struct IconDesign {
    let role: String
    let app: String
    let title: String
    let subtitle: String
    let rgb: [CGFloat]
    var color: CGColor {
        CGColor(colorSpace: colorSpace, components: rgb + [1])!
    }
}

let designs = [
    IconDesign(role: "customer", app: "customer_app", title: "Grap Customer",
               subtitle: "Khách hàng · Định vị & hướng đi", rgb: [8/255, 127/255, 80/255]),
    IconDesign(role: "driver", app: "driver_app", title: "Grap Driver",
               subtitle: "Tài xế · Vô lăng & hướng đi", rgb: [23/255, 44/255, 36/255])
]

func render(_ width: Int, _ height: Int? = nil, opaque: Bool = true,
            paint: (CGContext) -> Void) -> CGImage {
    let alpha = opaque ? CGImageAlphaInfo.noneSkipLast : .premultipliedLast
    let context = CGContext(data: nil, width: width, height: height ?? width,
                            bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: colorSpace,
                            bitmapInfo: alpha.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
    context.interpolationQuality = .high
    paint(context)
    return context.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) throws {
    try files.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let bitmap = NSBitmapImageRep(cgImage: image)
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}

// Convert the two-color source to the alpha-only white artwork needed by
// adaptive/themed icons, removing the generated background and color variation.
// Geometry is preserved; output colors and padding are set by the export format.
func loadArtwork(_ url: URL) throws -> CGImage {
    let source = NSImage(contentsOf: url)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    let width = source.width, height = source.height
    let sample = render(width, height, opaque: false) {
        $0.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    let sampleData = sample.dataProvider!.data!
    let bytes = CFDataGetBytePtr(sampleData)!
    var mask = [UInt8](repeating: 0, count: width * height * 4)
    var minX = width, minY = height, maxX = 0, maxY = 0
    for y in 0..<height {
        for x in 0..<width {
            let sourceIndex = y * sample.bytesPerRow + x * 4
            let minimum = min(bytes[sourceIndex], bytes[sourceIndex + 1], bytes[sourceIndex + 2])
            let alpha = UInt8(max(0, min(255, (Double(minimum) - 80) * 255 / 165)))
            let index = (y * width + x) * 4
            mask[index] = alpha
            mask[index + 1] = alpha
            mask[index + 2] = alpha
            mask[index + 3] = alpha
            if alpha > 12 {
                minX = min(minX, x); minY = min(minY, y)
                maxX = max(maxX, x); maxY = max(maxY, y)
            }
        }
    }
    precondition(minX < maxX && minY < maxY, "Source must contain a white emblem")
    let provider = CGDataProvider(data: Data(mask) as CFData)!
    let image = CGImage(width: width, height: height, bitsPerComponent: 8,
                        bitsPerPixel: 32, bytesPerRow: width * 4, space: colorSpace,
                        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                        provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    return image.cropping(to: CGRect(x: minX, y: minY,
                                    width: maxX - minX + 1, height: maxY - minY + 1))!
}

func paintArtwork(_ image: CGImage, context: CGContext, size: CGFloat, fraction: CGFloat) {
    let scale = size * fraction / CGFloat(max(image.width, image.height))
    let width = CGFloat(image.width) * scale, height = CGFloat(image.height) * scale
    context.draw(image, in: CGRect(x: (size - width) / 2, y: (size - height) / 2,
                                  width: width, height: height))
}

func icon(_ artwork: CGImage, design: IconDesign, size: Int,
          foreground: Bool = false, legacy: Bool = false) -> CGImage {
    render(size, opaque: !foreground && !legacy) { context in
        let side = CGFloat(size)
        if legacy {
            context.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: side, height: side),
                                   cornerWidth: side * 0.225, cornerHeight: side * 0.225,
                                   transform: nil))
            context.clip()
        }
        if !foreground {
            context.setFillColor(design.color)
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        }
        // 58% of 108dp = 62.64dp, inside Android's central 66dp safe zone.
        paintArtwork(artwork, context: context, size: side, fraction: foreground ? 0.58 : 0.68)
    }
}

func writeText(_ value: String, at point: CGPoint, size: CGFloat,
               color: NSColor, weight: NSFont.Weight = .regular) {
    (value as NSString).draw(at: point, withAttributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color
    ])
}

var artworks = [CGImage]()
for design in designs {
    let artwork = try loadArtwork(output.appendingPathComponent("\(design.role)-source.png"))
    artworks.append(artwork)
    try writePNG(icon(artwork, design: design, size: 1024),
                 to: output.appendingPathComponent("\(design.role)-app-icon.png"))
    try writePNG(icon(artwork, design: design, size: 512),
                 to: output.appendingPathComponent("\(design.role)-play-store.png"))
    try writePNG(icon(artwork, design: design, size: 1024, foreground: true),
                 to: output.appendingPathComponent("\(design.role)-foreground.png"))

    let app = root.appendingPathComponent("mobile/apps/\(design.app)")
    let assets = app.appendingPathComponent("ios/Runner/Assets.xcassets")
    let originalContents = assets.appendingPathComponent("AppIcon.appiconset/Contents.json")
    let contentsData = try Data(contentsOf: originalContents)
    let contents = try JSONSerialization.jsonObject(with: contentsData) as! [String: Any]
    let catalog = assets.appendingPathComponent("GrapIcon.appiconset")
    var exported = Set<String>()
    for entry in contents["images"] as! [[String: String]] {
        let name = entry["filename"]!
        if exported.contains(name) { continue }
        exported.insert(name)
        let points = Double(entry["size"]!.split(separator: "x")[0])!
        let scale = Double(entry["scale"]!.replacingOccurrences(of: "x", with: ""))!
        try writePNG(icon(artwork, design: design, size: Int(points * scale)),
                     to: catalog.appendingPathComponent(name))
    }
    try contentsData.write(to: catalog.appendingPathComponent("Contents.json"))

    let res = app.appendingPathComponent("android/app/src/main/res")
    for (density, size) in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)] {
        try writePNG(icon(artwork, design: design, size: size, legacy: true),
                     to: res.appendingPathComponent("mipmap-\(density)/ic_launcher_grap.png"))
    }
    try writePNG(icon(artwork, design: design, size: 432, foreground: true),
                 to: res.appendingPathComponent("drawable-nodpi/ic_grap_foreground.png"))
    print("\(design.app): exported master/store/foreground, \(exported.count) iOS and 6 Android PNGs")
}

let preview = render(1600, 1000) { context in
    context.setFillColor(CGColor(colorSpace: colorSpace, components: [0.96, 0.97, 0.95, 1])!)
    context.fill(CGRect(x: 0, y: 0, width: 1600, height: 1000))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    writeText("Grap / App icons", at: CGPoint(x: 100, y: 880), size: 48,
              color: NSColor(srgbRed: 23/255, green: 44/255, blue: 36/255, alpha: 1), weight: .bold)
    writeText("Customer & Driver · Android / iOS", at: CGPoint(x: 102, y: 832), size: 24,
              color: .secondaryLabelColor)
    for (index, design) in designs.enumerated() {
        let x = CGFloat(280 + index * 760)
        let master = icon(artworks[index], design: design, size: 1024)
        context.saveGState()
        context.addPath(CGPath(roundedRect: CGRect(x: x, y: 470, width: 280, height: 280),
                               cornerWidth: 64, cornerHeight: 64, transform: nil))
        context.clip()
        context.draw(master, in: CGRect(x: x, y: 470, width: 280, height: 280))
        context.restoreGState()
        writeText(design.title, at: CGPoint(x: x - 6, y: 400), size: 36,
                  color: .labelColor, weight: .semibold)
        writeText(design.subtitle, at: CGPoint(x: x - 6, y: 352), size: 24,
                  color: .secondaryLabelColor)
        for (offset, side) in [48, 72, 96].enumerated() {
            let rect = CGRect(x: x - 2 + CGFloat(offset) * 104, y: 175,
                              width: CGFloat(side), height: CGFloat(side))
            context.saveGState()
            context.addEllipse(in: rect)
            context.clip()
            context.draw(master, in: rect)
            context.restoreGState()
        }
        writeText("48 / 72 / 96 px", at: CGPoint(x: x - 2, y: 125), size: 21,
                  color: .secondaryLabelColor)
    }
    NSGraphicsContext.restoreGraphicsState()
}
try writePNG(preview, to: output.appendingPathComponent("preview.png"))
print("Preview: docs/design/app-icons/v1/preview.png")
