import Foundation

struct ClipboardHistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    let content: String
    let createdAt: Date
    let contentHash: String
    let type: ContentType
    let attachmentFilename: String?
    let attachmentKind: AttachmentKind?
    let isOversize: Bool

    init(
        id: UUID,
        content: String,
        createdAt: Date,
        contentHash: String,
        type: ContentType,
        attachmentFilename: String? = nil,
        attachmentKind: AttachmentKind? = nil,
        isOversize: Bool = false
    ) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.contentHash = contentHash
        self.type = type
        self.attachmentFilename = attachmentFilename
        self.attachmentKind = attachmentKind
        self.isOversize = isOversize
    }

    private enum CodingKeys: String, CodingKey {
        case id, content, createdAt, contentHash, type, attachmentFilename, attachmentKind, isOversize
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.content = try container.decode(String.self, forKey: .content)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.contentHash = try container.decode(String.self, forKey: .contentHash)
        self.type = try container.decodeIfPresent(ContentType.self, forKey: .type) ?? .text
        self.attachmentFilename = try container.decodeIfPresent(String.self, forKey: .attachmentFilename)
        self.attachmentKind = try container.decodeIfPresent(AttachmentKind.self, forKey: .attachmentKind)
        self.isOversize = try container.decodeIfPresent(Bool.self, forKey: .isOversize) ?? false
    }
}
