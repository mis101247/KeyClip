import Foundation

struct ClipboardGroup: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var systemImage: String
    var itemIDs: [UUID]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        systemImage: String = "folder",
        itemIDs: [UUID] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.systemImage = systemImage
        self.itemIDs = itemIDs
        self.createdAt = createdAt
    }
}
