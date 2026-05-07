import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var historyStore: ClipboardHistoryStore?
    private var groupStore: ClipboardGroupStore?
    private var clipboardMonitor: ClipboardMonitor?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let store = ClipboardHistoryStore()
        groupStore = ClipboardGroupStore()
        store.onItemsRemoved = { [weak groupStore] ids in
            groupStore?.purgeItems(ids)
        }

        let monitor = ClipboardMonitor { content, type in
            store.add(content: content, type: type)
        }
        guard let groupStore else { return }

        let controller = MenuBarController(store: store, monitor: monitor, groupStore: groupStore)

        historyStore = store
        clipboardMonitor = monitor
        menuBarController = controller

        monitor.start()
    }
}
