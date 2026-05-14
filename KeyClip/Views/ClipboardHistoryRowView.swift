import SwiftUI

struct ClipboardHistoryRowView: View {
    let item: ClipboardHistoryItem
    let shortcutLabel: String?
    let isSelected: Bool
    @ObservedObject var groupStore: ClipboardGroupStore
    let attachmentStore: AttachmentStore
    let onCopy: () -> Void
    let onUpdateTitle: (String) -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var isEditingTitle = false

    private let previewCharacterLimit = 150
    private let rowSpacing: CGFloat = 12
    private let metadataSpacing: CGFloat = 5
    private let rowHorizontalPadding: CGFloat = 16
    private let rowVerticalPadding: CGFloat = 10
    private let rowMinHeight: CGFloat = 52
    private let typeIconSize: CGFloat = 16
    private let typeIconContainerSize: CGFloat = 20
    private let imagePreviewSize: CGFloat = 36
    private let imagePreviewCornerRadius: CGFloat = Theme.radiusSm
    private let shortcutMinWidth: CGFloat = 24

    private var titleText: String? {
        guard let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else {
            return nil
        }

        return title
    }

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
            return Theme.textCodePreview
        }

        return Theme.textSm
    }

    var body: some View {
        HStack(alignment: .top, spacing: rowSpacing) {
            leadingPreview

            VStack(alignment: .leading, spacing: titleText == nil ? 0 : 3) {
                if let titleText {
                    HStack(spacing: 4) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.primary)

                        Text(titleText)
                            .font(Theme.textSmEmphasis)
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .textSelection(.disabled)
                    }

                    Text(previewText)
                        .font(previewFont)
                        .foregroundStyle(Theme.textMuted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .textSelection(.disabled)
                } else {
                    Text(previewText)
                        .font(previewFont)
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .textSelection(.disabled)
                }

                MetadataLine(chunks: metadataChunks, spacing: metadataSpacing)
                    .font(Theme.textXs)
                    .foregroundStyle(Theme.textMuted)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let shortcutLabel {
                Text(shortcutLabel)
                    .font(Theme.textMono)
                    .foregroundStyle(Theme.textFaint)
                    .padding(.top, 2)
                    .frame(minWidth: shortcutMinWidth, alignment: .trailing)
            }
        }
        .padding(.horizontal, rowHorizontalPadding)
        .padding(.vertical, rowVerticalPadding)
        .frame(maxWidth: .infinity, minHeight: rowMinHeight, alignment: .leading)
        .background(rowBackground)
        .shadow(color: (isSelected || isHovered) ? Theme.softShadowLight : Color.clear, radius: 12, x: 0, y: 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button(L10n.tr("common.copy")) {
                onCopy()
            }

            Divider()

            Button {
                isEditingTitle = true
            } label: {
                Label(titleText == nil ? L10n.tr("clip.add_title") : L10n.tr("clip.edit_title"), systemImage: "pencil")
            }

            if titleText != nil {
                Button {
                    onUpdateTitle("")
                } label: {
                    Label(L10n.tr("clip.clear_title"), systemImage: "xmark.circle")
                }
            }

            Divider()

            if groupStore.groups.isEmpty {
                Text(L10n.tr("clip.no_custom_groups"))
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
                    Label(L10n.tr("clip.add_to_group"), systemImage: "folder.badge.plus")
                }
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(L10n.tr("common.delete"), systemImage: "trash")
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .sheet(isPresented: $isEditingTitle) {
            ClipboardItemTitleEditor(
                title: titleText ?? "",
                preview: previewText,
                onSave: onUpdateTitle
            )
        }
        .onDrag {
            NSItemProvider(object: item.id.uuidString as NSString)
        }
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: Theme.radiusMd)
                .fill(Theme.selectedBackground)
        } else if isHovered {
            RoundedRectangle(cornerRadius: Theme.radiusMd)
                .fill(Theme.canvas.opacity(0.82))
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var leadingPreview: some View {
        if item.type == .image,
           let filename = item.attachmentFilename,
           let nsImage = ClipboardPreviewImageCache.image(filename: filename, attachmentStore: attachmentStore) {
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
            .foregroundStyle(item.type.themeTint)
            .frame(width: typeIconContainerSize, height: typeIconContainerSize)
    }

    private var metadataChunks: [AnyView] {
        var chunks: [AnyView] = []

        if item.isOversize {
            chunks.append(AnyView(oversizeChip))
        }

        chunks.append(AnyView(Text(relativeTimestamp)))

        if item.sourceAppBundleID != nil {
            chunks.append(AnyView(sourceAppChip))
        }

        if !membershipGroups.isEmpty {
            chunks.append(AnyView(groupChips))
        }

        return chunks
    }

    private var oversizeChip: some View {
        HStack(spacing: 3) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("24h")
        }
        .font(Theme.textXs)
        .foregroundStyle(Theme.sunset)
        .help(L10n.tr("clip.auto_deletes_24h"))
    }

    @ViewBuilder
    private var sourceAppChip: some View {
        if let bundleID = item.sourceAppBundleID {
            HStack(spacing: 3) {
                if let icon = AppIconLoader.icon(forBundleID: bundleID) {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 10, height: 10)
                } else {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 10, weight: .medium))
                        .frame(width: 10, height: 10)
                }

                Text(item.sourceAppName ?? bundleID)
                    .font(Theme.textXs)
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 70, alignment: .leading)
            }
            .help(item.sourceAppName ?? bundleID)
        } else {
            EmptyView()
        }
    }

    private var groupChips: some View {
        HStack(spacing: 3) {
            ForEach(membershipGroups.prefix(3)) { group in
                Image(systemName: group.systemImage)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textMuted)
            }

            if membershipGroups.count > 3 {
                Text("+\(membershipGroups.count - 3)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .help(membershipGroups.map(\.name).joined(separator: ", "))
    }
}

private enum ClipboardPreviewImageCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func image(filename: String, attachmentStore: AttachmentStore) -> NSImage? {
        if let cached = cache.object(forKey: filename as NSString) {
            return cached
        }

        guard let data = attachmentStore.read(filename: filename),
              let image = NSImage(data: data) else {
            return nil
        }

        cache.setObject(image, forKey: filename as NSString)
        return image
    }
}

private struct ClipboardItemTitleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draftTitle: String

    let preview: String
    let onSave: (String) -> Void

    private let editorWidth: CGFloat = 340
    private let editorSpacing: CGFloat = 12

    init(title: String, preview: String, onSave: @escaping (String) -> Void) {
        self._draftTitle = State(initialValue: title)
        self.preview = preview
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: editorSpacing) {
            Text(L10n.tr("title_editor.title"))
                .font(Theme.headingSm)
                .tracking(Theme.headingTracking)
                .foregroundStyle(Theme.text)

            Text(preview)
                .font(Theme.textXs)
                .foregroundStyle(Theme.textMuted)
                .lineLimit(2)
                .truncationMode(.tail)

            TextField(L10n.tr("title_editor.placeholder"), text: $draftTitle)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()

                Button(L10n.tr("common.cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(L10n.tr("common.save")) {
                    onSave(draftTitle)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: editorWidth)
        .background(Theme.contentBackground)
    }
}

private struct MetadataLine: View {
    let chunks: [AnyView]
    let spacing: CGFloat

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(chunks.enumerated()), id: \.offset) { index, chunk in
                if index > 0 {
                    Text("·")
                        .font(Theme.textXs)
                        .fontWeight(.regular)
                        .foregroundStyle(Theme.textFaint)
                }

                chunk
            }
        }
        .lineLimit(1)
        .truncationMode(.tail)
    }
}
