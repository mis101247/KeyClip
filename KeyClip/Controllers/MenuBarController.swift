import AppKit
import SwiftUI

final class MenuBarController: NSObject {
    private let store: ClipboardHistoryStore
    private let monitor: ClipboardMonitor
    private let groupStore: ClipboardGroupStore
    private let statusItem: NSStatusItem
    private let popover: NSPopover

    init(store: ClipboardHistoryStore, monitor: ClipboardMonitor, groupStore: ClipboardGroupStore) {
        self.store = store
        self.monitor = monitor
        self.groupStore = groupStore
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.popover = NSPopover()

        super.init()

        configureStatusItem()
        configurePopover()
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "doc.on.clipboard",
                accessibilityDescription: "Clipboard History"
            )
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }

    private func configurePopover() {
        popover.contentSize = NSSize(width: 600, height: 520)
        popover.behavior = .transient
        resetPopoverContent()
    }

    private func resetPopoverContent() {
        popover.contentViewController = NSHostingController(
            rootView: ClipboardPopoverView(
                store: store,
                groupStore: groupStore,
                onSelect: { [weak self] item in
                    self?.monitor.writeToPasteboard(item.content)
                    self?.closePopover()
                },
                onClose: { [weak self] in
                    self?.closePopover()
                }
            )
        )
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }

        resetPopoverContent()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func closePopover() {
        popover.performClose(nil)
    }
}
