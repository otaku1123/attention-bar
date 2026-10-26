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

## TestFlight で配布

App Store Connect にアップロードし、TestFlight アプリからインストール・更新できるようにする。App Sandbox を有効にしている。

### 初回の準備

1. **App Store Connect にアプリを登録する**
   [App Store Connect](https://appstoreconnect.apple.com) → アプリ →「+」→ 新規 App。
   プラットフォーム: macOS、名前: AttentionBar（ストア上で一意である必要がある）、Bundle ID: `com.otaku1123.AttentionBar`、SKU: 任意（例: `attentionbar`）。
   Bundle ID が選択肢にない場合は、[Identifiers](https://developer.apple.com/account/resources/identifiers/list) で App ID を登録する。
2. **Xcode に Apple ID でサインインする**
   Xcode → Settings → Accounts に Team 8F2U53RA9A の Apple ID があること。配布用の証明書・プロファイルはアップロード時に自動作成される。

### 手順

```bash
scripts/testflight.sh
```

archive → App Store 用に署名 → App Store Connect へアップロードまでを行う。ビルド番号は日時（例: `20261026.1145`）から自動で付ける。

### 期待される結果

- `** EXPORT SUCCEEDED **` と `完了: ビルド ... をアップロードしました` が表示される
- 数分〜数十分後、App Store Connect の TestFlight タブにビルドが表示される

### インストール

開発者アカウントとは別の Apple ID（仕事用など）でも入れられるよう、外部テストで配布する。

1. App Store Connect → TestFlight →「テスト情報」に、ベータ版 App の説明・フィードバック用メールアドレス・審査用の連絡先を入力する（サインインは不要と記載）
2. 外部テスト → グループを作り、ビルドを追加して「審査へ提出」する。初回のビルドはベータ版 App 審査がある（通常 1 日程度）。同じバージョンの 2 回目以降のビルドは審査なしで配布されることが多い
3. 承認後、テスターに使う Apple ID のメールアドレスを追加する（または公開リンクを有効にする）
4. インストールしたい Mac に [TestFlight](https://apps.apple.com/app/testflight/id899247664) を入れ、招待された Apple ID でサインインし、招待メールのリンク（または公開リンク）から AttentionBar をインストールする
5. Developer ID 版（zip）を入れている場合は、先に `/Applications/AttentionBar.app` を削除する

TestFlight のビルドは 90 日で期限切れになるため、定期的にアップロードし直す。

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
| `testflight.sh` で `No Accounts` / 認証エラー | Xcode → Settings → Accounts で Apple ID にサインインし直す |
| アップロードで `No suitable application records were found` | 「TestFlight で配布」の初回の準備 1（App Store Connect への登録）を行う |
| アップロードで `bundle version must be higher` | 同じビルド番号が既にある。`BUILD_NUMBER=<より大きい値> scripts/testflight.sh` |
