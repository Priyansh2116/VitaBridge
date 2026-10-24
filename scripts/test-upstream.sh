#!/bin/bash
# Fetch only for local testing; upstream has no clear redistribution license.
set -euo pipefail
cd "$(dirname "$0")/.."
research_dir="${VITABRIDGE_UPSTREAM_DIR:-${TMPDIR:-/tmp}/vitabridge-upstream}"
revision=bfecfd258dee02b495a1c0f91abb34939647475a
if [[ ! -d "$research_dir/.git" ]]; then
  git clone --no-checkout https://github.com/bclarke123/VitaPad-NG "$research_dir"
  git -C "$research_dir" checkout --detach "$revision"
fi
if [[ "$(git -C "$research_dir" rev-parse HEAD)" != "$revision" ]]; then
  echo "Expected upstream revision $revision in $research_dir. Use a separate checkout at that revision."
  exit 1
fi
export VITABRIDGE_FAKE_VITA="$research_dir/tools/fake_vita.py"
exec ./scripts/test.sh "$@"
