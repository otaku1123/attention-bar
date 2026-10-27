import Foundation

/// 外部ソース（Calendar / Reminders / GitHub など）から AttentionItem を取得する。
protocol AttentionProvider {
    /// 現在から lookahead 秒後までに開始・期限を迎えるアイテムを取得する。
    func fetchItems(lookahead: TimeInterval) async throws -> [AttentionItem]

    /// データソースに変更があったときに onChange を呼ぶ。
    func observeChanges(_ onChange: @escaping () -> Void)
}

extension AttentionProvider {
    /// 変更通知を持たない Provider は何もしない（定期再取得のみで反映される）。
    func observeChanges(_ onChange: @escaping () -> Void) {}
}

enum AttentionProviderError: Error {
    /// ユーザーがデータソースへのアクセスを許可していない。
    case accessDenied(AttentionSource)
}

/// 権限エラーの表示用。
extension AttentionSource {
    var displayName: String {
        switch self {
        case .calendar: return "カレンダー"
        case .reminder: return "リマインダー"
        case .github: return "GitHub"
        case .custom: return "カスタム"
        }
    }

    /// システム設定の該当プライバシー画面。OS の権限ではないソースは nil。
    var privacySettingsURL: URL? {
        switch self {
        case .calendar:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
        case .reminder:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders")
        case .github, .custom:
            return nil
        }
    }
}
