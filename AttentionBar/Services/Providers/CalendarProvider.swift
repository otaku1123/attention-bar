import Foundation
import EventKit

enum CalendarProviderError: Error {
    case accessDenied
}

/// EventKit 経由でカレンダー（macOS のカレンダーアプリに同期済みのもの）から直近の予定を取得する。
final class CalendarProvider: AttentionProvider {
    private let store = EKEventStore()
    private let lookahead: TimeInterval

    init(lookahead: TimeInterval = 24 * 60 * 60) {
        self.lookahead = lookahead
    }

    func fetchItems() async throws -> [AttentionItem] {
        guard try await requestAccess() else {
            throw CalendarProviderError.accessDenied
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
                    && event.startDate > now
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
                    actionURL: event.url
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
}
