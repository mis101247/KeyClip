import AppKit
import SwiftUI

final class MenuBarController: NSObject {
    private let store: ClipboardHistoryStore
    private let monitor: ClipboardMonitor
    private let groupStore: ClipboardGroupStore
    private let attachmentStore: AttachmentStore
    private let settings: UserSettings
    private let onCheckForUpdates: () -> Void
    private let canCheckForUpdates: () -> Bool
    private let popoverPresentationState = PopoverPresentationState()
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var globalClickMonitor: Any?
    private var flashTimer: Timer?
    private var settingsWindowController: NSWindowController?

    init(
        store: ClipboardHistoryStore,
        monitor: ClipboardMonitor,
        groupStore: ClipboardGroupStore,
        attachmentStore: AttachmentStore,
        settings: UserSettings,
        onCheckForUpdates: @escaping () -> Void,
        canCheckForUpdates: @escaping () -> Bool
    ) {
        self.store = store
        self.monitor = monitor
        self.groupStore = groupStore
        self.attachmentStore = attachmentStore
        self.settings = settings
        self.onCheckForUpdates = onCheckForUpdates
        self.canCheckForUpdates = canCheckForUpdates
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.popover = NSPopover()

        super.init()

        configureStatusItem()
        configurePopover()
        updateStatusItemAppearance()
    }

    deinit {
        flashTimer?.invalidate()
        removeGlobalClickMonitor()
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
        popover.animates = false
        resetPopoverContent()
    }

    private func resetPopoverContent() {
        popover.contentViewController = NSHostingController(
            rootView: ClipboardPopoverView(
                store: store,
                groupStore: groupStore,
                settings: settings,
                presentationState: popoverPresentationState,
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
                },
                onOpenSettings: { [weak self] in
                    self?.showSettingsWindow()
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
        let pauseTitle = monitor.isPaused ? L10n.tr("menu.resume_clipboard") : L10n.tr("menu.pause_clipboard")
        let pauseItem = NSMenuItem(title: pauseTitle, action: #selector(togglePaused), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)
        menu.addItem(NSMenuItem.separator())
        let settingsItem = NSMenuItem(title: L10n.tr("menu.settings"), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        let updateItem = NSMenuItem(title: L10n.tr("menu.check_for_updates"), action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        updateItem.isEnabled = canCheckForUpdates()
        menu.addItem(updateItem)
        menu.addItem(NSMenuItem.separator())
        let quit = NSMenuItem(title: L10n.tr("menu.quit_keyclip"), action: #selector(quit), keyEquivalent: "q")
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

    @objc private func openSettings() {
        showSettingsWindow()
    }

    @objc private func checkForUpdates() {
        onCheckForUpdates()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    func flashCaptureFeedback() {
        guard let button = statusItem.button, !monitor.isPaused else { return }
        flashTimer?.invalidate()
        button.image = NSImage(
            systemSymbolName: "doc.on.clipboard.fill",
            accessibilityDescription: L10n.tr("accessibility.captured")
        )
        button.alphaValue = 1.0
        flashTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
            self?.updateStatusItemAppearance()
        }
    }

    private func updateStatusItemAppearance() {
        guard let button = statusItem.button else { return }
        let symbolName = monitor.isPaused ? "doc.on.clipboard.fill" : "doc.on.clipboard"
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: L10n.tr("accessibility.clipboard_history"))
        button.alphaValue = monitor.isPaused ? 0.45 : 1.0
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popoverPresentationState.markOpened()
        popover.contentViewController?.view.window?.makeKey()
        installGlobalClickMonitor()
    }

    private func showSettingsWindow() {
        closePopover()

        if settingsWindowController == nil {
            let hostingView = FirstMouseHostingView(
                rootView: SettingsPanelView(settings: settings, historyStore: store)
            )
            let viewController = NSViewController()
            viewController.view = hostingView

            let window = NSWindow(contentViewController: viewController)
            window.title = L10n.tr("window.settings_title")
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.minSize = NSSize(width: 720, height: 500)
            window.setContentSize(NSSize(width: 760, height: 620))
            window.center()
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.moveToActiveSpace]

            settingsWindowController = NSWindowController(window: window)
        }

        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closePopover() {
        removeGlobalClickMonitor()
        popover.performClose(nil)
    }

    private func installGlobalClickMonitor() {
        removeGlobalClickMonitor()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.closePopover()
            }
        }
    }

    private func removeGlobalClickMonitor() {
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
    }
}

final class PopoverPresentationState: ObservableObject {
    @Published private(set) var openCount = 0

    func markOpened() {
        openCount += 1
    }
}

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
