#!/usr/bin/env swift

import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "KeyClip.app/Contents/Resources/AppIcon.icns"
let outputURL = URL(fileURLWithPath: outputPath)
let fileManager = FileManager.default

try fileManager.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

struct IconChunk {
    let type: String
    let pixels: Int
}

let chunks = [
    IconChunk(type: "icp4", pixels: 16),
    IconChunk(type: "icp5", pixels: 32),
    IconChunk(type: "icp6", pixels: 64),
    IconChunk(type: "ic07", pixels: 128),
    IconChunk(type: "ic08", pixels: 256),
    IconChunk(type: "ic09", pixels: 512),
    IconChunk(type: "ic10", pixels: 1024)
]

func roundedRect(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func oval(_ rect: CGRect) -> NSBezierPath {
    NSBezierPath(ovalIn: rect)
}

func color(_ hex: Int, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

func drawIcon(size: Int) throws -> Data {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "KeyClipIcon", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Could not create bitmap representation."
        ])
    }

    rep.size = NSSize(width: size, height: size)

    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        throw NSError(domain: "KeyClipIcon", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Could not create graphics context."
        ])
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.clear(CGRect(x: 0, y: 0, width: size, height: size))
    context.cgContext.setShouldAntialias(true)

    let s = CGFloat(size)
    let canvas = CGRect(x: 0, y: 0, width: s, height: s)
    let background = canvas.insetBy(dx: s * 0.055, dy: s * 0.055)
    let bgPath = roundedRect(background, radius: s * 0.225)
    let backgroundGradient = NSGradient(colors: [
        color(0xFAFBFC),
        color(0xD6ECF8),
        color(0xFFF3C0)
    ])
    backgroundGradient?.draw(in: bgPath, angle: 38)

    color(0xE2EAF0, alpha: 0.22).setFill()
    roundedRect(background.insetBy(dx: s * 0.026, dy: s * 0.026), radius: s * 0.19).fill()

    let cloudPath = NSBezierPath()
    cloudPath.move(to: CGPoint(x: s * 0.22, y: s * 0.69))
    cloudPath.curve(
        to: CGPoint(x: s * 0.11, y: s * 0.58),
        controlPoint1: CGPoint(x: s * 0.16, y: s * 0.69),
        controlPoint2: CGPoint(x: s * 0.11, y: s * 0.65)
    )
    cloudPath.curve(
        to: CGPoint(x: s * 0.20, y: s * 0.48),
        controlPoint1: CGPoint(x: s * 0.11, y: s * 0.52),
        controlPoint2: CGPoint(x: s * 0.15, y: s * 0.49)
    )
    cloudPath.line(to: CGPoint(x: s * 0.46, y: s * 0.48))
    cloudPath.curve(
        to: CGPoint(x: s * 0.58, y: s * 0.60),
        controlPoint1: CGPoint(x: s * 0.53, y: s * 0.48),
        controlPoint2: CGPoint(x: s * 0.58, y: s * 0.53)
    )
    cloudPath.curve(
        to: CGPoint(x: s * 0.45, y: s * 0.72),
        controlPoint1: CGPoint(x: s * 0.58, y: s * 0.67),
        controlPoint2: CGPoint(x: s * 0.52, y: s * 0.72)
    )
    cloudPath.curve(
        to: CGPoint(x: s * 0.34, y: s * 0.67),
        controlPoint1: CGPoint(x: s * 0.40, y: s * 0.72),
        controlPoint2: CGPoint(x: s * 0.37, y: s * 0.70)
    )
    cloudPath.curve(
        to: CGPoint(x: s * 0.22, y: s * 0.69),
        controlPoint1: CGPoint(x: s * 0.31, y: s * 0.69),
        controlPoint2: CGPoint(x: s * 0.27, y: s * 0.69)
    )
    color(0xB8D8F0, alpha: 0.58).setFill()
    cloudPath.fill()

    color(0xFFF3C0, alpha: 0.92).setFill()
    oval(CGRect(x: s * 0.68, y: s * 0.65, width: s * 0.19, height: s * 0.19)).fill()

    let lotusPath = NSBezierPath()
    lotusPath.move(to: CGPoint(x: s * 0.13, y: s * 0.29))
    lotusPath.curve(
        to: CGPoint(x: s * 0.42, y: s * 0.17),
        controlPoint1: CGPoint(x: s * 0.22, y: s * 0.20),
        controlPoint2: CGPoint(x: s * 0.31, y: s * 0.15)
    )
    lotusPath.curve(
        to: CGPoint(x: s * 0.69, y: s * 0.27),
        controlPoint1: CGPoint(x: s * 0.52, y: s * 0.18),
        controlPoint2: CGPoint(x: s * 0.60, y: s * 0.22)
    )
    lotusPath.line(to: CGPoint(x: s * 0.69, y: s * 0.10))
    lotusPath.line(to: CGPoint(x: s * 0.13, y: s * 0.10))
    lotusPath.close()
    color(0xFFD6DC, alpha: 0.55).setFill()
    lotusPath.fill()

    let iconShadow = NSShadow()
    iconShadow.shadowOffset = NSSize(width: 0, height: -s * 0.020)
    iconShadow.shadowBlurRadius = s * 0.050
    iconShadow.shadowColor = color(0x3A6080, alpha: 0.18)
    iconShadow.set()

    let boardRect = CGRect(x: s * 0.245, y: s * 0.185, width: s * 0.51, height: s * 0.62)
    let boardPath = roundedRect(boardRect, radius: s * 0.060)
    color(0x3A6080, alpha: 0.98).setFill()
    boardPath.fill()
    NSShadow().set()

    let paperRect = boardRect.insetBy(dx: s * 0.030, dy: s * 0.038)
    let paperPath = roundedRect(paperRect, radius: s * 0.038)
    let paperGradient = NSGradient(colors: [
        color(0xFAFBFC),
        color(0xF7F1E6)
    ])
    paperGradient?.draw(in: paperPath, angle: 90)

    color(0xE2EAF0, alpha: 0.82).setStroke()
    paperPath.lineWidth = max(1, s * 0.010)
    paperPath.stroke()

    let clipRect = CGRect(x: s * 0.365, y: s * 0.720, width: s * 0.270, height: s * 0.145)
    let clipBack = roundedRect(clipRect.offsetBy(dx: 0, dy: -s * 0.030), radius: s * 0.050)
    color(0x3A6080, alpha: 0.94).setFill()
    clipBack.fill()

    let clipFront = roundedRect(clipRect, radius: s * 0.050)
    let clipGradient = NSGradient(colors: [
        color(0xFFF3C0),
        color(0xFFDF90)
    ])
    clipGradient?.draw(in: clipFront, angle: 90)
    color(0x3A6080, alpha: 0.22).setStroke()
    clipFront.lineWidth = max(1, s * 0.009)
    clipFront.stroke()

    color(0xFAFBFC, alpha: 0.70).setFill()
    roundedRect(
        CGRect(x: s * 0.435, y: s * 0.765, width: s * 0.130, height: s * 0.032),
        radius: s * 0.016
    ).fill()

    let kPath = NSBezierPath()
    kPath.move(to: CGPoint(x: s * 0.392, y: s * 0.585))
    kPath.line(to: CGPoint(x: s * 0.392, y: s * 0.375))
    kPath.move(to: CGPoint(x: s * 0.415, y: s * 0.485))
    kPath.curve(
        to: CGPoint(x: s * 0.555, y: s * 0.600),
        controlPoint1: CGPoint(x: s * 0.465, y: s * 0.505),
        controlPoint2: CGPoint(x: s * 0.510, y: s * 0.548)
    )
    kPath.move(to: CGPoint(x: s * 0.425, y: s * 0.475))
    kPath.curve(
        to: CGPoint(x: s * 0.585, y: s * 0.355),
        controlPoint1: CGPoint(x: s * 0.490, y: s * 0.450),
        controlPoint2: CGPoint(x: s * 0.535, y: s * 0.405)
    )
    kPath.lineWidth = s * 0.046
    kPath.lineCapStyle = .round
    kPath.lineJoinStyle = .round
    color(0x3A6080).setStroke()
    kPath.stroke()

    let lineRects = [
        CGRect(x: s * 0.610, y: s * 0.565, width: s * 0.075, height: s * 0.024),
        CGRect(x: s * 0.590, y: s * 0.490, width: s * 0.105, height: s * 0.024),
        CGRect(x: s * 0.605, y: s * 0.415, width: s * 0.080, height: s * 0.024)
    ]
    for rect in lineRects {
        color(0xB8D8F0, alpha: 0.82).setFill()
        roundedRect(rect, radius: s * 0.012).fill()
    }

    let paperclipPath = NSBezierPath()
    paperclipPath.move(to: CGPoint(x: s * 0.645, y: s * 0.300))
    paperclipPath.curve(
        to: CGPoint(x: s * 0.755, y: s * 0.435),
        controlPoint1: CGPoint(x: s * 0.720, y: s * 0.300),
        controlPoint2: CGPoint(x: s * 0.755, y: s * 0.350)
    )
    paperclipPath.line(to: CGPoint(x: s * 0.755, y: s * 0.505))
    paperclipPath.curve(
        to: CGPoint(x: s * 0.650, y: s * 0.585),
        controlPoint1: CGPoint(x: s * 0.755, y: s * 0.560),
        controlPoint2: CGPoint(x: s * 0.715, y: s * 0.585)
    )
    paperclipPath.curve(
        to: CGPoint(x: s * 0.575, y: s * 0.515),
        controlPoint1: CGPoint(x: s * 0.600, y: s * 0.585),
        controlPoint2: CGPoint(x: s * 0.575, y: s * 0.555)
    )
    paperclipPath.line(to: CGPoint(x: s * 0.575, y: s * 0.435))
    paperclipPath.curve(
        to: CGPoint(x: s * 0.645, y: s * 0.380),
        controlPoint1: CGPoint(x: s * 0.575, y: s * 0.400),
        controlPoint2: CGPoint(x: s * 0.605, y: s * 0.380)
    )
    paperclipPath.curve(
        to: CGPoint(x: s * 0.690, y: s * 0.430),
        controlPoint1: CGPoint(x: s * 0.675, y: s * 0.380),
        controlPoint2: CGPoint(x: s * 0.690, y: s * 0.400)
    )
    paperclipPath.line(to: CGPoint(x: s * 0.690, y: s * 0.500))
    paperclipPath.lineWidth = s * 0.024
    paperclipPath.lineCapStyle = .round
    paperclipPath.lineJoinStyle = .round
    color(0xF47C6B, alpha: 0.95).setStroke()
    paperclipPath.stroke()

    let leafPath = NSBezierPath()
    leafPath.move(to: CGPoint(x: s * 0.770, y: s * 0.190))
    leafPath.curve(
        to: CGPoint(x: s * 0.895, y: s * 0.315),
        controlPoint1: CGPoint(x: s * 0.855, y: s * 0.195),
        controlPoint2: CGPoint(x: s * 0.895, y: s * 0.245)
    )
    leafPath.curve(
        to: CGPoint(x: s * 0.770, y: s * 0.190),
        controlPoint1: CGPoint(x: s * 0.825, y: s * 0.310),
        controlPoint2: CGPoint(x: s * 0.770, y: s * 0.270)
    )
    leafPath.close()
    color(0xD8EDD8, alpha: 0.95).setFill()
    leafPath.fill()

    let leafVein = NSBezierPath()
    leafVein.move(to: CGPoint(x: s * 0.795, y: s * 0.215))
    leafVein.curve(
        to: CGPoint(x: s * 0.875, y: s * 0.295),
        controlPoint1: CGPoint(x: s * 0.820, y: s * 0.245),
        controlPoint2: CGPoint(x: s * 0.845, y: s * 0.275)
    )
    leafVein.lineWidth = max(1, s * 0.010)
    leafVein.lineCapStyle = .round
    color(0x3A6080, alpha: 0.46).setStroke()
    leafVein.stroke()

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "KeyClipIcon", code: 3, userInfo: [
            NSLocalizedDescriptionKey: "Could not encode PNG."
        ])
    }
    return data
}

func appendFourCC(_ value: String, to data: inout Data) {
    precondition(value.utf8.count == 4)
    data.append(contentsOf: value.utf8)
}

func appendBigEndianUInt32(_ value: UInt32, to data: inout Data) {
    var bigEndianValue = value.bigEndian
    withUnsafeBytes(of: &bigEndianValue) { data.append(contentsOf: $0) }
}

var iconData = Data()
var imageChunks: [(type: String, data: Data)] = []

for chunk in chunks {
    imageChunks.append((type: chunk.type, data: try drawIcon(size: chunk.pixels)))
}

let totalLength = imageChunks.reduce(8) { total, imageChunk in
    total + 8 + imageChunk.data.count
}

appendFourCC("icns", to: &iconData)
appendBigEndianUInt32(UInt32(totalLength), to: &iconData)

for imageChunk in imageChunks {
    appendFourCC(imageChunk.type, to: &iconData)
    appendBigEndianUInt32(UInt32(imageChunk.data.count + 8), to: &iconData)
    iconData.append(imageChunk.data)
}

try iconData.write(to: outputURL)
print("Generated \(outputURL.path)")
