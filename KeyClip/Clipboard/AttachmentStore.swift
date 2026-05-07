import AppKit
import Foundation

enum AttachmentKind: String, Codable {
    case image
    case rtf
}

final class AttachmentStore {
    private let directory: URL

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            self.directory = Self.defaultAttachmentDirectory()
        }
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    func write(data: Data, kind: AttachmentKind, suggestedExtension: String) throws -> String {
        let filename = "\(UUID().uuidString).\(suggestedExtension)"
        let url = directory.appendingPathComponent(filename, isDirectory: false)
        try data.write(to: url, options: .atomic)
        return filename
    }

    func url(forFilename filename: String) -> URL {
        directory.appendingPathComponent(filename, isDirectory: false)
    }

    func read(filename: String) -> Data? {
        try? Data(contentsOf: url(forFilename: filename))
    }

    func delete(filename: String) {
        let url = url(forFilename: filename)
        try? FileManager.default.removeItem(at: url)
    }

    private static func defaultAttachmentDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport
            .appendingPathComponent("com.keyo.KeyClip", isDirectory: true)
            .appendingPathComponent("attachments", isDirectory: true)
    }
}
