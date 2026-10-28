import Foundation

/// 予定の開始時刻の知らせ方。
enum StartAlertStyle: String, CaseIterable {
    case off
    /// 画面中央の小さなパネル。フォーカスは奪わない。
    case panel
    /// メインディスプレイ全体を覆う。Esc で閉じられるようフォーカスを取る。
    case fullScreen

    var displayName: String {
        switch self {
        case .off: "知らせない"
        case .panel: "パネル"
        case .fullScreen: "全画面"
        }
    }
}

/// ユーザーが変更できる設定。UserDefaults に保存する。
@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let gracePeriodMinutes = "gracePeriodMinutes"
        static let lookaheadHours = "lookaheadHours"
        static let notificationLeadMinutes = "notificationLeadMinutes"
        static let startAlertStyle = "startAlertStyle"
        /// 旧設定（ON/OFF）。startAlertStyle が未保存のときだけ引き継ぎに使う。
        static let showsStartAlert = "showsStartAlert"
        static let excludedCalendarIDs = "excludedCalendarIDs"
        static let hiddenEventKeys = "hiddenEventKeys"
    }

    /// 非表示にした予定の記録を残す期間（開始時刻から）。過ぎたものは表示対象外になっているので消す。
    static let hiddenEventRetention: TimeInterval = 24 * 60 * 60

    /// 設定画面の選択肢。
    static let gracePeriodChoices = [0, 5, 10, 15, 30]
    static let lookaheadChoices = [6, 12, 24, 48]
    /// 0 は「通知しない」。
    static let notificationLeadChoices = [0, 1, 5, 10, 15]

    /// 予定の開始後も表示を残す時間（分）。
    @Published var gracePeriodMinutes: Int {
        didSet { defaults.set(gracePeriodMinutes, forKey: Key.gracePeriodMinutes) }
    }

    /// 何時間先までの予定・リマインダーを取得するか。
    @Published var lookaheadHours: Int {
        didSet { defaults.set(lookaheadHours, forKey: Key.lookaheadHours) }
    }

    /// 予定の開始の何分前に通知するか。0 なら通知しない。
    @Published var notificationLeadMinutes: Int {
        didSet { defaults.set(notificationLeadMinutes, forKey: Key.notificationLeadMinutes) }
    }

    /// 予定の開始時刻に最前面の画面でどう知らせるか。
    @Published var startAlertStyle: StartAlertStyle {
        didSet { defaults.set(startAlertStyle.rawValue, forKey: Key.startAlertStyle) }
    }

    /// 表示しないカレンダーの calendarIdentifier。後から追加されたカレンダーは表示対象になるよう、除外側を保存する。
    @Published var excludedCalendarIDs: Set<String> {
        didSet { defaults.set(Array(excludedCalendarIDs).sorted(), forKey: Key.excludedCalendarIDs) }
    }

    /// 非表示にした予定（今回だけ無視）のキー。形式は「開始時刻の UNIX 秒.タイトル」（#46）。
    @Published private(set) var hiddenEventKeys: Set<String> {
        didSet { defaults.set(Array(hiddenEventKeys).sorted(), forKey: Key.hiddenEventKeys) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        gracePeriodMinutes = defaults.object(forKey: Key.gracePeriodMinutes) as? Int ?? 10
        lookaheadHours = defaults.object(forKey: Key.lookaheadHours) as? Int ?? 24
        notificationLeadMinutes = defaults.object(forKey: Key.notificationLeadMinutes) as? Int ?? 5
        if let style = defaults.string(forKey: Key.startAlertStyle).flatMap(StartAlertStyle.init(rawValue:)) {
            startAlertStyle = style
        } else {
            startAlertStyle = defaults.object(forKey: Key.showsStartAlert) as? Bool == false ? .off : .panel
        }
        excludedCalendarIDs = Set(defaults.stringArray(forKey: Key.excludedCalendarIDs) ?? [])
        hiddenEventKeys = Set(defaults.stringArray(forKey: Key.hiddenEventKeys) ?? [])
    }

    /// 予定ごとのキー。繰り返しの予定は回ごとに別のキーになる。
    /// 複数のカレンダーに入っている同じ会議もまとめて非表示になるよう、カレンダーの識別子は含めない。
    nonisolated static func hiddenEventKey(for item: AttentionItem) -> String {
        "\(Int(item.dueAt.timeIntervalSince1970)).\(item.title)"
    }

    func hide(_ item: AttentionItem) {
        hiddenEventKeys.insert(Self.hiddenEventKey(for: item))
    }

    func isHidden(_ item: AttentionItem) -> Bool {
        hiddenEventKeys.contains(Self.hiddenEventKey(for: item))
    }

    func unhideAll() {
        hiddenEventKeys = []
    }

    /// 開始から hiddenEventRetention を過ぎた記録を消す。変更がなければ代入しない（設定変更として再取得が走らないように）。
    func pruneHiddenEvents(now: Date) {
        let limit = now.addingTimeInterval(-Self.hiddenEventRetention).timeIntervalSince1970
        let kept = hiddenEventKeys.filter { key in
            guard let seconds = key.split(separator: ".", maxSplits: 1).first.flatMap({ TimeInterval($0) }) else { return false }
            return seconds >= limit
        }
        if kept != hiddenEventKeys {
            hiddenEventKeys = kept
        }
    }

    var gracePeriod: TimeInterval {
        TimeInterval(gracePeriodMinutes * 60)
    }

    var lookahead: TimeInterval {
        TimeInterval(lookaheadHours * 60 * 60)
    }

    var notificationLeadTime: TimeInterval {
        TimeInterval(notificationLeadMinutes * 60)
    }
}
