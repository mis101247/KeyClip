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
        NSColor(calibratedRed: 0.015, green: 0.075, blue: 0.19, alpha: 1),
        NSColor(calibratedRed: 0.02, green: 0.18, blue: 0.36, alpha: 1)
    ])
    backgroundGradient?.draw(in: bgPath, angle: 42)

    NSColor.white.withAlphaComponent(0.08).setFill()
    roundedRect(background.insetBy(dx: s * 0.035, dy: s * 0.035), radius: s * 0.185).fill()

    let shinePath = NSBezierPath()
    shinePath.move(to: CGPoint(x: s * 0.20, y: s * 0.72))
    shinePath.curve(
        to: CGPoint(x: s * 0.68, y: s * 0.88),
        controlPoint1: CGPoint(x: s * 0.34, y: s * 0.86),
        controlPoint2: CGPoint(x: s * 0.52, y: s * 0.91)
    )
    shinePath.lineWidth = s * 0.035
    shinePath.lineCapStyle = .round
    NSColor.white.withAlphaComponent(0.16).setStroke()
    shinePath.stroke()

    let paperclipPath = NSBezierPath()
    paperclipPath.move(to: CGPoint(x: s * 0.55, y: s * 0.78))
    paperclipPath.curve(
        to: CGPoint(x: s * 0.25, y: s * 0.58),
        controlPoint1: CGPoint(x: s * 0.38, y: s * 0.80),
        controlPoint2: CGPoint(x: s * 0.25, y: s * 0.72)
    )
    paperclipPath.line(to: CGPoint(x: s * 0.25, y: s * 0.42))
    paperclipPath.curve(
        to: CGPoint(x: s * 0.50, y: s * 0.21),
        controlPoint1: CGPoint(x: s * 0.25, y: s * 0.29),
        controlPoint2: CGPoint(x: s * 0.35, y: s * 0.21)
    )
    paperclipPath.curve(
        to: CGPoint(x: s * 0.77, y: s * 0.46),
        controlPoint1: CGPoint(x: s * 0.67, y: s * 0.21),
        controlPoint2: CGPoint(x: s * 0.77, y: s * 0.32)
    )
    paperclipPath.line(to: CGPoint(x: s * 0.77, y: s * 0.57))
    paperclipPath.curve(
        to: CGPoint(x: s * 0.53, y: s * 0.73),
        controlPoint1: CGPoint(x: s * 0.77, y: s * 0.68),
        controlPoint2: CGPoint(x: s * 0.67, y: s * 0.73)
    )
    paperclipPath.curve(
        to: CGPoint(x: s * 0.36, y: s * 0.58),
        controlPoint1: CGPoint(x: s * 0.42, y: s * 0.73),
        controlPoint2: CGPoint(x: s * 0.36, y: s * 0.66)
    )
    paperclipPath.line(to: CGPoint(x: s * 0.36, y: s * 0.43))
    paperclipPath.curve(
        to: CGPoint(x: s * 0.52, y: s * 0.32),
        controlPoint1: CGPoint(x: s * 0.36, y: s * 0.36),
        controlPoint2: CGPoint(x: s * 0.42, y: s * 0.32)
    )
    paperclipPath.curve(
        to: CGPoint(x: s * 0.64, y: s * 0.44),
        controlPoint1: CGPoint(x: s * 0.60, y: s * 0.32),
        controlPoint2: CGPoint(x: s * 0.64, y: s * 0.37)
    )
    paperclipPath.line(to: CGPoint(x: s * 0.64, y: s * 0.56))
    paperclipPath.lineWidth = s * 0.072
    paperclipPath.lineCapStyle = .round
    paperclipPath.lineJoinStyle = .round

    let iconShadow = NSShadow()
    iconShadow.shadowOffset = NSSize(width: 0, height: -s * 0.018)
    iconShadow.shadowBlurRadius = s * 0.04
    iconShadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    iconShadow.set()
    NSColor(calibratedRed: 0.07, green: 0.70, blue: 1.0, alpha: 1).setStroke()
    paperclipPath.stroke()
    NSShadow().set()

    let highlightPath = paperclipPath.copy() as! NSBezierPath
    highlightPath.lineWidth = s * 0.035
    NSColor(calibratedRed: 0.56, green: 0.96, blue: 1.0, alpha: 0.82).setStroke()
    highlightPath.stroke()

    let keyholeTop = oval(CGRect(x: s * 0.445, y: s * 0.50, width: s * 0.11, height: s * 0.11))
    let keyholeStem = roundedRect(CGRect(x: s * 0.472, y: s * 0.405, width: s * 0.056, height: s * 0.15), radius: s * 0.026)
    NSColor(calibratedRed: 0.018, green: 0.10, blue: 0.23, alpha: 0.96).setFill()
    keyholeTop.fill()
    keyholeStem.fill()

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
