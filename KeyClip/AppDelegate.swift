import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var historyStore: ClipboardHistoryStore?
    private var clipboardMonitor: ClipboardMonitor?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let store = ClipboardHistoryStore()
        let monitor = ClipboardMonitor { content in
            store.add(content: content)
        }
        let controller = MenuBarController(store: store, monitor: monitor)

        historyStore = store
        clipboardMonitor = monitor
        menuBarController = controller

        monitor.start()
    }
}
