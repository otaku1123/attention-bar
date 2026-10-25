import Foundation
import Combine

/// UI が参照する状態。取得済みの items と、残り時間計算用の現在時刻を保持する。
@MainActor
final class AttentionStore: ObservableObject {
    /// 開始後もこの時間だけは表示を残し、その後に次の予定へ切り替える。
    private static let gracePeriod: TimeInterval = 10 * 60
    /// Provider から再取得する間隔。
    private static let refreshInterval: TimeInterval = 5 * 60

    @Published private(set) var items: [AttentionItem] = []
    @Published private(set) var deniedSources: Set<AttentionSource> = []
    @Published private(set) var now = Date()

    private let service = AttentionService(providers: [CalendarProvider()])
    private var lastLoadedAt: Date?
    private var timer: AnyCancellable?
    private var reloadTask: Task<Void, Never>?

    init() {
        Task { await load() }

        service.observeChanges { [weak self] in
            Task { @MainActor in self?.scheduleReload() }
        }

        timer = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                guard let self else { return }
                now = date
                if let lastLoadedAt, date.timeIntervalSince(lastLoadedAt) >= Self.refreshInterval {
                    Task { await self.load() }
                }
            }
    }

    func load() async {
        lastLoadedAt = Date()
        let result = await service.fetchItems()
        items = result.items
        deniedSources = result.deniedSources
        now = Date()
    }

    /// 変更通知は短時間に連続して届くことがあるため、最後の通知から 0.5 秒待って 1 回だけ再取得する。
    private func scheduleReload() {
        reloadTask?.cancel()
        reloadTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await load()
        }
    }

    /// 表示対象。開始から gracePeriod を過ぎたものは除外する。
    /// 将来的には PriorityEngine で並べ替える。現時点では priority の小さい順、同値なら dueAt の早い順で先頭を採用。
    var item: AttentionItem? {
        items
            .filter { $0.dueAt.addingTimeInterval(Self.gracePeriod) > now }
            .min { ($0.priority, $0.dueAt) < ($1.priority, $1.dueAt) }
    }

    var menuBarTitle: String {
        guard let item else {
            // 他ソースのアイテムがあればそちらを優先し、何もないときだけ権限不足を表示する
            if let source = deniedSources.first {
                return "\(source.emoji) \(source.displayName)権限なし"
            }
            return "📅 予定なし"
        }
        let minutes = item.minutesRemaining(from: now)
        if minutes <= 0 {
            // minutesRemaining は切り上げなので、符号反転すると経過分数（切り捨て）になる
            let elapsed = -minutes
            if elapsed == 0 {
                return "\(item.source.emoji) \(item.title) 開始"
            }
            return "\(item.source.emoji) \(item.title) 開始から\(elapsed)分"
        }
        return "\(item.source.emoji) 次の予定まで\(Self.durationText(minutes: minutes))"
    }

    /// 60分未満は「18分」、以上は「1時間20分」「5時間」のように表示する。
    static func durationText(minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes)分" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours)時間" : "\(hours)時間\(rest)分"
    }
}
