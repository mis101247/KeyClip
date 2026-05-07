import Foundation

final class RetentionSweeper {
    private let historyStore: ClipboardHistoryStore
    private let groupStore: ClipboardGroupStore
    private let settings: UserSettings
    private var timer: Timer?

    init(historyStore: ClipboardHistoryStore, groupStore: ClipboardGroupStore, settings: UserSettings) {
        self.historyStore = historyStore
        self.groupStore = groupStore
        self.settings = settings
    }

    func start() {
        runSweep()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60 * 30, repeats: true) { [weak self] _ in
            self?.runSweep()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func runSweep() {
        let protected = Set(groupStore.groups.flatMap(\.itemIDs))
        let oversizeCutoff = Date().addingTimeInterval(-24 * 60 * 60)
        historyStore.sweepOversizeExpired(olderThan: oversizeCutoff, protectedIDs: protected)

        guard let maxAge = settings.retentionPolicy.maxAge else { return }
        let cutoff = Date().addingTimeInterval(-maxAge)
        historyStore.sweepExpired(olderThan: cutoff, protectedIDs: protected)
    }
}
