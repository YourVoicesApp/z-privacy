#!/usr/bin/env bash
# **The preview's two promises, measured** — paper 122 §4, gate G75.
#
#     scripts/check_the_preview.sh
#
# 1. `scripts/build_site_trial.sh` never writes `site/`: OUT is resolved and
#    checked before anything is built, and `site/`, a folder inside it, a path
#    that reaches it by `..`, a symbolic link to it, the repository itself and
#    a folder the script did not make are each refused (exit 3). The control:
#    a fresh temporary folder passes the same check (exit 0), so a refusal is
#    the check working and not the check refusing everything.
# 2. `scripts/preview_trial.sh` listens on 127.0.0.1 and nowhere else, sends
#    DIR/_headers exactly as written, serves `.wasm` as `application/wasm`,
#    and stops on SIGINT. Read from the socket table (`ss`), not from the
#    script's text; the control is a server bound to 0.0.0.0, which the same
#    reading must flag.
#
# Builds nothing (G74 runs the full trial in a browser); everything it makes
# is in one temporary folder, removed at the end.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
BUILD=scripts/build_site_trial.sh
PREVIEW=scripts/preview_trial.sh
FAILS=0
ok() { printf 'ok    %s\n' "$1"; }
bad() { printf 'FAIL  %s\n' "$1"; FAILS=$((FAILS + 1)); }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/check-preview.XXXXXX")"
PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill -TERM "$p" 2>/dev/null; done; rm -rf -- "$WORK"; }
trap cleanup EXIT

# ---- 1 · the refusal
site_print() { find site -type f -print0 | sort -z | xargs -0 sha1sum | sha1sum; }
SITE_BEFORE="$(site_print)"
ln -s "$ROOT/site" "$WORK/a-link-to-site"
mkdir "$WORK/someone-elses" && : > "$WORK/someone-elses/a-file"
for out in site site/ site/en "$ROOT/site/new" ./site/../site/x "$WORK/a-link-to-site" \
           "$WORK/a-link-to-site/en" . "$WORK/someone-elses"; do
  "$BUILD" --only-check-out "$out" >/dev/null 2>&1
  rc=$?
  if [ "$rc" = 3 ]; then ok "refused: $out"; else bad "not refused (exit $rc): $out"; fi
done
for out in "$WORK/a-new-folder" "$WORK/nested/new"; do
  "$BUILD" --only-check-out "$out" >/dev/null 2>&1
  rc=$?
  if [ "$rc" = 0 ]; then ok "the control passes: $out"; else bad "the control was refused (exit $rc): $out"; fi
done
[ "$(site_print)" = "$SITE_BEFORE" ] && ok "site/ is byte for byte what it was before the refusals ran" || bad "site/ changed while the refusals ran"

# ---- 2 · 127.0.0.1 only, the headers as written
listeners() { ss -Hltn "sport = :$1" 2>/dev/null | awk '{print $4}'; }
only_loopback() {  # every listener on the port is 127.0.0.1, and there is one
  local l; l="$(listeners "$1")"
  [ -n "$l" ] && ! grep -qv '^127\.0\.0\.1:' <<< "$l"
}

FIX="$WORK/site-trial"
mkdir -p "$FIX"
printf '<!doctype html><title>fixture</title>\n' > "$FIX/index.html"
printf '// fixture\n' > "$FIX/z_web.js"
printf '\0asm\1\0\0\0' > "$FIX/z_web_bg.wasm"
CSP="default-src 'none'; script-src 'self' 'wasm-unsafe-eval'; connect-src 'self'"
# Paper 124: Scribe's page under scribe/, whose rule takes the two framing
# headers of /* off (`! Name`) and sends its own.
SCRIBE_CSP="default-src 'none'; frame-ancestors 'self'"
mkdir -p "$FIX/scribe" "$FIX/canvaskit"
printf '\0asm\1\0\0\0' > "$FIX/canvaskit/canvaskit.wasm"
printf '<!doctype html><title>scribe fixture</title>\n' > "$FIX/scribe/index.html"
printf '# fixture\n/*\n  Content-Security-Policy: %s\n  X-Frame-Options: DENY\n  X-Fixture: one, two\n\n/*/try/scribe/*\n  ! Content-Security-Policy\n  ! X-Frame-Options\n  Content-Security-Policy: %s\n  X-Frame-Options: SAMEORIGIN\n' "$CSP" "$SCRIBE_CSP" > "$FIX/_headers"

LOG="$WORK/preview.out"
"$PREVIEW" "$FIX" 0 > "$LOG" 2>/dev/null &
PIDS+=($!)
PREVIEW_PID=$!
PORT=""
for _ in $(seq 1 50); do
  PORT="$(grep -oE '127\.0\.0\.1:[0-9]+' "$LOG" | head -1 | cut -d: -f2)"
  [ -n "$PORT" ] && break
  sleep 0.1
done
if [ -z "$PORT" ]; then
  bad "the preview did not start"
else
  if only_loopback "$PORT"; then ok "the preview listens on 127.0.0.1:$PORT and nowhere else"; else bad "the preview listens on: $(listeners "$PORT" | tr '\n' ' ')"; fi
  grep -q "http://127.0.0.1:$PORT/ar/try/" "$LOG" && grep -q "/en/try/" "$LOG" && grep -q "/sv/try/" "$LOG" \
    && ok "it prints the English, Arabic and Swedish addresses" || bad "the three addresses are not printed"
  HEAD="$(curl -s -D - -o /dev/null "http://127.0.0.1:$PORT/ar/try/")"
  grep -qxF "Content-Security-Policy: $CSP"$'\r' <<< "$HEAD" && ok "the CSP is sent exactly as _headers writes it" || bad "the CSP is not the one in _headers"
  grep -qxF "X-Fixture: one, two"$'\r' <<< "$HEAD" && ok "every header of _headers is sent" || bad "a header of _headers is missing"
  # Paper 124: `! Name` takes off what /* set, for Scribe's page only.
  SHEAD="$(curl -s -D - -o /dev/null "http://127.0.0.1:$PORT/sv/try/scribe/")"
  [ "$(grep -ci '^Content-Security-Policy:' <<< "$SHEAD")" = 1 ] && grep -qxF "Content-Security-Policy: $SCRIBE_CSP"$'\r' <<< "$SHEAD" \
    && ok "Scribe's page is sent its own CSP, and only it (\`! Content-Security-Policy\`)" || bad "Scribe's page is not sent exactly its own CSP"
  [ "$(grep -ci '^X-Frame-Options:' <<< "$SHEAD")" = 1 ] && grep -qxF "X-Frame-Options: SAMEORIGIN"$'\r' <<< "$SHEAD" \
    && grep -qxF "X-Fixture: one, two"$'\r' <<< "$SHEAD" \
    && ok "…and X-Frame-Options SAMEORIGIN alone, the other headers of /* kept" || bad "Scribe's page's X-Frame-Options or other headers are wrong"
  grep -qxF "X-Frame-Options: DENY"$'\r' <<< "$HEAD" && ! grep -qi 'SAMEORIGIN' <<< "$HEAD" \
    && ok "the trial's own page still may not be framed (DENY)" || bad "the trial's page lost its DENY"
  WASM="$(curl -s -D - -o /dev/null "http://127.0.0.1:$PORT/en/try/z_web_bg.wasm")"
  grep -qi '^Content-Type: application/wasm' <<< "$WASM" && ok ".wasm is application/wasm" || bad ".wasm has another type"
  # Paper 124: CanvasKit at one absolute address, the trial's own copy.
  CK="$(curl -s -D - -o "$WORK/ck.wasm" "http://127.0.0.1:$PORT/try/canvaskit/canvaskit.wasm")"
  grep -qi '^Content-Type: application/wasm' <<< "$CK" && cmp -s "$WORK/ck.wasm" "$FIX/canvaskit/canvaskit.wasm" \
    && grep -qxF "X-Frame-Options: DENY"$'\r' <<< "$CK" \
    && ok "CanvasKit is served at /try/canvaskit/, the build's own, with the trial's headers" \
    || bad "/try/canvaskit/ does not serve the build's CanvasKit"
  [ "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/en/try/_headers")" = 404 ] \
    && ok "_headers itself is not served" || bad "_headers is served as a file"
  printf 'record\n' > "$FIX/_trial.nginx"
  [ "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/en/try/_trial.nginx")" = 404 ] \
    && ok "_trial.nginx is not served" || bad "_trial.nginx is served as a file"
  kill -INT "$PREVIEW_PID"
  for _ in $(seq 1 30); do kill -0 "$PREVIEW_PID" 2>/dev/null || break; sleep 0.1; done
  if kill -0 "$PREVIEW_PID" 2>/dev/null; then bad "SIGINT did not stop the preview"; else ok "SIGINT stops it"; fi
fi

# ---- 3 · the server's record (paper 125): its headers are _headers's
REC="$WORK/record"
mkdir -p "$REC" && cp apps/flutter_app/web/_headers "$REC/"
if python3 -I scripts/write_trial_nginx.py "$REC" >/dev/null && python3 -I scripts/write_trial_nginx.py --check "$REC" >/dev/null; then
  ok "the server record is written from _headers and sends exactly its headers"
else
  bad "the server record does not hold _headers's headers"
fi
cp "$REC/_trial.nginx" "$REC/good"
# Paper 124: Scribe's snippet is checked as the trial's is.
sed -i "/^# ---- 2b/,/^# ---- 3/s/frame-ancestors 'self'/frame-ancestors */" "$REC/_trial.nginx"
if python3 -I scripts/write_trial_nginx.py --check "$REC" >/dev/null 2>&1; then
  bad "the control: a record whose Scribe CSP differs from _headers passed the check"
else
  ok "the control: a record whose Scribe CSP differs from _headers is refused"
fi
cp "$REC/good" "$REC/_trial.nginx"
# Paper 124: what the real _headers says about frames.
TRIAL_CSP="$(sed -n '/^\/\*$/,/^$/p' apps/flutter_app/web/_headers | grep -m1 'Content-Security-Policy:')"
SCRIBE_REAL="$(sed -n '/^\/\*\/try\/scribe\/\*$/,$p' apps/flutter_app/web/_headers | grep -m1 'Content-Security-Policy:')"
grep -q "frame-src 'self'" <<< "$TRIAL_CSP" && grep -q "frame-ancestors 'none'" <<< "$TRIAL_CSP" \
  && grep -q "frame-ancestors 'self'" <<< "$SCRIBE_REAL" && ! grep -q "frame-src" <<< "$SCRIBE_REAL" \
  && ok "the trial may frame its own origin and be framed by none; Scribe's page may be framed by its own origin only" \
  || bad "the trial's _headers do not say who may frame whom as paper 124 does"
sed -i "s/connect-src 'self';/connect-src *;/" "$REC/_trial.nginx"
if python3 -I scripts/write_trial_nginx.py --check "$REC" >/dev/null 2>&1; then
  bad "the control: a record whose CSP differs from _headers passed the check"
else
  ok "the control: a record whose CSP differs from _headers is refused"
fi

# The control: a server on every address must be flagged by the same reading.
CONTROL_LOG="$WORK/control.out"
python3 -I -c '
import http.server, sys
s = http.server.HTTPServer(("0.0.0.0", 0), http.server.BaseHTTPRequestHandler)
print(s.server_address[1], flush=True)
s.serve_forever()' > "$CONTROL_LOG" 2>/dev/null &
PIDS+=($!)
CPORT=""
for _ in $(seq 1 50); do CPORT="$(head -1 "$CONTROL_LOG" 2>/dev/null)"; [ -n "$CPORT" ] && break; sleep 0.1; done
if [ -n "$CPORT" ] && ! only_loopback "$CPORT"; then
  ok "the control: a server on 0.0.0.0:$CPORT is flagged by the same reading"
else
  bad "the control: a server on 0.0.0.0 was not flagged, so the reading proves nothing"
fi

echo
if [ "$FAILS" = 0 ]; then echo "check_the_preview: all held"; else echo "check_the_preview: $FAILS failed"; fi
exit "$FAILS"
