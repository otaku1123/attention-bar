import Foundation
import Testing
@testable import AttentionBar

struct StartAlertPlanTests {
    private let minute: TimeInterval = 60

    @Test func plansCalendarEventsBeforeStart() {
        let plans = StartAlertScheduler.plan(for: [item("会議", at: 30 * minute)], now: now(0))
        #expect(plans.count == 1)
        #expect(plans.first?.item.title == "会議")
    }

    @Test func excludesRemindersAndStartedEvents() {
        let items = [
            item("提出", at: 30 * minute, source: .reminder),
            item("ちょうど開始", at: 0),
            item("進行中", at: -minute),
        ]
        #expect(StartAlertScheduler.plan(for: items, now: now(0)).isEmpty)
    }

    @Test func identifierIsStableAndDistinguishesEvents() {
        let a = StartAlertScheduler.plan(for: [item("会議", at: 30 * minute)], now: now(0))
        let b = StartAlertScheduler.plan(for: [item("会議", at: 30 * minute)], now: now(minute))
        let moved = StartAlertScheduler.plan(for: [item("会議", at: 40 * minute)], now: now(0))
        #expect(a.first?.identifier == b.first?.identifier)
        #expect(a.first?.identifier != moved.first?.identifier)
    }

    @Test func firesLeadTimeBeforeStart() {
        let plans = StartAlertScheduler.plan(for: [item("会議", at: 30 * minute)], now: now(0), leadTime: minute)
        #expect(plans.first?.fireDate == now(29 * minute))
    }

    /// 表示時刻を過ぎていても、開始前なら対象にする（すぐに表示される）。
    @Test func plansEventStartingWithinLeadTime() {
        let plans = StartAlertScheduler.plan(for: [item("会議", at: 30)], now: now(0), leadTime: minute)
        #expect(plans.count == 1)
        #expect(plans.first?.fireDate == now(-30))
    }

    @Test func identifierDoesNotDependOnLeadTime() {
        let onTime = StartAlertScheduler.plan(for: [item("会議", at: 30 * minute)], now: now(0))
        let early = StartAlertScheduler.plan(for: [item("会議", at: 30 * minute)], now: now(0), leadTime: minute)
        #expect(onTime.first?.identifier == early.first?.identifier)
    }
}
