import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ClipboardPopoverView: View {
    @ObservedObject var store: ClipboardHistoryStore
    @ObservedObject var groupStore: ClipboardGroupStore
    @ObservedObject var settings: UserSettings
    @State private var searchQuery: String = ""
    @State private var sidebarSelection: SidebarSelection = .all
    @State private var showClearConfirmation = false
    @State private var selectedItemID: UUID?

    let attachmentStore: AttachmentStore
    let onSelect: (ClipboardHistoryItem) -> Void
    let onClose: () -> Void
    let onOpenSettings: () -> Void

    private let popoverWidth: CGFloat = 600
    private let popoverHeight: CGFloat = 520
    private let contentWidth: CGFloat = 400
    private let paneSpacing: CGFloat = 0
    private let headerHorizontalPadding: CGFloat = 16
    private let headerTopPadding: CGFloat = 12
    private let headerBottomPadding: CGFloat = 8
    private let listSpacing: CGFloat = 4
    private let listVerticalPadding: CGFloat = 8
    private let footerHorizontalPadding: CGFloat = 16
    private let footerVerticalPadding: CGFloat = 8
    private let footerGearSize: CGFloat = 14
    private let emptyStateSpacing: CGFloat = 8
    private let emptyStateIconSize: CGFloat = 28
    private let emptyStatePadding: CGFloat = 24
    private let hiddenHotkeySize: CGFloat = 0
    private let hiddenHotkeyOpacity: Double = 0
    private let selectionScrollAnchor: UnitPoint = .center

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
        case .tags:
            return store.items.filter(\.hasTitle)
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
            let searchableText = [item.title, item.content]
                .compactMap { $0 }
                .joined(separator: "\n")

            return searchableText.range(
                of: trimmedSearchQuery,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) != nil
        }
    }

    private var protectedIDs: Set<UUID> {
        Set(groupStore.groups.flatMap(\.itemIDs)).union(store.titledItemIDs)
    }

    private var clearableItems: [ClipboardHistoryItem] {
        sidebarFilteredItems.filter { !protectedIDs.contains($0.id) }
    }

    private var listTitle: String {
        switch sidebarSelection {
        case .all:
            return "All"
        case .tags:
            return "Tags"
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
        case .tags:
            return ""
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
        case .tags:
            return ""
        case .contentType(let type):
            return "Clear all \(type.displayName) items?"
        case .group:
            return ""
        }
    }

    private var clearConfirmationMessage: String {
        let count = clearableItems.count
        let noun = count == 1 ? "item" : "items"
        return "\(count) \(noun) will be removed. Items in Tags or custom groups will be kept."
    }

    private var shouldShowClearButton: Bool {
        if case .tags = sidebarSelection {
            return false
        }

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
                .fill(Theme.contentBackground)
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
        .onAppear {
            reconcileSelection()
        }
        .onChange(of: filteredItems) { _ in
            reconcileSelection()
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
                .font(Theme.headingSm)
                .tracking(Theme.headingTracking)
                .foregroundStyle(Theme.text)

            Spacer()

            Text("\(filteredItems.count)")
                .font(Theme.textXs)
                .foregroundStyle(Theme.textFaint)
        }
        .padding(.horizontal, headerHorizontalPadding)
        .padding(.top, headerTopPadding)
        .padding(.bottom, headerBottomPadding)
        .background(Theme.canvas.opacity(0.72))
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
            case .tags:
                emptyState(
                    systemImage: "tag",
                    title: "No tags yet",
                    hint: "Right-click an item to add a title"
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
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: listSpacing) {
                        ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                            ClipboardHistoryRowView(
                                item: item,
                                shortcutLabel: shortcutLabel(for: index),
                                isSelected: item.id == selectedItemID,
                                groupStore: groupStore,
                                attachmentStore: attachmentStore,
                                onCopy: { onSelect(item) },
                                onUpdateTitle: { title in store.updateTitle(id: item.id, title: title) },
                                onDelete: { store.remove(id: item.id) }
                            )
                            .id(item.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedItemID = item.id
                                onSelect(item)
                            }

                            if index < filteredItems.count - 1 {
                                Divider()
                                    .background(Theme.divider)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, listVerticalPadding)
                }
                .background(Theme.contentBackground)
                .onChange(of: selectedItemID) { id in
                    guard let id else { return }
                    withAnimation(.easeInOut(duration: 0.12)) {
                        proxy.scrollTo(id, anchor: selectionScrollAnchor)
                    }
                }
            }
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

                Button {
                    onOpenSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: footerGearSize, weight: .regular))
                        .foregroundStyle(Theme.textMuted)
                }
                .buttonStyle(.plain)
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
        .background(Theme.canvas.opacity(0.76))
    }

    private var hotkeyButtons: some View {
        VStack {
            ForEach(0..<10, id: \.self) { index in
                Button("") {
                    selectFilteredItem(at: index)
                }
                .keyboardShortcut(KeyEquivalent(Character(index == 9 ? "0" : "\(index + 1)")), modifiers: .command)
            }

            Button("") {
                moveSelection(delta: -1)
            }
            .keyboardShortcut(.upArrow, modifiers: [])

            Button("") {
                moveSelection(delta: 1)
            }
            .keyboardShortcut(.downArrow, modifiers: [])

            Button("") {
                selectHighlightedItem()
            }
            .keyboardShortcut(.return, modifiers: [])
        }
        .frame(width: hiddenHotkeySize, height: hiddenHotkeySize)
        .opacity(hiddenHotkeyOpacity)
        .accessibilityHidden(true)
    }

    private func selectFilteredItem(at index: Int) {
        guard filteredItems.indices.contains(index) else { return }

        onSelect(filteredItems[index])
    }

    private func reconcileSelection() {
        guard !filteredItems.isEmpty else {
            selectedItemID = nil
            return
        }

        if let selectedItemID,
           filteredItems.contains(where: { $0.id == selectedItemID }) {
            return
        }

        selectedItemID = filteredItems[0].id
    }

    private func moveSelection(delta: Int) {
        guard !filteredItems.isEmpty else { return }

        guard let selectedItemID,
              let currentIndex = filteredItems.firstIndex(where: { $0.id == selectedItemID }) else {
            self.selectedItemID = filteredItems[0].id
            return
        }

        let nextIndex = min(max(currentIndex + delta, 0), filteredItems.count - 1)
        self.selectedItemID = filteredItems[nextIndex].id
    }

    private func selectHighlightedItem() {
        guard !filteredItems.isEmpty else { return }

        if let selectedItemID,
           let item = filteredItems.first(where: { $0.id == selectedItemID }) {
            onSelect(item)
            return
        }

        onSelect(filteredItems[0])
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
                .font(Theme.headingSm)
                .tracking(Theme.headingTracking)
                .foregroundStyle(Theme.text)

            Text(hint)
                .font(Theme.textXs)
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(emptyStatePadding)
        .background(Theme.contentBackground)
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
                    .fill(isHovered ? Theme.honey.opacity(0.34) : Color.clear)
            )
            .shadow(color: isHovered ? Theme.softShadowLight : Color.clear, radius: 10, x: 0, y: 4)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case exclusion
    case statistics
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "通用"
        case .exclusion: return "排除規則"
        case .statistics: return "統計"
        case .about: return "關於"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .exclusion: return "hand.raised.slash"
        case .statistics: return "chart.bar"
        case .about: return "info.circle"
        }
    }
}

struct SettingsPanelView: View {
    @ObservedObject var settings: UserSettings
    @ObservedObject var historyStore: ClipboardHistoryStore
    @State private var selectedTab: SettingsTab = .general
    @State private var selectedExcludedAppID: String?

    private let minPanelWidth: CGFloat = 760
    private let minPanelHeight: CGFloat = 520
    private let toolbarIconSize: CGFloat = 30
    private let contentInset: CGFloat = 28
    private let listHeight: CGFloat = 220
    private let maxCaptureByteOptions = [
        1 * 1024 * 1024,
        5 * 1024 * 1024,
        10 * 1024 * 1024,
        25 * 1024 * 1024,
        100 * 1024 * 1024
    ]

    init(settings: UserSettings, historyStore: ClipboardHistoryStore, initialTab: SettingsTab = .general) {
        self.settings = settings
        self.historyStore = historyStore
        self._selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            settingsToolbar

            Divider()
                .background(Theme.divider)

            Group {
                switch selectedTab {
                case .general:
                    generalSettings
                case .exclusion:
                    exclusionSettings
                case .statistics:
                    statisticsSettings
                case .about:
                    aboutSettings
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(minWidth: minPanelWidth, minHeight: minPanelHeight)
        .background(Theme.contentBackground)
    }

    private var settingsToolbar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 24) {
                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: toolbarIconSize, weight: .regular))
                                .foregroundStyle(selectedTab == tab ? Theme.daySky : Theme.textMuted)
                                .frame(width: 46, height: 34)

                            Text(tab.title)
                                .font(Theme.textXsMedium)
                                .foregroundStyle(selectedTab == tab ? Theme.daySky : Theme.textMuted)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(width: 86, height: 78)
                        .contentShape(RoundedRectangle(cornerRadius: Theme.radiusMd))
                        .background(
                            RoundedRectangle(cornerRadius: Theme.radiusMd)
                                .fill(selectedTab == tab ? Theme.canvas.opacity(0.86) : Color.clear)
                        )
                        .shadow(color: selectedTab == tab ? Theme.softShadowLight : Color.clear, radius: 14, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(Theme.canvas.opacity(0.58))
    }

    private var generalSettings: some View {
        SettingsContent {
            SettingsSection(title: "啟動") {
                Toggle("Launch at Login", isOn: launchAtLoginBinding)
                    .font(Theme.textSm)
                    .foregroundStyle(Theme.text)
            }

            SettingsSection(title: "保存期限") {
                HStack(spacing: 12) {
                    Text("Keep History For")
                        .font(Theme.textSm)
                        .foregroundStyle(Theme.text)

                    Picker("Keep History For", selection: $settings.retentionPolicy) {
                        ForEach(RetentionPolicy.allCases) { policy in
                            Text(policy.displayName).tag(policy)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }

                Text("Items in Tags or custom groups never expire.")
                    .font(Theme.textXs)
                    .foregroundStyle(Theme.textMuted)
            }

            SettingsSection(title: "目前佔用空間") {
                HStack(spacing: 12) {
                    StatPill(title: "保留筆數", value: "\(historyStore.items.count) items")
                    StatPill(title: "估算大小", value: formattedBytes(historyStore.estimatedStorageBytes()))
                }
            }
        }
    }

    private var exclusionSettings: some View {
        SettingsContent {
            SettingsSection(title: "根據 App") {
                Text("如果當前 App 在「排除列表」中，KeyClip 會忽略複製操作。")
                    .font(Theme.textXs)
                    .foregroundStyle(Theme.textMuted)

                excludedAppsList
            }

            SettingsSection(title: "排除格式") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ForEach(ContentType.allCases) { type in
                        ExcludedContentTypeChip(
                            type: type,
                            isExcluded: settings.excludedContentTypes.contains(type)
                        ) {
                            settings.toggleExcludedContentType(type)
                        }
                    }
                }
            }

            SettingsSection(title: "根據容量") {
                HStack(spacing: 12) {
                    Text("不要收錄超過")
                        .font(Theme.textSm)
                        .foregroundStyle(Theme.text)

                    Picker("最大容量", selection: $settings.maxCaptureBytes) {
                        ForEach(maxCaptureByteOptions, id: \.self) { bytes in
                            Text(formattedBytes(bytes)).tag(bytes)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }

                Text("KeyClip 仍有 100 MB 的安全硬上限。容量規則會在保存前先套用。")
                    .font(Theme.textXs)
                    .foregroundStyle(Theme.textMuted)
            }
        }
    }

    private var excludedAppsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(settings.excludedApps) { app in
                        ExcludedAppRow(
                            app: app,
                            isSelected: selectedExcludedAppID == app.bundleID
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedExcludedAppID = app.bundleID
                        }
                    }

                    if settings.excludedApps.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "hand.raised.slash")
                                .font(.system(size: 28, weight: .regular))
                                .foregroundStyle(Theme.textFaint)

                            Text("尚未排除任何 App")
                                .font(Theme.textSmEmphasis)
                                .foregroundStyle(Theme.text)

                            Text("按左下角 + 加入不想記錄剪貼簿的 App。")
                                .font(Theme.textXs)
                                .foregroundStyle(Theme.textMuted)
                        }
                        .frame(maxWidth: .infinity, minHeight: listHeight)
                    }
                }
            }
            .frame(minHeight: listHeight, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSm)
                    .fill(Theme.canvas.opacity(0.86))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusSm)
                            .stroke(Theme.quartz.opacity(0.9), lineWidth: 1)
                    )
            )

            HStack(spacing: 0) {
                Button {
                    chooseExcludedAppForExclusion()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .regular))
                        .frame(width: 32, height: 26)
                }
                .buttonStyle(.plain)
                .help("加入 App")

                Divider()
                    .frame(height: 18)

                Button {
                    removeSelectedExcludedApp()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 15, weight: .regular))
                        .frame(width: 32, height: 26)
                }
                .buttonStyle(.plain)
                .disabled(selectedExcludedAppID == nil)
                .help("移除 App")
            }
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSm)
                    .fill(Theme.quartz.opacity(0.62))
            )
            .foregroundStyle(Theme.text)
        }
    }

    private var statisticsSettings: some View {
        SettingsContent {
            SettingsSection(title: "總覽") {
                HStack(spacing: 12) {
                    StatPill(title: "累積剪貼", value: "\(settings.captureStatistics.totalCount)")
                    StatPill(title: "最常見格式", value: rankedTypeStatistics.first?.name ?? "-")
                    StatPill(title: "最常見來源", value: rankedAppStatistics.first?.name ?? "-")
                }

                Button("清除統計") {
                    settings.resetCaptureStatistics()
                }
                .buttonStyle(.bordered)
                .disabled(settings.captureStatistics.totalCount == 0)
            }

            SettingsSection(title: "Top 5 複製格式") {
                RankingTable(entries: Array(rankedTypeStatistics.prefix(5)), emptyText: "還沒有格式統計資料")
            }

            SettingsSection(title: "Top 5 複製來源 App") {
                RankingTable(entries: Array(rankedAppStatistics.prefix(5)), emptyText: "還沒有來源 App 統計資料")
            }
        }
    }

    private var aboutSettings: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(Theme.daySky)

            Text("KeyClip")
                .font(Theme.headingSm)
                .tracking(Theme.headingTracking)
                .foregroundStyle(Theme.text)

            Text("輕輕做好一件事，讓你的每一天多一點餘裕。")
                .font(Theme.textSm)
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settings.launchAtLogin },
            set: { settings.launchAtLogin = $0 }
        )
    }

    private var rankedTypeStatistics: [CaptureStatEntry] {
        settings.captureStatistics.byType.values.sorted { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.count > rhs.count
        }
    }

    private var rankedAppStatistics: [CaptureStatEntry] {
        settings.captureStatistics.byApp.values.sorted { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.count > rhs.count
        }
    }

    private func chooseExcludedAppForExclusion() {
        let panel = NSOpenPanel()
        panel.title = "選擇要排除的 App"
        panel.prompt = "排除"
        panel.message = "從這個 App 複製的內容不會被 KeyClip 記錄。"
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier else {
            return
        }

        settings.addExcludedApp(
            bundleID: bundleID,
            name: appDisplayName(for: bundle, url: url),
            path: url.path
        )
        selectedExcludedAppID = bundleID
    }

    private func removeSelectedExcludedApp() {
        guard let selectedExcludedAppID else { return }
        settings.removeExcludedApp(bundleID: selectedExcludedAppID)
        self.selectedExcludedAppID = nil
    }

    private func appDisplayName(for bundle: Bundle, url: URL) -> String {
        if let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.isEmpty {
            return displayName
        }

        if let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !bundleName.isEmpty {
            return bundleName
        }

        return url.deletingPathExtension().lastPathComponent
    }

    private func formattedBytes(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

private struct ExcludedAppRow: View {
    let app: ExcludedApp
    let isSelected: Bool

    private let rowHeight: CGFloat = 58
    private let iconSize: CGFloat = 32

    var body: some View {
        HStack(spacing: 14) {
            appIcon
                .frame(width: iconSize, height: iconSize)

            VStack(alignment: .leading, spacing: 3) {
                Text(app.displayName)
                    .font(Theme.textSmEmphasis)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)

                Text(app.bundleID)
                    .font(Theme.textXs)
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .frame(height: rowHeight)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusSm)
                .fill(isSelected ? Theme.selectedBackground : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom))
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private var appIcon: some View {
        if let image = iconImage {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "app")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(Theme.textFaint)
        }
    }

    private var iconImage: NSImage? {
        if let path = app.path,
           FileManager.default.fileExists(atPath: path) {
            return NSWorkspace.shared.icon(forFile: path)
        }

        return AppIconLoader.icon(forBundleID: app.bundleID)
    }
}

private struct ExcludedContentTypeChip: View {
    let type: ContentType
    let isExcluded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: type.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isExcluded ? Theme.textFaint : type.themeTint)
                    .frame(width: 18)

                Text(type.displayName)
                    .font(Theme.textXsMedium)
                    .foregroundStyle(isExcluded ? Theme.textMuted : Theme.text)
                    .strikethrough(isExcluded, color: Theme.textMuted)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSm)
                    .fill(chipBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusSm)
                            .stroke(isExcluded ? Theme.quartz.opacity(0.54) : Theme.quartz.opacity(0.72), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var chipBackground: LinearGradient {
        if isExcluded {
            return LinearGradient(
                colors: [Theme.quartz.opacity(0.42), Theme.canvas.opacity(0.70)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [Theme.canvas.opacity(0.88), Theme.mist.opacity(0.36)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct SettingsContent<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                content()
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.textSmEmphasis)
                .foregroundStyle(Theme.text)

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusMd)
                    .fill(Theme.canvas.opacity(0.72))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMd)
                            .stroke(Theme.quartz.opacity(0.74), lineWidth: 1)
                    )
            )
        }
    }
}

private struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.textXs)
                .foregroundStyle(Theme.textMuted)

            Text(value)
                .font(Theme.textSmEmphasis)
                .foregroundStyle(Theme.text)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minWidth: 120, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusSm)
                .fill(Theme.mist.opacity(0.56))
        )
    }
}

private struct RankingTable: View {
    let entries: [CaptureStatEntry]
    let emptyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if entries.isEmpty {
                Text(emptyText)
                    .font(Theme.textXs)
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
            } else {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 12) {
                        Text("#\(index + 1)")
                            .font(Theme.textXsMedium)
                            .foregroundStyle(Theme.textFaint)
                            .frame(width: 34, alignment: .leading)

                        Text(entry.name)
                            .font(Theme.textSm)
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)

                        Spacer()

                        Text("\(entry.count)")
                            .font(Theme.textXsMedium)
                            .foregroundStyle(Theme.text)
                            .frame(width: 72, alignment: .trailing)
                    }
                    .padding(.vertical, 8)

                    if entry.id != entries.last?.id {
                        Divider()
                            .background(Theme.divider)
                    }
                }
            }
        }
    }
}
