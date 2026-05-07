import Foundation

struct ClipboardHistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    let content: String
    let createdAt: Date
    let contentHash: String
    let type: ContentType

    init(
        id: UUID,
        content: String,
        createdAt: Date,
        contentHash: String,
        type: ContentType
    ) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.contentHash = contentHash
        self.type = type
    }

    private enum CodingKeys: String, CodingKey {
        case id, content, createdAt, contentHash, type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.content = try container.decode(String.self, forKey: .content)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.contentHash = try container.decode(String.self, forKey: .contentHash)
        self.type = try container.decodeIfPresent(ContentType.self, forKey: .type) ?? .text
    }
}
