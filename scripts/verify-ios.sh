#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="${ROOT_DIR}/.tmp/swift"

mkdir -p \
  "${TMP_DIR}/cache" \
  "${TMP_DIR}/config" \
  "${TMP_DIR}/security" \
  "${TMP_DIR}/scratch" \
  "${TMP_DIR}/module-cache"

CLANG_MODULE_CACHE_PATH="${TMP_DIR}/module-cache" \
swift test \
  --package-path "${ROOT_DIR}/platforms/ios" \
  --cache-path "${TMP_DIR}/cache" \
  --config-path "${TMP_DIR}/config" \
  --security-path "${TMP_DIR}/security" \
  --scratch-path "${TMP_DIR}/scratch" \
  --manifest-cache local \
  --disable-sandbox

CLANG_MODULE_CACHE_PATH="${TMP_DIR}/module-cache" \
swift build \
  --package-path "${ROOT_DIR}/platforms/ios/Examples/NativeNetKitExample" \
  --cache-path "${TMP_DIR}/cache" \
  --config-path "${TMP_DIR}/config" \
  --security-path "${TMP_DIR}/security" \
  --scratch-path "${TMP_DIR}/example-scratch" \
  --manifest-cache local \
  --disable-sandbox
