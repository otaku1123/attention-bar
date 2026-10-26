#!/bin/bash
# AttentionBar を archive して App Store Connect（TestFlight）にアップロードする。
#
# 前提（初回のみ。手順は README.md を参照）
#   - App Store Connect に Bundle ID com.otaku1123.AttentionBar のアプリを登録済み
#   - Xcode → Settings → Accounts に Apple ID（Team 8F2U53RA9A）でサインイン済み
#     （配布用の証明書・プロファイルは -allowProvisioningUpdates で自動作成される）
#
# 使い方: scripts/testflight.sh
set -euo pipefail

cd "$(dirname "$0")/.."

BUILD_DIR="build/testflight"
ARCHIVE="$BUILD_DIR/AttentionBar.xcarchive"
# アップロードごとに増やす必要があるため、日時からビルド番号を作る（例: 20261026.1145）
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d.%H%M)}"

echo "==> archive（ビルド番号: $BUILD_NUMBER）"
rm -rf "$BUILD_DIR"
xcodebuild archive \
    -project AttentionBar.xcodeproj \
    -scheme AttentionBar \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates \
    -quiet \
    CODE_SIGN_STYLE=Automatic \
    CODE_SIGN_IDENTITY="Apple Development" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

echo "==> App Store Connect にアップロード"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportOptionsPlist scripts/ExportOptions-TestFlight.plist \
    -exportPath "$BUILD_DIR/export" \
    -allowProvisioningUpdates

echo
echo "完了: ビルド $BUILD_NUMBER をアップロードしました。App Store Connect で処理が終わると TestFlight に表示されます。"
