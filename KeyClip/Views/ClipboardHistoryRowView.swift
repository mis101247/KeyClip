import SwiftUI

struct ClipboardHistoryRowView: View {
    let item: ClipboardHistoryItem
    let shortcutLabel: String?
    @ObservedObject var groupStore: ClipboardGroupStore
    let onCopy: () -> Void

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
        item.type == .code
            || item.content.contains("{")
            || item.content.contains("}")
            || item.content.contains(";")
            || item.content.first?.isWhitespace == true
    }

    private var previewFont: Font {
        if item.type == .code {
            return .system(.body, design: .monospaced)
        }

        if item.type == .emoji {
            return .system(size: 18)
        }

        if usesMonospacedPreview {
            return .system(.body, design: .monospaced)
        }

        return .body
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: item.type.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(item.type.tintColor)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(item.type.tintColor.opacity(0.15))
                    )

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
                    .font(previewFont)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .textSelection(.disabled)
            }

            HStack(spacing: 4) {
                Text(relativeTimestamp)

                Text("·")

                Text(item.type.displayName)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 64, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(
                    Color(nsColor: isHovered ? .selectedControlColor : .controlBackgroundColor)
                        .opacity(isHovered ? 0.18 : 0.75)
                )
        )
        .contextMenu {
            Button("Copy") {
                onCopy()
            }

            Divider()

            if groupStore.groups.isEmpty {
                Text("No custom groups yet")
            } else {
                Menu {
                    ForEach(groupStore.groups) { group in
                        Button {
                            groupStore.toggleItem(item.id, in: group.id)
                        } label: {
                            if groupStore.contains(itemID: item.id, in: group.id) {
                                Label(group.name, systemImage: "checkmark")
                            } else {
                                Text(group.name)
                            }
                        }
                    }
                } label: {
                    Label("Add to Group", systemImage: "folder.badge.plus")
                }
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
