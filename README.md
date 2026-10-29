# AttentionBar

「今気づくべきこと」をメニューバーに表示する macOS アプリ。カレンダーの予定とリマインダーから、優先度の高い 1 件をメニューバーに、上位数件をポップアップに表示する。

- 対応 OS: macOS 13 以降
- 外部ライブラリなし（SwiftUI / EventKit / ServiceManagement）
- ネットワーク通信なし。カレンダー・リマインダーは端末内で読むだけ（[プライバシーポリシー](PRIVACY.md)）

## できること

- 次の予定・期限までの残り時間をメニューバーに常時表示（例: `📅 次の予定まで12分`、開始後は `📅 定例会議 3分経過`）
- クリックで上位数件を優先順に一覧表示。予定に会議 URL があればそこから開ける
- 開始 5 分前（設定可）に通知。開始時刻には最前面のパネルまたは全画面で知らせる
- 表示するカレンダーの選択、先読み時間・通知タイミングの設定、ログイン時の自動起動

## インストール

1. [Releases](https://github.com/otaku1123/attention-bar/releases) から最新の `AttentionBar-<バージョン>.zip` をダウンロードし、ダブルクリックで展開する
2. `AttentionBar.app` を `/Applications` に移動して起動する
3. カレンダー・リマインダーへのアクセスを許可する
4. 自動起動したい場合は、ポップアップの「ログイン時に起動」にチェックを入れる（`/Applications` に置いてから設定する）

Developer ID で署名・公証済みなので、Gatekeeper の警告なしで起動できる。

不具合・要望は [Issues](https://github.com/otaku1123/attention-bar/issues) へ。

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
- バージョンは Xcode の `MARKETING_VERSION`（現在 0.3.0）

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
2. 外部テスト → グループを作り（左側に「外部テスト」が無い場合は、先に内部テストのグループを 1 つ作る）、ビルドを追加して「審査へ提出」する。初回のビルドはベータ版 App 審査がある（通常 1 日程度）。同じバージョンの 2 回目以降のビルドは審査なしで配布されることが多い
3. 承認後、テスターに使う Apple ID のメールアドレスを追加する（または公開リンクを有効にする）
4. インストールしたい Mac に [TestFlight](https://apps.apple.com/app/testflight/id899247664) を入れ、招待された Apple ID でサインインし、招待メールのリンク（または公開リンク）から AttentionBar をインストールする
5. Developer ID 版（zip）を入れている場合は、先に `/Applications/AttentionBar.app` を削除する

TestFlight のビルドは 90 日で期限切れになるため、定期的にアップロードし直す。

## ブランチ運用とリリース

- `develop`: 開発ブランチ。機能ブランチ（`feature/<issue番号>-<名前>`）からの PR はここに向ける
- `main`: リリース済みのコードだけを置く。**配布物は必ず `main` からビルドする**
- タグ `v<MARKETING_VERSION>` は `main` のマージコミットに打つ

### リリース手順

1. Xcode で `MARKETING_VERSION` を上げ、`develop` にマージしておく
2. `develop` → `main` の PR を作ってマージする（PR の本文がリリースノートの下書きになる）
3. `main` でビルド・署名・公証し、Release を作る

```bash
git checkout main && git pull
scripts/release.sh
gh release create v0.3.0 build/release/AttentionBar-0.3.0.zip \
    --target main --title "AttentionBar 0.3.0" --generate-notes
```

- `--generate-notes` は前回のタグ以降にマージされた PR からノートを自動生成する
- zip を直接渡す場合（AirDrop など）も、受け取った側の手順は「インストール」と同じ
- TestFlight（`scripts/testflight.sh`）も同様に `main` から行う

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
| `Failed to Use Accounts`、または `Team "... (Personal Team)" is not enrolled` | Program 加入前のチーム情報が残っている。Xcode → Settings → Accounts で Apple ID を削除して追加し直し、Xcode を再起動する。コマンドラインで失敗する場合は `open build/testflight/AttentionBar.xcarchive` → Distribute App → App Store Connect でアップロードする |
| アップロードで `No suitable application records were found` | 「TestFlight で配布」の初回の準備 1（App Store Connect への登録）を行う |
| アップロードで `bundle version must be higher` | 同じビルド番号が既にある。`BUILD_NUMBER=<より大きい値> scripts/testflight.sh` |
| 会議中などにメニューバーから表示が消える | メニューバーの幅が足りず、macOS が左側のアイコンから隠している。⌘ を押しながらアイコンを右側（時計の近く）へドラッグすると隠れにくくなる。不要な常駐アプリを減らすのも有効 |

## ライセンス

[MIT License](LICENSE)
