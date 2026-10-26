#!/bin/bash
# 配布用の AttentionBar.app を Developer ID で署名し、公証（Notarization）して zip にする。
#
# 前提（初回のみ。手順は README.md を参照）
#   - キーチェーンに "Developer ID Application" 証明書がある
#   - notarytool の認証情報をキーチェーンプロファイルに保存済み（既定名: AttentionBar-notary）
#
# 使い方: scripts/release.sh
#   NOTARY_PROFILE=<プロファイル名> で別のプロファイルを使える。
set -euo pipefail

cd "$(dirname "$0")/.."

NOTARY_PROFILE="${NOTARY_PROFILE:-AttentionBar-notary}"
BUILD_DIR="build/release"
APP="$BUILD_DIR/Build/Products/Release/AttentionBar.app"

if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo "error: Developer ID Application 証明書がキーチェーンにありません。README.md の「初回の準備」を参照してください。" >&2
    exit 1
fi

echo "==> Release ビルド（Developer ID で署名）"
rm -rf "$BUILD_DIR"
xcodebuild build \
    -project AttentionBar.xcodeproj \
    -scheme AttentionBar \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$BUILD_DIR" \
    -quiet \
    CODE_SIGN_IDENTITY="Developer ID Application" \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    OTHER_CODE_SIGN_FLAGS="--timestamp"

codesign --verify --strict --deep "$APP"
# デバッグ用の get-task-allow が残っていると公証で却下されるため、提出前に止める
if codesign -d --entitlements - "$APP" 2>/dev/null | grep -q "get-task-allow"; then
    echo "error: 署名に com.apple.security.get-task-allow が含まれています。" >&2
    exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
ZIP="$BUILD_DIR/AttentionBar-$VERSION.zip"

echo "==> 公証に提出（数分かかることがあります）"
ditto -c -k --keepParent "$APP" "$ZIP"
RESULT=$(xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json)
STATUS=$(echo "$RESULT" | plutil -extract status raw -)
if [ "$STATUS" != "Accepted" ]; then
    SUBMISSION_ID=$(echo "$RESULT" | plutil -extract id raw -)
    echo "error: 公証に失敗しました（status: $STATUS）。詳細:" >&2
    xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$NOTARY_PROFILE" >&2
    exit 1
fi

echo "==> 公証チケットを staple して zip を作り直す"
xcrun stapler staple "$APP"
rm "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Gatekeeper の判定"
spctl --assess --type execute --verbose "$APP"

echo
echo "完了: $ZIP"
