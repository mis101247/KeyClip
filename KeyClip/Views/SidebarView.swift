import SwiftUI
import UniformTypeIdentifiers

enum SidebarSelection: Hashable {
    case all
    case tags
    case contentType(ContentType)
    case group(UUID)
}

struct SidebarView: View {
    @ObservedObject var historyStore: ClipboardHistoryStore
    @ObservedObject var groupStore: ClipboardGroupStore
    @Binding var searchQuery: String
    @Binding var selection: SidebarSelection

    @State private var isAddingGroup = false
    @State private var newGroupName = ""
    @State private var renamingGroupID: UUID?
    @State private var renameDraft = ""
    @State private var dropTargetGroupID: UUID?
    @FocusState private var focusedField: FocusedField?
    @FocusState private var isSearchFocused: Bool

    private let sidebarWidth: CGFloat = 200
    private let sectionSpacing: CGFloat = 4
    private let scrollBottomPadding: CGFloat = 12
    private let sidebarDividerWidth: CGFloat = 1
    private let addIconSize: CGFloat = 14
    private let addButtonSize: CGFloat = 22
    private let menuIconSize: CGFloat = 12
    private let menuButtonSize: CGFloat = 22
    private let textFieldHorizontalPadding: CGFloat = 10
    private let textFieldHeight: CGFloat = 28
    private let textFieldOuterHorizontalPadding: CGFloat = 8

    private var taggedItemsCount: Int {
        historyStore.items.filter(\.hasTitle).count
    }

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
                .fill(Theme.surface)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                sidebarHeader
                searchField

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: sectionSpacing) {
                        allSection
                        contentTypesSection
                        groupsSection
                    }
                    .padding(.bottom, scrollBottomPadding)
                }
            }

            Rectangle()
                .fill(Theme.divider)
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

    private var sidebarHeader: some View {
        HStack(spacing: 8) {
            Text("Clipboard")
                .font(Theme.textSmEmphasis)
                .foregroundStyle(Theme.text)

            Spacer(minLength: 4)

            CountBadge(count: historyStore.items.count)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var searchField: some View {
        TextField("Search clipboard…", text: $searchQuery)
            .textFieldStyle(.plain)
            .focused($isSearchFocused)
            .font(Theme.textXs)
            .foregroundStyle(Theme.text)
            .padding(.leading, 26)
            .padding(.trailing, 8)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSm)
                    .fill(Theme.surface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusSm)
                            .stroke(isSearchFocused ? Theme.primary : Theme.border, lineWidth: 1)
                    )
            )
            .overlay(alignment: .leading) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textFaint)
                    .padding(.leading, 8)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
    }

    private var allSection: some View {
        SidebarRow(
            systemImage: "tray.full",
            title: "All",
            count: historyStore.items.count,
            tintColor: Theme.textMuted,
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

            ForEach(visibleTypes, id: \.0) { type, count in
                SidebarRow(
                    systemImage: type.systemImage,
                    title: type.displayName,
                    count: count,
                    tintColor: type.themeTint,
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
                        .font(.system(size: addIconSize, weight: .regular))
                        .foregroundStyle(Theme.textFaint)
                        .frame(width: addButtonSize, height: addButtonSize)
                }
                .buttonStyle(.plain)
                .modifier(SidebarHoverBackground())
                .help("New group")
            }

            if isAddingGroup {
                groupTextField(
                    text: $newGroupName,
                    focus: .newGroup,
                    onSubmit: commitNewGroup,
                    onCancel: cancelAddingGroup
                )
            }

            tagsRow

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

    private var tagsRow: some View {
        SidebarRow(
            systemImage: "tag.fill",
            title: "Tags",
            count: taggedItemsCount,
            tintColor: Theme.primary,
            isSelected: selection == .tags
        ) {
            selection = .tags
        }
    }

    private func groupRow(_ group: ClipboardGroup) -> some View {
        SidebarRow(
            systemImage: group.systemImage,
            title: group.name,
            count: group.itemIDs.count,
            tintColor: Theme.textMuted,
            isSelected: selection == .group(group.id),
            backgroundFill: dropTargetGroupID == group.id
                ? Theme.primary.opacity(0.18)
                : nil,
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
        .onDrop(of: [UTType.text.identifier], isTargeted: Binding(
            get: { dropTargetGroupID == group.id },
            set: { isTarget in
                dropTargetGroupID = isTarget ? group.id : (dropTargetGroupID == group.id ? nil : dropTargetGroupID)
            }
        )) { providers in
            handleDrop(providers: providers, into: group.id)
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
                RoundedRectangle(cornerRadius: Theme.radiusSm)
                    .fill(Theme.surface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusSm)
                            .stroke(Theme.border, lineWidth: 1)
                    )
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

    private func handleDrop(providers: [NSItemProvider], into groupID: UUID) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let raw = object as? String, let id = UUID(uuidString: raw) else { return }
            DispatchQueue.main.async {
                groupStore.addItem(id, to: groupID)
            }
        }
        return true
    }
}

private struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    private let headerSpacing: CGFloat = 6
    private let horizontalPadding: CGFloat = 8
    private let trackingAmount: CGFloat = 0.96

    init(title: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: headerSpacing) {
            Text(title)
                .font(Theme.textXs)
                .tracking(trackingAmount)
                .foregroundStyle(Theme.textFaint)

            Spacer()

            trailing()
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 4)
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
    let backgroundFill: Color?
    @ViewBuilder var trailingMenu: () -> TrailingMenu
    let action: () -> Void

    @State private var isHovered = false

    private let rowSpacing: CGFloat = 8
    private let rowHorizontalPadding: CGFloat = 10
    private let rowOuterHorizontalPadding: CGFloat = 8
    private let rowIconSize: CGFloat = 13
    private let rowIconWidth: CGFloat = 16
    private let spacerMinLength: CGFloat = 4

    var body: some View {
        Button(action: action) {
            HStack(spacing: rowSpacing) {
                Image(systemName: systemImage)
                    .font(.system(size: rowIconSize, weight: .medium))
                    .foregroundStyle(isSelected ? Theme.primary : tintColor)
                    .frame(width: rowIconWidth)

                Text(title)
                    .font(Theme.textSm)
                    .fontWeight(isSelected ? .medium : .regular)
                    .foregroundStyle(isSelected ? Theme.primary : Theme.textMuted)
                    .lineLimit(1)

                Spacer(minLength: spacerMinLength)

                if isHovered {
                    trailingMenu()
                } else {
                    CountBadge(count: count)
                }
            }
            .padding(.horizontal, rowHorizontalPadding)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSm)
                    .fill(
                        backgroundFill
                            ?? (isHovered ? Theme.surfaceOffset : Color.clear)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .padding(.horizontal, rowOuterHorizontalPadding)
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
            backgroundFill: nil,
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

private struct CountBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(Theme.textXs)
            .foregroundStyle(Theme.textMuted)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusFull)
                    .fill(Theme.surfaceOffset)
            )
    }
}

private struct SidebarHoverBackground: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSm)
                    .fill(isHovered ? Theme.surfaceOffset : Color.clear)
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
