import SwiftUI

enum SidebarSelection: Hashable {
    case all
    case contentType(ContentType)
    case group(UUID)
}

struct SidebarView: View {
    @ObservedObject var historyStore: ClipboardHistoryStore
    @ObservedObject var groupStore: ClipboardGroupStore
    @Binding var selection: SidebarSelection

    @State private var isAddingGroup = false
    @State private var newGroupName = ""
    @State private var renamingGroupID: UUID?
    @State private var renameDraft = ""
    @FocusState private var focusedField: FocusedField?

    private let sidebarWidth: CGFloat = 180
    private let sectionSpacing: CGFloat = 4
    private let scrollVerticalPadding: CGFloat = 12
    private let sectionTopPadding: CGFloat = 8
    private let sidebarDividerWidth: CGFloat = 1
    private let sidebarDividerOpacity: Double = 0.08
    private let addIconSize: CGFloat = 11
    private let addButtonSize: CGFloat = 18
    private let menuIconSize: CGFloat = 12
    private let menuButtonSize: CGFloat = 22
    private let textFieldHorizontalPadding: CGFloat = 10
    private let textFieldHeight: CGFloat = 28
    private let textFieldCornerRadius: CGFloat = 6
    private let textFieldOuterHorizontalPadding: CGFloat = 8

    private let iconChoices = [
        "folder",
        "star",
        "heart",
        "bookmark",
        "tag",
        "tray",
        "paperclip",
        "archivebox"
    ]

    var body: some View {
        ZStack(alignment: .trailing) {
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: sectionSpacing) {
                    allSection
                    contentTypesSection
                    groupsSection
                }
                .padding(.vertical, scrollVerticalPadding)
            }

            Rectangle()
                .fill(Color.primary.opacity(sidebarDividerOpacity))
                .frame(width: sidebarDividerWidth)
        }
        .frame(width: sidebarWidth)
        .onChange(of: isAddingGroup) { isAdding in
            guard isAdding else { return }

            DispatchQueue.main.async {
                focusedField = .newGroup
            }
        }
        .onChange(of: renamingGroupID) { groupID in
            guard let groupID else { return }

            DispatchQueue.main.async {
                focusedField = .renameGroup(groupID)
            }
        }
    }

    private var allSection: some View {
        SidebarRow(
            systemImage: "tray.full",
            title: "All",
            count: historyStore.items.count,
            tintColor: .accentColor,
            isSelected: selection == .all
        ) {
            selection = .all
        }
    }

    @ViewBuilder
    private var contentTypesSection: some View {
        let visibleTypes = ContentType.allCases.compactMap { type -> (ContentType, Int)? in
            let count = historyStore.items.filter { $0.type == type }.count
            return count > 0 ? (type, count) : nil
        }

        if !visibleTypes.isEmpty {
            SectionHeader(title: "CONTENT TYPES")
                .padding(.top, sectionTopPadding)

            ForEach(visibleTypes, id: \.0) { type, count in
                SidebarRow(
                    systemImage: type.systemImage,
                    title: type.displayName,
                    count: count,
                    tintColor: type.tintColor,
                    isSelected: selection == .contentType(type)
                ) {
                    selection = .contentType(type)
                }
            }
        }
    }

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            SectionHeader(title: "GROUPS") {
                Button {
                    startAddingGroup()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: addIconSize, weight: .semibold))
                        .frame(width: addButtonSize, height: addButtonSize)
                }
                .buttonStyle(.plain)
                .help("New group")
            }
            .padding(.top, sectionTopPadding)

            if isAddingGroup {
                groupTextField(
                    text: $newGroupName,
                    focus: .newGroup,
                    onSubmit: commitNewGroup,
                    onCancel: cancelAddingGroup
                )
            }

            ForEach(groupStore.groups) { group in
                if renamingGroupID == group.id {
                    groupTextField(
                        text: $renameDraft,
                        focus: .renameGroup(group.id),
                        onSubmit: { commitRename(for: group.id) },
                        onCancel: cancelRename
                    )
                } else {
                    groupRow(group)
                }
            }
        }
    }

    private func groupRow(_ group: ClipboardGroup) -> some View {
        SidebarRow(
            systemImage: group.systemImage,
            title: group.name,
            count: group.itemIDs.count,
            tintColor: .secondary,
            isSelected: selection == .group(group.id),
            trailingMenu: {
                groupActionsMenu(for: group, labelStyle: .ellipsis)
            },
            action: {
                selection = .group(group.id)
            }
        )
        .contextMenu {
            groupActionItems(for: group)
        }
    }

    private func groupActionsMenu(for group: ClipboardGroup, labelStyle: GroupActionMenuLabelStyle) -> some View {
        Menu {
            groupActionItems(for: group)
        } label: {
            switch labelStyle {
            case .ellipsis:
                Image(systemName: "ellipsis")
                    .font(.system(size: menuIconSize, weight: .semibold))
                    .frame(width: menuButtonSize, height: menuButtonSize)
            case .text:
                Text("Actions")
            }
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .help("Group actions")
    }

    @ViewBuilder
    private func groupActionItems(for group: ClipboardGroup) -> some View {
        Button("Rename") {
            startRenaming(group)
        }

        Menu("Change Icon") {
            ForEach(iconChoices, id: \.self) { systemImage in
                Button {
                    groupStore.updateIcon(id: group.id, to: systemImage)
                } label: {
                    Label(systemImage, systemImage: systemImage)
                }
            }
        }

        Divider()

        Button("Delete", role: .destructive) {
            groupStore.deleteGroup(id: group.id)
            if selection == .group(group.id) {
                selection = .all
            }
        }
    }

    private func groupTextField(
        text: Binding<String>,
        focus: FocusedField,
        onSubmit: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        TextField("Group name", text: text)
            .textFieldStyle(.plain)
            .focused($focusedField, equals: focus)
            .onSubmit(onSubmit)
            .onExitCommand(perform: onCancel)
            .padding(.horizontal, textFieldHorizontalPadding)
            .frame(height: textFieldHeight)
            .background(
                RoundedRectangle(cornerRadius: textFieldCornerRadius)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .padding(.horizontal, textFieldOuterHorizontalPadding)
    }

    private func startAddingGroup() {
        renamingGroupID = nil
        renameDraft = ""
        newGroupName = ""
        isAddingGroup = true
    }

    private func commitNewGroup() {
        let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            cancelAddingGroup()
            return
        }

        let group = groupStore.createGroup(name: name)
        selection = .group(group.id)
        cancelAddingGroup()
    }

    private func cancelAddingGroup() {
        isAddingGroup = false
        newGroupName = ""
        focusedField = nil
    }

    private func startRenaming(_ group: ClipboardGroup) {
        isAddingGroup = false
        newGroupName = ""
        renameDraft = group.name
        renamingGroupID = group.id
    }

    private func commitRename(for groupID: UUID) {
        let name = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            cancelRename()
            return
        }

        groupStore.renameGroup(id: groupID, to: name)
        cancelRename()
    }

    private func cancelRename() {
        renamingGroupID = nil
        renameDraft = ""
        focusedField = nil
    }
}

private struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    private let headerSpacing: CGFloat = 6
    private let horizontalPadding: CGFloat = 10
    private let headerHeight: CGFloat = 22
    private let trackingAmount: CGFloat = 0.5

    init(title: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: headerSpacing) {
            Text(title)
                .font(.system(.caption2, weight: .semibold))
                .tracking(trackingAmount)
                .foregroundStyle(.tertiary)

            Spacer()

            trailing()
        }
        .padding(.horizontal, horizontalPadding)
        .frame(height: headerHeight)
    }
}

private extension SectionHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) {
            EmptyView()
        }
    }
}

private struct SidebarRow<TrailingMenu: View>: View {
    let systemImage: String
    let title: String
    let count: Int
    let tintColor: Color
    let isSelected: Bool
    @ViewBuilder var trailingMenu: () -> TrailingMenu
    let action: () -> Void

    @State private var isHovered = false

    private let rowSpacing: CGFloat = 8
    private let rowHorizontalPadding: CGFloat = 10
    private let rowOuterHorizontalPadding: CGFloat = 8
    private let rowHeight: CGFloat = 28
    private let rowCornerRadius: CGFloat = 6
    private let rowIconSize: CGFloat = 13
    private let rowIconWidth: CGFloat = 16
    private let rowTitleSize: CGFloat = 13
    private let spacerMinLength: CGFloat = 4
    private let selectedBackgroundOpacity: Double = 0.12
    private let hoverBackgroundOpacity: Double = 0.04

    var body: some View {
        Button(action: action) {
            HStack(spacing: rowSpacing) {
                Image(systemName: systemImage)
                    .font(.system(size: rowIconSize, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : tintColor)
                    .frame(width: rowIconWidth)

                Text(title)
                    .font(.system(size: rowTitleSize))
                    .lineLimit(1)

                Spacer(minLength: spacerMinLength)

                if isHovered {
                    trailingMenu()
                } else {
                    Text("\(count)")
                        .font(.system(.caption2, design: .monospaced).monospacedDigit())
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                }
            }
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
            .padding(.horizontal, rowHorizontalPadding)
            .frame(maxWidth: .infinity, minHeight: rowHeight, maxHeight: rowHeight, alignment: .leading)
            .background(rowBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .padding(.horizontal, rowOuterHorizontalPadding)
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: rowCornerRadius)
                .fill(Color.accentColor.opacity(selectedBackgroundOpacity))
        } else if isHovered {
            RoundedRectangle(cornerRadius: rowCornerRadius)
                .fill(Color.primary.opacity(hoverBackgroundOpacity))
        } else {
            Color.clear
        }
    }
}

private extension SidebarRow where TrailingMenu == EmptyView {
    init(
        systemImage: String,
        title: String,
        count: Int,
        tintColor: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.init(
            systemImage: systemImage,
            title: title,
            count: count,
            tintColor: tintColor,
            isSelected: isSelected,
            trailingMenu: {
                EmptyView()
            },
            action: action
        )
    }
}

private enum FocusedField: Hashable {
    case newGroup
    case renameGroup(UUID)
}

private enum GroupActionMenuLabelStyle {
    case ellipsis
    case text
}
