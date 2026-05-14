import Foundation

enum L10n {
    static func tr(_ key: String, _ arguments: CVarArg...) -> String {
        let format = localizedString(for: key)

        guard !arguments.isEmpty else {
            return format
        }

        return String(format: format, locale: Locale.current, arguments: arguments)
    }

    private static func localizedString(for key: String) -> String {
        if let overrideBundle {
            return overrideBundle.localizedString(forKey: key, value: nil, table: nil)
        }

        return NSLocalizedString(key, bundle: .module, comment: "")
    }

    private static let overrideBundle: Bundle? = makeOverrideBundle()

    private static func makeOverrideBundle() -> Bundle? {
        let languageCode = launchArgumentValue(for: "KeyClipLanguage")
            ?? ProcessInfo.processInfo.environment["KEYCLIP_LANGUAGE"]
            ?? persistedLanguageCode()

        guard let languageCode,
              !languageCode.isEmpty else {
            return nil
        }

        let normalized = languageCode.replacingOccurrences(of: "_", with: "-")
        let candidates = [normalized, normalized.lowercased()]

        for candidate in candidates {
            if let path = Bundle.module.path(forResource: candidate, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }

            let url = Bundle.module.bundleURL.appendingPathComponent("\(candidate).lproj", isDirectory: true)
            if FileManager.default.fileExists(atPath: url.path),
               let bundle = Bundle(url: url) {
                return bundle
            }
        }

        return nil
    }

    private static func persistedLanguageCode() -> String? {
        let rawValue = UserDefaults.standard.string(forKey: "appLanguage")
            ?? UserDefaults.standard.string(forKey: "KeyClipLanguage")

        guard let rawValue,
              rawValue != AppLanguage.system.rawValue else {
            return nil
        }

        return AppLanguage(rawValue: rawValue)?.languageCode
    }

    private static func launchArgumentValue(for key: String) -> String? {
        let arguments = CommandLine.arguments

        for index in arguments.indices {
            let argument = arguments[index]
            if argument == "-\(key)",
               arguments.indices.contains(index + 1) {
                return arguments[index + 1]
            }

            let prefix = "-\(key)="
            if argument.hasPrefix(prefix) {
                return String(argument.dropFirst(prefix.count))
            }
        }

        return nil
    }
}
