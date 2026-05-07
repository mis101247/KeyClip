import SwiftUI

struct ClipboardHistoryRowView: View {
    let item: ClipboardHistoryItem
    let shortcutLabel: String?

    @State private var isHovered = false

    private var previewText: String {
        let limit = 150
        let firstLine = item.content
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init) ?? item.content

        if firstLine.count <= limit {
            return firstLine
        }

        let endIndex = firstLine.index(firstLine.startIndex, offsetBy: limit)
        return String(firstLine[..<endIndex]) + "..."
    }

    private var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full

        return formatter.localizedString(for: item.createdAt, relativeTo: Date())
    }

    private var usesMonospacedPreview: Bool {
        item.content.contains("{")
            || item.content.contains("}")
            || item.content.contains(";")
            || item.content.first?.isWhitespace == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let shortcutLabel {
                    Text(shortcutLabel)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(nsColor: .quaternaryLabelColor))
                        )
                }

                Text(previewText)
                    .font(usesMonospacedPreview ? .system(.body, design: .monospaced) : .body)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .textSelection(.disabled)
            }

            Text(relativeTimestamp)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 64, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(
                    Color(nsColor: isHovered ? .selectedControlColor : .controlBackgroundColor)
                        .opacity(isHovered ? 0.18 : 0.75)
                )
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
