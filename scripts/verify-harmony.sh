#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARMONY_DIR="${ROOT_DIR}/platforms/harmony"
DEVECO_HOME="${DEVECO_HOME:-/Applications/DevEco-Studio.app}"
DEVECO_STUDIO_DIR="${DEVECO_HOME}/Contents"
DEVECO_HVIGORW="${DEVECO_STUDIO_DIR}/tools/hvigor/bin/hvigorw"
DEVECO_OHPM="${DEVECO_STUDIO_DIR}/tools/ohpm/bin/ohpm"
DEVECO_NODE_HOME="${DEVECO_STUDIO_DIR}/tools/node"
DEVECO_DEFAULT_SDK_HOME="${DEVECO_STUDIO_DIR}/sdk"
HVIGOR_FLAGS=(--no-daemon --no-parallel)

run_hvigor() {
  local hvigorw="$1"
  local use_deveco_defaults="$2"
  shift 2
  local env_args=()

  if [ -n "${DEVECO_SDK_HOME:-}" ]; then
    env_args+=("DEVECO_SDK_HOME=${DEVECO_SDK_HOME}")
  elif [ "${use_deveco_defaults}" = "true" ]; then
    env_args+=("DEVECO_SDK_HOME=${DEVECO_DEFAULT_SDK_HOME}")
  fi

  if [ -n "${NODE_HOME:-}" ]; then
    env_args+=("NODE_HOME=${NODE_HOME}")
  elif [ "${use_deveco_defaults}" = "true" ] && [ -x "${DEVECO_NODE_HOME}/bin/node" ]; then
    env_args+=("NODE_HOME=${DEVECO_NODE_HOME}")
  fi

  (
    cd "${HARMONY_DIR}"
    env "${env_args[@]}" "${hvigorw}" "$@" "${HVIGOR_FLAGS[@]}"
  )
}

install_harmony_test_deps() {
  local ohpm_bin=""
  if command -v ohpm >/dev/null 2>&1; then
    ohpm_bin="$(command -v ohpm)"
  elif [ -x "${DEVECO_OHPM}" ]; then
    ohpm_bin="${DEVECO_OHPM}"
  else
    echo "PENDING: ohpm is not available. Install Harmony test dependencies, then rerun this script."
    exit 0
  fi

  (
    cd "${HARMONY_DIR}/native-netkit"
    "${ohpm_bin}" install
  )
}

install_harmony_test_deps

if [ -x "${HARMONY_DIR}/hvigorw" ]; then
  run_hvigor "${HARMONY_DIR}/hvigorw" false --mode module -p module=NativeNetKit test
  run_hvigor "${HARMONY_DIR}/hvigorw" false --mode module -p module=NativeNetKit assembleHar
  run_hvigor "${HARMONY_DIR}/hvigorw" false assembleHap
elif command -v hvigorw >/dev/null 2>&1; then
  run_hvigor "$(command -v hvigorw)" false --mode module -p module=NativeNetKit test
  run_hvigor "$(command -v hvigorw)" false --mode module -p module=NativeNetKit assembleHar
  run_hvigor "$(command -v hvigorw)" false assembleHap
elif [ -x "${DEVECO_HVIGORW}" ] && [ -x "${DEVECO_NODE_HOME}/bin/node" ]; then
  run_hvigor "${DEVECO_HVIGORW}" true --mode module -p module=NativeNetKit test
  run_hvigor "${DEVECO_HVIGORW}" true --mode module -p module=NativeNetKit assembleHar
  run_hvigor "${DEVECO_HVIGORW}" true assembleHap
else
  echo "PENDING: hvigorw is not available. Open platforms/harmony in DevEco Studio or install Hvigor, then rerun this script."
fi
