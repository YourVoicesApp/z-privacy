#!/usr/bin/env bash
# **Build the core for the browser** — paper 122 part A.
#
#     scripts/build_web_core.sh [OUT_DIR]
#
# Writes `z_web.js` and `z_web_bg.wasm` (wasm-bindgen, `--target web`) into
# OUT_DIR, `target/web-core/` when none is given. The page loads them with
#
#     import init, * as z from './z_web.js'; await init();
#
# so they go next to the page that imports them: for the trial, the folder the
# web build is served from (`site-trial/`, or `apps/flutter_app/web/` before a
# `flutter build web`, which copies that folder into its output).
#
# What it needs, and refuses to start without:
#   * the `wasm32-unknown-unknown` target for the toolchain (1.97.1 unless
#     RUSTUP_TOOLCHAIN says otherwise: 1.98 ICEs on a fresh crate here);
#   * `wasm-bindgen` 0.2.130 — the CLI and the crate must be the same version,
#     or the glue and the module disagree about their imports:
#         cargo install wasm-bindgen-cli --version 0.2.130 --locked
#
# Gate G1g reads the finished module and refuses any import that is not on its
# list by name; this script only builds.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/target/web-core}"
WANT_BINDGEN="0.2.130"
export RUSTUP_TOOLCHAIN="${RUSTUP_TOOLCHAIN:-1.97.1}"
# Its own target directory: the remapping below is a RUSTFLAGS change, and in a
# shared directory it would rebuild every native crate the gates just built.
BUILD_DIR="${CARGO_TARGET_DIR:-$ROOT/target}/web"

die() { echo "build_web_core: $*" >&2; exit 1; }

command -v cargo >/dev/null || die "no cargo"
# A herestring, not a pipe: under pipefail a `grep -q` that stops reading at
# its first match can hand back the writer's SIGPIPE as the answer (G70).
grep -qx 'wasm32-unknown-unknown' <<< "$(rustup target list --installed --toolchain "$RUSTUP_TOOLCHAIN" 2>/dev/null)" \
  || die "no wasm32-unknown-unknown for $RUSTUP_TOOLCHAIN (rustup target add wasm32-unknown-unknown --toolchain $RUSTUP_TOOLCHAIN)"
command -v wasm-bindgen >/dev/null || die "no wasm-bindgen (cargo install wasm-bindgen-cli --version $WANT_BINDGEN --locked)"
HAVE_BINDGEN="$(wasm-bindgen --version | awk '{print $2}')"
[ "$HAVE_BINDGEN" = "$WANT_BINDGEN" ] || die "wasm-bindgen is $HAVE_BINDGEN, the crate is pinned to $WANT_BINDGEN"

# **The module may not carry the name of the machine that built it** — the
# same four remaps as `package_linux.sh`, for the same reason: a panic location
# is written into the binary as the path it was compiled from.
REMAP="--remap-path-prefix=$HOME/.cargo/registry/src=/crates"
REMAP="$REMAP --remap-path-prefix=$HOME/.rustup/toolchains=/rust"
REMAP="$REMAP --remap-path-prefix=$HOME/.pub-cache=/pub"
REMAP="$REMAP --remap-path-prefix=$ROOT=/zprivacy"

(
  cd "$ROOT/bridges/web"
  RUSTFLAGS="$REMAP" CARGO_TARGET_DIR="$BUILD_DIR" \
    cargo build --locked --release --target wasm32-unknown-unknown --lib --quiet
) || die "the wasm build failed"

WASM="$BUILD_DIR/wasm32-unknown-unknown/release/z_web.wasm"
[ -f "$WASM" ] || die "no module at $WASM"
mkdir -p "$OUT"
wasm-bindgen --target web --no-typescript --remove-name-section --remove-producers-section --out-dir "$OUT" "$WASM" || die "wasm-bindgen failed"

for f in z_web.js z_web_bg.wasm; do
  [ -f "$OUT/$f" ] || die "wasm-bindgen wrote no $f"
done
echo "build_web_core: $OUT/z_web.js ($(wc -c <"$OUT/z_web.js") bytes), $OUT/z_web_bg.wasm ($(wc -c <"$OUT/z_web_bg.wasm") bytes; $(gzip -9c "$OUT/z_web_bg.wasm" | wc -c) gzipped)"
