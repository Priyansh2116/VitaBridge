#!/bin/bash
# Ad-hoc development artifact; this does not sign with Developer ID or notarize.
set -euo pipefail
cd "$(dirname "$0")/.."
release_dir="${VITABRIDGE_RELEASE_DIR:-dist}"
build_dir="${VITABRIDGE_BUILD_DIR:-build}"
./scripts/build.sh ONLY_ACTIVE_ARCH=NO ARCHS='arm64 x86_64' "$@"
app_path="$build_dir/Build/Products/Release/VitaBridge.app"
codesign --verify --deep --strict "$app_path"
python3 scripts/check-watchdog.py "$app_path/Contents/MacOS/VitaBridge"
mkdir -p "$release_dir"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$release_dir/VitaBridge-macOS-universal.zip"
(
  cd "$release_dir"
  shasum -a 256 VitaBridge-macOS-universal.zip > SHA256SUMS
)
