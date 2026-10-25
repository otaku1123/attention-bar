import Foundation

struct AttentionFetchResult {
    var items: [AttentionItem] = []
    /// アクセスが許可されていないソース。
    var deniedSources: Set<AttentionSource> = []
}

/// 登録された Provider から AttentionItem を集める窓口。
struct AttentionService {
    private let providers: [any AttentionProvider]

    init(providers: [any AttentionProvider] = [DummyProvider()]) {
        self.providers = providers
    }

    /// 失敗した Provider はスキップし、取得できた分だけ返す。権限がないソースは deniedSources に記録する。
    func fetchItems() async -> AttentionFetchResult {
        var result = AttentionFetchResult()
        for provider in providers {
            do {
                result.items += try await provider.fetchItems()
            } catch AttentionProviderError.accessDenied(let source) {
                result.deniedSources.insert(source)
            } catch {
                print("[AttentionService] \(type(of: provider)) failed: \(error)")
            }
        }
        return result
    }

    /// いずれかの Provider でデータが変わったときに onChange を呼ぶ。
    func observeChanges(_ onChange: @escaping () -> Void) {
        for provider in providers {
            provider.observeChanges(onChange)
        }
    }
}
