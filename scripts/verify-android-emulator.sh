#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_ANDROID_SDK="${HOME}/Library/Android/sdk"
ANDROID_SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-${DEFAULT_ANDROID_SDK}}}"
ADB="${ANDROID_SDK}/platform-tools/adb"
EMULATOR="${ANDROID_SDK}/emulator/emulator"
EVIDENCE_DIR="${ROOT_DIR}/.tmp/android-emulator-harness"
ADB_DEVICES_FILE="${EVIDENCE_DIR}/adb-devices.txt"
WINDOW_FILE="${EVIDENCE_DIR}/window.txt"
UI_FILE="${EVIDENCE_DIR}/ui.xml"
LOGCAT_FILE="${EVIDENCE_DIR}/logcat.txt"
EMULATOR_LOG="${EVIDENCE_DIR}/emulator.log"
EMULATOR_SESSION_LOG="${EVIDENCE_DIR}/emulator-session.log"
REMOTE_UI_FILE="/sdcard/native-netkit-ui.xml"
PACKAGE_NAME="com.aifirst.nativenetkit.example"
ACTIVITY_NAME="${PACKAGE_NAME}/.MainActivity"
APK_PATH="${ROOT_DIR}/platforms/android/example/build/outputs/apk/debug/example-debug.apk"
STARTED_EMULATOR_SERIAL=""

if [ ! -d "${ANDROID_SDK}" ]; then
  echo "Android SDK not found. Set ANDROID_HOME or ANDROID_SDK_ROOT, or install SDK at ${DEFAULT_ANDROID_SDK}." >&2
  exit 1
fi

if [ ! -x "${ADB}" ]; then
  echo "adb not found or not executable: ${ADB}" >&2
  exit 1
fi

mkdir -p "${EVIDENCE_DIR}"

cleanup() {
  if [ -n "${STARTED_EMULATOR_SERIAL}" ] && [ "${NATIVE_NET_KIT_KEEP_EMULATOR:-0}" != "1" ]; then
    "${ADB}" -s "${STARTED_EMULATOR_SERIAL}" emu kill >/dev/null 2>&1 || true
    for _ in $(seq 1 20); do
      if ! "${ADB}" devices | awk -v serial="${STARTED_EMULATOR_SERIAL}" 'NR > 1 && $1 == serial { found = 1 } END { exit found ? 0 : 1 }'; then
        break
      fi
      sleep 1
    done
  fi
}
trap cleanup EXIT INT TERM

online_targets() {
  "${ADB}" devices | awk 'NR > 1 && $2 == "device" { print $1 }'
}

choose_avd() {
  if [ -n "${NATIVE_NET_KIT_ANDROID_AVD:-}" ]; then
    printf '%s\n' "${NATIVE_NET_KIT_ANDROID_AVD}"
    return
  fi

  local avds
  avds="$("${EMULATOR}" -list-avds)"
  if printf '%s\n' "${avds}" | grep -qx "Medium_Phone_API_36.0"; then
    printf '%s\n' "Medium_Phone_API_36.0"
    return
  fi

  printf '%s\n' "${avds}" | sed -n '1p'
}

wait_for_boot() {
  local serial="$1"
  for _ in $(seq 1 180); do
    local state
    state="$("${ADB}" -s "${serial}" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
    if [ "${state}" = "1" ]; then
      return 0
    fi
    sleep 1
  done
  return 1
}

start_emulator_if_needed() {
  "${ADB}" devices > "${ADB_DEVICES_FILE}"

  if [ -n "${ANDROID_SERIAL:-}" ]; then
    TARGET_SERIAL="${ANDROID_SERIAL}"
    if ! "${ADB}" -s "${TARGET_SERIAL}" get-state 2>/dev/null | grep -qx "device"; then
      echo "ANDROID_SERIAL is set to '${TARGET_SERIAL}', but that target is not online." >&2
      echo "See ${ADB_DEVICES_FILE} for adb devices output." >&2
      exit 1
    fi
    return
  fi

  local targets target_count
  targets="$(online_targets)"
  target_count="$(printf '%s\n' "${targets}" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [ "${target_count}" -eq 1 ]; then
    TARGET_SERIAL="$(printf '%s\n' "${targets}" | sed -n '1p')"
    return
  fi
  if [ "${target_count}" -gt 1 ]; then
    echo "Multiple online adb targets found. Set ANDROID_SERIAL to choose one, then rerun this script." >&2
    echo "See ${ADB_DEVICES_FILE} for adb devices output." >&2
    exit 1
  fi

  if [ ! -x "${EMULATOR}" ]; then
    echo "No online adb target found and emulator is missing or not executable: ${EMULATOR}" >&2
    exit 1
  fi
  if ! command -v script >/dev/null 2>&1; then
    echo "No online adb target found and required PTY launcher is missing: script" >&2
    exit 1
  fi

  local avd_name
  avd_name="$(choose_avd)"
  if [ -z "${avd_name}" ]; then
    echo "No online adb target found and no Android Virtual Device is configured." >&2
    echo "Create an AVD in Android Studio Device Manager, or set NATIVE_NET_KIT_ANDROID_AVD to an existing AVD name." >&2
    exit 1
  fi

  rm -f "${EMULATOR_LOG}" "${EMULATOR_SESSION_LOG}"
  echo "No online adb target found. Starting AVD: ${avd_name}"
  # macOS emulator can exit early when launched with plain nohup/background IO.
  # `script` allocates a pseudo-terminal, matching the stable interactive launch path.
  script -q "${EMULATOR_SESSION_LOG}" \
    "${EMULATOR}" -avd "${avd_name}" -no-window -gpu swiftshader_indirect -no-audio -no-snapshot-save \
    >"${EMULATOR_LOG}" 2>&1 &

  for _ in $(seq 1 60); do
    targets="$(online_targets)"
    target_count="$(printf '%s\n' "${targets}" | sed '/^$/d' | wc -l | tr -d ' ')"
    if [ "${target_count}" -eq 1 ]; then
      TARGET_SERIAL="$(printf '%s\n' "${targets}" | sed -n '1p')"
      STARTED_EMULATOR_SERIAL="${TARGET_SERIAL}"
      break
    fi
    sleep 1
  done

  if [ -z "${STARTED_EMULATOR_SERIAL}" ]; then
    echo "Emulator did not appear in adb devices." >&2
    echo "See ${EMULATOR_LOG} and ${EMULATOR_SESSION_LOG}." >&2
    exit 1
  fi

  if ! wait_for_boot "${STARTED_EMULATOR_SERIAL}"; then
    echo "Emulator target did not complete boot: ${STARTED_EMULATOR_SERIAL}" >&2
    echo "See ${EMULATOR_LOG} and ${EMULATOR_SESSION_LOG}." >&2
    exit 1
  fi

  "${ADB}" devices > "${ADB_DEVICES_FILE}"
}

"${ROOT_DIR}/scripts/verify-android.sh"

start_emulator_if_needed

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
