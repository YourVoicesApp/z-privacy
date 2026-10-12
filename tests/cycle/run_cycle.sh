#!/usr/bin/env bash
# tests/cycle/run_cycle.sh
set -eu
BASEDIR=$(dirname "$0")
OUTDIR="$BASEDIR/output"
mkdir -p "$OUTDIR"

CAPTURE=http://localhost:8081

# Check capture server
if ! curl -sSf "$CAPTURE/requests" >/dev/null; then
  echo "Capture server not reachable at $CAPTURE — start it with docker-compose up -d or run capture_server/app.py"
  exit 2
fi

# Prepare the three canned responses and clear logs
curl -s -X POST "$CAPTURE/prepare" -H 'Content-Type: application/json' -d '{"responses": [
  {"status":200, "body": {"content":"RESTORE_OK: [FULLNAME_1] -> Alice Jensen"}},
  {"status":200, "body": {"content":"RESTORE_FRAGMENTED: [FULLNAME_1_PART] [NAME_PART]"}},
  {"status":200, "body": {"content":"RESTORE_UNKNOWN: <UNKNOWN_TOKEN>"}}
]}' > /dev/null

# Synthetic input text
read -r -d '' PAYLOAD <<'JSON'
{
  "text": "Document: Alice Jensen (also seen as Alicia Jensen) met with Alice Jensen in another place. Account: IT60X0542811101000000123456",
  "include_mapping": true
}
JSON

# Targets (adjust ports if your instances run elsewhere)
declare -A TARGETS=(
  [Z]=http://localhost:5005/analyze
  [RIZZO]=http://localhost:5006/analyze
  [SG]=http://localhost:5007/analyze
)

for name in "Z" "RIZZO" "SG"; do
  url=${TARGETS[$name]}
  echo "--> Posting payload to $name at $url"
  if curl -s -o "$OUTDIR/${name}.response.json" -w "%{http_code}" -X POST "$url" -H 'Content-Type: application/json' -d "$PAYLOAD"; then
    echo " posted to $name"
  else
    echo " failed to post to $name (check service is running and endpoint matches)"
  fi
done

# Give the services a moment to forward to capture server
sleep 1

# Save captured requests
curl -s "$CAPTURE/requests" | jq '.' > "$OUTDIR/captured_requests.json"

echo "Captured requests written to $OUTDIR/captured_requests.json"

# Next: simulate session persistence test (manual steps recommended)
cat > "$OUTDIR/notes.txt" <<'TXT'
Session-persistence tests require stopping and restarting the service while preserving its configured data directory.
For Z: lock the vault or stop the server, restart, then POST the same payload and observe whether the services attempt to restore values.
Record outcomes here.
TXT

echo "Run finished. Inspect $OUTDIR. Then run tests/cycle/check_results.sh to summarize."
