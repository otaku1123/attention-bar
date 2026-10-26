import SwiftUI
import AppKit

struct MenuBarContentView: View {
    @ObservedObject var store: AttentionStore
    @StateObject private var launchAtLogin = LaunchAtLogin()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AttentionBar")
                .font(.headline)

            Divider()

            if !store.deniedSources.isEmpty {
                ForEach(Array(store.deniedSources), id: \.self) { source in
                    VStack(alignment: .leading, spacing: 6) {
                        Label("\(source.displayName)へのアクセスが許可されていません", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                        if let url = source.privacySettingsURL {
                            Button("システム設定を開く") {
                                NSWorkspace.shared.open(url)
                            }
                            // 起動中のプロセスには権限変更が反映されないため
                            Text("設定を変更した後は、アプリを再起動してください。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Divider()
            }

            Text("次にやること")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let item = store.item {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.body.weight(.semibold))
                    Text("\(item.source == .reminder ? "期限" : "開始"): \(AttentionStore.dueText(item.dueAt, now: store.now))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    if let url = item.actionURL {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Label("開く", systemImage: "arrow.up.right.square")
                        }
                        .padding(.top, 4)
                    }
                }
            } else {
                Text(store.deniedSources.isEmpty ? "予定はありません" : "予定を取得できません")
                    .foregroundStyle(.secondary)
            }

            let upcoming = store.rankedItems.dropFirst()
            if !upcoming.isEmpty {
                Divider()

                Text("このあと")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(Array(upcoming.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 6) {
                        Text(item.source.emoji)
                        Text(item.title)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 8)
                        Text(AttentionStore.dueText(item.dueAt, now: store.now))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .font(.callout)
                }
            }

            Divider()

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

            HStack {
                Toggle("ログイン時に起動", isOn: Binding(
                    get: { launchAtLogin.isEnabled || launchAtLogin.requiresApproval },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                .toggleStyle(.checkbox)
                Spacer()
                Button("終了") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 260)
        .onAppear {
            launchAtLogin.refresh()
        }
    }
}
