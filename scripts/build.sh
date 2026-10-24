#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild -project VitaBridge.xcodeproj -scheme VitaBridge -configuration Release -derivedDataPath "${VITABRIDGE_BUILD_DIR:-build}" build "$@"
