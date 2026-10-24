import Foundation

/// 外部ソース（Calendar / Reminders / GitHub など）から AttentionItem を取得する。
protocol AttentionProvider {
    func fetchItems() async throws -> [AttentionItem]
}
