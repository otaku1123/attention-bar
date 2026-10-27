import Foundation
import EventKit

/// EventKit 経由でリマインダーから期限付きの未完了項目を取得する。
final class ReminderProvider: AttentionProvider {
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
            throw AttentionProviderError.accessDenied(.reminder)
        }

        // 開始日に nil を渡し、期限切れの未完了リマインダーも含める（表示を残すかは AttentionStore が判断）
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: Date().addingTimeInterval(lookahead),
            calendars: nil
        )

        return await fetchReminders(matching: predicate)
            .compactMap { reminder in
                // 時刻のない（日付のみの）リマインダーは残り時間を計算できないため対象外
                guard let components = reminder.dueDateComponents,
                      components.hour != nil,
                      let dueAt = Calendar.current.date(from: components)
                else { return nil }

                return AttentionItem(
                    title: reminder.title ?? "(無題のリマインダー)",
                    dueAt: dueAt,
                    priority: 1,
                    source: .reminder,
                    actionURL: reminder.url
                )
            }
            .sorted { $0.dueAt < $1.dueAt }
    }

    private func fetchReminders(matching predicate: NSPredicate) async -> [EKReminder] {
        await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    private func requestAccess() async throws -> Bool {
        if #available(macOS 14.0, *) {
            return try await store.requestFullAccessToReminders()
        } else {
            return try await store.requestAccess(to: .reminder)
        }
    }
}
