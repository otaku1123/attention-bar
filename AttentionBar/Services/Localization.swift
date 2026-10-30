import Foundation

/// 表示に使う言語。アプリでは macOS の言語設定に従い、テストでは言語を固定するために差し替える（#61）。
struct Localization {
    let bundle: Bundle
    let locale: Locale

    static let current = Localization(bundle: .main, locale: .current)

    init(bundle: Bundle, locale: Locale) {
        self.bundle = bundle
        self.locale = locale
    }

    /// 指定した言語の翻訳だけを使う。その言語のリソースがなければ current と同じ翻訳になる。
    init(language: String) {
        let path = Bundle.main.path(forResource: language, ofType: "lproj")
        self.init(bundle: path.flatMap(Bundle.init(path:)) ?? .main, locale: Locale(identifier: language))
    }

    func string(_ value: String.LocalizationValue) -> String {
        String(localized: value, bundle: bundle, locale: locale)
    }
}
