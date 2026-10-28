import Foundation

/// AttentionItem の中から「今ユーザーが気づくべき」1件を選ぶ。
///
/// 上の段ほど優先する。同じ段の中では priority の小さい順、同値なら dueAt の早い順。
/// 1. 直前・進行中の予定: 開始まで imminentWindow 以内、または開始から gracePeriod 以内
/// 2. 期限切れのリマインダー: 期限超過 overdueLimit 以内の未完了リマインダー
/// 3. これからのアイテム: 上記以外で、開始・期限前のもの
enum PriorityEngine {
    /// 予定の開始後もこの時間だけは表示を残し、その後に次のアイテムへ切り替える（既定値。設定で変更できる）。
    static let gracePeriod: TimeInterval = 10 * 60
    /// 開始までこの時間以内の予定は、期限切れリマインダーより優先する。
    static let imminentWindow: TimeInterval = 15 * 60
    /// 期限切れリマインダーを表示し続ける上限。放置された古いリマインダーが表示を占拠しないようにする。
    static let overdueLimit: TimeInterval = 24 * 60 * 60

    enum Tier: Int, Comparable {
        case imminentEvent = 1
        case overdueReminder
        case upcoming

        static func < (lhs: Tier, rhs: Tier) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    static func select(from items: [AttentionItem], now: Date, gracePeriod: TimeInterval = gracePeriod) -> AttentionItem? {
        ranked(from: items, now: now, gracePeriod: gracePeriod).first
    }

    /// 表示対象のアイテムを優先順に並べて返す。
    static func ranked(from items: [AttentionItem], now: Date, gracePeriod: TimeInterval = gracePeriod) -> [AttentionItem] {
        deduplicated(items)
            .compactMap { item in tier(of: item, now: now, gracePeriod: gracePeriod).map { (tier: $0, item: item) } }
            .sorted { ($0.tier, $0.item.priority, $0.item.dueAt) < ($1.tier, $1.item.priority, $1.item.dueAt) }
            .map(\.item)
    }

    /// 複数のカレンダーに入っている同じ会議（タイトルと開始時刻が同じ予定）を 1 件にまとめる（#45）。
    /// 会議 URL を持つものを優先して残し、どちらも持つ・持たないなら先に現れたものを残す。
    /// リマインダーは同名でも別の項目なのでまとめない。
    static func deduplicated(_ items: [AttentionItem]) -> [AttentionItem] {
        struct Key: Hashable {
            let title: String
            let dueAt: Date
        }
        var indexByKey: [Key: Int] = [:]
        var result: [AttentionItem] = []
        for item in items {
            guard item.source == .calendar else {
                result.append(item)
                continue
            }
            let key = Key(title: item.title, dueAt: item.dueAt)
            if let index = indexByKey[key] {
                if result[index].actionURL == nil && item.actionURL != nil {
                    result[index] = item
                }
            } else {
                indexByKey[key] = result.count
                result.append(item)
            }
        }
        return result
    }

    /// アイテムの優先段。表示対象外なら nil。
    static func tier(of item: AttentionItem, now: Date, gracePeriod: TimeInterval = gracePeriod) -> Tier? {
        // 正の値は開始・期限からの経過秒数、負の値は開始・期限までの残り秒数
        let elapsed = now.timeIntervalSince(item.dueAt)

        switch item.source {
        case .reminder:
            if elapsed >= 0 {
                return elapsed < overdueLimit ? .overdueReminder : nil
            }
            return .upcoming
        case .calendar, .github, .custom:
            if elapsed >= 0 {
                return elapsed < gracePeriod ? .imminentEvent : nil
            }
            return -elapsed <= imminentWindow ? .imminentEvent : .upcoming
        }
    }
}
