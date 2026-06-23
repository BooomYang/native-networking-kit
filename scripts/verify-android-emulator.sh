#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_ANDROID_SDK="${HOME}/Library/Android/sdk"
ANDROID_SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-${DEFAULT_ANDROID_SDK}}}"
ADB="${ANDROID_SDK}/platform-tools/adb"
EVIDENCE_DIR="${ROOT_DIR}/.tmp/android-emulator-harness"
ADB_DEVICES_FILE="${EVIDENCE_DIR}/adb-devices.txt"
WINDOW_FILE="${EVIDENCE_DIR}/window.txt"
UI_FILE="${EVIDENCE_DIR}/ui.xml"
LOGCAT_FILE="${EVIDENCE_DIR}/logcat.txt"
REMOTE_UI_FILE="/sdcard/native-netkit-ui.xml"
PACKAGE_NAME="com.aifirst.nativenetkit.example"
ACTIVITY_NAME="${PACKAGE_NAME}/.MainActivity"
APK_PATH="${ROOT_DIR}/platforms/android/example/build/outputs/apk/debug/example-debug.apk"

if [ ! -d "${ANDROID_SDK}" ]; then
  echo "Android SDK not found. Set ANDROID_HOME or ANDROID_SDK_ROOT, or install SDK at ${DEFAULT_ANDROID_SDK}." >&2
  exit 1
fi

if [ ! -x "${ADB}" ]; then
  echo "adb not found or not executable: ${ADB}" >&2
  exit 1
fi

mkdir -p "${EVIDENCE_DIR}"

"${ROOT_DIR}/scripts/verify-android.sh"

"${ADB}" devices > "${ADB_DEVICES_FILE}"

if [ -n "${ANDROID_SERIAL:-}" ]; then
  TARGET_SERIAL="${ANDROID_SERIAL}"
  if ! "${ADB}" -s "${TARGET_SERIAL}" get-state 2>/dev/null | grep -qx "device"; then
    echo "ANDROID_SERIAL is set to '${TARGET_SERIAL}', but that target is not online." >&2
    echo "See ${ADB_DEVICES_FILE} for adb devices output." >&2
    exit 1
  fi
else
  ONLINE_TARGETS="$(awk 'NR > 1 && $2 == "device" { print $1 }' "${ADB_DEVICES_FILE}")"
  ONLINE_TARGET_COUNT="$(printf '%s\n' "${ONLINE_TARGETS}" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [ "${ONLINE_TARGET_COUNT}" -eq 0 ]; then
    echo "No online adb target found. Start an emulator or connect a device, then rerun this script." >&2
    echo "See ${ADB_DEVICES_FILE} for adb devices output." >&2
    exit 1
  fi
  if [ "${ONLINE_TARGET_COUNT}" -gt 1 ]; then
    echo "Multiple online adb targets found. Set ANDROID_SERIAL to choose one, then rerun this script." >&2
    echo "See ${ADB_DEVICES_FILE} for adb devices output." >&2
    exit 1
  fi
  TARGET_SERIAL="$(printf '%s\n' "${ONLINE_TARGETS}" | sed -n '1p')"
fi

adb_target() {
  "${ADB}" -s "${TARGET_SERIAL}" "$@"
}

if [ ! -f "${APK_PATH}" ]; then
  echo "Android example APK not found after verify-android.sh: ${APK_PATH}" >&2
  exit 1
fi

adb_target logcat -c
adb_target uninstall "${PACKAGE_NAME}" >/dev/null 2>&1 || true
adb_target install -r "${APK_PATH}" >/dev/null
adb_target shell am start -W -n "${ACTIVITY_NAME}" >/dev/null
sleep 2

adb_target shell dumpsys window > "${WINDOW_FILE}"
FOREGROUND_WINDOW="$(grep -E "mCurrentFocus|mFocusedApp|topResumedActivity|mTopResumedActivity" "${WINDOW_FILE}" || true)"
if ! printf '%s\n' "${FOREGROUND_WINDOW}" | grep -q "${PACKAGE_NAME}"; then
  echo "Android example app is not visible in foreground window state." >&2
  echo "See ${WINDOW_FILE} for dumpsys window output." >&2
  exit 1
fi

adb_target shell uiautomator dump "${REMOTE_UI_FILE}" >/dev/null
adb_target pull "${REMOTE_UI_FILE}" "${UI_FILE}" >/dev/null
adb_target shell rm -f "${REMOTE_UI_FILE}" >/dev/null 2>&1 || true

if ! grep -q "Ready" "${UI_FILE}"; then
  echo "Android example UI dump does not contain expected text: Ready" >&2
  echo "See ${UI_FILE} for uiautomator output." >&2
  exit 1
fi

if ! grep -q "GET" "${UI_FILE}"; then
  echo "Android example UI dump does not contain expected text: GET" >&2
  echo "See ${UI_FILE} for uiautomator output." >&2
  exit 1
fi

APP_PID="$(adb_target shell pidof "${PACKAGE_NAME}" 2>/dev/null | tr -d '\r' | awk '{ print $1 }')"
if [ -n "${APP_PID}" ]; then
  adb_target logcat -d --pid="${APP_PID}" > "${LOGCAT_FILE}"
else
  echo "Android example process pid was not found after launch." >&2
  exit 1
fi

echo "Android emulator capability check passed."
echo "Evidence written to ${EVIDENCE_DIR}"
