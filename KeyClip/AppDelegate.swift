import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = UserSettings.shared
    private let attachmentStore = AttachmentStore()
    private var historyStore: ClipboardHistoryStore?
    private var groupStore: ClipboardGroupStore?
    private var clipboardMonitor: ClipboardMonitor?
    private var menuBarController: MenuBarController?
    private var retentionSweeper: RetentionSweeper?
    private var cancellable: AnyCancellable?
    private var globalHotkey: GlobalHotkey?
    private var appUpdater: AppUpdater?
    private var demoWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if DemoMode.isEnabled {
            runDemoMode()
            return
        }

        NSApp.setActivationPolicy(.accessory)

        let store = ClipboardHistoryStore(attachments: attachmentStore)
        groupStore = ClipboardGroupStore()
        store.protectedIDsProvider = { [weak store, weak groupStore] in
            let groupedIDs = Set(groupStore?.groups.flatMap(\.itemIDs) ?? [])
            let titledIDs = store?.titledItemIDs ?? []
            return groupedIDs.union(titledIDs)
        }
        store.onItemsRemoved = { [weak groupStore] ids in
            groupStore?.purgeItems(ids)
        }

        let monitor = ClipboardMonitor(
            isSourceAppExcluded: { [weak self] bundleID in
                self?.settings.isAppExcluded(bundleID: bundleID) ?? false
            },
            shouldCapture: { [weak self] type, byteCount, bundleID in
                self?.settings.shouldCapture(type: type, byteCount: byteCount, bundleID: bundleID) ?? true
            },
            onNewText: { [weak self] content, type, rtfData, isOversize, bundleID, appName in
                store.add(
                    content: content,
                    type: type,
                    rtfData: rtfData,
                    isOversize: isOversize,
                    sourceAppBundleID: bundleID,
                    sourceAppName: appName
                )
                self?.settings.recordCapture(
                    type: type,
                    byteCount: content.utf8.count + (rtfData?.count ?? 0),
                    sourceAppBundleID: bundleID,
                    sourceAppName: appName
                )
            },
            onNewImage: { [weak self] data, hash, dimensions, isOversize, bundleID, appName in
                store.addImage(
                    data: data,
                    hash: hash,
                    dimensions: dimensions,
                    isOversize: isOversize,
                    sourceAppBundleID: bundleID,
                    sourceAppName: appName
                )
                self?.settings.recordCapture(
                    type: .image,
                    byteCount: data.count,
                    sourceAppBundleID: bundleID,
                    sourceAppName: appName
                )
            }
        )
        guard let groupStore else { return }

        let retentionSweeper = RetentionSweeper(
            historyStore: store,
            groupStore: groupStore,
            settings: settings
        )
        self.retentionSweeper = retentionSweeper
        retentionSweeper.start()
        appUpdater = AppUpdater()
        cancellable = settings.$retentionPolicy.sink { [weak retentionSweeper] _ in
            DispatchQueue.main.async {
                retentionSweeper?.runSweep()
            }
        }

        let controller = MenuBarController(
            store: store,
            monitor: monitor,
            groupStore: groupStore,
            attachmentStore: attachmentStore,
            settings: settings,
            onCheckForUpdates: { [weak self] in
                self?.appUpdater?.checkForUpdates()
            },
            canCheckForUpdates: { [weak self] in
                self?.appUpdater?.canCheckForUpdates ?? false
            }
        )
        store.onItemCaptured = { [weak controller] in
            DispatchQueue.main.async {
                controller?.flashCaptureFeedback()
            }
        }

        historyStore = store
        clipboardMonitor = monitor
        menuBarController = controller

        monitor.start()

        let hotkey = GlobalHotkey(
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: UInt32(cmdKey | shiftKey),
            onTrigger: { [weak controller] in controller?.togglePopover() }
        )
        hotkey.register()
        self.globalHotkey = hotkey
    }

    func applicationWillTerminate(_ notification: Notification) {
        globalHotkey?.unregister()
    }

    private func runDemoMode() {
        NSApp.setActivationPolicy(.regular)

        let demo = DemoMode.makeEnvironment()
        let target = DemoMode.target
        let rootView: AnyView
        let size: NSSize

        switch target {
        case .settingsGeneral:
            rootView = AnyView(SettingsPanelView(settings: demo.settings, historyStore: demo.historyStore))
            size = NSSize(width: 760, height: 620)
        case .settingsExclusions:
            rootView = AnyView(SettingsPanelView(settings: demo.settings, historyStore: demo.historyStore, initialTab: .exclusion))
            size = NSSize(width: 760, height: 620)
        case .settingsStatistics:
            rootView = AnyView(SettingsPanelView(settings: demo.settings, historyStore: demo.historyStore, initialTab: .statistics))
            size = NSSize(width: 760, height: 640)
        case .popover:
            rootView = AnyView(
                ClipboardPopoverView(
                    store: demo.historyStore,
                    groupStore: demo.groupStore,
                    settings: demo.settings,
                    presentationState: PopoverPresentationState(),
                    attachmentStore: demo.attachmentStore,
                    onSelect: { _ in },
                    onClose: {},
                    onOpenSettings: {}
                )
            )
            size = NSSize(width: 600, height: 520)
        }

        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "KeyClip Demo - \(target.windowTitle)"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.backgroundColor = Self.demoCanvasColor
        window.isOpaque = true
        window.setContentSize(size)
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = Self.demoCanvasColor.cgColor
        demoWindowController = NSWindowController(window: window)
        demoWindowController?.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if let captureDirectory = ProcessInfo.processInfo.environment["KEYCLIP_DEMO_CAPTURE_DIR"] {
            captureDemoWindow(window, target: target, directoryPath: captureDirectory)
        }
    }

    private func captureDemoWindow(_ window: NSWindow, target: DemoMode.Target, directoryPath: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak window] in
            guard let contentView = window?.contentView else {
                NSApp.terminate(nil)
                return
            }

            contentView.layoutSubtreeIfNeeded()
            let bounds = contentView.bounds
            guard let bitmap = contentView.bitmapImageRepForCachingDisplay(in: bounds) else {
                fputs("Could not create bitmap for demo window\n", stderr)
                NSApp.terminate(nil)
                return
            }

            contentView.cacheDisplay(in: bounds, to: bitmap)

            guard let data = bitmap.representation(using: .png, properties: [:]) else {
                fputs("Could not encode demo window PNG\n", stderr)
                NSApp.terminate(nil)
                return
            }

            let directoryURL = URL(fileURLWithPath: directoryPath, isDirectory: true)
            try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let outputURL = directoryURL.appendingPathComponent(target.screenshotFilename)

            do {
                try data.write(to: outputURL, options: .atomic)
                print("Captured \(outputURL.path)")
            } catch {
                fputs("Could not write \(outputURL.path): \(error)\n", stderr)
            }

            NSApp.terminate(nil)
        }
    }

    private static var demoCanvasColor: NSColor {
        NSColor(red: 250 / 255, green: 251 / 255, blue: 252 / 255, alpha: 1)
    }

}
