import AppKit
import Carbon.HIToolbox
import Combine

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

    func applicationDidFinishLaunching(_ notification: Notification) {
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
}
