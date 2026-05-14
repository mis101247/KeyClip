import Foundation

enum DemoMode {
    enum Target: String {
        case popover
        case settingsGeneral
        case settingsExclusions
        case settingsStatistics

        var windowTitle: String {
            switch self {
            case .popover: return "Popover"
            case .settingsGeneral: return "Settings General"
            case .settingsExclusions: return "Settings Exclusions"
            case .settingsStatistics: return "Settings Statistics"
            }
        }

        var screenshotFilename: String {
            switch self {
            case .popover: return "popover.png"
            case .settingsGeneral: return "settings-general.png"
            case .settingsExclusions: return "settings-exclusions.png"
            case .settingsStatistics: return "settings-statistics.png"
            }
        }
    }

    struct Environment {
        let settings: UserSettings
        let attachmentStore: AttachmentStore
        let historyStore: ClipboardHistoryStore
        let groupStore: ClipboardGroupStore
    }

    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["KEYCLIP_DEMO"] == "1"
    }

    static var target: Target {
        let raw = ProcessInfo.processInfo.environment["KEYCLIP_DEMO_TARGET"] ?? Target.popover.rawValue
        return Target(rawValue: raw) ?? .popover
    }

    static func makeEnvironment() -> Environment {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeyClipDemo", isDirectory: true)
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let suiteName = "com.keyo.KeyClip.demo"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)

        let settings = UserSettings(defaults: defaults)
        settings.retentionPolicy = .sevenDays
        settings.maxCaptureBytes = 25 * 1024 * 1024
        settings.addExcludedApp(bundleID: "com.apple.keychainaccess", name: "Keychain Access")
        settings.addExcludedApp(bundleID: "com.bitwarden.desktop", name: "Bitwarden")
        settings.addExcludedApp(bundleID: "com.lastpass.LastPass", name: "LastPass")
        settings.toggleExcludedContentType(.email)
        settings.toggleExcludedContentType(.phone)

        let attachmentStore = AttachmentStore(directory: root.appendingPathComponent("attachments", isDirectory: true))
        let historyStore = ClipboardHistoryStore(
            fileURL: root.appendingPathComponent("clipboard-history.json", isDirectory: false),
            attachments: attachmentStore
        )
        let groupStore = ClipboardGroupStore(
            fileURL: root.appendingPathComponent("clipboard-groups.json", isDirectory: false)
        )

        seedHistory(historyStore, settings: settings)
        seedGroups(groupStore, historyStore: historyStore)
        seedStatistics(settings)

        return Environment(
            settings: settings,
            attachmentStore: attachmentStore,
            historyStore: historyStore,
            groupStore: groupStore
        )
    }

    private static func seedHistory(_ store: ClipboardHistoryStore, settings: UserSettings) {
        let now = Date()
        let samples: [(String, ContentType, String?, String?, String?)] = [
            ("輕輕做好一件事，讓你的每一天多一點餘裕。", .richText, "Brand line", "com.apple.Notes", "Notes"),
            ("func copySelection() {\n    pasteboard.setString(text, forType: .string)\n}", .code, "Snippet", "com.microsoft.VSCode", "Visual Studio Code"),
            ("https://keyclip.keyo.tw", .link, "Release page", "com.apple.Safari", "Safari"),
            ("#B8D8F0", .color, "Sky token", "com.figma.Desktop", "Figma"),
            ("Meet at 09:30 near Amsterdam Centraal.", .text, nil, "com.tinyspeck.slackmacgap", "Slack"),
            ("keyo@example.com", .email, nil, "com.google.Chrome", "Google Chrome"),
            ("Image 1200x800", .image, "Travel photo", "com.apple.Photos", "Photos"),
            ("Remember to notarize the DMG before public release.", .text, nil, "com.apple.Notes", "Notes")
        ]

        for (index, sample) in samples.enumerated() {
            store.add(
                content: sample.0,
                type: sample.1,
                isOversize: false,
                sourceAppBundleID: sample.3,
                sourceAppName: sample.4
            )

            if let id = store.items.first?.id {
                store.updateTitle(id: id, title: sample.2 ?? "")
                let createdAt = now.addingTimeInterval(TimeInterval(-index * 900))
                rewriteCreatedAt(id: id, createdAt: createdAt, in: store)
            }
        }
    }

    private static func seedGroups(_ groupStore: ClipboardGroupStore, historyStore: ClipboardHistoryStore) {
        let release = groupStore.createGroup(name: "Release Notes", systemImage: "sparkles")
        let design = groupStore.createGroup(name: "Design Tokens", systemImage: "paintpalette")

        for item in historyStore.items.prefix(3) {
            groupStore.addItem(item.id, to: release.id)
        }

        for item in historyStore.items.filter({ $0.type == .color || $0.sourceAppName == "Figma" }) {
            groupStore.addItem(item.id, to: design.id)
        }
    }

    private static func seedStatistics(_ settings: UserSettings) {
        record(settings, type: .richText, appID: "com.google.Chrome", appName: "Google Chrome", count: 13, bytes: 18_000)
        record(settings, type: .code, appID: "com.microsoft.VSCode", appName: "Visual Studio Code", count: 9, bytes: 42_000)
        record(settings, type: .text, appID: "com.apple.Notes", appName: "Notes", count: 5, bytes: 8_200)
        record(settings, type: .image, appID: "com.apple.Photos", appName: "Photos", count: 3, bytes: 1_600_000)
        record(settings, type: .link, appID: "com.apple.Safari", appName: "Safari", count: 2, bytes: 1_200)
        record(settings, type: .color, appID: "com.figma.Desktop", appName: "Figma", count: 2, bytes: 800)
        record(settings, type: .email, appID: "com.tinyspeck.slackmacgap", appName: "Slack", count: 1, bytes: 900)
    }

    private static func record(
        _ settings: UserSettings,
        type: ContentType,
        appID: String,
        appName: String,
        count: Int,
        bytes: Int
    ) {
        for _ in 0..<count {
            settings.recordCapture(
                type: type,
                byteCount: bytes / max(count, 1),
                sourceAppBundleID: appID,
                sourceAppName: appName
            )
        }
    }

    private static func rewriteCreatedAt(id: UUID, createdAt: Date, in store: ClipboardHistoryStore) {
        guard let index = store.items.firstIndex(where: { $0.id == id }) else { return }
        let item = store.items[index]
        let rewritten = ClipboardHistoryItem(
            id: item.id,
            content: item.content,
            createdAt: createdAt,
            contentHash: item.contentHash,
            type: item.type,
            attachmentFilename: item.attachmentFilename,
            attachmentKind: item.attachmentKind,
            isOversize: item.isOversize,
            title: item.title,
            sourceAppBundleID: item.sourceAppBundleID,
            sourceAppName: item.sourceAppName
        )
        store.replaceForDemo(at: index, with: rewritten)
    }
}
