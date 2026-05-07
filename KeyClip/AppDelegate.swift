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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let store = ClipboardHistoryStore(attachments: attachmentStore)
        groupStore = ClipboardGroupStore()
        store.onItemsRemoved = { [weak groupStore] ids in
            groupStore?.purgeItems(ids)
        }

        let monitor = ClipboardMonitor(
            onNewText: { content, type, rtfData, isOversize in
                store.add(content: content, type: type, rtfData: rtfData, isOversize: isOversize)
            },
            onNewImage: { data, hash, dimensions, isOversize in
                store.addImage(data: data, hash: hash, dimensions: dimensions, isOversize: isOversize)
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
            settings: settings
        )

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
