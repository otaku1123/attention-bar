import Foundation
import Combine

/// UI が参照する状態。取得済みの items と、残り時間計算用の現在時刻を保持する。
@MainActor
final class AttentionStore: ObservableObject {
    /// Provider から再取得する間隔。
    private static let refreshInterval: TimeInterval = 5 * 60
    /// メニューバーに出すタイトルの最大文字数。超えた分は「…」で省略する。
    /// 会議中はマイク等のインジケータが増えて幅が足りなくなり、macOS にアイコンごと隠されるため短めにする（#35）。
    private nonisolated static let menuBarTitleMaxLength = 6
    /// ポップアップに一覧表示する最大件数。
    private static let listLimit = 5

    @Published private(set) var items: [AttentionItem] = []
    @Published private(set) var deniedSources: Set<AttentionSource> = []
    @Published private(set) var now = Date()

    let settings = AppSettings()

    private let calendarProvider = CalendarProvider()
    private let reminderProvider = ReminderProvider()
    private lazy var service = AttentionService(providers: [calendarProvider, reminderProvider])
    private let notifications = NotificationScheduler()
    private let startAlerts = StartAlertScheduler()
    private var settingsObserver: AnyCancellable?
    private var lastLoadedAt: Date?
    private var timer: AnyCancellable?
    private var reloadTask: Task<Void, Never>?

    init() {
        Task { await load() }

        service.observeChanges { [weak self] in
            Task { @MainActor in self?.scheduleReload() }
        }

        // objectWillChange は値の変更前に届くが、再取得は 0.5 秒後なので新しい値で取得できる
        settingsObserver = settings.objectWillChange.sink { [weak self] in
            self?.scheduleReload()
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
        calendarProvider.excludedCalendarIDs = settings.excludedCalendarIDs
        let result = await service.fetchItems(lookahead: settings.lookahead)
        items = result.items
        deniedSources = result.deniedSources
        now = Date()
        startAlerts.schedule(items, now: now, style: settings.startAlertStyle)
        await notifications.schedule(items, now: now, leadTime: settings.notificationLeadTime)
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

    /// リマインダーを完了にする。保存を待たずに一覧から消し、失敗したら取り直して元に戻す。
    func complete(_ item: AttentionItem) {
        guard item.source == .reminder, let id = item.sourceID else { return }
        items.removeAll { $0.source == .reminder && $0.sourceID == id }
        do {
            try reminderProvider.complete(id: id)
        } catch {
            print("[AttentionStore] complete failed: \(error)")
            scheduleReload()
        }
    }

    /// 優先順に並べた表示対象。先頭がメニューバーに出す 1 件。
    var rankedItems: [AttentionItem] {
        Array(PriorityEngine.ranked(from: items, now: now, gracePeriod: settings.gracePeriod).prefix(Self.listLimit))
    }

    /// 設定画面で選択できるカレンダー。
    func calendarOptions() -> [CalendarOption] {
        calendarProvider.availableCalendars()
    }

    var item: AttentionItem? {
        rankedItems.first
    }

    var menuBarTitle: String {
        Self.menuBarTitle(item: item, deniedSources: deniedSources, now: now)
    }

    nonisolated static func menuBarTitle(item: AttentionItem?, deniedSources: Set<AttentionSource>, now: Date) -> String {
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
            let title = truncated(item.title, maxLength: menuBarTitleMaxLength)
            switch item.source {
            case .reminder:
                if elapsed == 0 {
                    return "\(item.source.emoji) \(title) 期限"
                }
                return "\(item.source.emoji) \(title) 期限超過\(durationText(minutes: elapsed))"
            default:
                if elapsed == 0 {
                    return "\(item.source.emoji) \(title) 開始"
                }
                return "\(item.source.emoji) \(title) \(elapsed)分経過"
            }
        }
        let label = item.source == .reminder ? "期限まで" : "次の予定まで"
        return "\(item.source.emoji) \(label)\(durationText(minutes: minutes))"
    }

    /// maxLength 文字を超える場合は先頭 maxLength 文字に「…」を付ける。
    nonisolated static func truncated(_ text: String, maxLength: Int) -> String {
        text.count > maxLength ? String(text.prefix(maxLength)) + "…" : text
    }

    /// 今日は「10:00」、前後 1 日は「昨日 18:00」「明日 9:00」、それ以外は「10/28 9:00」のように表示する。
    nonisolated static func dueText(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "H:mm"
        let time = formatter.string(from: date)

        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return time
        case -1: return "昨日 \(time)"
        case 1: return "明日 \(time)"
        default:
            formatter.dateFormat = "M/d H:mm"
            return formatter.string(from: date)
        }
    }

    /// 60分未満は「18分」、以上は「1時間20分」「5時間」のように表示する。
    nonisolated static func durationText(minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes)分" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours)時間" : "\(hours)時間\(rest)分"
    }
}
