#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift test --scratch-path "${VITABRIDGE_SWIFT_BUILD_DIR:-.build}" "$@"
