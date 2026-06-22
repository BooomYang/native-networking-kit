#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"${ROOT_DIR}/scripts/verify-ios.sh"
"${ROOT_DIR}/scripts/verify-ios-network-harness.sh"
