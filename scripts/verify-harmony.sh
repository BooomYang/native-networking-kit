#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARMONY_DIR="${ROOT_DIR}/platforms/harmony"

if [ -x "${HARMONY_DIR}/hvigorw" ]; then
  "${HARMONY_DIR}/hvigorw" --mode module -p module=NativeNetKit assembleHar
  "${HARMONY_DIR}/hvigorw" assembleHap
elif command -v hvigorw >/dev/null 2>&1; then
  (cd "${HARMONY_DIR}" && hvigorw --mode module -p module=NativeNetKit assembleHar)
  (cd "${HARMONY_DIR}" && hvigorw assembleHap)
else
  echo "PENDING: hvigorw is not available. Open platforms/harmony in DevEco Studio or install Hvigor, then rerun this script."
fi
