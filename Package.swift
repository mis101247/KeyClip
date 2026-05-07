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
    targets: [
        .executableTarget(
            name: "KeyClip",
            path: "KeyClip",
            sources: [
                "KeyClipApp.swift",
                "AppDelegate.swift",
                "Controllers/MenuBarController.swift",
                "Clipboard/ClipboardMonitor.swift",
                "Clipboard/ClipboardHistoryStore.swift",
                "Clipboard/ClipboardGroupStore.swift",
                "Models/ContentType.swift",
                "Models/ClipboardHistoryItem.swift",
                "Models/ClipboardGroup.swift",
                "Views/SidebarView.swift",
                "Views/ClipboardPopoverView.swift",
                "Views/ClipboardHistoryRowView.swift",
                "Utilities/ContentTypeDetector.swift",
                "Utilities/StringHashing.swift"
            ]
        )
    ]
)
