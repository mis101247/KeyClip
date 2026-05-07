import Foundation

final class ClipboardGroupStore: ObservableObject {
    @Published private(set) var groups: [ClipboardGroup] = []

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            self.fileURL = Self.defaultGroupsFileURL()
        }

        load()
    }

    func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            groups = try JSONDecoder().decode([ClipboardGroup].self, from: data)
        } catch {
            groups = []
            NSLog("Failed to load clipboard groups: \(error.localizedDescription)")
        }
    }

    func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(groups)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Failed to save clipboard groups: \(error.localizedDescription)")
        }
    }

    func createGroup(name: String, systemImage: String = "folder") -> ClipboardGroup {
        let group = ClipboardGroup(name: name, systemImage: systemImage)
        groups.append(group)
        save()
        return group
    }

    func renameGroup(id: UUID, to newName: String) {
        guard let index = groups.firstIndex(where: { $0.id == id }) else {
            return
        }

        groups[index].name = newName
        save()
    }

    func updateIcon(id: UUID, to systemImage: String) {
        guard let index = groups.firstIndex(where: { $0.id == id }) else {
            return
        }

        groups[index].systemImage = systemImage
        save()
    }

    func deleteGroup(id: UUID) {
        groups.removeAll { $0.id == id }
        save()
    }

    func addItem(_ itemID: UUID, to groupID: UUID) {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else {
            return
        }

        guard !groups[index].itemIDs.contains(itemID) else {
            return
        }

        groups[index].itemIDs.append(itemID)
        save()
    }

    func removeItem(_ itemID: UUID, from groupID: UUID) {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else {
            return
        }

        groups[index].itemIDs.removeAll { $0 == itemID }
        save()
    }

    func toggleItem(_ itemID: UUID, in groupID: UUID) {
        if contains(itemID: itemID, in: groupID) {
            removeItem(itemID, from: groupID)
        } else {
            addItem(itemID, to: groupID)
        }
    }

    func contains(itemID: UUID, in groupID: UUID) -> Bool {
        guard let group = groups.first(where: { $0.id == groupID }) else {
            return false
        }

        return group.itemIDs.contains(itemID)
    }

    func groupsContaining(itemID: UUID) -> [ClipboardGroup] {
        groups.filter { $0.itemIDs.contains(itemID) }
    }

    func purgeItems(_ ids: [UUID]) {
        let ids = Set(ids)
        guard !ids.isEmpty else {
            return
        }

        for index in groups.indices {
            groups[index].itemIDs.removeAll { ids.contains($0) }
        }

        save()
    }

    private static func defaultGroupsFileURL() -> URL {
        let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        return applicationSupportURL
            .appendingPathComponent("com.keyo.KeyClip", isDirectory: true)
            .appendingPathComponent("clipboard-groups.json", isDirectory: false)
    }
}
