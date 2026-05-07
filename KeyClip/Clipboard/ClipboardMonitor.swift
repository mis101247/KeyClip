import AppKit

final class ClipboardMonitor {
    private let pasteboard: NSPasteboard
    private let onNewClip: (String) -> Void
    private var timer: Timer?
    private var lastChangeCount: Int
    private var isWritingFromHistory = false

    init(
        pasteboard: NSPasteboard = .general,
        onNewClip: @escaping (String) -> Void
    ) {
        self.pasteboard = pasteboard
        self.onNewClip = onNewClip
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.pollPasteboard()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func writeToPasteboard(_ content: String) {
        isWritingFromHistory = true
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        lastChangeCount = pasteboard.changeCount
        isWritingFromHistory = false
    }

    private func pollPasteboard() {
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else { return }

        lastChangeCount = currentChangeCount

        guard !isWritingFromHistory else {
            return
        }

        guard let content = pasteboard.string(forType: .string),
              isValidClipboardContent(content) else {
            return
        }

        onNewClip(content)
    }

    private func isValidClipboardContent(_ content: String) -> Bool {
        guard !content.isEmpty else { return false }
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard content.utf8.count <= 500 * 1024 else { return false }

        return true
    }
}
