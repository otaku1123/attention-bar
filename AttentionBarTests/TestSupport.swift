import Foundation
@testable import AttentionBar

/// テストの基準時刻。実行時刻に依存しないよう固定する。
let base = Date(timeIntervalSince1970: 1_800_000_000)

func item(
    _ title: String = "定例ミーティング",
    at offset: TimeInterval,
    priority: Int = 1,
    source: AttentionSource = .calendar
) -> AttentionItem {
    AttentionItem(title: title, dueAt: base.addingTimeInterval(offset), priority: priority, source: source, actionURL: nil)
}

func now(_ offset: TimeInterval) -> Date {
    base.addingTimeInterval(offset)
}
