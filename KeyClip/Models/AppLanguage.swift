import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case traditionalChinese = "zh-Hant"

    var id: String { rawValue }

    var languageCode: String? {
        switch self {
        case .system:
            return nil
        case .english, .traditionalChinese:
            return rawValue
        }
    }

    var displayName: String {
        switch self {
        case .system:
            return L10n.tr("settings.language.system")
        case .english:
            return "English"
        case .traditionalChinese:
            return "正體中文"
        }
    }
}
