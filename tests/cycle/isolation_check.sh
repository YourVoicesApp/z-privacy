#!/usr/bin/env bash
# Prove the comparison copy will not write into the original app's vault,
# sessions, settings or PDF folder. Does not start the app.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
# Snapshot the caller's HOME before env.sh replaces it.
REAL_HOME="${HOME}"
# shellcheck source=env.sh
source "$HERE/env.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

DATA_DIR="${XDG_DATA_HOME}/zprivacy"
DOCS_DIR="${HOME}/Documents/zprivacy"
ORIGIN_DATA="${REAL_HOME}/.local/share/zprivacy"
ORIGIN_DOCS="${REAL_HOME}/Documents/zprivacy"
COMP="$(cd "$HERE/../.." && pwd)"

[[ "$DATA_DIR" == "$CYCLE_SANDBOX/xdg-data/zprivacy" ]] || fail "data dir is not the sandbox: $DATA_DIR"
[[ "$DOCS_DIR" == "$CYCLE_SANDBOX/home/Documents/zprivacy" ]] || fail "docs dir is not the sandbox: $DOCS_DIR"
[[ "$DATA_DIR" != "$ORIGIN_DATA" ]] || fail "data dir collides with original"
[[ "$DOCS_DIR" != "$ORIGIN_DOCS" ]] || fail "docs dir collides with original"
[[ "$HOME" == "$CYCLE_HOME" ]] || fail "HOME was not remapped"
[[ "$HOME" != "$REAL_HOME" ]] || fail "HOME still the real home"
case "$DATA_DIR" in
  "$CYCLE_SANDBOX"/*) ;;
  *) fail "data dir escaped the sandbox" ;;
esac
ok "vault/settings/sessions would land in $DATA_DIR"
ok "PDF output would land in $DOCS_DIR"
ok "original data dir left alone: $ORIGIN_DATA"
ok "original docs dir left alone: $ORIGIN_DOCS"

want_builder="$COMP/apps/flutter_app/rust_builder"
LINUX_RESOLVED="$(readlink -f "$COMP/apps/flutter_app/linux/flutter/ephemeral/.plugin_symlinks/z_bridge")"
WIN_RESOLVED="$(readlink -f "$COMP/apps/flutter_app/windows/flutter/ephemeral/.plugin_symlinks/z_bridge" 2>/dev/null || true)"
[[ "$LINUX_RESOLVED" == "$want_builder" ]] || fail "linux z_bridge resolves outside the copy: $LINUX_RESOLVED"
if [[ -n "$WIN_RESOLVED" ]]; then
  [[ "$WIN_RESOLVED" == "$want_builder" ]] || fail "windows z_bridge resolves outside the copy: $WIN_RESOLVED"
fi
ok "plugin z_bridge points at this copy's rust_builder"

# Absolute path in redteam harness still names the original tree. We do not run it.
if grep -F '/home/monopeaks/mono-privacy/z_core' "$COMP/redteam/2026-09-28/original/Cargo.toml" >/dev/null; then
  ok "noted: redteam original Cargo.toml still names the original z_core path — do not run that harness from this copy"
fi

BUNDLE="$COMP/apps/flutter_app/build/linux/x64/release/bundle/zprivacy"
[[ -x "$BUNDLE" ]] || fail "release bundle missing at $BUNDLE"
ok "isolated runner (not started): $BUNDLE"

printf '\nISOLATION_READY=1\n'
printf 'To start the copy later, after the mock cycle is green:\n'
printf '  bash %s/run_app_isolated.sh\n' "$HERE"
