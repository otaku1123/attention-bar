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

    /// 全 Provider から並列に取得する。
    /// 失敗した Provider はスキップし、取得できた分だけ返す。権限がないソースは deniedSources に記録する。
    func fetchItems(lookahead: TimeInterval) async -> AttentionFetchResult {
        await withTaskGroup(of: (name: String, result: Result<[AttentionItem], Error>).self) { group in
            for provider in providers {
                group.addTask {
                    do {
                        return ("\(type(of: provider))", .success(try await provider.fetchItems(lookahead: lookahead)))
                    } catch {
                        return ("\(type(of: provider))", .failure(error))
                    }
                }
            }

            // 完了順に集約する（順序は不定だが、表示対象の選択は AttentionStore が行うため影響しない）
            var result = AttentionFetchResult()
            for await (name, outcome) in group {
                switch outcome {
                case .success(let items):
                    result.items += items
                case .failure(AttentionProviderError.accessDenied(let source)):
                    result.deniedSources.insert(source)
                case .failure(let error):
                    print("[AttentionService] \(name) failed: \(error)")
                }
            }
            return result
        }
    }

    /// いずれかの Provider でデータが変わったときに onChange を呼ぶ。
    func observeChanges(_ onChange: @escaping () -> Void) {
        for provider in providers {
            provider.observeChanges(onChange)
        }
    }
}
