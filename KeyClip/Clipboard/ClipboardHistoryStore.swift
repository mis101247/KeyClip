import AppKit
import Foundation

final class ClipboardHistoryStore: ObservableObject {
    @Published private(set) var items: [ClipboardHistoryItem] = []
    var onItemsRemoved: (([UUID]) -> Void)?

    private let maxItems = 100
    private let fileURL: URL
    private let attachments: AttachmentStore

    init(fileURL: URL? = nil, attachments: AttachmentStore = AttachmentStore()) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            self.fileURL = Self.defaultHistoryFileURL()
        }
        self.attachments = attachments

        load()
    }

    func add(content: String, type: ContentType, rtfData: Data? = nil) {
        let contentHash = sha256Hash(content)

        if let existingIndex = items.firstIndex(where: { $0.contentHash == contentHash }) {
            let existingItem = items.remove(at: existingIndex)
            let rtfAttachmentFilename = upgradedRTFAttachmentFilename(for: existingItem, type: type, rtfData: rtfData)
            let updatedItem = ClipboardHistoryItem(
                id: existingItem.id,
                content: existingItem.content,
                createdAt: existingItem.createdAt,
                contentHash: existingItem.contentHash,
                type: type,
                attachmentFilename: rtfAttachmentFilename ?? existingItem.attachmentFilename,
                attachmentKind: rtfAttachmentFilename == nil ? existingItem.attachmentKind : .rtf
            )
            items.insert(updatedItem, at: 0)
        } else {
            let rtfAttachmentFilename = newRTFAttachmentFilename(type: type, rtfData: rtfData)
            let item = ClipboardHistoryItem(
                id: UUID(),
                content: content,
                createdAt: Date(),
                contentHash: contentHash,
                type: type,
                attachmentFilename: rtfAttachmentFilename,
                attachmentKind: rtfAttachmentFilename == nil ? nil : .rtf
            )
            items.insert(item, at: 0)
        }

        enforceMaxItems()
        save()
    }

    private func upgradedRTFAttachmentFilename(
        for item: ClipboardHistoryItem,
        type: ContentType,
        rtfData: Data?
    ) -> String? {
        guard type == .richText,
              !hasRTFAttachment(item),
              let rtfData else {
            return nil
        }

        return newRTFAttachmentFilename(type: type, rtfData: rtfData)
    }

    private func hasRTFAttachment(_ item: ClipboardHistoryItem) -> Bool {
        item.attachmentKind == .rtf && item.attachmentFilename != nil
    }

    private func newRTFAttachmentFilename(type: ContentType, rtfData: Data?) -> String? {
        guard type == .richText,
              let rtfData else {
            return nil
        }

        do {
            return try attachments.write(data: rtfData, kind: .rtf, suggestedExtension: "rtf")
        } catch {
            NSLog("Failed to save clipboard RTF: \(error.localizedDescription)")
            return nil
        }
    }

    func addImage(data: Data, hash: String, dimensions: CGSize) {
        if let existingIndex = items.firstIndex(where: { $0.contentHash == hash }) {
            let existingItem = items.remove(at: existingIndex)
            items.insert(existingItem, at: 0)
        } else {
            do {
                let filename = try attachments.write(data: data, kind: .image, suggestedExtension: "png")
                let width = Int(dimensions.width.rounded())
                let height = Int(dimensions.height.rounded())
                let item = ClipboardHistoryItem(
                    id: UUID(),
                    content: "Image \(width)x\(height)",
                    createdAt: Date(),
                    contentHash: hash,
                    type: .image,
                    attachmentFilename: filename,
                    attachmentKind: .image
                )
                items.insert(item, at: 0)
            } catch {
                NSLog("Failed to save clipboard image: \(error.localizedDescription)")
                return
            }
        }

        enforceMaxItems()
        save()
    }

    private func enforceMaxItems() {
        if items.count > maxItems {
            let droppedItems = Array(items.suffix(items.count - maxItems))
            let dropped = droppedItems.map(\.id)
            cleanupAttachments(for: droppedItems)
            items = Array(items.prefix(maxItems))
            onItemsRemoved?(dropped)
        }
    }

    func clear() {
        let removed = items.map(\.id)
        cleanupAttachments(for: items)
        items.removeAll()
        onItemsRemoved?(removed)
        save()
    }

    /// Remove items with createdAt before cutoff, exempting protectedIDs (items in custom groups).
    func sweepExpired(olderThan cutoff: Date, protectedIDs: Set<UUID>) {
        let toRemove = items.filter { item in
            item.createdAt < cutoff && !protectedIDs.contains(item.id)
        }
        guard !toRemove.isEmpty else { return }
        let removeIDs = Set(toRemove.map(\.id))
        items.removeAll { removeIDs.contains($0.id) }
        cleanupAttachments(for: toRemove)
        onItemsRemoved?(toRemove.map(\.id))
        save()
    }

    func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            items = try JSONDecoder().decode([ClipboardHistoryItem].self, from: data)
        } catch {
            items = []
        }
    }

    func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Failed to save clipboard history: \(error.localizedDescription)")
        }
    }

    private func cleanupAttachments(for items: [ClipboardHistoryItem]) {
        for item in items {
            if let filename = item.attachmentFilename {
                attachments.delete(filename: filename)
            }
        }
    }

    private static func defaultHistoryFileURL() -> URL {
        let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        return applicationSupportURL
            .appendingPathComponent("com.keyo.KeyClip", isDirectory: true)
            .appendingPathComponent("clipboard-history.json", isDirectory: false)
    }
}
