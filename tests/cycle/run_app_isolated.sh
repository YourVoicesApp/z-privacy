#!/usr/bin/env bash
# Start the comparison copy of Z Privacy against the sandbox data dirs and
# the local capture server. Refuses to start if isolation_check.sh fails.
#
# This script is the isolated run method. It is not invoked by run_cycle.sh.
# Connect the in-app provider to http://127.0.0.1:8081 with an empty key
# (loopback). Do not use localhost (the core refuses a name). Do not use a
# real provider. Do not point at ~/.local/share/zprivacy.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
bash "$HERE/isolation_check.sh" >/dev/null
# shellcheck source=env.sh
source "$HERE/env.sh"

COMP="$(cd "$HERE/../.." && pwd)"
BUNDLE_DIR="$COMP/apps/flutter_app/build/linux/x64/release/bundle"
BUNDLE="$BUNDLE_DIR/zprivacy"

if [[ ! -x "$BUNDLE" ]]; then
  echo "no release bundle at $BUNDLE" >&2
  exit 1
fi

if [[ "${1:-}" == "--dry-run" ]]; then
  echo "would exec: $BUNDLE"
  echo "HOME=$HOME"
  echo "XDG_DATA_HOME=$XDG_DATA_HOME"
  echo "data -> $XDG_DATA_HOME/zprivacy"
  echo "docs -> $HOME/Documents/zprivacy"
  echo "provider base (manual Connect): $CYCLE_CAPTURE"
  exit 0
fi

echo "starting isolated Z Privacy"
echo "  data: $XDG_DATA_HOME/zprivacy"
echo "  docs: $HOME/Documents/zprivacy"
echo "  connect the OpenAI-compatible provider to $CYCLE_CAPTURE (empty key)"
cd "$BUNDLE_DIR"
exec ./zprivacy
