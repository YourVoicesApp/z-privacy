#!/usr/bin/env bash
# **The web trial in a real browser** — paper 122 part B.
#
#     scripts/check_the_trial_in_a_browser.sh [MODULE_DIR]
#
# Runs `apps/flutter_app/test/web_browser/` in Chrome (`flutter test
# --platform chrome`, its own temporary profile):
#
#   * the full flow on the fake of ed's shape, then the browser's own storage
#     read — localStorage, sessionStorage, cookies, IndexedDB, Cache Storage,
#     service workers — which must all be empty (rule 85 (c));
#   * with MODULE_DIR, the same flow against the **real** module: `z_web.js`
#     and `z_web_bg.wasm` from `scripts/build_web_core.sh`, served from
#     MODULE_DIR on 127.0.0.1 only, for the length of the run — and the PDF
#     «Save to my device» offers is read back with `pdftotext`.
#
# Builds nothing and writes nothing into the tree. The module is never
# committed: the lead builds it into `site-trial/`.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE_DIR="${1:-}"
die() { echo "check_the_trial_in_a_browser: $*" >&2; exit 1; }
command -v google-chrome >/dev/null || command -v chromium >/dev/null || die "no Chrome on this machine"

command -v pdftotext >/dev/null || die "no pdftotext on this machine"
DEFINE=()
SERVER=""
cleanup() { [ -n "$SERVER" ] && kill "$SERVER" 2>/dev/null || true; }
trap cleanup EXIT

if [ -n "$MODULE_DIR" ]; then
  [ -f "$MODULE_DIR/z_web.js" ] && [ -f "$MODULE_DIR/z_web_bg.wasm" ] || die "no z_web.js and z_web_bg.wasm in $MODULE_DIR"
fi
PORT_FILE="$(mktemp)"
# **The run's own server**: 127.0.0.1, a free port, for the length of the run.
#   GET  /z_web.js, /z_web_bg.wasm — the module, from MODULE_DIR (CORS open to
#        the test page, `application/wasm` so the browser streams it);
#   GET  /font — the trial's font, which `rootBundle` cannot read in Chrome;
#   POST /pdf  — a PDF's bytes in, `pdftotext`'s reading of them out, from a
#        temporary file deleted at once.
python3 -I - "${MODULE_DIR:-/nonexistent}" "$ROOT/apps/flutter_app/assets/fonts/DejaVuSans.ttf" "$PORT_FILE" <<'PY' &
import http.server, os, subprocess, sys, tempfile
root, font, port_file = sys.argv[1], sys.argv[2], sys.argv[3]
class H(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map,
                      '.wasm': 'application/wasm', '.js': 'text/javascript'}
    def __init__(self, *a, **k): super().__init__(*a, directory=root, **k)
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()
    def log_message(self, *a): pass
    def _send(self, body, kind):
        self.send_response(200)
        self.send_header('Content-Type', kind)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def do_GET(self):
        if self.path == '/font':
            with open(font, 'rb') as f:
                return self._send(f.read(), 'font/ttf')
        return super().do_GET()
    def do_POST(self):
        if self.path != '/pdf':
            return self.send_error(404)
        data = self.rfile.read(int(self.headers.get('Content-Length', 0)))
        with tempfile.NamedTemporaryFile(suffix='.pdf') as f:
            f.write(data); f.flush()
            text = subprocess.run(['pdftotext', f.name, '-'], capture_output=True).stdout
        self._send(text, 'text/plain; charset=utf-8')
s = http.server.ThreadingHTTPServer(('127.0.0.1', 0), H)
open(port_file, 'w').write(str(s.server_address[1]))
s.serve_forever()
PY
SERVER=$!
for _ in $(seq 1 50); do [ -s "$PORT_FILE" ] && break; sleep 0.1; done
PORT="$(cat "$PORT_FILE")"; rm -f "$PORT_FILE"
[ -n "$PORT" ] || die "the run's server did not start"
DEFINE=(--dart-define="Z_TRIAL_SERVER=http://127.0.0.1:$PORT")
[ -n "$MODULE_DIR" ] && DEFINE+=(--dart-define="Z_WEB_MODULE=http://127.0.0.1:$PORT/z_web.js")

cd "$ROOT/apps/flutter_app"
flutter test --platform chrome "${DEFINE[@]}" test/web_browser/
