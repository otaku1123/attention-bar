# AttentionBar

「今気づくべきこと」をメニューバーに表示する macOS アプリ。カレンダーの予定とリマインダーから、優先度の高い 1 件をメニューバーに、上位数件をポップアップに表示する。

- 対応 OS: macOS 13 以降
- 外部ライブラリなし（SwiftUI / EventKit / ServiceManagement）

## 開発

```bash
open AttentionBar.xcodeproj
```

Xcode で Run するか、コマンドラインでビルド・テストする。

```bash
xcodebuild build -project AttentionBar.xcodeproj -scheme AttentionBar -derivedDataPath build
xcodebuild test  -project AttentionBar.xcodeproj -scheme AttentionBar -destination 'platform=macOS' -derivedDataPath build
open build/Build/Products/Debug/AttentionBar.app
```

開発用ビルドは Apple Development 証明書（Team 8F2U53RA9A）で署名している。他の Mac では起動できないため、配布には次の手順を使う。

## 配布用ビルド（Developer ID 署名 + 公証）

### 初回の準備

1. **Developer ID Application 証明書を作る**
   Xcode → Settings → Accounts → チーム（8F2U53RA9A）を選択 → Manage Certificates → 左下の「+」→ **Developer ID Application**。
   作成できるのは Apple Developer Program のアカウント所有者（Account Holder）のみ。

   ```bash
   security find-identity -v -p codesigning   # "Developer ID Application: ..." が表示されれば OK
   ```

2. **公証用の認証情報をキーチェーンに保存する**
   [appleid.apple.com](https://appleid.apple.com) の「サインインとセキュリティ」→「App 用パスワード」でパスワードを発行し、次を実行する（対話形式でパスワードを入力）。

   ```bash
   xcrun notarytool store-credentials AttentionBar-notary \
       --apple-id <Apple ID のメールアドレス> \
       --team-id 8F2U53RA9A
   ```

   認証情報はキーチェーンにのみ保存され、リポジトリには含まれない。

### 手順

```bash
scripts/release.sh
```

ビルド → 署名 → 公証 → staple → zip 化 → Gatekeeper の判定までを行う。

### 期待される結果

- 最後に `source=Notarized Developer ID` と `完了: build/release/AttentionBar-<バージョン>.zip` が表示される
- バージョンは Xcode の `MARKETING_VERSION`（現在 0.1.0）

## 別の Mac へのインストール

1. `AttentionBar-<バージョン>.zip` をコピーし（AirDrop、クラウドストレージなど）、ダブルクリックで展開する
2. `AttentionBar.app` を `/Applications` に移動して起動する
3. カレンダー・リマインダーへのアクセスを許可する
4. 自動起動したい場合は、ポップアップの「ログイン時に起動」にチェックを入れる（`/Applications` に置いてから設定する）

## トラブルシューティング

| 症状 | 対処 |
|---|---|
| `Developer ID Application 証明書がキーチェーンにありません` | 「初回の準備」の 1 を行う |
| `No Keychain password item found for profile` | 「初回の準備」の 2 を行う。別名で保存した場合は `NOTARY_PROFILE=<名前> scripts/release.sh` |
| 公証が `Invalid` になる | スクリプトが表示するログの `issues` を確認する（Hardened Runtime、署名のタイムスタンプなど） |
| 別の Mac で「開発元を検証できません」と出る | `spctl --assess --type execute --verbose /Applications/AttentionBar.app` で `Notarized Developer ID` か確認する。staple 前の zip を渡していないか確認する |
| 管理された Mac（MDM）で起動できない | 組織のポリシーで制限されている可能性がある。管理者に確認する |
| 権限をシステム設定で変更しても反映されない | アプリを再起動する |
