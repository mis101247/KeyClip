// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "KeyClip",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "KeyClip",
            targets: ["KeyClip"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.1")
    ],
    targets: [
        .executableTarget(
            name: "KeyClip",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "KeyClip",
            sources: [
                "KeyClipApp.swift",
                "AppDelegate.swift",
                "Controllers/MenuBarController.swift",
                "Clipboard/AttachmentStore.swift",
                "Clipboard/ClipboardMonitor.swift",
                "Clipboard/ClipboardHistoryStore.swift",
                "Clipboard/ClipboardGroupStore.swift",
                "Clipboard/RetentionSweeper.swift",
                "Models/ContentType.swift",
                "Models/ClipboardHistoryItem.swift",
                "Models/ClipboardGroup.swift",
                "Models/RetentionPolicy.swift",
                "Views/Theme.swift",
                "Views/SidebarView.swift",
                "Views/ClipboardPopoverView.swift",
                "Views/ClipboardHistoryRowView.swift",
                "Utilities/AppIconLoader.swift",
                "Utilities/AppUpdater.swift",
                "Utilities/ContentTypeDetector.swift",
                "Utilities/DemoMode.swift",
                "Utilities/GlobalHotkey.swift",
                "Utilities/StringHashing.swift",
                "Utilities/UserSettings.swift"
            ]
        )
    ]
)
