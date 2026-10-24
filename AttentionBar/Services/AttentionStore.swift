import Foundation
import Combine

/// UI が参照する状態。表示対象の item と、残り時間計算用の現在時刻を保持する。
@MainActor
final class AttentionStore: ObservableObject {
    @Published private(set) var item: AttentionItem?
    @Published private(set) var now = Date()

    private let service = AttentionService()
    private var timer: AnyCancellable?

    init() {
        // 将来的には PriorityEngine で並べ替える。現時点では priority の小さい順で先頭を採用。
        item = service.fetchItems(now: now).min { $0.priority < $1.priority }

        timer = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                self?.now = date
            }
    }

    var menuBarTitle: String {
        guard let item else { return "📅 予定なし" }
        let minutes = item.minutesRemaining(from: now)
        if minutes <= 0 {
            return "\(item.source.emoji) \(item.title) 開始"
        }
        return "\(item.source.emoji) 次の予定まで\(minutes)分"
    }
}
