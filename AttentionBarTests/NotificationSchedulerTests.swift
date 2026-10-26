import Foundation
import Testing
@testable import AttentionBar

struct NotificationPlanTests {
    private let minute: TimeInterval = 60

    @Test func notifiesCalendarEventsLeadTimeBeforeStart() {
        let plans = NotificationScheduler.plan(for: [item("会議", at: 30 * minute)], now: now(0))
        #expect(plans.count == 1)
        #expect(plans.first?.title == "会議")
        #expect(plans.first?.fireDate == now(30 * minute - NotificationScheduler.leadTime))
    }

    @Test func excludesRemindersAndPastFireDates() {
        let items = [
            item("提出", at: 30 * minute, source: .reminder),
            item("まもなく", at: NotificationScheduler.leadTime),
            item("進行中", at: -minute),
        ]
        #expect(NotificationScheduler.plan(for: items, now: now(0)).isEmpty)
    }

    @Test func identifierIsStableAndDistinguishesEvents() {
        let a = NotificationScheduler.plan(for: [item("会議", at: 30 * minute)], now: now(0))
        let b = NotificationScheduler.plan(for: [item("会議", at: 30 * minute)], now: now(minute))
        let moved = NotificationScheduler.plan(for: [item("会議", at: 40 * minute)], now: now(0))
        #expect(a.first?.identifier == b.first?.identifier)
        #expect(a.first?.identifier != moved.first?.identifier)
    }
}
