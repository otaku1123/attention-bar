import Foundation
import Testing
@testable import AttentionBar

struct SnoozeOptionTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    @Test func oneHourLater() {
        #expect(SnoozeOption.oneHour.date(from: date(11, 10, 23), calendar: calendar) == date(11, 11, 23))
    }

    @Test func eveningIsTodayUntil18() {
        #expect(SnoozeOption.evening.date(from: date(11, 10), calendar: calendar) == date(11, 18))
        #expect(SnoozeOption.evening.displayName(now: date(11, 10), calendar: calendar) == "今日の夕方")
    }

    @Test func eveningMovesToTomorrowAfter18() {
        #expect(SnoozeOption.evening.date(from: date(11, 18), calendar: calendar) == date(12, 18))
        #expect(SnoozeOption.evening.date(from: date(11, 23, 30), calendar: calendar) == date(12, 18))
        #expect(SnoozeOption.evening.displayName(now: date(11, 19), calendar: calendar) == "明日の夕方")
    }

    @Test func tomorrowMorning() {
        #expect(SnoozeOption.tomorrowMorning.date(from: date(11, 10), calendar: calendar) == date(12, 9))
        // 日付が変わった直後でも「明日」は翌日
        #expect(SnoozeOption.tomorrowMorning.date(from: date(12, 0, 30), calendar: calendar) == date(13, 9))
    }
}
