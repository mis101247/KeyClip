import Foundation

final class ClipboardHistoryStore: ObservableObject {
    @Published private(set) var items: [ClipboardHistoryItem] = []
    var onItemsRemoved: (([UUID]) -> Void)?

    private let maxItems = 100
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            self.fileURL = Self.defaultHistoryFileURL()
        }

        load()
    }

    func add(content: String, type: ContentType) {
        let contentHash = sha256Hash(content)

        if let existingIndex = items.firstIndex(where: { $0.contentHash == contentHash }) {
            let existingItem = items.remove(at: existingIndex)
            let updatedItem = ClipboardHistoryItem(
                id: existingItem.id,
                content: existingItem.content,
                createdAt: existingItem.createdAt,
                contentHash: existingItem.contentHash,
                type: type
            )
            items.insert(updatedItem, at: 0)
        } else {
            let item = ClipboardHistoryItem(
                id: UUID(),
                content: content,
                createdAt: Date(),
                contentHash: contentHash,
                type: type
            )
            items.insert(item, at: 0)
        }

        if items.count > maxItems {
            let dropped = Array(items.suffix(items.count - maxItems)).map(\.id)
            items = Array(items.prefix(maxItems))
            onItemsRemoved?(dropped)
        }

        save()
    }

    func clear() {
        let removed = items.map(\.id)
        items.removeAll()
        onItemsRemoved?(removed)
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
