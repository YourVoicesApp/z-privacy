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

echo "Summary of captured requests (per request):"
jq -r '.[] | "- method: \(.method) path: \(.path) leak_detected: \(.leak_detected) body: \(.body)"' "$CAPTURE_LOG" || true

# Report leakage detections flagged by capture server
if jq -e '.[] | .leak_detected | (.ibans | length > 0) or (.names | length > 0)' "$CAPTURE_LOG" >/dev/null 2>&1; then
  echo "WARNING: One or more captured requests contained raw values (logged as leaks)"
  jq -r '.[] | select(.leak_detected) | "- request leak_detected: " + (if .leak_detected.ibans then ("IBANs:" + (.leak_detected.ibans|join(","))) else "" end) + (if .leak_detected.names then (" NAMES:" + (.leak_detected.names|join(","))) else "" end)' "$CAPTURE_LOG" || true
else
  echo "OK: No obvious raw IBANs or clear names detected by capture server"
fi

# check for placeholders like [FULLNAME_1]
if jq -e '.[] | .body | tostring | test("\\[[A-Z0-9_]+_\\d+\\]")' "$CAPTURE_LOG" >/dev/null 2>&1; then
  echo "Placeholders observed in captured requests (good: placeholders should be sent instead of raw values)."
else
  echo "No obvious placeholders observed in captured requests."
fi

# Report per-service status files produced by run_cycle.sh
for svc in Z RIZZO SG; do
  if [ -f "$OUTDIR/${svc}.status" ]; then
    status=$(cat "$OUTDIR/${svc}.status")
    echo "$svc status: $status"
  else
    echo "$svc status: MISSING (did not run or probe failed)"
  fi
done

echo "Detailed capture written at $CAPTURE_LOG"
