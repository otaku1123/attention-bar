import Foundation

enum AttentionSource {
    case calendar
    case reminder
    case github
    case custom

    var emoji: String {
        switch self {
        case .calendar: return "📅"
        case .reminder: return "✅"
        case .github: return "🐙"
        case .custom: return "📌"
        }
    }
}
