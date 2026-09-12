#!/usr/bin/env swift

// Exports Apple app-icon resources from the user-approved transparent PNG.
// The white appearance is derived by replacing RGB only; the source alpha and
// geometry stay unchanged. Run from the repository root.

import AppKit
import Foundation
import ImageIO

private let fileManager = FileManager.default
private let root = URL(fileURLWithPath: fileManager.currentDirectoryPath)
private let sourceURL = root.appendingPathComponent("Design/AppIcon/Source/mpgu-building-approved.png")
private let canvasSize = 1024
private let artworkScale: CGFloat = 0.82
private let brandBlue = (r: UInt8(31), g: UInt8(119), b: UInt8(180)) // #1F77B4

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

private func loadImage(_ url: URL) -> CGImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { fail("unable to read \(url.path)") }
    guard image.alphaInfo != .none && image.alphaInfo != .noneSkipFirst && image.alphaInfo != .noneSkipLast else {
        fail("approved source must contain transparency")
    }
    return image
}

private func bitmapContext(size: Int, opaque: Bool = false) -> (CGContext, UnsafeMutableRawPointer) {
    let byteCount = size * size * 4
    guard let data = calloc(byteCount, 1) else { fail("unable to allocate bitmap") }
    guard let context = CGContext(
        data: data,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: opaque
            ? CGImageAlphaInfo.noneSkipLast.rawValue
            : CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        free(data)
        fail("unable to create bitmap context")
    }
    return (context, data)
}

private func renderApprovedLayer(_ source: CGImage) -> (image: CGImage, pixels: [UInt8]) {
    let (context, allocation) = bitmapContext(size: canvasSize)
    defer { free(allocation) }

    let scale = CGFloat(canvasSize) / CGFloat(max(source.width, source.height)) * artworkScale
    let width = CGFloat(source.width) * scale
    let height = CGFloat(source.height) * scale
    context.interpolationQuality = .high
    context.draw(source, in: CGRect(
        x: (CGFloat(canvasSize) - width) / 2,
        y: (CGFloat(canvasSize) - height) / 2,
        width: width,
        height: height
    ))

    guard let image = context.makeImage() else { fail("unable to render approved layer") }
    let bytes = Array(UnsafeBufferPointer(
        start: allocation.assumingMemoryBound(to: UInt8.self),
        count: canvasSize * canvasSize * 4
    ))
    return (image, bytes)
}

private func solidColorVariant(
    from premultipliedPixels: [UInt8],
    color: (r: UInt8, g: UInt8, b: UInt8)
) -> CGImage {
    var pixels = premultipliedPixels
    for index in stride(from: 0, to: pixels.count, by: 4) {
        let alpha = pixels[index + 3]
        pixels[index] = UInt8((UInt16(color.r) * UInt16(alpha) + 127) / 255)
        pixels[index + 1] = UInt8((UInt16(color.g) * UInt16(alpha) + 127) / 255)
        pixels[index + 2] = UInt8((UInt16(color.b) * UInt16(alpha) + 127) / 255)
    }
    return pixels.withUnsafeMutableBytes { buffer in
        guard let context = CGContext(
            data: buffer.baseAddress,
            width: canvasSize,
            height: canvasSize,
            bitsPerComponent: 8,
            bytesPerRow: canvasSize * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = context.makeImage() else { fail("unable to create solid-colour variant") }
        return image
    }
}

private func compileMacAssetsCar(from iconPackage: URL, to destination: URL) {
    let developerDirectory = URL(fileURLWithPath: "/Applications/Xcode.app/Contents/Developer")
    let actoolURL = developerDirectory.appendingPathComponent("usr/bin/actool")
    guard fileManager.isExecutableFile(atPath: actoolURL.path) else {
        fail("Xcode 26 or newer is required to compile the layered macOS icon")
    }

    let workDirectory = fileManager.temporaryDirectory
        .appendingPathComponent("MyMPSU-AssetsCar-\(UUID().uuidString)")
    let outputDirectory = workDirectory.appendingPathComponent("out")
    do {
        try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    } catch { fail("unable to create actool output directory: \(error)") }
    defer { try? fileManager.removeItem(at: workDirectory) }

    let actool = Process()
    actool.executableURL = actoolURL
    actool.environment = ProcessInfo.processInfo.environment.merging([
        "DEVELOPER_DIR": developerDirectory.path,
    ]) { _, configured in configured }
    actool.arguments = [
        iconPackage.path,
        "--compile", outputDirectory.path,
        "--output-format", "human-readable-text",
        "--notices", "--warnings",
        "--output-partial-info-plist", outputDirectory.appendingPathComponent("assetcatalog_generated_info.plist").path,
        "--app-icon", "Icon",
        "--include-all-app-icons",
        "--accent-color", "AccentColor",
        "--enable-on-demand-resources", "NO",
        "--development-region", "en",
        "--target-device", "mac",
        "--minimum-deployment-target", "26.0",
        "--platform", "macosx",
    ]

    do {
        try actool.run()
        actool.waitUntilExit()
    } catch { fail("unable to launch actool: \(error)") }
    guard actool.terminationStatus == 0 else { fail("actool failed with status \(actool.terminationStatus)") }

    let compiled = outputDirectory.appendingPathComponent("Assets.car")
    do {
        try Data(contentsOf: compiled).write(to: destination, options: .atomic)
    } catch { fail("unable to save precompiled Assets.car: \(error)") }
}

private func composeIcon(layer: CGImage, background: NSColor, rounded: Bool) -> CGImage {
    let (context, allocation) = bitmapContext(size: canvasSize, opaque: !rounded)
    defer { free(allocation) }
    let rect = CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize)

    context.setFillColor(background.cgColor)
    if rounded {
        context.addPath(CGPath(
            roundedRect: rect.insetBy(dx: 28, dy: 28),
            cornerWidth: 220,
            cornerHeight: 220,
            transform: nil
        ))
        context.fillPath()
    } else {
        context.fill(rect)
    }
    context.draw(layer, in: rect)
    return context.makeImage()!
}

private func resize(_ image: CGImage, to size: Int) -> CGImage {
    let (context, allocation) = bitmapContext(size: size)
    defer { free(allocation) }
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    return context.makeImage()!
}

private func writePNG(_ image: CGImage, to url: URL) {
    do {
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    } catch { fail("unable to create \(url.deletingLastPathComponent().path): \(error)") }

    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        fail("unable to create PNG destination \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fail("unable to write \(url.path)") }
}

private let source = loadImage(sourceURL)
private let approved = renderApprovedLayer(source)
private let blueLayer = solidColorVariant(from: approved.pixels, color: brandBlue)
private let whiteLayer = solidColorVariant(from: approved.pixels, color: (255, 255, 255))
private let lightBackground = NSColor(srgbRed: 0.925, green: 0.961, blue: 1, alpha: 1)
private let darkBackground = NSColor(srgbRed: 0.025, green: 0.090, blue: 0.180, alpha: 1)

private let lightIcon = composeIcon(layer: blueLayer, background: lightBackground, rounded: false)
private let darkIcon = composeIcon(layer: whiteLayer, background: darkBackground, rounded: false)
private let macFallback = composeIcon(layer: blueLayer, background: lightBackground, rounded: true)

private let designDirectory = root.appendingPathComponent("Design/AppIcon")
writePNG(blueLayer, to: designDirectory.appendingPathComponent("Layers/building-blue.png"))
writePNG(whiteLayer, to: designDirectory.appendingPathComponent("Layers/building-white.png"))
writePNG(lightIcon, to: designDirectory.appendingPathComponent("Previews/light.png"))
writePNG(darkIcon, to: designDirectory.appendingPathComponent("Previews/dark.png"))

for iconPackage in [
    root.appendingPathComponent("iOS/MyMPSU/AppIcon.icon"),
    root.appendingPathComponent("Desktop/src-tauri/icons/AppIcon.icon"),
] {
    writePNG(blueLayer, to: iconPackage.appendingPathComponent("Assets/building-blue.png"))
    writePNG(whiteLayer, to: iconPackage.appendingPathComponent("Assets/building-white.png"))
}

compileMacAssetsCar(
    from: root.appendingPathComponent("Desktop/src-tauri/icons/AppIcon.icon"),
    to: root.appendingPathComponent("Desktop/src-tauri/icons/Assets.car")
)

private let appIconSet = root.appendingPathComponent("iOS/MyMPSU/Assets.xcassets/AppIcon.appiconset")
writePNG(lightIcon, to: appIconSet.appendingPathComponent("AppIcon-Light-1024.png"))
writePNG(darkIcon, to: appIconSet.appendingPathComponent("AppIcon-Dark-1024.png"))
writePNG(whiteLayer, to: appIconSet.appendingPathComponent("AppIcon-Tinted-1024.png"))

private let desktopIcons = root.appendingPathComponent("Desktop/src-tauri/icons")
writePNG(resize(macFallback, to: 32), to: desktopIcons.appendingPathComponent("32x32.png"))
writePNG(resize(macFallback, to: 128), to: desktopIcons.appendingPathComponent("128x128.png"))
writePNG(resize(macFallback, to: 256), to: desktopIcons.appendingPathComponent("128x128@2x.png"))
writePNG(macFallback, to: desktopIcons.appendingPathComponent("icon.png"))

private let iconset = fileManager.temporaryDirectory
    .appendingPathComponent("MyMPSU-AppIcon-\(UUID().uuidString).iconset")
defer { try? fileManager.removeItem(at: iconset) }
for (name, size) in [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
] {
    writePNG(resize(macFallback, to: size), to: iconset.appendingPathComponent(name))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", desktopIcons.appendingPathComponent("icon.icns").path]
do {
    try iconutil.run()
    iconutil.waitUntilExit()
} catch { fail("unable to launch iconutil: \(error)") }
guard iconutil.terminationStatus == 0 else { fail("iconutil failed with status \(iconutil.terminationStatus)") }

print("Exported approved blue layer, alpha-identical white layer, and Apple fallback icons.")
