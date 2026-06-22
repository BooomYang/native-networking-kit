#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS_DIR="${ROOT_DIR}/platforms/ios/Harnesses/NetworkHarness"
TMP_DIR="${ROOT_DIR}/.tmp/ios-network-harness"
SWIFT_TMP_DIR="${TMP_DIR}/swift"
SERVER_LOG="${TMP_DIR}/mock-server.log"
SERVER_PID=""

mkdir -p \
  "${TMP_DIR}" \
  "${SWIFT_TMP_DIR}/cache" \
  "${SWIFT_TMP_DIR}/config" \
  "${SWIFT_TMP_DIR}/security" \
  "${SWIFT_TMP_DIR}/scratch" \
  "${SWIFT_TMP_DIR}/module-cache"

cleanup() {
  if [[ -n "${SERVER_PID}" ]] && kill -0 "${SERVER_PID}" >/dev/null 2>&1; then
    kill "${SERVER_PID}" >/dev/null 2>&1 || true
    wait "${SERVER_PID}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

for tool in node swift; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "[error] required tool not found: ${tool}" >&2
    exit 1
  fi
done

rm -f "${SERVER_LOG}"
node "${HARNESS_DIR}/mock-server.js" >"${SERVER_LOG}" 2>&1 &
SERVER_PID="$!"

PORT=""
UNUSED_PORT=""
for _ in $(seq 1 100); do
  if ! kill -0 "${SERVER_PID}" >/dev/null 2>&1; then
    echo "[error] mock server exited before becoming ready" >&2
    cat "${SERVER_LOG}" >&2 || true
    exit 1
  fi

  PORT="$(awk '/^PORT / { print $2; exit }' "${SERVER_LOG}" 2>/dev/null || true)"
  UNUSED_PORT="$(awk '/^UNUSED_PORT / { print $2; exit }' "${SERVER_LOG}" 2>/dev/null || true)"

  if [[ -n "${PORT}" && -n "${UNUSED_PORT}" ]]; then
    break
  fi

  sleep 0.1
done

if [[ -z "${PORT}" || -z "${UNUSED_PORT}" ]]; then
  echo "[error] mock server did not publish ready ports" >&2
  cat "${SERVER_LOG}" >&2 || true
  exit 1
fi

echo "NativeNetKit Swift host loopback integration harness"
echo "Mock server: http://127.0.0.1:${PORT}"

CLANG_MODULE_CACHE_PATH="${SWIFT_TMP_DIR}/module-cache" \
NATIVE_NET_KIT_MOCK_BASE_URL="http://127.0.0.1:${PORT}" \
NATIVE_NET_KIT_UNUSED_PORT="${UNUSED_PORT}" \
swift run \
  --package-path "${HARNESS_DIR}" \
  --cache-path "${SWIFT_TMP_DIR}/cache" \
  --config-path "${SWIFT_TMP_DIR}/config" \
  --security-path "${SWIFT_TMP_DIR}/security" \
  --scratch-path "${SWIFT_TMP_DIR}/scratch" \
  --manifest-cache local \
  --disable-sandbox \
  NativeNetKitNetworkHarness
