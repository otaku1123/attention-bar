import Foundation
import EventKit

/// EventKit 経由でカレンダー（macOS のカレンダーアプリに同期済みのもの）から直近の予定を取得する。
final class CalendarProvider: AttentionProvider {
    private let store = EKEventStore()
    private var changeObserver: NSObjectProtocol?

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

        let now = Date()
        let predicate = store.predicateForEvents(
            withStart: now,
            end: now.addingTimeInterval(lookahead),
            calendars: nil
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
                    title: event.title ?? "(無題の予定)",
                    dueAt: event.startDate,
                    priority: 1,
                    source: .calendar,
                    actionURL: actionURL(for: event)
                )
            }
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

    /// 会議サービスのホスト。メモ内の資料リンクなどを拾わないよう、場所・メモからはこれらのみ抽出する。
    private static let meetingHosts = ["meet.google.com", "zoom.us", "teams.microsoft.com", "teams.live.com", "webex.com"]

    /// event.url を優先し、なければ場所・メモに書かれた会議URLを返す。
    /// Google Calendar の同期予定では Meet のリンクが url ではなくメモ・場所に入っていることが多いため。
    private func actionURL(for event: EKEvent) -> URL? {
        if let url = event.url {
            return url
        }
        let text = [event.location, event.notes].compactMap { $0 }.joined(separator: "\n")
        guard !text.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return nil }

        return detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap(\.url)
            .first { url in
                guard let host = url.host?.lowercased() else { return false }
                return Self.meetingHosts.contains { host == $0 || host.hasSuffix("." + $0) }
            }
    }
}
