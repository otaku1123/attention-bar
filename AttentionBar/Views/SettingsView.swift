import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    /// 設定画面を開くたびにカレンダー一覧を読み直す。
    let loadCalendars: () -> [CalendarOption]
    @StateObject private var launchAtLogin = LaunchAtLogin()
    @State private var calendars: [CalendarOption] = []

    private static func startAlertLeadText(_ seconds: Int) -> String {
        switch seconds {
        case 0: String(localized: "開始時刻")
        case ..<60: String(localized: "\(seconds)秒前")
        default: String(localized: "\(seconds / 60)分前")
        }
    }

    var body: some View {
        Form {
            Section("表示") {
                Picker("予定の開始後も表示する時間", selection: $settings.gracePeriodMinutes) {
                    ForEach(AppSettings.gracePeriodChoices, id: \.self) { minutes in
                        Text(minutes == 0 ? "表示しない" : "\(minutes)分" as LocalizedStringKey).tag(minutes)
                    }
                }
                Text("2時間以内の予定は、終了まで残り時間を表示します（次の予定が15分以内に迫ったら切り替えます）。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Picker("先読み時間", selection: $settings.lookaheadHours) {
                    ForEach(AppSettings.lookaheadChoices, id: \.self) { hours in
                        Text("\(hours)時間先まで").tag(hours)
                    }
                }
            }

            Section("カレンダー") {
                if calendars.isEmpty {
                    Text("カレンダーを取得できません。カレンダーへのアクセスを許可してください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(sourceTitles, id: \.self) { source in
                    Text(source)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(calendars.filter { $0.sourceTitle == source }) { calendar in
                        Toggle(isOn: isIncluded(calendar)) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(cgColor: calendar.color ?? CGColor(gray: 0.5, alpha: 1)))
                                    .frame(width: 10, height: 10)
                                Text(calendar.title)
                            }
                        }
                    }
                }
            }

            Section("通知") {
                Picker("予定の開始前に通知", selection: $settings.notificationLeadMinutes) {
                    ForEach(AppSettings.notificationLeadChoices, id: \.self) { minutes in
                        Text(minutes == 0 ? "通知しない" : "\(minutes)分前" as LocalizedStringKey).tag(minutes)
                    }
                }
                Picker("予定の開始時刻に最前面で知らせる", selection: $settings.startAlertStyle) {
                    ForEach(StartAlertStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                Picker("最前面で知らせるタイミング", selection: $settings.startAlertLeadSeconds) {
                    ForEach(AppSettings.startAlertLeadChoices, id: \.self) { seconds in
                        Text(Self.startAlertLeadText(seconds)).tag(seconds)
                    }
                }
                .disabled(settings.startAlertStyle == .off)
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
        // カレンダーが多いと縦に長くなるため、高さを固定して Form 内をスクロールさせる
        .frame(width: 420, height: 560)
        .onAppear {
            launchAtLogin.refresh()
            calendars = loadCalendars()
        }
    }

    /// アカウント名（並び順は一覧のソート順に従う）。
    private var sourceTitles: [String] {
        calendars.reduce(into: []) { titles, calendar in
            if !titles.contains(calendar.sourceTitle) {
                titles.append(calendar.sourceTitle)
            }
        }
    }

    private func isIncluded(_ calendar: CalendarOption) -> Binding<Bool> {
        Binding(
            get: { !settings.excludedCalendarIDs.contains(calendar.id) },
            set: { included in
                if included {
                    settings.excludedCalendarIDs.remove(calendar.id)
                } else {
                    settings.excludedCalendarIDs.insert(calendar.id)
                }
            }
        )
    }
}
