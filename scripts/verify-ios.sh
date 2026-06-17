#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="${ROOT_DIR}/.tmp/swift"
XCODE_DERIVED_DATA="${ROOT_DIR}/.tmp/xcode-ios-example"
XCODE_HOME="${ROOT_DIR}/.tmp/xcode-home"
XCODE_PACKAGE_CACHE="${ROOT_DIR}/.tmp/xcode-package-cache"
XCODE_CLONED_PACKAGES="${ROOT_DIR}/.tmp/xcode-packages"

mkdir -p \
  "${TMP_DIR}/cache" \
  "${TMP_DIR}/config" \
  "${TMP_DIR}/security" \
  "${TMP_DIR}/scratch" \
  "${TMP_DIR}/module-cache" \
  "${XCODE_HOME}" \
  "${XCODE_PACKAGE_CACHE}" \
  "${XCODE_CLONED_PACKAGES}"

CLANG_MODULE_CACHE_PATH="${TMP_DIR}/module-cache" \
swift test \
  --package-path "${ROOT_DIR}/platforms/ios" \
  --cache-path "${TMP_DIR}/cache" \
  --config-path "${TMP_DIR}/config" \
  --security-path "${TMP_DIR}/security" \
  --scratch-path "${TMP_DIR}/scratch" \
  --manifest-cache local \
  --disable-sandbox

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
