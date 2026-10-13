# Isolation environment for the comparison copy of Z Privacy.
# Source this file; do not run the app until isolation_check.sh exits 0.
#
# The core's data dir is `$XDG_DATA_HOME/zprivacy`, else
# `$HOME/.local/share/zprivacy`. The PDF output dir is `$HOME/Documents/zprivacy`.
# Both are taken from the environment; the Flutter UI does not pick a second path.
# See z_core/src/data_dir.rs.

cycle_root() {
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  printf '%s' "$here"
}

CYCLE_ROOT="$(cycle_root)"
CYCLE_SANDBOX="$CYCLE_ROOT/sandbox"
CYCLE_HOME="$CYCLE_SANDBOX/home"
CYCLE_XDG_DATA="$CYCLE_SANDBOX/xdg-data"
CYCLE_XDG_CONFIG="$CYCLE_SANDBOX/xdg-config"
CYCLE_XDG_CACHE="$CYCLE_SANDBOX/xdg-cache"
CYCLE_XDG_STATE="$CYCLE_SANDBOX/xdg-state"
CYCLE_OUTPUT="$CYCLE_ROOT/output"
CYCLE_CAPTURE="http://127.0.0.1:8081"

# Remember the real home once, so sourcing this file twice cannot point
# "origin" at the sandbox.
if [[ -z "${CYCLE_REAL_HOME:-}" ]]; then
  CYCLE_REAL_HOME="$HOME"
fi

# The live original app's files. The comparison copy must never use these.
CYCLE_ORIGIN_DATA="${CYCLE_REAL_HOME}/.local/share/zprivacy"
CYCLE_ORIGIN_DOCS="${CYCLE_REAL_HOME}/Documents/zprivacy"

export CYCLE_ROOT CYCLE_SANDBOX CYCLE_HOME CYCLE_XDG_DATA CYCLE_XDG_CONFIG
export CYCLE_XDG_CACHE CYCLE_XDG_STATE CYCLE_OUTPUT CYCLE_CAPTURE
export CYCLE_REAL_HOME CYCLE_ORIGIN_DATA CYCLE_ORIGIN_DOCS

# Keep the real Flutter/Dart package cache so a later isolated run does not
# re-download. It is not vault/session/settings/output.
export PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"

# Isolate every path the core actually writes.
export HOME="$CYCLE_HOME"
export XDG_DATA_HOME="$CYCLE_XDG_DATA"
export XDG_CONFIG_HOME="$CYCLE_XDG_CONFIG"
export XDG_CACHE_HOME="$CYCLE_XDG_CACHE"
export XDG_STATE_HOME="$CYCLE_XDG_STATE"

# Display / Wayland sockets stay on the real session. Do not rewrite
# XDG_RUNTIME_DIR, DISPLAY, WAYLAND_DISPLAY, or DBUS_SESSION_BUS_ADDRESS.

mkdir -p "$CYCLE_HOME/Documents/zprivacy" \
  "$CYCLE_XDG_DATA/zprivacy" \
  "$CYCLE_XDG_CONFIG" \
  "$CYCLE_XDG_CACHE" \
  "$CYCLE_XDG_STATE" \
  "$CYCLE_OUTPUT"
