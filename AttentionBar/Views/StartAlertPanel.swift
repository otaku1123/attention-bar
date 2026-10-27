import SwiftUI
import AppKit

/// 予定の開始を知らせる最前面のパネル。予定ごとに 1 枚出し、閉じるまで残す。
@MainActor
final class StartAlertPanelController {
    /// 複数の予定が同時に始まったときに重ならないよう、2 枚目以降をずらす幅。
    private static let cascadeOffset: CGFloat = 24

    private var panels: [String: NSPanel] = [:]
    /// 全画面表示でフォーカスを取る前に前面だったアプリ。閉じたらそこへ戻す。
    private var previousApp: NSRunningApplication?

    func show(_ item: AttentionItem, identifier: String, fullScreen: Bool) {
        guard panels[identifier] == nil else { return }

        let close: () -> Void = { [weak self] in self?.close(identifier) }
        let panel = fullScreen ? makeFullScreenPanel(item, close: close) : makeFloatingPanel(item, close: close)
        // 全画面表示中のアプリや別のデスクトップを使っていても見えるようにする
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panels[identifier] = panel

        if fullScreen {
            // Esc を受け取るためにフォーカスを取る
            if previousApp == nil {
                previousApp = NSWorkspace.shared.frontmostApplication
            }
            // macOS 13 をサポートするため、14 以降の activate() ではなくこちらを使う
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        } else {
            // メニューバーアプリは前面にならないため、アクティブでなくても表示する
            panel.orderFrontRegardless()
        }
    }

    private func makeFloatingPanel(_ item: AttentionItem, close: @escaping () -> Void) -> NSPanel {
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
        panel.level = .statusBar

        let hostingView = NSHostingView(rootView: StartAlertView(item: item, close: close)
            // 透明なタイトルバーの分だけ上に余白を取る
            .padding(.top, 8))
        panel.contentView = hostingView
        panel.setContentSize(hostingView.fittingSize)
        panel.center()
        let offset = CGFloat(panels.count) * Self.cascadeOffset
        panel.setFrameOrigin(NSPoint(x: panel.frame.minX + offset, y: panel.frame.minY - offset))
        return panel
    }

    /// メインディスプレイ（メニューバーのある画面）全体を覆う。
    private func makeFullScreenPanel(_ item: AttentionItem, close: @escaping () -> Void) -> NSPanel {
        let frame = NSScreen.screens.first?.frame ?? NSScreen.main?.frame ?? .zero
        let panel = KeyablePanel(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        // メニューバーと Dock も覆う
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.contentView = NSHostingView(rootView: FullScreenStartAlertView(item: item, close: close))
        panel.setFrame(frame, display: true)
        return panel
    }

    private func close(_ identifier: String) {
        panels[identifier]?.close()
        panels[identifier] = nil

        // 全画面表示がすべて閉じたら、元のアプリにフォーカスを戻す
        let hasFullScreen = panels.values.contains { $0 is KeyablePanel }
        if !hasFullScreen, let app = previousApp {
            previousApp = nil
            app.activate()
        }
    }
}

/// 枠なしのパネルは標準ではキー入力を受けないため、Esc で閉じられるようにする。
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
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
                // フォーカスのある全画面表示では Esc で閉じられる
                Button("閉じる", action: close)
                    .keyboardShortcut(.cancelAction)
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
        .frame(width: 360, alignment: .leading)
    }
}

/// 画面を暗くし、中央にパネルと同じ内容を出す。
private struct FullScreenStartAlertView: View {
    let item: AttentionItem
    let close: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
            StartAlertView(item: item, close: close)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
