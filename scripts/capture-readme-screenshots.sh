#!/bin/bash
# Requires a logged-in graphical macOS session; uses only the harness's own views.
set -euo pipefail
cd "$(dirname "$0")/.."
build_dir="${VITABRIDGE_BUILD_DIR:-build}"
./scripts/build.sh
products="$build_dir/Build/Products/Release"
xcrun swiftc -parse-as-library -swift-version 6 \
  -F "$products" -framework VitaProtocol -framework VitaTransport \
  -framework ControllerEngine -framework OutputBackends \
  Sources/VitaBridgeApp/AppModel.swift Sources/VitaBridgeApp/ContentView.swift \
  Sources/VitaBridgeApp/MappingEditorView.swift Sources/VitaBridgeApp/SettingsView.swift \
  scripts/CaptureReadmeScreenshots.swift -o "$build_dir/VitaBridgeScreenshotCapture"
"$build_dir/VitaBridgeScreenshotCapture" "$PWD/docs/assets"
