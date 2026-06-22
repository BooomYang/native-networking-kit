#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODE_DERIVED_DATA="${ROOT_DIR}/.tmp/xcode-ios-example"
XCODE_HOME="${ROOT_DIR}/.tmp/xcode-home"
XCODE_PACKAGE_CACHE="${ROOT_DIR}/.tmp/xcode-package-cache"
XCODE_CLONED_PACKAGES="${ROOT_DIR}/.tmp/xcode-packages"

"${ROOT_DIR}/scripts/verify-ios-tests.sh"

mkdir -p \
  "${XCODE_HOME}" \
  "${XCODE_PACKAGE_CACHE}" \
  "${XCODE_CLONED_PACKAGES}"

CFFIXED_USER_HOME="${XCODE_HOME}" \
HOME="${XCODE_HOME}" \
xcodebuild \
  -project "${ROOT_DIR}/platforms/ios/Examples/NativeNetKitExample/NativeNetKitExample.xcodeproj" \
  -scheme NativeNetKitExample \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "${XCODE_DERIVED_DATA}" \
  -clonedSourcePackagesDirPath "${XCODE_CLONED_PACKAGES}" \
  -packageCachePath "${XCODE_PACKAGE_CACHE}" \
  CODE_SIGNING_ALLOWED=NO \
  build
