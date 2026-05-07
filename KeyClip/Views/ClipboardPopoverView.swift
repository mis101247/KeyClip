import SwiftUI

struct ClipboardPopoverView: View {
    @ObservedObject var store: ClipboardHistoryStore
    @ObservedObject var groupStore: ClipboardGroupStore
    @ObservedObject var settings: UserSettings
    @State private var searchQuery: String = ""
    @State private var sidebarSelection: SidebarSelection = .all
    @State private var showClearConfirmation = false

    let attachmentStore: AttachmentStore
    let onSelect: (ClipboardHistoryItem) -> Void
    let onClose: () -> Void

    private let popoverWidth: CGFloat = 600
    private let popoverHeight: CGFloat = 520
    private let contentWidth: CGFloat = 400
    private let paneSpacing: CGFloat = 0
    private let headerHorizontalPadding: CGFloat = 16
    private let headerTopPadding: CGFloat = 12
    private let headerBottomPadding: CGFloat = 8
    private let listSpacing: CGFloat = 0
    private let listVerticalPadding: CGFloat = 0
    private let footerHorizontalPadding: CGFloat = 16
    private let footerVerticalPadding: CGFloat = 8
    private let footerGearSize: CGFloat = 14
    private let emptyStateSpacing: CGFloat = 8
    private let emptyStateIconSize: CGFloat = 28
    private let emptyStatePadding: CGFloat = 24
    private let hiddenHotkeySize: CGFloat = 0
    private let hiddenHotkeyOpacity: Double = 0

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
            return "All"
        case .contentType(let type):
            return type.displayName
        case .group(let groupID):
            return groupStore.groups.first(where: { $0.id == groupID })?.name ?? "All"
        }
    }

    private var clearScopeLabel: String {
        switch sidebarSelection {
        case .all:
            return "Clear All"
        case .contentType(let type):
            return "Clear all in \(type.displayName) type"
        case .group:
            return ""
        }
    }

    private var clearConfirmationTitle: String {
        switch sidebarSelection {
        case .all:
            return "Clear all clipboard items?"
        case .contentType(let type):
            return "Clear all \(type.displayName) items?"
        case .group:
            return ""
        }
    }

    private var clearConfirmationMessage: String {
        let count = clearableItems.count
        let noun = count == 1 ? "item" : "items"
        return "\(count) \(noun) will be removed. Items in custom groups will be kept."
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
                .fill(Theme.bg)
                .ignoresSafeArea()

            HStack(spacing: paneSpacing) {
                SidebarView(
                    historyStore: store,
                    groupStore: groupStore,
                    searchQuery: $searchQuery,
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
        .alert(
            clearConfirmationTitle,
            isPresented: $showClearConfirmation
        ) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                performScopedClear()
            }
        } message: {
            Text(clearConfirmationMessage)
        }
    }

    private var header: some View {
        HStack {
            Text(listTitle)
                .font(Theme.textSmEmphasis)
                .foregroundStyle(Theme.text)

            Spacer()

            Text("\(filteredItems.count)")
                .font(Theme.textXs)
                .foregroundStyle(Theme.textFaint)
        }
        .padding(.horizontal, headerHorizontalPadding)
        .padding(.top, headerTopPadding)
        .padding(.bottom, headerBottomPadding)
        .background(Theme.bg)
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
                            Divider()
                                .background(Theme.divider)
                        }
                    }
                }
                .padding(.vertical, listVerticalPadding)
            }
            .background(Theme.bg)
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Theme.divider)

            HStack {
                if shouldShowClearButton {
                    Button {
                        showClearConfirmation = true
                    } label: {
                        Text(clearScopeLabel)
                    }
                    .disabled(clearableItems.isEmpty)
                    .buttonStyle(.plain)
                    .font(Theme.textXs)
                    .foregroundStyle(Theme.textMuted)
                    .modifier(FooterHoverBackground())
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
                        .foregroundStyle(Theme.textMuted)
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.plain)
                .fixedSize()
                .modifier(FooterHoverBackground())

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Text("Quit")
                }
                .buttonStyle(.plain)
                .font(Theme.textXs)
                .foregroundStyle(Theme.textMuted)
                .modifier(FooterHoverBackground())
            }
            .padding(.horizontal, footerHorizontalPadding)
            .padding(.vertical, footerVerticalPadding)
        }
        .background(Theme.bg)
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
                .foregroundStyle(Theme.textFaint)

            Text(title)
                .font(Theme.textSmEmphasis)
                .foregroundStyle(Theme.text)

            Text(hint)
                .font(Theme.textXs)
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(emptyStatePadding)
        .background(Theme.bg)
    }
}

private struct FooterHoverBackground: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 6)
            .frame(height: 24)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSm)
                    .fill(isHovered ? Theme.surfaceOffset : Color.clear)
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
