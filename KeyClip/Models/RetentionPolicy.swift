import Foundation

enum RetentionPolicy: String, Codable, CaseIterable, Identifiable {
    case forever
    case oneDay
    case sevenDays
    case thirtyDays

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .forever: return L10n.tr("retention.forever")
        case .oneDay: return L10n.tr("retention.one_day")
        case .sevenDays: return L10n.tr("retention.seven_days")
        case .thirtyDays: return L10n.tr("retention.thirty_days")
        }
    }

    /// nil = never expires
    var maxAge: TimeInterval? {
        switch self {
        case .forever: return nil
        case .oneDay: return 60 * 60 * 24
        case .sevenDays: return 60 * 60 * 24 * 7
        case .thirtyDays: return 60 * 60 * 24 * 30
        }
    }
}
