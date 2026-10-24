import Foundation

/// 外部ソース（Calendar / Reminders / GitHub など）から AttentionItem を取得する。
protocol AttentionProvider {
    func fetchItems() async throws -> [AttentionItem]

    /// データソースに変更があったときに onChange を呼ぶ。
    func observeChanges(_ onChange: @escaping () -> Void)
}

extension AttentionProvider {
    /// 変更通知を持たない Provider は何もしない（定期再取得のみで反映される）。
    func observeChanges(_ onChange: @escaping () -> Void) {}
}
