import SwiftUI

enum ContentType: String, Codable, CaseIterable, Identifiable {
    case text, richText, image, file, files, link, code, email, phone, color, emoji

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .text: return L10n.tr("content_type.text")
        case .richText: return L10n.tr("content_type.rich_text")
        case .image: return L10n.tr("content_type.image")
        case .file: return L10n.tr("content_type.file")
        case .files: return L10n.tr("content_type.files")
        case .link: return L10n.tr("content_type.link")
        case .code: return L10n.tr("content_type.code")
        case .email: return L10n.tr("content_type.email")
        case .phone: return L10n.tr("content_type.phone")
        case .color: return L10n.tr("content_type.color")
        case .emoji: return L10n.tr("content_type.emoji")
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
