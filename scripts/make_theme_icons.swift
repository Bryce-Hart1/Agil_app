#!/usr/bin/env swift
// CLAUDE  Date 09/03/2026
// Builds the themed app-icon assets from the Agil_logo_*_v2 source art: each render is
// drawn aspect-fit on a 1024x1024 OPAQUE near-black canvas and written into an
// .appiconset (app icons must be square with no alpha; the sources are neither).
// Side effect: OVERWRITES AppIcon.appiconset/icon-1024.png and the five AppIcon-*
// sets. Re-run with `swift scripts/make_theme_icons.swift` whenever the art changes.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// CLAUDE  Date 09/03/2026
// The ground the six icons share. Sampled from the corner of the five full-bleed
// renders (#06070D…#110F14) — only classic_v2 actually paints with it, since it ships
// transparent, but keeping it in the family's range is what makes the set look like one set.
let canvasSize = 1024
let background = (r: 0x0D, g: 0x0D, b: 0x10)

// source imageset name -> destination appiconset name.
// Classic has no alternate: it IS the primary icon (see ThemeIcon.swift).
let mapping: [(source: String, destination: String)] = [
    ("Agil_logo_classic_v2",  "AppIcon"),
    ("Agil_logo_midnight_v2", "AppIcon-Midnight"),
    ("Agil_logo_deep_sea_v2", "AppIcon-DeepSea"),
    ("Agil_logo_sunset_v2",   "AppIcon-Sunset"),
    ("Agil_logo_leaf_v2",     "AppIcon-Leaf"),
    ("Agil_logo_woods_v2",    "AppIcon-Woods"),
]

let catalog = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("GymApp/Resources/Assets.xcassets")

let contentsJSON = """
{
  "images" : [
    {
      "filename" : "icon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

"""

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

for entry in mapping {
    let sourceURL = catalog
        .appendingPathComponent("\(entry.source).imageset")
        .appendingPathComponent("\(entry.source).png")
    guard let provider = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(provider, 0, nil) else {
        fail("could not read \(sourceURL.path)")
    }

    // No alpha in the context: the canvas is the opaque background, and anything the
    // source leaves transparent (classic_v2) resolves onto it rather than to black-with-alpha.
    guard let ctx = CGContext(data: nil, width: canvasSize, height: canvasSize,
                              bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        fail("could not create canvas for \(entry.destination)")
    }
    ctx.interpolationQuality = .high
    ctx.setFillColor(red: CGFloat(background.r) / 255, green: CGFloat(background.g) / 255,
                     blue: CGFloat(background.b) / 255, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))

    // Aspect-fit, centred. Square sources fill the canvas exactly, so the five full-bleed
    // renders are a plain downscale and only classic_v2 gets letterboxed.
    let scale = min(CGFloat(canvasSize) / CGFloat(image.width), CGFloat(canvasSize) / CGFloat(image.height))
    let width = CGFloat(image.width) * scale
    let height = CGFloat(image.height) * scale
    ctx.draw(image, in: CGRect(x: (CGFloat(canvasSize) - width) / 2,
                               y: (CGFloat(canvasSize) - height) / 2,
                               width: width, height: height))

    guard let output = ctx.makeImage() else { fail("could not render \(entry.destination)") }

    let setURL = catalog.appendingPathComponent("\(entry.destination).appiconset")
    try? FileManager.default.createDirectory(at: setURL, withIntermediateDirectories: true)
    let pngURL = setURL.appendingPathComponent("icon-1024.png")
    guard let dest = CGImageDestinationCreateWithURL(pngURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fail("could not write \(pngURL.path)")
    }
    CGImageDestinationAddImage(dest, output, nil)
    guard CGImageDestinationFinalize(dest) else { fail("could not finalize \(pngURL.path)") }

    try? contentsJSON.write(to: setURL.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    print("✓ \(entry.destination).appiconset  ←  \(entry.source) (\(image.width)×\(image.height))")
}
