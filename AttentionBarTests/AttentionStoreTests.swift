import Foundation
import Testing
@testable import AttentionBar

struct MenuBarTitleTests {
    private func title(_ item: AttentionItem?, denied: Set<AttentionSource> = [], at offset: TimeInterval, localization: Localization = japanese) -> String {
        AttentionStore.menuBarTitle(item: item, deniedSources: denied, now: now(offset), localization: localization)
    }

    @Test func showsNoItem() {
        #expect(title(nil, at: 0) == "📅 予定なし")
    }

    @Test func showsAccessDeniedWhenNoItem() {
        #expect(title(nil, denied: [.calendar], at: 0) == "📅 カレンダー権限なし")
        #expect(title(nil, denied: [.reminder], at: 0) == "✅ リマインダー権限なし")
    }

    @Test func prefersItemOverAccessDenied() {
        #expect(title(item(at: 18 * 60), denied: [.reminder], at: 0) == "📅 次の予定まで18分")
    }

    @Test func calendarBeforeStart() {
        #expect(title(item(at: 18 * 60), at: 0) == "📅 次の予定まで18分")
        #expect(title(item(at: 80 * 60), at: 0) == "📅 次の予定まで1時間20分")
        // 切り上げのため、30秒前は「1分」
        #expect(title(item(at: 30), at: 0) == "📅 次の予定まで1分")
    }

    @Test func calendarAfterStart() {
        #expect(title(item(at: 0), at: 30) == "📅 定例ミーティ… 開始")
        #expect(title(item(at: 0), at: 3 * 60) == "📅 定例ミーティ… 3分経過")
        #expect(title(item(at: 0), at: 3 * 60 + 59) == "📅 定例ミーティ… 3分経過")
    }

    @Test func reminderBeforeAndAfterDue() {
        let reminder = item("牛乳を買う", at: 0, source: .reminder)
        #expect(title(reminder, at: -5 * 60) == "✅ 期限まで5分")
        #expect(title(reminder, at: 30) == "✅ 牛乳を買う 期限")
        #expect(title(reminder, at: 2 * 60) == "✅ 牛乳を買う 期限超過2分")
        #expect(title(reminder, at: 125 * 60) == "✅ 牛乳を買う 期限超過2時間5分")
    }

    @Test func remainingTimeOfTrackedMeeting() {
        let meeting = AttentionItem(title: "定例ミーティング", dueAt: now(0), priority: 1, source: .calendar, actionURL: nil, endAt: now(30 * 60))
        #expect(title(meeting, at: 0) == "📅 定例ミーティ… 残り30分")
        #expect(title(meeting, at: 3 * 60) == "📅 定例ミーティ… 残り27分")
        #expect(title(meeting, at: 30 * 60 - 30) == "📅 定例ミーティ… 残り1分")
    }

    @Test func longEventShowsElapsedTime() {
        let block = AttentionItem(title: "定例ミーティング", dueAt: now(0), priority: 1, source: .calendar, actionURL: nil, endAt: now(3 * 60 * 60))
        #expect(title(block, at: 3 * 60) == "📅 定例ミーティ… 3分経過")
    }

    @Test func truncatesLongTitleAfterStart() {
        let long = item("【確認用】猶予時間の切り替えテスト予定", at: 0)
        #expect(title(long, at: 60) == "📅 【確認用】猶… 1分経過")
    }

    @Test func showsInEnglish() {
        let reminder = item("Milk", at: 0, source: .reminder)
        let meeting = AttentionItem(title: "Sync", dueAt: now(0), priority: 1, source: .calendar, actionURL: nil, endAt: now(30 * 60))
        #expect(title(nil, at: 0, localization: english) == "📅 No events")
        #expect(title(nil, denied: [.calendar], at: 0, localization: english) == "📅 No Calendars access")
        #expect(title(item(at: 80 * 60), at: 0, localization: english) == "📅 Next in 1h 20m")
        #expect(title(item("Sync", at: 0), at: 30, localization: english) == "📅 Sync now")
        #expect(title(item("Sync", at: 0), at: 3 * 60, localization: english) == "📅 Sync 3m ago")
        #expect(title(meeting, at: 3 * 60, localization: english) == "📅 Sync 27m left")
        #expect(title(reminder, at: -5 * 60, localization: english) == "✅ Due in 5m")
        #expect(title(reminder, at: 30, localization: english) == "✅ Milk due")
        #expect(title(reminder, at: 125 * 60, localization: english) == "✅ Milk overdue 2h 5m")
        // 英語は全角 6 文字分の幅（半角 12 文字）まで表示する
        #expect(title(item("Weekly sync with design", at: 0), at: 60, localization: english) == "📅 Weekly sync… 1m ago")
    }
}

struct FormattingTests {
    @Test(arguments: [
        (1, "1分"), (59, "59分"), (60, "1時間"), (61, "1時間1分"),
        (80, "1時間20分"), (120, "2時間"), (1439, "23時間59分"),
    ])
    func durationText(minutes: Int, expected: String) {
        #expect(AttentionStore.durationText(minutes: minutes, localization: japanese) == expected)
    }

    @Test(arguments: [
        (1, "1m"), (60, "1h"), (80, "1h 20m"),
    ])
    func durationTextInEnglish(minutes: Int, expected: String) {
        #expect(AttentionStore.durationText(minutes: minutes, localization: english) == expected)
    }

    @Test(arguments: [
        ("定例ミーティング", "定例ミーティ…"),
        ("定例ミーティ", "定例ミーティ"),
        ("定例MTG", "定例MTG"),
        ("123456789012", "123456789012"),
        ("1234567890123", "123456789012…"),
        ("Weekly sync with design team", "Weekly sync…"),
        ("第3回 Design Review", "第3回 Design…"),
        ("🎉 Party planning", "🎉 Party pla…"),
        ("ＡＢＣ全角英字テスト", "ＡＢＣ全角英…"),
    ])
    func truncated(text: String, expected: String) {
        #expect(AttentionStore.truncated(text, maxWidth: 12) == expected)
    }

    @Test(arguments: [
        (0, "10:00"), (-60, "9:00"), (780, "23:00"),
        (-600, "0:00"), (-601, "昨日 23:59"), (840, "明日 0:00"),
        (2880, "10/30 10:00"), (-2880, "10/26 10:00"),
    ] as [(TimeInterval, String)])
    func dueText(minutesFromNow: TimeInterval, expected: String) {
        #expect(dueText(minutesFromNow: minutesFromNow, localization: japanese) == expected)
    }

    @Test(arguments: [
        // AM / PM の前は通常の空白ではなく U+202F（狭いノーブレークスペース）
        (0, "10:00\u{202F}AM"), (780, "11:00\u{202F}PM"), (-601, "Yesterday 11:59\u{202F}PM"),
        (840, "Tomorrow 12:00\u{202F}AM"), (2880, "10/30, 10:00\u{202F}AM"),
    ] as [(TimeInterval, String)])
    func dueTextInEnglish(minutesFromNow: TimeInterval, expected: String) {
        // 地域を含めないと 12 / 24 時間制が実行環境で変わるため、米国英語に固定する
        let localization = Localization(bundle: english.bundle, locale: Locale(identifier: "en_US"))
        #expect(dueText(minutesFromNow: minutesFromNow, localization: localization) == expected)
    }

    private func dueText(minutesFromNow: TimeInterval, localization: Localization) -> String {
        // 2026-10-28 10:00 (JST) を基準にする
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let reference = calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 10))!
        let date = reference.addingTimeInterval(minutesFromNow * 60)
        return AttentionStore.dueText(date, now: reference, calendar: calendar, localization: localization)
    }

    @Test(arguments: [
        (30.0, 1), (60.0, 1), (61.0, 2), (0.0, 0), (-30.0, 0), (-90.0, -1),
    ])
    func minutesRemaining(secondsUntilDue: TimeInterval, expected: Int) {
        let target = AttentionItem(title: "x", dueAt: base.addingTimeInterval(secondsUntilDue), priority: 1, source: .calendar, actionURL: nil)
        #expect(target.minutesRemaining(from: base) == expected)
    }

    @Test(arguments: [
        (0.0, 60.05), (1.0, 59.05), (30.0, 30.05), (59.5, 0.55), (60.0, 60.05),
    ])
    func secondsUntilNextMinute(secondsPastMinute: TimeInterval, expected: TimeInterval) {
        // base は分の境界
        let delay = AttentionStore.secondsUntilNextMinute(from: base.addingTimeInterval(secondsPastMinute))
        #expect(abs(delay - expected) < 0.001)
    }
}
