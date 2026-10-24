import SwiftUI
import AppKit

struct MenuBarContentView: View {
    @ObservedObject var store: AttentionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AttentionBar")
                .font(.headline)

            Divider()

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
                }
            } else {
                Text("予定はありません")
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
