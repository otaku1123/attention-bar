import Foundation
import EventKit
import CoreGraphics

/// 設定画面に表示するカレンダー。
struct CalendarOption: Identifiable {
    let id: String
    let title: String
    /// アカウント名（iCloud、Google など）。
    let sourceTitle: String
    let color: CGColor?
}

/// EventKit 経由でカレンダー（macOS のカレンダーアプリに同期済みのもの）から直近の予定を取得する。
final class CalendarProvider: AttentionProvider {
    private let store = EKEventStore()
    private var changeObserver: NSObjectProtocol?

    /// 予定を取得しないカレンダーの calendarIdentifier。取得の前に AttentionStore が設定する。
    var excludedCalendarIDs: Set<String> = []

    deinit {
        if let changeObserver {
            NotificationCenter.default.removeObserver(changeObserver)
        }
    }

    func observeChanges(_ onChange: @escaping () -> Void) {
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { _ in
            onChange()
        }
    }

    func fetchItems(lookahead: TimeInterval) async throws -> [AttentionItem] {
        guard try await requestAccess() else {
            throw AttentionProviderError.accessDenied(.calendar)
        }

        let calendars = store.calendars(for: .event).filter { !excludedCalendarIDs.contains($0.calendarIdentifier) }
        // 空配列を渡すと全カレンダーが対象になるため、すべて除外されている場合はここで終える
        guard !calendars.isEmpty else { return [] }

        let now = Date()
        let predicate = store.predicateForEvents(
            withStart: now,
            end: now.addingTimeInterval(lookahead),
            calendars: calendars
        )

        return store.events(matching: predicate)
            .filter { event in
                !event.isAllDay
                    && event.endDate > now  // 進行中の予定も含める（表示を残すかは AttentionStore が判断）
                    && event.status != .canceled
                    && !isDeclined(event)
            }
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                AttentionItem(
                    title: event.title ?? String(localized: "(無題の予定)"),
                    dueAt: event.startDate,
                    priority: 1,
                    source: .calendar,
                    actionURL: actionURL(for: event),
                    endAt: event.endDate
                )
            }
    }

    /// 選択できるカレンダーの一覧。アクセスが許可されていなければ空。
    func availableCalendars() -> [CalendarOption] {
        store.calendars(for: .event)
            .map { calendar in
                CalendarOption(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    sourceTitle: calendar.source?.title ?? String(localized: "その他"),
                    color: calendar.cgColor
                )
            }
            .sorted { ($0.sourceTitle, $0.title) < ($1.sourceTitle, $1.title) }
    }

    private func requestAccess() async throws -> Bool {
        if #available(macOS 14.0, *) {
            return try await store.requestFullAccessToEvents()
        } else {
            return try await store.requestAccess(to: .event)
        }
    }

    private func isDeclined(_ event: EKEvent) -> Bool {
        event.attendees?.first(where: \.isCurrentUser)?.participantStatus == .declined
    }

    /// 会議サービスの URL のパターン。メモ内の資料リンクなどを拾わないよう、場所・メモからはこれらのみ抽出する。
    struct MeetingPattern {
        /// サブドメイン（us02web.zoom.us など）も一致とみなす。
        let host: String
        /// 同じホストで会議以外のページもあるサービスは、パスの先頭も見る。
        var pathPrefix: String? = nil

        func matches(_ url: URL) -> Bool {
            guard let urlHost = url.host?.lowercased(), urlHost == host || urlHost.hasSuffix("." + host) else { return false }
            guard let pathPrefix else { return true }
            return url.path.lowercased().hasPrefix(pathPrefix)
        }
    }

    static let meetingPatterns: [MeetingPattern] = [
        MeetingPattern(host: "meet.google.com"),
        MeetingPattern(host: "zoom.us"),
        MeetingPattern(host: "zoomgov.com"),
        MeetingPattern(host: "teams.microsoft.com"),
        MeetingPattern(host: "teams.live.com"),
        MeetingPattern(host: "teams.cloud.microsoft"),
        MeetingPattern(host: "webex.com"),
        // app.slack.com はメッセージのリンクにも使われるため、ハドルだけを対象にする
        MeetingPattern(host: "app.slack.com", pathPrefix: "/huddle/"),
        MeetingPattern(host: "chime.aws"),
        MeetingPattern(host: "whereby.com"),
        MeetingPattern(host: "meet.jit.si"),
        MeetingPattern(host: "meet.goto.com"),
        MeetingPattern(host: "gotomeeting.com"),
        MeetingPattern(host: "join.skype.com"),
        MeetingPattern(host: "meeting.zoho.com"),
        MeetingPattern(host: "meetings.ringcentral.com"),
        MeetingPattern(host: "v.ringcentral.com"),
    ]

    /// event.url を優先し、なければ場所・メモに書かれた会議URLを返す。
    /// Google Calendar の同期予定では Meet のリンクが url ではなくメモ・場所に入っていることが多いため。
    private func actionURL(for event: EKEvent) -> URL? {
        if let url = event.url {
            return url
        }
        let text = [event.location, event.notes].compactMap { $0 }.joined(separator: "\n")
        return Self.meetingURL(in: text)
    }

    /// テキスト中で最初に現れる会議 URL。
    static func meetingURL(in text: String) -> URL? {
        guard !text.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return nil }

        return detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap(\.url)
            .first { url in meetingPatterns.contains { $0.matches(url) } }
    }
}
