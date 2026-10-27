import SwiftUI
import AppKit

/// 予定の開始を知らせる最前面のパネル。予定ごとに 1 枚出し、閉じるまで残す。
@MainActor
final class StartAlertPanelController {
    /// 複数の予定が同時に始まったときに重ならないよう、2 枚目以降をずらす幅。
    private static let cascadeOffset: CGFloat = 24

    private var panels: [String: NSPanel] = [:]

    func show(_ item: AttentionItem, identifier: String) {
        guard panels[identifier] == nil else { return }

        // nonactivatingPanel: 作業中のアプリからフォーカスを奪わない
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(button)?.isHidden = true
        }
        // 全画面表示のアプリや別のデスクトップを使っていても見えるようにする
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false

        let hostingView = NSHostingView(rootView: StartAlertView(item: item) { [weak self] in
            self?.close(identifier)
        })
        panel.contentView = hostingView
        panel.setContentSize(hostingView.fittingSize)
        panel.center()
        let offset = CGFloat(panels.count) * Self.cascadeOffset
        panel.setFrameOrigin(NSPoint(x: panel.frame.minX + offset, y: panel.frame.minY - offset))

        // メニューバーアプリは前面にならないため、アクティブでなくても表示する
        panel.orderFrontRegardless()
        panels[identifier] = panel
    }

    private func close(_ identifier: String) {
        panels[identifier]?.close()
        panels[identifier] = nil
    }
}

private struct StartAlertView: View {
    let item: AttentionItem
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("予定の時刻です", systemImage: "bell.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.title2.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("開始: \(AttentionStore.dueText(item.dueAt, now: Date()))")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("閉じる", action: close)
                if let url = item.actionURL {
                    Button {
                        NSWorkspace.shared.open(url)
                        close()
                    } label: {
                        Label("開く", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(20)
        // 透明なタイトルバーの分だけ上に余白を取る
        .padding(.top, 8)
        .frame(width: 360, alignment: .leading)
    }
}
