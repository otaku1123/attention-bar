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

            Text("次の予定")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let item = store.item {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.body.weight(.semibold))
                    Text("開始: \(item.dueAt.formatted(date: .omitted, time: .shortened))")
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

            Divider()

            HStack {
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
