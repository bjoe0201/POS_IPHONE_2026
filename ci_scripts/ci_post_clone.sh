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

# Xcode Cloud 關閉「自動」套件解析，且要求預先存在 Package.resolved。
# 由於 .xcodeproj（含其 Package.resolved）未入版控，這裡明確解析一次，
# 把 Package.resolved 寫到 Xcode Cloud 期望的路徑（專案內 workspace 的 swiftpm 目錄）。
echo "==> Resolving Swift Package dependencies (writes Package.resolved)"
xcodebuild -resolvePackageDependencies \
  -project POS_IPHONE_2026.xcodeproj \
  -scheme POS

echo "==> Done. Project + Package.resolved generated:"
ls -la "$CI_PRIMARY_REPOSITORY_PATH"/POS_IPHONE_2026.xcodeproj
ls -la "$CI_PRIMARY_REPOSITORY_PATH"/POS_IPHONE_2026.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/ 2>/dev/null || true
