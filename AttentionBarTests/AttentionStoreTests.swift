import Foundation
import Testing
@testable import AttentionBar

struct MenuBarTitleTests {
    private func title(_ item: AttentionItem?, denied: Set<AttentionSource> = [], at offset: TimeInterval) -> String {
        AttentionStore.menuBarTitle(item: item, deniedSources: denied, now: now(offset))
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
        #expect(title(item(at: 0), at: 30) == "📅 定例ミーティング 開始")
        #expect(title(item(at: 0), at: 3 * 60) == "📅 定例ミーティング 開始から3分")
        #expect(title(item(at: 0), at: 3 * 60 + 59) == "📅 定例ミーティング 開始から3分")
    }

    @Test func reminderBeforeAndAfterDue() {
        let reminder = item("牛乳を買う", at: 0, source: .reminder)
        #expect(title(reminder, at: -5 * 60) == "✅ 期限まで5分")
        #expect(title(reminder, at: 30) == "✅ 牛乳を買う 期限")
        #expect(title(reminder, at: 2 * 60) == "✅ 牛乳を買う 期限超過2分")
        #expect(title(reminder, at: 125 * 60) == "✅ 牛乳を買う 期限超過2時間5分")
    }

    @Test func truncatesLongTitleAfterStart() {
        let long = item("【確認用】猶予時間の切り替えテスト予定", at: 0)
        #expect(title(long, at: 60) == "📅 【確認用】猶予時間の切り替えテ… 開始から1分")
    }
}

struct FormattingTests {
    @Test(arguments: [
        (1, "1分"), (59, "59分"), (60, "1時間"), (61, "1時間1分"),
        (80, "1時間20分"), (120, "2時間"), (1439, "23時間59分"),
    ])
    func durationText(minutes: Int, expected: String) {
        #expect(AttentionStore.durationText(minutes: minutes) == expected)
    }

    @Test(arguments: [
        ("定例ミーティング", "定例ミーティング"),
        ("123456789012345", "123456789012345"),
        ("1234567890123456", "123456789012345…"),
        ("Weekly sync with design team", "Weekly sync wit…"),
    ])
    func truncated(text: String, expected: String) {
        #expect(AttentionStore.truncated(text, maxLength: 15) == expected)
    }

    @Test(arguments: [
        (30.0, 1), (60.0, 1), (61.0, 2), (0.0, 0), (-30.0, 0), (-90.0, -1),
    ])
    func minutesRemaining(secondsUntilDue: TimeInterval, expected: Int) {
        let target = AttentionItem(title: "x", dueAt: base.addingTimeInterval(secondsUntilDue), priority: 1, source: .calendar, actionURL: nil)
        #expect(target.minutesRemaining(from: base) == expected)
    }
}
