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

echo "==> Done. Project generated:"
ls -la "$CI_PRIMARY_REPOSITORY_PATH"/POS_IPHONE_2026.xcodeproj
