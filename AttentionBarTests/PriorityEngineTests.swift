import Foundation
import Testing
@testable import AttentionBar

private let minute: TimeInterval = 60

private func select(_ items: [AttentionItem], at offset: TimeInterval) -> String? {
    PriorityEngine.select(from: items, now: now(offset))?.title
}

struct GracePeriodTests {
    @Test func returnsNilWhenEmpty() {
        #expect(select([], at: 0) == nil)
    }

    @Test func keepsStartedEventDuringGracePeriod() {
        let items = [item("A", at: 0), item("B", at: 30 * minute)]
        #expect(select(items, at: -minute) == "A")
        #expect(select(items, at: 0) == "A")
        #expect(select(items, at: PriorityEngine.gracePeriod - 1) == "A")
    }

    @Test func switchesToNextItemAfterGracePeriod() {
        let items = [item("A", at: 0), item("B", at: 30 * minute)]
        #expect(select(items, at: PriorityEngine.gracePeriod) == "B")
    }

    @Test func returnsNilAfterLastEventGracePeriod() {
        #expect(select([item("A", at: 0)], at: PriorityEngine.gracePeriod) == nil)
    }

    @Test func usesGivenGracePeriod() {
        let items = [item("A", at: 0), item("B", at: 30 * minute)]
        #expect(PriorityEngine.select(from: items, now: now(minute), gracePeriod: 0)?.title == "B")
        #expect(PriorityEngine.select(from: items, now: now(20 * minute), gracePeriod: 30 * minute)?.title == "A")
    }
}

struct TierTests {
    private let overdue = item("牛乳を買う", at: -60 * minute, source: .reminder)

    @Test func overdueReminderBeatsUpcomingEvent() {
        let items = [overdue, item("会議", at: 30 * minute)]
        #expect(select(items, at: 0) == "牛乳を買う")
    }

    @Test func imminentEventBeatsOverdueReminder() {
        let items = [overdue, item("会議", at: 10 * minute)]
        #expect(select(items, at: 0) == "会議")
    }

    @Test func imminentWindowBoundary() {
        let event = item("会議", at: PriorityEngine.imminentWindow)
        #expect(select([overdue, event], at: 0) == "会議")
        #expect(select([overdue, event], at: -1) == "牛乳を買う")
    }

    @Test func startedEventBeatsOverdueReminder() {
        let items = [overdue, item("会議", at: -5 * minute)]
        #expect(select(items, at: 0) == "会議")
    }

    @Test func keepsOverdueReminderWithinLimit() {
        let reminder = item("牛乳を買う", at: 0, source: .reminder)
        #expect(select([reminder], at: PriorityEngine.gracePeriod) == "牛乳を買う")
        #expect(select([reminder], at: PriorityEngine.overdueLimit - 1) == "牛乳を買う")
        #expect(select([reminder], at: PriorityEngine.overdueLimit) == nil)
    }

    @Test func mostOverdueReminderFirst() {
        let items = [item("新しい", at: -10 * minute, source: .reminder), overdue]
        #expect(select(items, at: 0) == "牛乳を買う")
    }

    @Test func upcomingItemsAreOrderedByDueAtAcrossSources() {
        let items = [item("会議", at: 60 * minute), item("提出", at: 30 * minute, source: .reminder)]
        #expect(select(items, at: 0) == "提出")
    }

    @Test(arguments: [
        (AttentionSource.calendar, -16 * minute, PriorityEngine.Tier?.some(.upcoming)),
        (.calendar, -15 * minute, .imminentEvent),
        (.calendar, 0, .imminentEvent),
        (.calendar, 10 * minute, nil),
        (.reminder, -5 * minute, .upcoming),
        (.reminder, 0, .overdueReminder),
        (.reminder, 24 * 60 * minute, nil),
    ])
    func tier(source: AttentionSource, elapsed: TimeInterval, expected: PriorityEngine.Tier?) {
        let target = item(at: 0, source: source)
        #expect(PriorityEngine.tier(of: target, now: now(elapsed)) == expected)
    }
}

struct PriorityTests {
    @Test func prefersLowerPriorityValueWithinSameTier() {
        let items = [item("soon", at: 20 * minute, priority: 2), item("important", at: 60 * minute, priority: 1)]
        #expect(select(items, at: 0) == "important")
    }

    @Test func tierTakesPrecedenceOverPriority() {
        let items = [item("imminent", at: minute, priority: 2), item("important", at: 60 * minute, priority: 1)]
        #expect(select(items, at: 0) == "imminent")
    }

    @Test func prefersEarlierDueAtWhenPriorityIsEqual() {
        let items = [item("later", at: 60 * minute), item("earlier", at: 30 * minute, source: .reminder)]
        #expect(select(items, at: 0) == "earlier")
    }
}

struct RankedTests {
    @Test func ordersByTierThenDueAtAndExcludesExpired() {
        let items = [
            item("後の会議", at: 60 * minute),
            item("終わった会議", at: -20 * minute),
            item("牛乳を買う", at: -60 * minute, source: .reminder),
            item("提出", at: 30 * minute, source: .reminder),
            item("直前の会議", at: 5 * minute),
        ]
        let titles = PriorityEngine.ranked(from: items, now: now(0)).map(\.title)
        #expect(titles == ["直前の会議", "牛乳を買う", "提出", "後の会議"])
    }

    @Test func firstMatchesSelect() {
        let items = [item("A", at: 30 * minute), item("B", at: 10 * minute, source: .reminder)]
        #expect(PriorityEngine.ranked(from: items, now: now(0)).first?.title == select(items, at: 0))
    }
}
