#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

check_optional_tool() {
  local name="$1"
  local command="$2"

  if command -v "${command}" >/dev/null 2>&1; then
    echo "[optional-ok] ${name}: $(command -v "${command}")"
  else
    echo "[optional-missing] ${name}: ${command}"
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

check_optional_tool "xcodebuildmcp" "xcodebuildmcp"

if [ -x "${ROOT_DIR}/platforms/harmony/hvigorw" ]; then
  echo "[ok] harmony hvigor wrapper: platforms/harmony/hvigorw"
elif command -v hvigorw >/dev/null 2>&1; then
  echo "[ok] harmony hvigorw on PATH: $(command -v hvigorw)"
else
  echo "[pending] harmony hvigorw not found"
fi
