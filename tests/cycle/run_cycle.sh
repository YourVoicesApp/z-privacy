#!/usr/bin/env bash
# Test the cycle tools against the local capture server.
# Does not start Z Privacy. Does not call a real provider.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$HERE/run_cycle.py"
