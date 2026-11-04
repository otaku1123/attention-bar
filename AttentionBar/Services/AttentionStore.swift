import Foundation
import Combine
import AppKit

/// UI が参照する状態。取得済みの items と、残り時間計算用の現在時刻を保持する。
@MainActor
final class AttentionStore: ObservableObject {
    /// Provider から再取得する間隔。
    private static let refreshInterval: TimeInterval = 5 * 60
    /// メニューバーに出すタイトルの最大幅（全角 1 文字 = 2、半角 1 文字 = 1）。超えた分は「…」で省略する。
    /// 会議中はマイク等のインジケータが増えて幅が足りなくなり、macOS にアイコンごと隠されるため短めにする（#35）。
    /// 文字数で数えると英語が短くなりすぎるため、全角 6 文字分の幅で数える（#65）。
    private nonisolated static let menuBarTitleMaxWidth = 12
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
    private var systemObserver: AnyCancellable?
    private var lastLoadedAt: Date?
    private var tickTask: Task<Void, Never>?
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

        // スリープ中の時間は表示を更新できないため、復帰時や日付・時刻の設定が変わったときは取り直す（#43）
        let center = NotificationCenter.default
        systemObserver = Publishers.MergeMany(
            NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification),
            center.publisher(for: .NSCalendarDayChanged),
            center.publisher(for: .NSSystemTimeZoneDidChange),
            center.publisher(for: .NSSystemClockDidChange)
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            guard let self else { return }
            now = Date()
            scheduleReload()
        }

        // 残り時間は分単位で切り替わるため、起動時刻ではなく分の境界に合わせて更新する（#43）
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.secondsUntilNextMinute(from: Date())))
                guard let self else { return }
                tick(Date())
            }
        }
    }

    private func tick(_ date: Date) {
        now = date
        if let lastLoadedAt, date.timeIntervalSince(lastLoadedAt) >= Self.refreshInterval {
            Task { await load() }
        }
    }

    /// 次の分の境界（hh:mm:00）までの秒数。早めに起きて同じ分を表示し直さないよう、少しだけ後ろにずらす。
    /// 基準日（2001-01-01 00:00:00 UTC）は分の境界で、分単位でないタイムゾーンもないため、秒数の剰余で求められる。
    nonisolated static func secondsUntilNextMinute(from date: Date) -> TimeInterval {
        let seconds = date.timeIntervalSinceReferenceDate
        return 60 - (seconds - 60 * (seconds / 60).rounded(.down)) + 0.05
    }

    func load() async {
        lastLoadedAt = Date()
        calendarProvider.excludedCalendarIDs = settings.excludedCalendarIDs
        let result = await service.fetchItems(lookahead: settings.lookahead)
        now = Date()
        settings.pruneHiddenEvents(now: now)
        // 非表示にした予定は、通知・開始時刻のパネルの対象からも外す
        items = result.items.filter { !($0.source == .calendar && settings.isHidden($0)) }
        deniedSources = result.deniedSources
        startAlerts.schedule(items, now: now, style: settings.startAlertStyle, leadTime: settings.startAlertLeadTime)
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

    /// 予定を今回だけ表示しないようにする。設定の変更で再取得が走るが、それを待たずに一覧から消す。
    func hide(_ item: AttentionItem) {
        guard item.source == .calendar else { return }
        settings.hide(item)
        items.removeAll { $0.source == .calendar && settings.isHidden($0) }
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

    nonisolated static func menuBarTitle(item: AttentionItem?, deniedSources: Set<AttentionSource>, now: Date, localization: Localization = .current) -> String {
        let l = localization
        guard let item else {
            // 他ソースのアイテムがあればそちらを優先し、何もないときだけ権限不足を表示する
            if let source = deniedSources.first {
                return "\(source.emoji) " + l.string("\(source.displayName(l))権限なし")
            }
            return "📅 " + l.string("予定なし")
        }
        let emoji = item.source.emoji
        let minutes = item.minutesRemaining(from: now)
        if minutes <= 0 {
            // minutesRemaining は切り上げなので、符号反転すると経過分数（切り捨て）になる
            let elapsed = -minutes
            let title = truncated(item.title, maxWidth: menuBarTitleMaxWidth)
            switch item.source {
            case .reminder:
                if elapsed == 0 {
                    return "\(emoji) " + l.string("\(title) 期限")
                }
                return "\(emoji) " + l.string("\(title) 期限超過\(durationText(minutes: elapsed, localization: l))")
            default:
                if PriorityEngine.tracksUntilEnd(item), let endAt = item.endAt, endAt > now {
                    // 切り上げのため、残り 30 秒は「残り1分」
                    let remaining = Int(ceil(endAt.timeIntervalSince(now) / 60))
                    return "\(emoji) " + l.string("\(title) 残り\(durationText(minutes: remaining, localization: l))")
                }
                if elapsed == 0 {
                    return "\(emoji) " + l.string("\(title) 開始")
                }
                return "\(emoji) " + l.string("\(title) \(elapsed)分経過")
            }
        }
        let duration = durationText(minutes: minutes, localization: l)
        return "\(emoji) " + (item.source == .reminder ? l.string("期限まで\(duration)") : l.string("次の予定まで\(duration)"))
    }

    /// 表示幅が maxWidth を超える場合は、幅に収まる先頭部分に「…」を付ける。
    nonisolated static func truncated(_ text: String, maxWidth: Int) -> String {
        var width = 0
        for index in text.indices {
            width += displayWidth(of: text[index])
            if width > maxWidth {
                // 「Weekly sync …」のように空白の直後で切れたときは空白を詰める
                var head = text[..<index]
                while head.last == " " { head = head.dropLast() }
                return String(head) + "…"
            }
        }
        return text
    }

    /// 全角（CJK・かな・ハングル・全角記号・絵文字）は 2、それ以外は 1。
    /// Unicode の East Asian Width のうち、タイトルに出てくる主な範囲だけを見る。
    nonisolated static func displayWidth(of character: Character) -> Int {
        guard let scalar = character.unicodeScalars.first else { return 1 }
        switch scalar.value {
        case 0x1100...0x115F,   // ハングル字母
             0x2E80...0x303E,   // CJK 部首・記号と句読点
             0x3041...0x33FF,   // かな・CJK 互換
             0x3400...0x4DBF,   // CJK 統合漢字拡張 A
             0x4E00...0x9FFF,   // CJK 統合漢字
             0xA960...0xA97F,   // ハングル字母拡張 A
             0xAC00...0xD7A3,   // ハングル音節
             0xF900...0xFAFF,   // CJK 互換漢字
             0xFE30...0xFE4F,   // CJK 互換形
             0xFF00...0xFF60,   // 全角英数・記号
             0xFFE0...0xFFE6,   // 全角記号
             0x1F300...0x1FAFF, // 絵文字
             0x20000...0x3FFFD: // CJK 統合漢字拡張 B 以降
            return 2
        default:
            return 1
        }
    }

    /// 今日は「10:00」、前後 1 日は「昨日 18:00」「明日 9:00」、それ以外は「10/28 9:00」のように表示する。
    /// 時刻の書式（12 / 24 時間制など）は言語・地域に合わせる。
    nonisolated static func dueText(_ date: Date, now: Date, calendar: Calendar = .current, localization: Localization = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = localization.locale
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        let time = formatter.string(from: date)

        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return time
        case -1: return localization.string("昨日 \(time)")
        case 1: return localization.string("明日 \(time)")
        default:
            formatter.setLocalizedDateFormatFromTemplate("Mdjmm")
            return formatter.string(from: date)
        }
    }

    /// 60分未満は「18分」、以上は「1時間20分」「5時間」のように表示する。
    /// メニューバーの幅を取らないよう英語は「18m」「1h 20m」と短く書くため、設定画面の「N分」とはキーを分ける。
    nonisolated static func durationText(minutes: Int, localization: Localization = .current) -> String {
        let (bundle, locale) = (localization.bundle, localization.locale)
        guard minutes >= 60 else {
            return String(localized: "duration.minutes", defaultValue: "\(minutes)分", bundle: bundle, locale: locale)
        }
        let hours = minutes / 60
        let rest = minutes % 60
        if rest == 0 {
            return String(localized: "duration.hours", defaultValue: "\(hours)時間", bundle: bundle, locale: locale)
        }
        return String(localized: "duration.hoursMinutes", defaultValue: "\(hours)時間\(rest)分", bundle: bundle, locale: locale)
    }
}
