import Foundation

/// リマインダーの期限をずらす先（#73）。
enum SnoozeOption: CaseIterable {
    case oneHour
    /// 今日の 18:00。過ぎていれば明日の 18:00。
    case evening
    /// 明日の 9:00。
    case tomorrowMorning

    private static let eveningHour = 18
    private static let morningHour = 9

    func date(from now: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .oneHour:
            return now.addingTimeInterval(60 * 60)
        case .evening:
            let today = Self.date(hour: Self.eveningHour, daysAfter: 0, from: now, calendar: calendar)
            return today > now ? today : Self.date(hour: Self.eveningHour, daysAfter: 1, from: now, calendar: calendar)
        case .tomorrowMorning:
            return Self.date(hour: Self.morningHour, daysAfter: 1, from: now, calendar: calendar)
        }
    }

    func displayName(now: Date, calendar: Calendar = .current) -> String {
        switch self {
        case .oneHour: String(localized: "1時間後")
        case .evening:
            calendar.isDate(date(from: now, calendar: calendar), inSameDayAs: now) ? String(localized: "今日の夕方") : String(localized: "明日の夕方")
        case .tomorrowMorning: String(localized: "明日の朝")
        }
    }

    private static func date(hour: Int, daysAfter days: Int, from now: Date, calendar: Calendar) -> Date {
        let day = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now)) ?? now
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }
}
