import AppKit
import CryptoKit

final class ClipboardMonitor {
    private static let maxTextBytes = 500 * 1024
    private static let maxRichTextBytes = 1024 * 1024
    private static let maxImageBytes = 10 * 1024 * 1024

    private let pasteboard: NSPasteboard
    private let onNewText: (String, ContentType, Data?) -> Void
    private let onNewImage: (Data, String, CGSize) -> Void
    private var timer: Timer?
    private var lastChangeCount: Int
    private var isWritingFromHistory = false

    init(
        pasteboard: NSPasteboard = .general,
        onNewText: @escaping (String, ContentType, Data?) -> Void,
        onNewImage: @escaping (Data, String, CGSize) -> Void
    ) {
        self.pasteboard = pasteboard
        self.onNewText = onNewText
        self.onNewImage = onNewImage
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.pollPasteboard()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func writeToPasteboard(_ content: String) {
        isWritingFromHistory = true
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        lastChangeCount = pasteboard.changeCount
        isWritingFromHistory = false
    }

    func writeImage(_ data: Data) {
        isWritingFromHistory = true
        pasteboard.clearContents()
        pasteboard.setData(data, forType: .png)
        lastChangeCount = pasteboard.changeCount
        isWritingFromHistory = false
    }

    func writeRichText(plain: String, rtf: Data) {
        isWritingFromHistory = true
        pasteboard.clearContents()
        pasteboard.setData(rtf, forType: .rtf)
        pasteboard.setString(plain, forType: .string)
        lastChangeCount = pasteboard.changeCount
        isWritingFromHistory = false
    }

    private func pollPasteboard() {
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else { return }

        lastChangeCount = currentChangeCount

        guard !isWritingFromHistory else {
            return
        }

        if let image = readImageFromPasteboard() {
            guard image.data.count <= Self.maxImageBytes else {
                NSLog("Skipping oversize image clip: \(image.data.count) bytes")
                return
            }

            let contentHash = sha256HexHash(image.data)
            onNewImage(image.data, contentHash, image.dimensions)
            return
        }

        guard let content = pasteboard.string(forType: .string),
              isValidClipboardContent(content) else {
            return
        }

        let rtfData = sanitizedRtfData(pasteboard.data(forType: .rtf))
        var type = ContentTypeDetector.detect(content: content, pasteboard: pasteboard)
        if type == .richText && rtfData == nil {
            type = .text
        }
        onNewText(content, type, rtfData)
    }

    private func readImageFromPasteboard() -> (data: Data, dimensions: CGSize)? {
        if let pngData = pasteboard.data(forType: .png),
           let dimensions = imageDimensions(from: pngData) {
            return (pngData, dimensions)
        }

        guard let tiffData = pasteboard.data(forType: .tiff),
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        let dimensions = CGSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
        return (pngData, dimensions)
    }

    private func imageDimensions(from data: Data) -> CGSize? {
        if let bitmap = NSBitmapImageRep(data: data) {
            return CGSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
        }

        return NSImage(data: data)?.size
    }

    private func sha256HexHash(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)

        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func sanitizedRtfData(_ data: Data?) -> Data? {
        guard let data, data.count <= Self.maxRichTextBytes else { return nil }
        return data
    }

    private func isValidClipboardContent(_ content: String) -> Bool {
        guard !content.isEmpty else { return false }
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard content.utf8.count <= Self.maxTextBytes else { return false }

        return true
    }
}
