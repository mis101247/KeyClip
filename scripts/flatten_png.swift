#!/usr/bin/env swift
import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: flatten_png.swift <png-path>\n", stderr)
    exit(2)
}

let fileURL = URL(fileURLWithPath: CommandLine.arguments[1])

guard let inputData = try? Data(contentsOf: fileURL),
      let sourceRep = NSBitmapImageRep(data: inputData),
      let image = NSImage(data: inputData) else {
    fputs("Could not read PNG at \(fileURL.path)\n", stderr)
    exit(1)
}

let pixelSize = NSSize(width: sourceRep.pixelsWide, height: sourceRep.pixelsHigh)

guard let outputRep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: sourceRep.pixelsWide,
    pixelsHigh: sourceRep.pixelsHigh,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Could not allocate output bitmap\n", stderr)
    exit(1)
}

outputRep.size = pixelSize
image.size = pixelSize

NSGraphicsContext.saveGraphicsState()
defer { NSGraphicsContext.restoreGraphicsState() }

guard let context = NSGraphicsContext(bitmapImageRep: outputRep) else {
    fputs("Could not create bitmap graphics context\n", stderr)
    exit(1)
}

NSGraphicsContext.current = context
NSColor(red: 250 / 255, green: 251 / 255, blue: 252 / 255, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: pixelSize)).fill()
image.draw(
    in: NSRect(origin: .zero, size: pixelSize),
    from: NSRect(origin: .zero, size: pixelSize),
    operation: .sourceOver,
    fraction: 1
)
context.flushGraphics()

guard let outputData = outputRep.representation(using: .png, properties: [:]) else {
    fputs("Could not encode flattened PNG\n", stderr)
    exit(1)
}

try outputData.write(to: fileURL, options: .atomic)
