#!/usr/bin/env bash
# tests/cycle/check_results.sh
set -eu
BASEDIR=$(dirname "$0")
OUTDIR="$BASEDIR/output"
CAPTURE_LOG="$OUTDIR/captured_requests.json"

if [ ! -f "$CAPTURE_LOG" ]; then
  echo "No captured requests found. Run run_cycle.sh first."
  exit 1
fi

echo "Summary of captured requests:"
jq -r '.[] | "- method: \(.method) path: \(.path) body: \(.body)"' "$CAPTURE_LOG" || true

# check whether any captured body contains an IBAN or the clear name
if jq -e '.[] | .body | tostring | test("IT60X0542811101000000123456" )' "$CAPTURE_LOG" >/dev/null 2>&1; then
  echo "WARNING: clear IBAN observed in captured requests"
else
  echo "OK: No clear IBAN observed in captured requests"
fi

if jq -e '.[] | .body | tostring | test("Alice Jensen" )' "$CAPTURE_LOG" >/dev/null 2>&1; then
  echo "NOTICE: clear name 'Alice Jensen' observed in captured requests"
else
  echo "OK: No clear name observed in captured requests"
fi

echo "Detailed capture written at $CAPTURE_LOG"
