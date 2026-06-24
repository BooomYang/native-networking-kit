#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVECO_HOME="${DEVECO_HOME:-/Applications/DevEco-Studio.app}"
DEVECO_STUDIO_DIR="${DEVECO_HOME}/Contents"
DEVECO_HVIGORW="${DEVECO_STUDIO_DIR}/tools/hvigor/bin/hvigorw"
DEVECO_NODE_HOME="${DEVECO_STUDIO_DIR}/tools/node"
DEVECO_SDK_HOME="${DEVECO_SDK_HOME:-${DEVECO_STUDIO_DIR}/sdk}"

echo "NativeNetKit doctor"
echo "Repo: ${ROOT_DIR}"
echo

check_tool() {
  local name="$1"
  local command="$2"

  if command -v "${command}" >/dev/null 2>&1; then
    echo "[ok] ${name}: $(command -v "${command}")"
  else
    echo "[missing] ${name}: ${command}"
  fi
}

check_tool "swift" "swift"
if command -v swift >/dev/null 2>&1; then
  swift --version | head -n 1
fi

check_tool "xcodebuild" "xcodebuild"
if command -v xcodebuild >/dev/null 2>&1; then
  xcodebuild -version | tr '\n' ' '
  echo
fi

check_tool "java" "java"
if command -v java >/dev/null 2>&1; then
  java -version 2>&1 | head -n 1
fi

if [ -x "${ROOT_DIR}/platforms/android/gradlew" ]; then
  echo "[ok] android gradle wrapper: platforms/android/gradlew"
else
  echo "[missing] android gradle wrapper: platforms/android/gradlew"
fi

check_tool "node" "node"
if command -v node >/dev/null 2>&1; then
  node --version
fi

if [ -x "${ROOT_DIR}/platforms/harmony/hvigorw" ]; then
  echo "[ok] harmony hvigor wrapper: platforms/harmony/hvigorw"
elif command -v hvigorw >/dev/null 2>&1; then
  echo "[ok] harmony hvigorw on PATH: $(command -v hvigorw)"
elif [ -x "${DEVECO_HVIGORW}" ] && [ -x "${DEVECO_NODE_HOME}/bin/node" ]; then
  echo "[ok] harmony bundled hvigorw: ${DEVECO_HVIGORW}"
  if [ -d "${DEVECO_SDK_HOME}" ]; then
    echo "[ok] harmony bundled sdk path: ${DEVECO_SDK_HOME}"
  else
    echo "[pending] harmony bundled sdk path missing: ${DEVECO_SDK_HOME}"
  fi
else
  echo "[pending] harmony hvigorw not found"
fi
