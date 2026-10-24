import Foundation

/// 登録された Provider から AttentionItem を集める窓口。
struct AttentionService {
    private let providers: [any AttentionProvider]

    init(providers: [any AttentionProvider] = [DummyProvider()]) {
        self.providers = providers
    }

    /// 失敗した Provider はスキップし、取得できた分だけ返す。
    func fetchItems() async -> [AttentionItem] {
        var items: [AttentionItem] = []
        for provider in providers {
            do {
                items += try await provider.fetchItems()
            } catch {
                print("[AttentionService] \(type(of: provider)) failed: \(error)")
            }
        }
        return items
    }

    /// いずれかの Provider でデータが変わったときに onChange を呼ぶ。
    func observeChanges(_ onChange: @escaping () -> Void) {
        for provider in providers {
            provider.observeChanges(onChange)
        }
    }
}
