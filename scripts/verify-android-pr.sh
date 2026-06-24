#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"${ROOT_DIR}/scripts/verify-android-library.sh"
"${ROOT_DIR}/scripts/verify-android-example.sh"
"${ROOT_DIR}/scripts/verify-android-network-harness.sh"
