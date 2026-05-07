import AppKit
import SwiftUI

final class MenuBarController: NSObject {
    private let store: ClipboardHistoryStore
    private let monitor: ClipboardMonitor
    private let groupStore: ClipboardGroupStore
    private let attachmentStore: AttachmentStore
    private let settings: UserSettings
    private let statusItem: NSStatusItem
    private let popover: NSPopover

    init(
        store: ClipboardHistoryStore,
        monitor: ClipboardMonitor,
        groupStore: ClipboardGroupStore,
        attachmentStore: AttachmentStore,
        settings: UserSettings
    ) {
        self.store = store
        self.monitor = monitor
        self.groupStore = groupStore
        self.attachmentStore = attachmentStore
        self.settings = settings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.popover = NSPopover()

        super.init()

        configureStatusItem()
        configurePopover()
        updateStatusItemAppearance()
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
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
                settings: settings,
                attachmentStore: attachmentStore,
                onSelect: { [weak self] item in
                    if item.attachmentKind == .image {
                        if let filename = item.attachmentFilename,
                           let data = self?.attachmentStore.read(filename: filename) {
                            self?.monitor.writeImage(data)
                        }
                    } else if item.attachmentKind == .rtf {
                        if let filename = item.attachmentFilename,
                           let data = self?.attachmentStore.read(filename: filename) {
                            self?.monitor.writeRichText(plain: item.content, rtf: data)
                        } else {
                            self?.monitor.writeToPasteboard(item.content)
                        }
                    } else {
                        self?.monitor.writeToPasteboard(item.content)
                    }
                    self?.closePopover()
                },
                onClose: { [weak self] in
                    self?.closePopover()
                }
            )
        )
    }

    func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    @objc private func handleStatusItemClick(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else { togglePopover(); return }
        switch event.type {
        case .rightMouseUp: showStatusItemMenu()
        default: togglePopover()
        }
    }

    private func showStatusItemMenu() {
        let menu = NSMenu()
        let pauseTitle = monitor.isPaused ? "Resume Clipboard" : "Pause Clipboard"
        let pauseItem = NSMenuItem(title: pauseTitle, action: #selector(togglePaused), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)
        menu.addItem(NSMenuItem.separator())
        let quit = NSMenuItem(title: "Quit KeyClip", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        DispatchQueue.main.async { [weak self] in self?.statusItem.menu = nil }
    }

    @objc private func togglePaused() {
        monitor.togglePaused()
        updateStatusItemAppearance()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func updateStatusItemAppearance() {
        guard let button = statusItem.button else { return }
        let symbolName = monitor.isPaused ? "doc.on.clipboard.fill" : "doc.on.clipboard"
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Clipboard History")
        button.alphaValue = monitor.isPaused ? 0.45 : 1.0
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
