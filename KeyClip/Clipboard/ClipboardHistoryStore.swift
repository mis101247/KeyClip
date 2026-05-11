import AppKit
import Foundation

final class ClipboardHistoryStore: ObservableObject {
    @Published private(set) var items: [ClipboardHistoryItem] = []
    var onItemsRemoved: (([UUID]) -> Void)?
    var onItemCaptured: (() -> Void)?
    var protectedIDsProvider: () -> Set<UUID> = { [] }

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

    func add(
        content: String,
        type: ContentType,
        rtfData: Data? = nil,
        isOversize: Bool = false,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil
    ) {
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
                attachmentKind: rtfAttachmentFilename == nil ? existingItem.attachmentKind : .rtf,
                isOversize: isOversize,
                sourceAppBundleID: sourceAppBundleID,
                sourceAppName: sourceAppName
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
                attachmentKind: rtfAttachmentFilename == nil ? nil : .rtf,
                isOversize: isOversize,
                sourceAppBundleID: sourceAppBundleID,
                sourceAppName: sourceAppName
            )
            items.insert(item, at: 0)
        }

        enforceMaxItems()
        save()
        onItemCaptured?()
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

    func addImage(
        data: Data,
        hash: String,
        dimensions: CGSize,
        isOversize: Bool = false,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil
    ) {
        guard data.count <= 100 * 1024 * 1024 else {
            NSLog("Skipping oversize image: \(data.count) bytes")
            return
        }

        if let existingIndex = items.firstIndex(where: { $0.contentHash == hash }) {
            let existingItem = items.remove(at: existingIndex)
            let updatedItem = ClipboardHistoryItem(
                id: existingItem.id,
                content: existingItem.content,
                createdAt: existingItem.createdAt,
                contentHash: existingItem.contentHash,
                type: existingItem.type,
                attachmentFilename: existingItem.attachmentFilename,
                attachmentKind: existingItem.attachmentKind,
                isOversize: isOversize,
                sourceAppBundleID: sourceAppBundleID,
                sourceAppName: sourceAppName
            )
            items.insert(updatedItem, at: 0)
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
                    attachmentKind: .image,
                    isOversize: isOversize,
                    sourceAppBundleID: sourceAppBundleID,
                    sourceAppName: sourceAppName
                )
                items.insert(item, at: 0)
            } catch {
                NSLog("Failed to save clipboard image: \(error.localizedDescription)")
                return
            }
        }

        enforceMaxItems()
        save()
        onItemCaptured?()
    }

    private func enforceMaxItems() {
        let protectedIDs = protectedIDsProvider()
        var unprotectedSeen = 0
        var droppedItems: [ClipboardHistoryItem] = []
        var keptItems: [ClipboardHistoryItem] = []

        for item in items {
            if protectedIDs.contains(item.id) {
                keptItems.append(item)
                continue
            }

            unprotectedSeen += 1
            if unprotectedSeen <= maxItems {
                keptItems.append(item)
            } else {
                droppedItems.append(item)
            }
        }

        guard !droppedItems.isEmpty else { return }

        cleanupAttachments(for: droppedItems)
        items = keptItems
        onItemsRemoved?(droppedItems.map(\.id))
    }

    func clear() {
        let protectedIDs = protectedIDsProvider()
        let removedItems = items.filter { !protectedIDs.contains($0.id) }
        guard !removedItems.isEmpty else { return }

        let removed = removedItems.map(\.id)
        cleanupAttachments(for: removedItems)
        items.removeAll { !protectedIDs.contains($0.id) }
        onItemsRemoved?(removed)
        save()
    }

    func remove(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let removed = items.remove(at: index)
        cleanupAttachments(for: [removed])
        onItemsRemoved?([removed.id])
        save()
    }

    func remove(ids: [UUID]) {
        guard !ids.isEmpty else { return }
        let idSet = Set(ids)
        let removed = items.filter { idSet.contains($0.id) }
        guard !removed.isEmpty else { return }
        items.removeAll { idSet.contains($0.id) }
        cleanupAttachments(for: removed)
        onItemsRemoved?(removed.map(\.id))
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

    /// Remove oversize items older than cutoff, exempting protectedIDs (items in custom groups).
    func sweepOversizeExpired(olderThan cutoff: Date, protectedIDs: Set<UUID>) {
        let toRemove = items.filter { item in
            item.isOversize && item.createdAt < cutoff && !protectedIDs.contains(item.id)
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
