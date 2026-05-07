import Foundation

struct ClipboardHistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    let content: String
    let createdAt: Date
    let contentHash: String
}
