import Foundation

/// 各 Provider（Calendar / Reminder / GitHub など）から AttentionItem を集める窓口。
/// 現時点ではダミーデータを返すだけ。
struct AttentionService {
    func fetchItems(now: Date = Date()) -> [AttentionItem] {
        [
            AttentionItem(
                title: "定例ミーティング",
                dueAt: now.addingTimeInterval(18 * 60),
                priority: 1,
                source: .calendar,
                actionURL: nil
            )
        ]
    }
}
