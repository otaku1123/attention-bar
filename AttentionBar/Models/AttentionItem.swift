import Foundation

struct AttentionItem {
    let title: String
    let dueAt: Date
    let priority: Int
    let source: AttentionSource
    let actionURL: URL?
    /// 予定の終了時刻。リマインダーなど終了のないものは nil。
    var endAt: Date? = nil
    /// 元データの識別子（リマインダーは calendarItemIdentifier）。完了などの操作で元データを探すのに使う。
    var sourceID: String? = nil

    /// 残り分数（切り上げ）。期限を過ぎていれば 0 以下を返す。
    func minutesRemaining(from now: Date) -> Int {
        Int(ceil(dueAt.timeIntervalSince(now) / 60))
    }
}
