#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GRADLEW="${ROOT_DIR}/platforms/android/gradlew"
MOCK_SERVER="${ROOT_DIR}/tools/network-harness/mock-server.js"
TMP_DIR="${ROOT_DIR}/.tmp/android-network-harness"
GRADLE_HOME="${ROOT_DIR}/.tmp/gradle"
ANDROID_USER_DIR="${ROOT_DIR}/.tmp/android"
JAVA_USER_HOME="${ROOT_DIR}/.tmp/home"
MAVEN_LOCAL_REPO="${ROOT_DIR}/.tmp/m2/repository"
SERVER_LOG="${TMP_DIR}/mock-server.log"
DEFAULT_ANDROID_SDK="${HOME}/Library/Android/sdk"
ANDROID_SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-${DEFAULT_ANDROID_SDK}}}"
SERVER_PID=""

cleanup() {
  if [[ -n "${SERVER_PID}" ]] && kill -0 "${SERVER_PID}" >/dev/null 2>&1; then
    kill "${SERVER_PID}" >/dev/null 2>&1 || true
    wait "${SERVER_PID}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

for tool in node; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "[error] required tool not found: ${tool}" >&2
    exit 1
  fi
done

if [ ! -x "${GRADLEW}" ]; then
  echo "Android Gradle Wrapper is missing or not executable: ${GRADLEW}" >&2
  exit 1
fi

if [ ! -d "${ANDROID_SDK}" ]; then
  echo "Android SDK not found. Set ANDROID_HOME or ANDROID_SDK_ROOT, or install SDK at ${DEFAULT_ANDROID_SDK}." >&2
  exit 1
fi

mkdir -p "${TMP_DIR}" "${GRADLE_HOME}" "${ANDROID_USER_DIR}" "${JAVA_USER_HOME}" "${MAVEN_LOCAL_REPO}"

rm -f "${SERVER_LOG}"
node "${MOCK_SERVER}" >"${SERVER_LOG}" 2>&1 &
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

echo "NativeNetKit Android host loopback check"
echo "Mock server: http://127.0.0.1:${PORT}"

GRADLE_USER_HOME="${GRADLE_HOME}" \
GRADLE_OPTS="-Duser.home=${JAVA_USER_HOME} -Dmaven.repo.local=${MAVEN_LOCAL_REPO}" \
HOME="${JAVA_USER_HOME}" \
ANDROID_HOME="${ANDROID_SDK}" \
ANDROID_SDK_ROOT="${ANDROID_SDK}" \
ANDROID_USER_HOME="${ANDROID_USER_DIR}" \
NATIVE_NET_KIT_MOCK_BASE_URL="http://127.0.0.1:${PORT}" \
NATIVE_NET_KIT_UNUSED_PORT="${UNUSED_PORT}" \
"${GRADLEW}" --no-daemon --rerun-tasks -p "${ROOT_DIR}/platforms/android" :native-netkit:networkHarnessTest
