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
}
