import Foundation
import Combine

final class UserSettings: ObservableObject {
    static let shared = UserSettings()

    private let defaults: UserDefaults
    private let retentionKey = "retentionPolicy"

    @Published var retentionPolicy: RetentionPolicy {
        didSet {
            defaults.set(retentionPolicy.rawValue, forKey: retentionKey)
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
    }
}
