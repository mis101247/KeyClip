import SwiftUI

enum ContentType: String, Codable, CaseIterable, Identifiable {
    case text, richText, image, file, files, link, code, email, phone, color, emoji

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .richText: return "Rich Text"
        case .image: return "Image"
        case .file: return "File"
        case .files: return "Files"
        case .link: return "Link"
        case .code: return "Code"
        case .email: return "Email"
        case .phone: return "Phone"
        case .color: return "Color"
        case .emoji: return "Emoji"
        }
    }

    var systemImage: String {
        switch self {
        case .text: return "text.quote"
        case .richText: return "doc.richtext"
        case .image: return "photo"
        case .file: return "doc"
        case .files: return "doc.on.doc"
        case .link: return "link"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .email: return "envelope"
        case .phone: return "phone"
        case .color: return "paintpalette"
        case .emoji: return "face.smiling"
        }
    }

    var tintColor: Color {
        switch self {
        case .text: return .secondary
        case .richText: return .blue
        case .image: return .purple
        case .file, .files: return .gray
        case .link: return .cyan
        case .code: return .indigo
        case .email: return .orange
        case .phone: return .green
        case .color: return .pink
        case .emoji: return .yellow
        }
    }
}
