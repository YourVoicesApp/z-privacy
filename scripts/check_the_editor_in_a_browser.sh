#!/usr/bin/env bash
# **Scribe's editor in the web trial, in Chrome** — paper 124, rule 88 (ح).
#
#     scripts/check_the_editor_in_a_browser.sh [SITE_TRIAL_DIR] [SHOTS_DIR]
#
# Serves the assembled trial (`site-trial/` by default: Z's page, Scribe's
# page under `scribe/`, both with their real modules) through
# `scripts/preview_trial.sh` — 127.0.0.1 only, `_headers` applied as written —
# starts Chrome headless with a profile of its own in a temporary folder, and
# runs `scripts/the_editor_in_a_browser.mjs` against it: the button, the
# frame, typing, «Send to the editor», «Close», «Start over», the storage
# read back empty, no CSP violation, and the control (another origin may not
# frame the editor). With SHOTS_DIR, the six shots of the editor are taken.
#
# Builds nothing and writes nothing into the tree. Both programs it starts are
# stopped by their own process numbers when it ends, however it ends.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$(realpath -- "${1:-$ROOT/site-trial}")"
SHOTS="${2:-}"
die() { echo "check_the_editor_in_a_browser: $*" >&2; exit 2; }
CHROME="$(command -v google-chrome || command -v chromium || true)"
[ -n "$CHROME" ] || die "no Chrome on this machine"
command -v node >/dev/null || die "no node on this machine"
[ -f "$DIR/index.html" ] && [ -f "$DIR/scribe/index.html" ] && [ -f "$DIR/scribe/scribe_engine_bg.wasm" ] \
  || die "no trial with Scribe's page in $DIR — build it first: scripts/build_site_trial.sh"
[ -z "$SHOTS" ] || { mkdir -p -- "$SHOTS"; SHOTS="$(realpath -- "$SHOTS")"; }

free_port() { python3 -I -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()'; }
PREVIEW_PORT="$(free_port)"
DEVTOOLS_PORT="$(free_port)"
PROFILE="$(mktemp -d "${TMPDIR:-/tmp}/z-editor-chrome.XXXXXX")"
PREVIEW_PID=""
CHROME_PID=""
cleanup() {
  [ -n "$CHROME_PID" ] && kill "$CHROME_PID" 2>/dev/null || true
  [ -n "$PREVIEW_PID" ] && kill "$PREVIEW_PID" 2>/dev/null || true
  wait 2>/dev/null || true
  rm -f -- "$PROFILE.preview.log"
  # Chrome's helpers may still be writing into the profile for a moment.
  case "$PROFILE" in
    "${TMPDIR:-/tmp}"/z-editor-chrome.??????)
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        rm -rf -- "$PROFILE" 2>/dev/null && break
        sleep 0.5
      done ;;
  esac
}
trap cleanup EXIT

"$ROOT/scripts/preview_trial.sh" "$DIR" "$PREVIEW_PORT" >"$PROFILE.preview.log" 2>&1 &
PREVIEW_PID=$!
# Chrome's own sockets live under TMPDIR, and a socket's path may not pass
# 108 bytes: a long TMPDIR aborts it, so it is started with the system's.
env -u TMPDIR "$CHROME" --headless=new --no-first-run --no-default-browser-check --disable-extensions \
  --remote-debugging-port="$DEVTOOLS_PORT" --user-data-dir="$PROFILE" about:blank \
  >/dev/null 2>&1 &
CHROME_PID=$!

for _ in $(seq 1 80); do
  curl -sf -o /dev/null "http://127.0.0.1:$PREVIEW_PORT/en/try/" \
    && curl -sf -o /dev/null "http://127.0.0.1:$DEVTOOLS_PORT/json/version" && break
  sleep 0.25
done
curl -sf -o /dev/null "http://127.0.0.1:$PREVIEW_PORT/en/try/scribe/" || die "the preview does not serve Scribe's page"

node "$ROOT/scripts/the_editor_in_a_browser.mjs" "$DEVTOOLS_PORT" "http://127.0.0.1:$PREVIEW_PORT" $SHOTS
