// Export the supplied MPGU artwork without redrawing or distorting it.
// Run from the repository root: swift scripts/export-brand-assets.swift
import AppKit
import Foundation
import ImageIO

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = root.appendingPathComponent("20121118132132!Mpgu_logo.jpg")
guard let logo = NSImage(contentsOf: source) else { fatalError("Missing MPGU logo") }
let fm = FileManager.default
func export(_ path: String, size: Int, inset: CGFloat = 0.09) throws {
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
        bytesPerRow: size * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    NSColor.white.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()
    let available = CGFloat(size) * (1 - 2 * inset)
    let factor = available / max(logo.size.width, logo.size.height)
    let w = logo.size.width * factor, h = logo.size.height * factor
    logo.draw(in: NSRect(x: (CGFloat(size)-w)/2, y: (CGFloat(size)-h)/2, width: w, height: h),
              from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    let url = root.appendingPathComponent(path)
    try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("PNG export failed") }
}
let appleExporter = Process()
appleExporter.executableURL = root.appendingPathComponent("scripts/export-apple-app-icons.swift")
appleExporter.currentDirectoryURL = root
try appleExporter.run()
appleExporter.waitUntilExit()
guard appleExporter.terminationStatus == 0 else { fatalError("Apple icon export failed") }
let res = "Android/app/src/main/res"
for (density, scale) in [("mdpi", 1.0), ("hdpi", 1.5), ("xhdpi", 2.0), ("xxhdpi", 3.0), ("xxxhdpi", 4.0)] {
    for name in ["ic_launcher", "ic_launcher_round", "ic_launcher_foreground"] {
        let foreground = name == "ic_launcher_foreground"
        let path = "\(res)/mipmap-\(density)/\(name)"
        try export(path + ".png", size: Int((foreground ? 108 : 48) * scale), inset: foreground ? 0.23 : 0.09)
        let legacy = root.appendingPathComponent(path + ".webp")
        if fm.fileExists(atPath: legacy.path) { try fm.removeItem(at: legacy) }
    }
}
try export("Android/app/src/main/ic_launcher-playstore.png", size: 512)
try export("Web/mympsu.moonbaystudio.ru/img/logo.png", size: 512)
try export("Web/mympsu.moonbaystudio.ru/img/favicon.png", size: 256)
let favicon = try Data(contentsOf: root.appendingPathComponent("Web/mympsu.moonbaystudio.ru/img/favicon.png"))
var ico = Data([0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 24, 0])
for value in [UInt32(favicon.count), UInt32(22)] {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { ico.append(contentsOf: $0) }
}
ico.append(favicon)
try ico.write(to: root.appendingPathComponent("Web/mympsu.moonbaystudio.ru/favicon.ico"))
print("Exported MPGU icons for Apple platforms, Android and Web.")
