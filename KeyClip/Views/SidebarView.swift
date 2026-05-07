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
            Color(nsColor: .underPageBackgroundColor)
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    allSection
                    contentTypesSection
                    groupsSection
                }
                .padding(.vertical, 10)
            }

            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 1)
        }
        .frame(width: 180)
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
                .padding(.top, 8)

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
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "GROUPS") {
                Button {
                    startAddingGroup()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help("New group")
            }
            .padding(.top, 8)

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
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 22, height: 22)
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
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .padding(.horizontal, 8)
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

    init(title: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            trailing()
        }
        .padding(.horizontal, 10)
        .frame(height: 22)
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

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : tintColor)
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 13))
                    .lineLimit(1)

                Spacer(minLength: 4)

                if isHovered {
                    trailingMenu()
                } else {
                    Text("\(count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                }
            }
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
            .padding(.leading, 10)
            .padding(.trailing, 8)
            .frame(height: 30)
            .background(rowBackground)
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(width: 4)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor.opacity(0.18))
        } else if isHovered {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
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
