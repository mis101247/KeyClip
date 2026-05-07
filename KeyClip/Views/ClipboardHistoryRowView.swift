import SwiftUI

struct ClipboardHistoryRowView: View {
    let item: ClipboardHistoryItem
    let shortcutLabel: String?
    @ObservedObject var groupStore: ClipboardGroupStore
    let attachmentStore: AttachmentStore
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    private let previewCharacterLimit = 150
    private let rowSpacing: CGFloat = 5
    private let previewSpacing: CGFloat = 8
    private let metadataSpacing: CGFloat = 4
    private let rowHorizontalPadding: CGFloat = 12
    private let rowVerticalPadding: CGFloat = 8
    private let rowMinHeight: CGFloat = 52
    private let rowMaxHeight: CGFloat = 64
    private let rowCornerRadius: CGFloat = 8
    private let hoverOpacity: Double = 0.04
    private let typeIconSize: CGFloat = 13
    private let typeIconContainerSize: CGFloat = 22
    private let typeIconContainerCornerRadius: CGFloat = 6
    private let typeIconBackgroundOpacity: Double = 0.12
    private let typeIconTintOpacity: Double = 0.85
    private let imagePreviewSize: CGFloat = 36
    private let imagePreviewCornerRadius: CGFloat = 6
    private let shortcutPreviewSpacing: CGFloat = 4

    private var previewText: String {
        let firstLine = item.content
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init) ?? item.content

        if firstLine.count <= previewCharacterLimit {
            return firstLine
        }

        let endIndex = firstLine.index(firstLine.startIndex, offsetBy: previewCharacterLimit)
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

    private var membershipGroups: [ClipboardGroup] {
        groupStore.groupsContaining(itemID: item.id)
    }

    private var previewFont: Font {
        if item.type == .code {
            return .system(.callout, design: .monospaced)
        }

        if item.type == .emoji {
            return .system(.callout)
        }

        if usesMonospacedPreview {
            return .system(.callout, design: .monospaced)
        }

        return .system(.callout)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: previewSpacing) {
                leadingPreview

                HStack(alignment: .firstTextBaseline, spacing: shortcutPreviewSpacing) {
                    if let shortcutLabel {
                        Text(shortcutLabel)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Text(previewText)
                        .font(previewFont)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .textSelection(.disabled)
                }
            }

            HStack(spacing: metadataSpacing) {
                Text(relativeTimestamp)

                Text("·")

                Text(item.type.displayName)

                if !membershipGroups.isEmpty {
                    Text("·")
                        .font(.system(.caption2))
                        .foregroundStyle(.tertiary)

                    HStack(spacing: 3) {
                        ForEach(membershipGroups.prefix(3)) { group in
                            Image(systemName: group.systemImage)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        if membershipGroups.count > 3 {
                            Text("+\(membershipGroups.count - 3)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .help(membershipGroups.map(\.name).joined(separator: ", "))
                }
            }
            .font(.system(.caption2))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(.horizontal, rowHorizontalPadding)
        .padding(.vertical, rowVerticalPadding)
        .frame(maxWidth: .infinity, minHeight: rowMinHeight, maxHeight: rowMaxHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: rowCornerRadius)
                .fill(isHovered ? Color.primary.opacity(hoverOpacity) : Color.clear)
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

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }

    @ViewBuilder
    private var leadingPreview: some View {
        if item.type == .image,
           let filename = item.attachmentFilename,
           let data = attachmentStore.read(filename: filename),
           let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
                .frame(width: imagePreviewSize, height: imagePreviewSize)
                .clipShape(RoundedRectangle(cornerRadius: imagePreviewCornerRadius))
        } else {
            typeIcon
        }
    }

    private var typeIcon: some View {
        Image(systemName: item.type.systemImage)
            .font(.system(size: typeIconSize, weight: .medium))
            .foregroundStyle(item.type.tintColor.opacity(typeIconTintOpacity))
            .frame(width: typeIconContainerSize, height: typeIconContainerSize)
            .background(
                RoundedRectangle(cornerRadius: typeIconContainerCornerRadius)
                    .fill(item.type.tintColor.opacity(typeIconBackgroundOpacity))
            )
    }
}
