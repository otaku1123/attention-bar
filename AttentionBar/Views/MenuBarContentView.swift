import SwiftUI
import AppKit

struct MenuBarContentView: View {
    @ObservedObject var store: AttentionStore

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
                    HStack {
                        if let url = item.actionURL {
                            Button {
                                NSWorkspace.shared.open(url)
                            } label: {
                                Label("開く", systemImage: "arrow.up.right.square")
                            }
                        }
                        if item.isCompletable {
                            Button {
                                store.complete(item)
                            } label: {
                                Label("完了にする", systemImage: "checkmark.circle")
                            }
                        }
                    }
                    .padding(.top, 4)
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
                        if item.isCompletable {
                            Button {
                                store.complete(item)
                            } label: {
                                Image(systemName: "circle")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .help("完了にする")
                        } else {
                            Text(item.source.emoji)
                        }
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

            HStack {
                SettingsButton()
                    .keyboardShortcut(",")
                Spacer()
                Button("終了") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 260)
    }
}

private extension AttentionItem {
    var isCompletable: Bool {
        source == .reminder && sourceID != nil
    }
}

/// 設定画面を開くボタン。メニューバーアプリは前面にならないため、開いた後にアプリをアクティブにする。
private struct SettingsButton: View {
    var body: some View {
        if #available(macOS 14.0, *) {
            OpenSettingsButton()
        } else {
            Button("設定…") {
                // macOS 13 には openSettings がないため、Settings シーンのアクションを直接送る
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

@available(macOS 14.0, *)
private struct OpenSettingsButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("設定…") {
            openSettings()
            NSApp.activate()
        }
    }
}
