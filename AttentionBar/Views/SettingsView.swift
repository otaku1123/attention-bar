import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @StateObject private var launchAtLogin = LaunchAtLogin()

    var body: some View {
        Form {
            Section("表示") {
                Picker("予定の開始後も表示する時間", selection: $settings.gracePeriodMinutes) {
                    ForEach(AppSettings.gracePeriodChoices, id: \.self) { minutes in
                        Text(minutes == 0 ? "表示しない" : "\(minutes)分").tag(minutes)
                    }
                }
                Picker("先読み時間", selection: $settings.lookaheadHours) {
                    ForEach(AppSettings.lookaheadChoices, id: \.self) { hours in
                        Text("\(hours)時間先まで").tag(hours)
                    }
                }
            }

            Section("通知") {
                Picker("予定の開始前に通知", selection: $settings.notificationLeadMinutes) {
                    ForEach(AppSettings.notificationLeadChoices, id: \.self) { minutes in
                        Text(minutes == 0 ? "通知しない" : "\(minutes)分前").tag(minutes)
                    }
                }
            }

            Section("起動") {
                Toggle("ログイン時に起動", isOn: Binding(
                    get: { launchAtLogin.isEnabled || launchAtLogin.requiresApproval },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                if launchAtLogin.requiresApproval {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("システム設定のログイン項目で許可すると、自動起動が有効になります。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("ログイン項目を開く") {
                            launchAtLogin.openSystemSettings()
                        }
                    }
                }
                if let message = launchAtLogin.errorMessage {
                    Text("自動起動の設定に失敗しました: \(message)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize()
        .onAppear {
            launchAtLogin.refresh()
        }
    }
}
