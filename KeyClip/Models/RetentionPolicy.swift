import Foundation

enum RetentionPolicy: String, Codable, CaseIterable, Identifiable {
    case forever
    case oneDay
    case sevenDays
    case thirtyDays

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .forever: return "Forever"
        case .oneDay: return "1 Day"
        case .sevenDays: return "7 Days"
        case .thirtyDays: return "30 Days"
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
