import SwiftUI

struct ClipboardPopoverView: View {
    @ObservedObject var store: ClipboardHistoryStore
    @ObservedObject var groupStore: ClipboardGroupStore
    @ObservedObject var settings: UserSettings
    @State private var searchQuery = ""
    @State private var sidebarSelection: SidebarSelection = .all

    let attachmentStore: AttachmentStore
    let onSelect: (ClipboardHistoryItem) -> Void
    let onClose: () -> Void

    private let popoverWidth: CGFloat = 600
    private let popoverHeight: CGFloat = 520
    private let contentWidth: CGFloat = 420
    private let paneSpacing: CGFloat = 0
    private let headerSpacing: CGFloat = 12
    private let headerHorizontalPadding: CGFloat = 16
    private let headerTopPadding: CGFloat = 12
    private let headerBottomPadding: CGFloat = 12
    private let headerDividerHeight: CGFloat = 1
    private let headerDividerOpacity: Double = 0.08
    private let countHorizontalPadding: CGFloat = 8
    private let countVerticalPadding: CGFloat = 4
    private let searchSpacing: CGFloat = 8
    private let searchIconSize: CGFloat = 13
    private let searchHorizontalPadding: CGFloat = 10
    private let searchVerticalPadding: CGFloat = 8
    private let searchCornerRadius: CGFloat = 8
    private let subtleBackgroundOpacity: Double = 0.04
    private let listSpacing: CGFloat = 0
    private let listHorizontalPadding: CGFloat = 16
    private let listVerticalPadding: CGFloat = 12
    private let rowWhitespacePadding: CGFloat = 2
    private let rowWhitespaceHeight: CGFloat = 0
    private let footerHorizontalPadding: CGFloat = 16
    private let footerTopPadding: CGFloat = 12
    private let footerBottomPadding: CGFloat = 10
    private let footerGearSize: CGFloat = 14
    private let emptyStateSpacing: CGFloat = 8
    private let emptyStateIconSize: CGFloat = 28
    private let emptyStatePadding: CGFloat = 24
    private let hiddenHotkeySize: CGFloat = 0
    private let hiddenHotkeyOpacity: Double = 0

    private var countFont: Font {
        .system(.caption2, design: .monospaced).monospacedDigit()
    }

    private var retentionHintFont: Font {
        .system(.caption2)
    }

    private var trimmedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sidebarFilteredItems: [ClipboardHistoryItem] {
        switch sidebarSelection {
        case .all:
            return store.items
        case .contentType(let type):
            return store.items.filter { $0.type == type }
        case .group(let groupID):
            guard let group = groupStore.groups.first(where: { $0.id == groupID }) else {
                return []
            }

            let itemIDs = Set(group.itemIDs)
            return store.items.filter { itemIDs.contains($0.id) }
        }
    }

    private var filteredItems: [ClipboardHistoryItem] {
        guard !trimmedSearchQuery.isEmpty else {
            return sidebarFilteredItems
        }

        return sidebarFilteredItems.filter { item in
            item.content.range(
                of: trimmedSearchQuery,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) != nil
        }
    }

    private var protectedIDs: Set<UUID> {
        Set(groupStore.groups.flatMap(\.itemIDs))
    }

    private var clearableItems: [ClipboardHistoryItem] {
        sidebarFilteredItems.filter { !protectedIDs.contains($0.id) }
    }

    private var listTitle: String {
        switch sidebarSelection {
        case .all:
            return "Clipboard"
        case .contentType(let type):
            return type.displayName
        case .group(let groupID):
            return groupStore.groups.first(where: { $0.id == groupID })?.name ?? "Clipboard"
        }
    }

    private var clearScopeLabel: String {
        switch sidebarSelection {
        case .all:
            return "Clear Unfiled"
        case .contentType(let type):
            return "Clear \(type.displayName)"
        case .group:
            return ""
        }
    }

    private var shouldShowClearButton: Bool {
        if case .group = sidebarSelection {
            return false
        }

        return true
    }

    private func performScopedClear() {
        let ids = clearableItems.map(\.id)
        guard !ids.isEmpty else {
            return
        }

        store.remove(ids: ids)
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()

            HStack(spacing: paneSpacing) {
                SidebarView(
                    historyStore: store,
                    groupStore: groupStore,
                    selection: $sidebarSelection
                )

                VStack(spacing: paneSpacing) {
                    header

                    listSection

                    footer
                }
                .frame(width: contentWidth, height: popoverHeight)
            }
            .frame(width: popoverWidth, height: popoverHeight)

            hotkeyButtons
        }
        .frame(width: popoverWidth, height: popoverHeight)
        .onExitCommand {
            onClose()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: headerSpacing) {
            HStack {
                Text(listTitle)
                    .font(.system(.subheadline, weight: .semibold))

                Spacer()

                Text("\(filteredItems.count)")
                    .font(countFont)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, countHorizontalPadding)
                    .padding(.vertical, countVerticalPadding)
            }

            searchField
        }
        .padding(.horizontal, headerHorizontalPadding)
        .padding(.top, headerTopPadding)
        .padding(.bottom, headerBottomPadding)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(headerDividerOpacity))
                .frame(height: headerDividerHeight)
        }
    }

    private var searchField: some View {
        HStack(spacing: searchSpacing) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: searchIconSize, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Search clipboard…", text: $searchQuery)
                .textFieldStyle(.plain)

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, searchHorizontalPadding)
        .padding(.vertical, searchVerticalPadding)
        .background(
            RoundedRectangle(cornerRadius: searchCornerRadius)
                .fill(Color.primary.opacity(subtleBackgroundOpacity))
        )
    }

    @ViewBuilder
    private var listSection: some View {
        if sidebarFilteredItems.isEmpty {
            switch sidebarSelection {
            case .all:
                emptyState(
                    systemImage: "doc.on.clipboard",
                    title: "No history yet",
                    hint: "Copy something to get started"
                )
            case .contentType(let type):
                emptyState(
                    systemImage: type.systemImage,
                    title: "No items of type \(type.displayName)",
                    hint: "Copy something to add"
                )
            case .group:
                emptyState(
                    systemImage: "folder",
                    title: "Group is empty",
                    hint: "Right-click an item to add it"
                )
            }
        } else if filteredItems.isEmpty {
            emptyState(
                systemImage: "magnifyingglass",
                title: "No matches",
                hint: "No results for '\(trimmedSearchQuery)'"
            )
        } else {
            ScrollView {
                LazyVStack(spacing: listSpacing) {
                    ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                        ClipboardHistoryRowView(
                            item: item,
                            shortcutLabel: shortcutLabel(for: index),
                            groupStore: groupStore,
                            attachmentStore: attachmentStore,
                            onCopy: { onSelect(item) },
                            onDelete: { store.remove(id: item.id) }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(item)
                        }

                        if index < filteredItems.count - 1 {
                            Color.clear
                                .frame(height: rowWhitespaceHeight)
                                .padding(.vertical, rowWhitespacePadding)
                        }
                    }
                }
                .padding(.horizontal, listHorizontalPadding)
                .padding(.vertical, listVerticalPadding)
            }
        }
    }

    private var footer: some View {
        HStack {
            if shouldShowClearButton {
                Button(clearScopeLabel) {
                    performScopedClear()
                }
                    .disabled(clearableItems.isEmpty)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                Section("Keep History For") {
                    ForEach(RetentionPolicy.allCases) { policy in
                        Button {
                            settings.retentionPolicy = policy
                        } label: {
                            if settings.retentionPolicy == policy {
                                Label(policy.displayName, systemImage: "checkmark")
                            } else {
                                Text(policy.displayName)
                            }
                        }
                    }
                }
                Divider()
                Text("Items in custom groups never expire")
                    .font(retentionHintFont)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: footerGearSize, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, footerHorizontalPadding)
        .padding(.top, footerTopPadding)
        .padding(.bottom, footerBottomPadding)
    }

    private var hotkeyButtons: some View {
        VStack {
            ForEach(0..<10, id: \.self) { index in
                Button("") {
                    selectFilteredItem(at: index)
                }
                .keyboardShortcut(KeyEquivalent(Character(index == 9 ? "0" : "\(index + 1)")), modifiers: .command)
            }
        }
        .frame(width: hiddenHotkeySize, height: hiddenHotkeySize)
        .opacity(hiddenHotkeyOpacity)
        .accessibilityHidden(true)
    }

    private func selectFilteredItem(at index: Int) {
        guard filteredItems.indices.contains(index) else { return }

        onSelect(filteredItems[index])
    }

    private func shortcutLabel(for index: Int) -> String? {
        guard index < 10 else { return nil }

        return "⌘\(index == 9 ? 0 : index + 1)"
    }

    private func emptyState(systemImage: String, title: String, hint: String) -> some View {
        VStack(spacing: emptyStateSpacing) {
            Spacer(minLength: 0)

            Image(systemName: systemImage)
                .font(.system(size: emptyStateIconSize))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.system(.subheadline, weight: .semibold))

            Text(hint)
                .font(.system(.caption2))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(emptyStatePadding)
    }
}
