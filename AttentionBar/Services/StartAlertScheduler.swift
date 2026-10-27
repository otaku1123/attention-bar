import Foundation

/// カレンダーの予定の開始時刻に、最前面のパネルで知らせる。
///
/// 通知センターのバナーは見落とすことがあるため、閉じるまで残るパネルを出す。
/// 取得のたびに予約を作り直すが、識別子が同じ予定の予約は残すため二重には出ない。
@MainActor
final class StartAlertScheduler {
    /// スリープ明けなどで開始時刻を大きく過ぎていたら、今さら出しても役に立たないので出さない。
    nonisolated static let staleLimit: TimeInterval = 5 * 60

    struct Plan {
        let identifier: String
        let item: AttentionItem
    }

    private var tasks: [String: Task<Void, Never>] = [:]
    private let panels = StartAlertPanelController()

    /// enabled が false なら予約済みのものも取り消す。表示中のパネルは閉じない。
    func schedule(_ items: [AttentionItem], now: Date, enabled: Bool) {
        let plans = enabled ? Self.plan(for: items, now: now) : []
        let planned = Set(plans.map(\.identifier))

        // 消えた予定・時刻が変わった予定・表示済みの予定の予約を片付ける
        for (identifier, task) in tasks where !planned.contains(identifier) {
            task.cancel()
            tasks[identifier] = nil
        }

        for plan in plans where tasks[plan.identifier] == nil {
            tasks[plan.identifier] = Task { [weak self] in
                try? await Task.sleep(for: .seconds(plan.item.dueAt.timeIntervalSinceNow))
                guard !Task.isCancelled else { return }
                self?.fire(plan)
            }
        }
    }

    /// 開始前のカレンダーの予定が対象。リマインダーは対象外。
    nonisolated static func plan(for items: [AttentionItem], now: Date) -> [Plan] {
        items
            .filter { $0.source == .calendar && $0.dueAt > now }
            .map { item in
                Plan(identifier: "\(item.source).\(Int(item.dueAt.timeIntervalSince1970)).\(item.title)", item: item)
            }
    }

    /// 少し早く起きた直後に再取得が走っても再予約しないよう、tasks からは消さない（次の schedule で片付く）。
    private func fire(_ plan: Plan) {
        guard Date().timeIntervalSince(plan.item.dueAt) <= Self.staleLimit else { return }
        panels.show(plan.item, identifier: plan.identifier)
    }
}
