import Foundation

/// カレンダーの予定の開始時刻（設定によっては少し前）に、最前面のパネルで知らせる。
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
        /// 表示する時刻。開始の leadTime 前。過ぎていればすぐに表示する。
        let fireDate: Date
    }

    private var tasks: [String: (fireDate: Date, task: Task<Void, Never>)] = [:]
    private let panels = StartAlertPanelController()
    /// 予約後に設定が変わっても、表示する時点の知らせ方を使う。
    private var style: StartAlertStyle = .panel

    /// style が .off なら予約済みのものも取り消す。表示中のパネルは閉じない。
    func schedule(_ items: [AttentionItem], now: Date, style: StartAlertStyle, leadTime: TimeInterval = 0) {
        self.style = style
        let plans = style == .off ? [] : Self.plan(for: items, now: now, leadTime: leadTime)
        let planned = Dictionary(plans.map { ($0.identifier, $0.fireDate) }, uniquingKeysWith: { first, _ in first })

        // 消えた予定・時刻が変わった予定・表示済みの予定の予約を片付ける。
        // タイミングの設定が変わった予約も、まだ表示していなければ入れ直す（表示済みのものは二重に出さない）
        for (identifier, scheduled) in tasks {
            let fireDate = planned[identifier]
            if fireDate == nil || (fireDate != scheduled.fireDate && scheduled.fireDate > now) {
                scheduled.task.cancel()
                tasks[identifier] = nil
            }
        }

        for plan in plans where tasks[plan.identifier] == nil {
            let task = Task { [weak self] in
                try? await Task.sleep(for: .seconds(max(plan.fireDate.timeIntervalSinceNow, 0)))
                guard !Task.isCancelled else { return }
                self?.fire(plan)
            }
            tasks[plan.identifier] = (plan.fireDate, task)
        }
    }

    /// 開始前のカレンダーの予定が対象。リマインダーは対象外。
    /// 表示時刻を過ぎていても、開始前ならすぐに表示する。
    nonisolated static func plan(for items: [AttentionItem], now: Date, leadTime: TimeInterval = 0) -> [Plan] {
        items
            .filter { $0.source == .calendar && $0.dueAt > now }
            .map { item in
                Plan(
                    identifier: "\(item.source).\(Int(item.dueAt.timeIntervalSince1970)).\(item.title)",
                    item: item,
                    fireDate: item.dueAt.addingTimeInterval(-leadTime)
                )
            }
    }

    /// 少し早く起きた直後に再取得が走っても再予約しないよう、tasks からは消さない（次の schedule で片付く）。
    private func fire(_ plan: Plan) {
        guard Date().timeIntervalSince(plan.item.dueAt) <= Self.staleLimit else { return }
        panels.show(plan.item, identifier: plan.identifier, fullScreen: style == .fullScreen)
    }
}
