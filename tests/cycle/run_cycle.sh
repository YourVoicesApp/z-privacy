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

# Prepare the canned responses (templates using only {{ph}})
curl -s -X POST "$CAPTURE/prepare" -H 'Content-Type: application/json' -d '{"responses": [
  {"status":200, "body": {"content":"RESTORE_OK: {{ph}}"}},
  {"status":200, "body": {"content":"RESTORE_FRAGMENTED: {{ph}}_PART"}},
  {"status":200, "body": {"content":"RESTORE_UNKNOWN: <UNKNOWN_TOKEN>"}}
]}' > /dev/null

# Write payload to file to avoid quoting issues
cat > "$OUTDIR/payload.json" <<'JSON'
{
  "text": "Document: Alice Jensen (also seen as Alicia Jensen) met with Alice Jensen in another place. Account: IT60X0542811101000000123456",
  "include_mapping": true
}
JSON

# Targets (adjust ports if your instances run elsewhere). Provide full analyze endpoint.
declare -A TARGETS
TARGETS[Z]=${Z_ENDPOINT:-http://localhost:5005/analyze}
TARGETS[RIZZO]=${RIZZO_ENDPOINT:-http://localhost:5006/analyze}
TARGETS[SG]=${SG_ENDPOINT:-http://localhost:5007/analyze}

for name in "Z" "RIZZO" "SG"; do
  url=${TARGETS[$name]}
  echo "--> Probing $name at $url"
  code=$(curl -s -o /dev/null -w "%{http_code}" "$url" || echo 000)
  if [[ "$code" -lt 200 || "$code" -ge 300 ]]; then
    echo "Endpoint $url for $name did not respond 2xx (code=$code). Marking as SKIPPED for automation."
    echo "SKIPPED" > "$OUTDIR/${name}.status"
    continue
  fi

  echo "--> Posting payload to $name at $url"
  # Post payload and capture raw HTTP response and status
  http_out="$OUTDIR/${name}.response.raw"
  http_code_file="$OUTDIR/${name}.status.code"
  curl -s -D - -o "$http_out" -w "%{http_code}" -X POST "$url" -H 'Content-Type: application/json' --data-binary "@$OUTDIR/payload.json" > "$http_code_file" || true
  code=$(cat "$http_code_file")
  echo "$code" > "$OUTDIR/${name}.status"
  echo "HTTP code $code written to $OUTDIR/${name}.status"

  # Save a cleaned JSON response if possible
  if jq -e '.' "$http_out" >/dev/null 2>&1; then
    jq '.' "$http_out" > "$OUTDIR/${name}.response.json" || true
  else
    # try to extract JSON body from raw http response
    awk 'BEGIN{p=0} /^\r?$/{if(p==1) {p=2; next}} /^{/ {p=1} p==1{print}' "$http_out" > "$OUTDIR/${name}.maybe.json" || true
  fi

done

# Give the services a moment to forward to capture server
sleep 1

# Save captured requests
curl -s "$CAPTURE/requests" | jq '.' > "$OUTDIR/captured_requests.json"

echo "Captured requests written to $OUTDIR/captured_requests.json"

# Session persistence / PDF export test (best-effort)
Z_RESP_JSON="$OUTDIR/Z.response.json"
if [ -f "$Z_RESP_JSON" ]; then
  doc_id=$(jq -r '.doc_id // .doc // .download_url // empty' "$Z_RESP_JSON" 2>/dev/null || true)
  if [ -n "$doc_id" ]; then
    echo "Found doc id/url in Z response: $doc_id"
    if [[ "$doc_id" == /* ]]; then
      doc_url="http://localhost:5005${doc_id}"
    else
      doc_url="$doc_id"
    fi
    echo "Attempting to download anonymized PDF for Z -> $doc_url"
    curl -sS "$doc_url" -o "$OUTDIR/Z_anonymized.pdf" || echo "Download failed or not supported"
    if [ -f "$OUTDIR/Z_anonymized.pdf" ]; then
      echo "Anonymized PDF downloaded to $OUTDIR/Z_anonymized.pdf"
      # Note: do NOT attempt to auto-import mapping or open PDF in another session.
      echo "To test session-persistence: export mapping/session via the app (if supported), stop the service, restart, and import the mapping or open the anonymized PDF in the same session context. See README for manual steps."
    fi
  else
    echo "No doc download URL found in Z response; session persistence test for Z cannot be fully automated. Marking as manual step."
    echo "MANUAL: session persistence for Z requires exporting mapping or downloading anonymized PDF via the app UI or /pdf endpoint." > "$OUTDIR/Z_session.manual"
  fi
else
  echo "No machine-readable response from Z; session persistence test for Z cannot be automated." > "$OUTDIR/Z_session.manual"
fi

# Wrong-session test (manual unless programmatic export/import endpoints exist)
# We will not invent export/import endpoints. If your Z instance exposes an
# endpoint like /export-mapping or /import-mapping, you can script the wrong
# session test; otherwise perform these steps manually as documented in README.

cat > "$OUTDIR/notes.txt" <<'TXT'
Automated cycle finished. The capture log contains what each service attempted to send to the upstream.

Important: the capture server will NOT use raw detected names or IBANs in its replies. If the incoming request contained clear values, the server records them in "leak_detected" on the captured request but replies with <UNKNOWN_TOKEN> or a confirmed placeholder only.

Manual session-persistence steps (if the app UI provides export/import):
 - Export mapping/session from the running service (Z) to a file.
 - Stop the service process.
 - Restart the service process.
 - Import the previously exported mapping/session and re-run the same restore step (e.g. POST same payload or import PDF).
 - Observe the capture server whether the upstream received placeholders or real values.

Wrong-session test (manual):
 - Create a second, independent vault/session in the application (do not reuse passphrases or mapping files).
 - In that second session, attempt to open the anonymized PDF produced by session 1 (do not import session 1 keys or mapping).
 - Confirm that the application refuses to restore values or marks them as unknown; record the capture server logs for evidence.

If any of the above steps are not supported by the running service, mark them as 'Unable to test (manual)'.
TXT

echo "Run finished. Inspect $OUTDIR. Then run tests/cycle/check_results.sh to summarize."
