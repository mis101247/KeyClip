import Foundation
import Combine
import ServiceManagement

struct ExcludedApp: Codable, Hashable, Identifiable {
    let bundleID: String
    let name: String
    let path: String?

    var id: String { bundleID }
    var displayName: String { name.isEmpty ? bundleID : name }

    init(bundleID: String, name: String, path: String? = nil) {
        self.bundleID = bundleID
        self.name = name
        self.path = path
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.bundleID = try container.decode(String.self, forKey: .bundleID)
        self.name = try container.decode(String.self, forKey: .name)
        self.path = try container.decodeIfPresent(String.self, forKey: .path)
    }

    private enum CodingKeys: String, CodingKey {
        case bundleID
        case name
        case path
    }
}

struct CaptureStatEntry: Codable, Hashable, Identifiable {
    let id: String
    var name: String
    var count: Int
    var bytes: Int
}

struct CaptureStatistics: Codable, Hashable {
    var totalCount: Int
    var totalBytes: Int
    var byType: [String: CaptureStatEntry]
    var byApp: [String: CaptureStatEntry]

    static let empty = CaptureStatistics(
        totalCount: 0,
        totalBytes: 0,
        byType: [:],
        byApp: [:]
    )
}

final class UserSettings: ObservableObject {
    static let shared = UserSettings()

    private let defaults: UserDefaults
    private let retentionKey = "retentionPolicy"
    private let launchAtLoginKey = "launchAtLogin"
    private let excludedAppsKey = "excludedApps"
    private let excludedContentTypesKey = "excludedContentTypes"
    private let maxCaptureBytesKey = "maxCaptureBytes"
    private let captureStatisticsKey = "captureStatistics"

    @Published var retentionPolicy: RetentionPolicy {
        didSet {
            defaults.set(retentionPolicy.rawValue, forKey: retentionKey)
        }
    }

    @Published private(set) var excludedApps: [ExcludedApp] {
        didSet {
            saveExcludedApps()
        }
    }

    @Published var excludedContentTypes: Set<ContentType> {
        didSet {
            defaults.set(excludedContentTypes.map(\.rawValue), forKey: excludedContentTypesKey)
        }
    }

    @Published var maxCaptureBytes: Int {
        didSet {
            defaults.set(maxCaptureBytes, forKey: maxCaptureBytesKey)
        }
    }

    @Published private(set) var captureStatistics: CaptureStatistics {
        didSet {
            saveCaptureStatistics()
        }
    }

    var excludedAppBundleIDs: Set<String> {
        Set(excludedApps.map(\.bundleID))
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
            self.retentionPolicy = .sevenDays
        }

        if let data = defaults.data(forKey: excludedAppsKey),
           let excludedApps = try? JSONDecoder().decode([ExcludedApp].self, from: data) {
            self.excludedApps = excludedApps
        } else {
            self.excludedApps = []
        }

        let excludedTypeRawValues = defaults.stringArray(forKey: excludedContentTypesKey) ?? []
        self.excludedContentTypes = Set(excludedTypeRawValues.compactMap(ContentType.init(rawValue:)))

        let savedMaxCaptureBytes = defaults.integer(forKey: maxCaptureBytesKey)
        self.maxCaptureBytes = savedMaxCaptureBytes > 0 ? savedMaxCaptureBytes : 100 * 1024 * 1024

        if let data = defaults.data(forKey: captureStatisticsKey),
           let captureStatistics = try? JSONDecoder().decode(CaptureStatistics.self, from: data) {
            self.captureStatistics = captureStatistics
        } else {
            self.captureStatistics = .empty
        }

        if defaults.bool(forKey: launchAtLoginKey),
           SMAppService.mainApp.status != .enabled {
            try? SMAppService.mainApp.register()
        }
    }

    func addExcludedApp(bundleID: String, name: String, path: String? = nil) {
        let trimmedBundleID = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBundleID.isEmpty else { return }

        let excludedApp = ExcludedApp(
            bundleID: trimmedBundleID,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            path: path
        )

        excludedApps.removeAll { $0.bundleID == trimmedBundleID }
        excludedApps.append(excludedApp)
        excludedApps.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func removeExcludedApp(bundleID: String) {
        excludedApps.removeAll { $0.bundleID == bundleID }
    }

    func isAppExcluded(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return excludedAppBundleIDs.contains(bundleID)
    }

    func isContentTypeExcluded(_ type: ContentType) -> Bool {
        excludedContentTypes.contains(type)
    }

    func shouldCapture(type: ContentType, byteCount: Int, bundleID: String?) -> Bool {
        guard !isAppExcluded(bundleID: bundleID) else { return false }
        guard !isContentTypeExcluded(type) else { return false }
        return byteCount <= maxCaptureBytes
    }

    func toggleExcludedContentType(_ type: ContentType) {
        if excludedContentTypes.contains(type) {
            excludedContentTypes.remove(type)
        } else {
            excludedContentTypes.insert(type)
        }
    }

    func recordCapture(type: ContentType, byteCount: Int, sourceAppBundleID: String?, sourceAppName: String?) {
        let bytes = max(byteCount, 0)
        var updated = captureStatistics
        updated.totalCount += 1
        updated.totalBytes += bytes

        var typeEntry = updated.byType[type.rawValue] ?? CaptureStatEntry(
            id: type.rawValue,
            name: type.displayName,
            count: 0,
            bytes: 0
        )
        typeEntry.name = type.displayName
        typeEntry.count += 1
        typeEntry.bytes += bytes
        updated.byType[type.rawValue] = typeEntry

        let appID = sourceAppBundleID ?? "unknown"
        let appName = sourceAppName?.isEmpty == false ? sourceAppName! : "Unknown App"
        var appEntry = updated.byApp[appID] ?? CaptureStatEntry(
            id: appID,
            name: appName,
            count: 0,
            bytes: 0
        )
        appEntry.name = appName
        appEntry.count += 1
        appEntry.bytes += bytes
        updated.byApp[appID] = appEntry

        captureStatistics = updated
    }

    func resetCaptureStatistics() {
        captureStatistics = .empty
    }

    private func saveExcludedApps() {
        guard let data = try? JSONEncoder().encode(excludedApps) else { return }
        defaults.set(data, forKey: excludedAppsKey)
    }

    private func saveCaptureStatistics() {
        guard let data = try? JSONEncoder().encode(captureStatistics) else { return }
        defaults.set(data, forKey: captureStatisticsKey)
    }
}
