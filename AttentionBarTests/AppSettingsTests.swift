import Foundation
import Testing
@testable import AttentionBar

@MainActor
struct AppSettingsTests {
    /// テストごとに独立した UserDefaults を使い、実際の設定に影響しないようにする。
    private func makeDefaults() -> UserDefaults {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func usesDefaultValues() {
        let settings = AppSettings(defaults: makeDefaults())
        #expect(settings.gracePeriod == PriorityEngine.gracePeriod)
        #expect(settings.lookahead == 24 * 60 * 60)
        #expect(settings.notificationLeadTime == 5 * 60)
        #expect(settings.startAlertStyle == .panel)
        #expect(settings.excludedCalendarIDs.isEmpty)
    }

    @Test func restoresSavedValues() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.gracePeriodMinutes = 0
        settings.lookaheadHours = 48
        settings.notificationLeadMinutes = 0
        settings.startAlertStyle = .fullScreen
        settings.excludedCalendarIDs = ["work", "holidays"]

        let restored = AppSettings(defaults: defaults)
        #expect(restored.gracePeriodMinutes == 0)
        #expect(restored.lookaheadHours == 48)
        #expect(restored.notificationLeadMinutes == 0)
        #expect(restored.startAlertStyle == .fullScreen)
        #expect(restored.excludedCalendarIDs == ["work", "holidays"])
    }

    /// 旧設定（ON/OFF）で OFF にしていた人は「知らせない」、ON なら「パネル」として引き継ぐ。
    @Test func migratesOldStartAlertToggle() {
        let off = makeDefaults()
        off.set(false, forKey: "showsStartAlert")
        #expect(AppSettings(defaults: off).startAlertStyle == .off)

        let on = makeDefaults()
        on.set(true, forKey: "showsStartAlert")
        #expect(AppSettings(defaults: on).startAlertStyle == .panel)
    }

    @Test func hidesEventAndRestores() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        let event = item("定例", at: 30 * 60)
        settings.hide(event)
        #expect(settings.isHidden(event))
        // 同じタイトルでも別の回（開始時刻が違う）は対象外
        #expect(!settings.isHidden(item("定例", at: 90 * 60)))
        #expect(AppSettings(defaults: defaults).isHidden(event))

        settings.unhideAll()
        #expect(!settings.isHidden(event))
    }

    @Test func prunesHiddenEventsAfterRetention() {
        let settings = AppSettings(defaults: makeDefaults())
        let event = item("定例", at: 0)
        settings.hide(event)
        settings.pruneHiddenEvents(now: now(AppSettings.hiddenEventRetention))
        #expect(settings.isHidden(event))
        settings.pruneHiddenEvents(now: now(AppSettings.hiddenEventRetention + 1))
        #expect(!settings.isHidden(event))
    }

    @Test func hiddenEventKeyKeepsTitleWithDots() {
        let settings = AppSettings(defaults: makeDefaults())
        let event = item("v1.2 リリース確認", at: 0)
        settings.hide(event)
        settings.pruneHiddenEvents(now: now(0))
        #expect(settings.isHidden(event))
    }
}
