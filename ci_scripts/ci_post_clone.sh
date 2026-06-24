#!/bin/sh

#  ci_post_clone.sh
#  Xcode Cloud 在 clone 完成後執行。
#  本專案的 .xcodeproj 由 XcodeGen 產生且未入版控，故需在 CI 端重新生成，
#  否則會出現「Project POS_IPHONE_2026.xcodeproj does not exist at the root of the repository」。

set -e

echo "==> Installing XcodeGen via Homebrew"
brew install xcodegen

echo "==> Generating Xcode project from project.yml"
cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate

# Xcode Cloud 關閉「自動」套件解析，且要求預先存在 Package.resolved；
# 其沙箱在 post-clone 不允許網路解析。由於 .xcodeproj（含其 Package.resolved）
# 未入版控、且 xcodegen generate 會清掉 workspace，故改為：把版控中的
# ci_scripts/Package.resolved 複製到 Xcode Cloud 期望的路徑（generate 之後）。
echo "==> Installing committed Package.resolved into generated workspace"
SWIFTPM_DIR="POS_IPHONE_2026.xcodeproj/project.xcworkspace/xcshareddata/swiftpm"
mkdir -p "$SWIFTPM_DIR"
cp "ci_scripts/Package.resolved" "$SWIFTPM_DIR/Package.resolved"

echo "==> Done. Project + Package.resolved in place:"
ls -la "$CI_PRIMARY_REPOSITORY_PATH"/POS_IPHONE_2026.xcodeproj
ls -la "$CI_PRIMARY_REPOSITORY_PATH/$SWIFTPM_DIR"
