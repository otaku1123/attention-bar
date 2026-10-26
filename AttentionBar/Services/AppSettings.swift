import Foundation

/// ユーザーが変更できる設定。UserDefaults に保存する。
@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let gracePeriodMinutes = "gracePeriodMinutes"
        static let lookaheadHours = "lookaheadHours"
        static let notificationLeadMinutes = "notificationLeadMinutes"
        static let excludedCalendarIDs = "excludedCalendarIDs"
    }

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

    /// 表示しないカレンダーの calendarIdentifier。後から追加されたカレンダーは表示対象になるよう、除外側を保存する。
    @Published var excludedCalendarIDs: Set<String> {
        didSet { defaults.set(Array(excludedCalendarIDs).sorted(), forKey: Key.excludedCalendarIDs) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        gracePeriodMinutes = defaults.object(forKey: Key.gracePeriodMinutes) as? Int ?? 10
        lookaheadHours = defaults.object(forKey: Key.lookaheadHours) as? Int ?? 24
        notificationLeadMinutes = defaults.object(forKey: Key.notificationLeadMinutes) as? Int ?? 5
        excludedCalendarIDs = Set(defaults.stringArray(forKey: Key.excludedCalendarIDs) ?? [])
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
