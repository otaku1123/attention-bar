import Foundation
import UserNotifications

/// カレンダーの予定の開始前にローカル通知を出す。
///
/// 取得のたびに保留中の通知を作り直す。識別子を予定ごとに固定しているため、
/// 同じ予定を何度登録しても上書きになり、重複して通知しない。
@MainActor
final class NotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    private nonisolated static let identifierPrefix = "attention."

    struct Plan: Equatable {
        let identifier: String
        let title: String
        let body: String
        let fireDate: Date
    }

    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    /// leadTime が 0 以下なら通知しない（予約済みの通知も取り消す）。
    func schedule(_ items: [AttentionItem], now: Date, leadTime: TimeInterval) async {
        let plans = Self.plan(for: items, now: now, leadTime: leadTime)
        let planned = Set(plans.map(\.identifier))

        // 消えた予定・時刻が変わった予定の通知を取り消す
        let stale = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) && !planned.contains($0) }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        // 通知しない設定のときは許可ダイアログを出さない
        guard !plans.isEmpty else { return }

        // 初回のみ許可ダイアログが出る。2回目以降は現在の許可状態が返る
        let granted: Bool
        do {
            granted = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            print("[NotificationScheduler] requestAuthorization failed: \(error)")
            return
        }
        guard granted else { return }

        for plan in plans {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = plan.body
            content.sound = .default
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: plan.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: plan.identifier, content: content, trigger: trigger))
            } catch {
                print("[NotificationScheduler] add failed: \(error)")
            }
        }
    }

    /// 通知するアイテムと時刻を決める。通知時刻を過ぎたものは対象外。
    nonisolated static func plan(for items: [AttentionItem], now: Date, leadTime: TimeInterval, localization: Localization = .current) -> [Plan] {
        guard leadTime > 0 else { return [] }
        return items
            .filter { $0.source == .calendar }
            .compactMap { item in
                let fireDate = item.dueAt.addingTimeInterval(-leadTime)
                guard fireDate > now else { return nil }
                let time = item.dueAt.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(localization.locale))
                return Plan(
                    identifier: "\(identifierPrefix)\(item.source).\(Int(item.dueAt.timeIntervalSince1970)).\(item.title)",
                    title: item.title,
                    body: localization.string("\(Int(leadTime / 60))分後に開始（\(time)）"),
                    fireDate: fireDate
                )
            }
    }

    /// メニューバーアプリは前面扱いになることがあるため、その場合もバナーを出す。
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
