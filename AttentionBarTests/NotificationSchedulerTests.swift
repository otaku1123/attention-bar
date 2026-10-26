import Foundation
import Testing
@testable import AttentionBar

struct NotificationPlanTests {
    private let minute: TimeInterval = 60
    private let leadTime: TimeInterval = 5 * 60

    private func plan(_ items: [AttentionItem], at offset: TimeInterval, leadTime: TimeInterval? = nil) -> [NotificationScheduler.Plan] {
        NotificationScheduler.plan(for: items, now: now(offset), leadTime: leadTime ?? self.leadTime)
    }

    @Test func notifiesCalendarEventsLeadTimeBeforeStart() {
        let plans = plan([item("会議", at: 30 * minute)], at: 0)
        #expect(plans.count == 1)
        #expect(plans.first?.title == "会議")
        #expect(plans.first?.fireDate == now(30 * minute - leadTime))
    }

    @Test func excludesRemindersAndPastFireDates() {
        let items = [
            item("提出", at: 30 * minute, source: .reminder),
            item("まもなく", at: leadTime),
            item("進行中", at: -minute),
        ]
        #expect(plan(items, at: 0).isEmpty)
    }

    @Test func identifierIsStableAndDistinguishesEvents() {
        let a = plan([item("会議", at: 30 * minute)], at: 0)
        let b = plan([item("会議", at: 30 * minute)], at: minute)
        let moved = plan([item("会議", at: 40 * minute)], at: 0)
        #expect(a.first?.identifier == b.first?.identifier)
        #expect(a.first?.identifier != moved.first?.identifier)
    }

    @Test func noNotificationWhenLeadTimeIsZero() {
        #expect(plan([item("会議", at: 30 * minute)], at: 0, leadTime: 0).isEmpty)
    }

    @Test func usesGivenLeadTime() {
        let plans = plan([item("会議", at: 30 * minute)], at: 0, leadTime: 10 * minute)
        #expect(plans.first?.fireDate == now(20 * minute))
        #expect(plans.first?.body.hasPrefix("10分後に開始") == true)
    }
}
