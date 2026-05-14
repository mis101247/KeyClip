import Foundation
import Sparkle

@MainActor
final class AppUpdater {
    private let controller: SPUStandardUpdaterController

    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }

    init?() {
        guard let feedURLString = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              URL(string: feedURLString) != nil else {
            return nil
        }

        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
