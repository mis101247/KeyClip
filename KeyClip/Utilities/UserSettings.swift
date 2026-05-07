import Foundation
import Combine
import ServiceManagement

final class UserSettings: ObservableObject {
    static let shared = UserSettings()

    private let defaults: UserDefaults
    private let retentionKey = "retentionPolicy"
    private let launchAtLoginKey = "launchAtLogin"

    @Published var retentionPolicy: RetentionPolicy {
        didSet {
            defaults.set(retentionPolicy.rawValue, forKey: retentionKey)
        }
    }

    var launchAtLogin: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            objectWillChange.send()
            defaults.set(newValue, forKey: launchAtLoginKey)
            if newValue {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: retentionKey),
           let value = RetentionPolicy(rawValue: raw) {
            self.retentionPolicy = value
        } else {
            self.retentionPolicy = .forever
        }

        if defaults.bool(forKey: launchAtLoginKey),
           SMAppService.mainApp.status != .enabled {
            try? SMAppService.mainApp.register()
        }
    }
}
