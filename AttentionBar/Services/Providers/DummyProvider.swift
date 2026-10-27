import Foundation

/// 開発用の固定データ。dueAt は生成時に固定し、再取得しても残り時間がリセットされないようにする。
struct DummyProvider: AttentionProvider {
    private let dueAt: Date

    init(now: Date = Date()) {
        dueAt = now.addingTimeInterval(18 * 60)
    }

    func fetchItems(lookahead: TimeInterval) async throws -> [AttentionItem] {
        [
            AttentionItem(
                title: "定例ミーティング",
                dueAt: dueAt,
                priority: 1,
                source: .calendar,
                actionURL: nil
            )
        ]
    }
}
