import Foundation
import ServiceManagement

/// ログイン時の自動起動（SMAppService.mainApp）の登録状態を扱う。
@MainActor
final class LaunchAtLogin: ObservableObject {
    @Published private(set) var status: SMAppService.Status = .notRegistered
    @Published private(set) var errorMessage: String?

    var isEnabled: Bool {
        status == .enabled
    }

    /// 登録済みだが、システム設定のログイン項目で許可されていない状態。
    var requiresApproval: Bool {
        status == .requiresApproval
    }

    init() {
        refresh()
    }

    /// システム設定のログイン項目から変更されることもあるため、表示のたびに読み直す。
    func refresh() {
        status = SMAppService.mainApp.status
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            print("[LaunchAtLogin] \(enabled ? "register" : "unregister") failed: \(error)")
        }
        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
