#!/usr/bin/env bash
# **Build the web trial's folder** — paper 122 §4, rule 86.
#
#     scripts/build_site_trial.sh [OUT]            # OUT defaults to site-trial/
#     scripts/build_site_trial.sh --only-check-out [OUT]
#
# Builds, in a temporary folder of its own:
#
#   * the core for the browser — `scripts/build_web_core.sh` (ed's, part A):
#     `z_web.js` and `z_web_bg.wasm`;
#   * the trial's screen — `flutter build web --release` from
#     `lib/main_web.dart`, with the flags measured in part B:
#       --no-web-resources-cdn   CanvasKit from our own origin, never a CDN
#       --csp                    no code generated at run time
#       --no-wasm-dry-run        the JavaScript build only, said out loud
#
# and assembles OUT from them: the Flutter build (with `web/_headers`, the
# trial's CSP, which Flutter copies in; the fonts it bundles under
# `assets/fonts/` and `assets/assets/fonts/` — DejaVu Sans and the icon font),
# `z_web.js` and `z_web_bg.wasm` beside `index.html`, and a marker file
# `.site-trial` so a later build knows the folder is its own to replace.
#
# **Left out, because no page loads them:**
#   * `flutter_service_worker.js` — nothing registers it (`web/flutter_bootstrap.js`
#     loads with no service worker settings; rule 85 (c)), and a file that
#     could cache the site in a visitor's browser has no business being served;
#   * `version.json` — read only by that service worker;
#   * `.last_build_id` — the build tool's own note;
#   * `canvaskit/skwasm*`, `canvaskit/wimp*`, `canvaskit/experimental_webparagraph/`
#     — the renderers of a WebAssembly build; this is the JavaScript build, and
#     its `_flutter.buildConfig` names `canvaskit` only;
#   * every `*.symbols` — debugging symbols for CanvasKit, never fetched.
# `canvaskit/canvaskit.{js,wasm}` (other browsers) and `canvaskit/chromium/`
# (Chrome and Edge) stay.
#
# **It never touches `site/`.** OUT is resolved first, before anything is
# built, and an OUT that is `site/` or anything inside it is refused (exit 3) —
# the live site's tree is the owner's to publish (rule 86 (a)). So is an OUT
# that is the repository itself, or an existing folder this script did not
# make. `--only-check-out` stops after that check: gate G75 uses it to prove
# the refusal bites, and that an ordinary folder passes it.
#
# The old OUT is renamed aside before the new one moves in, and only then
# deleted: a build that fails leaves the last good folder where it was.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
die() { echo "build_site_trial: $*" >&2; exit 1; }
refuse() { echo "build_site_trial: refused: $*" >&2; exit 3; }

ONLY_CHECK=0
if [ "${1:-}" = "--only-check-out" ]; then ONLY_CHECK=1; shift; fi
OUT_ARG="${1:-$ROOT/site-trial}"

# **Where OUT really is**: every `..` and every symbolic link resolved, whether
# or not it exists yet, so neither `site/../site` nor a link to `site/` gets
# through. Relative to the current folder, as a path typed in a shell is.
OUT="$(realpath -m -- "$OUT_ARG")"
SITE="$(realpath -m -- "$ROOT/site")"
case "$OUT/" in
  "$SITE/"*) refuse "$OUT_ARG is site/ or inside it — the live site's tree is never written by this script" ;;
esac
[ "$OUT" != "$(realpath -m -- "$ROOT")" ] || refuse "$OUT_ARG is the repository itself"
[ "$OUT" != "/" ] || refuse "$OUT_ARG is /"
if [ -e "$OUT" ] && { [ ! -d "$OUT" ] || { [ -n "$(ls -A "$OUT" 2>/dev/null)" ] && [ ! -f "$OUT/.site-trial" ]; }; }; then
  refuse "$OUT_ARG exists and is not a folder this script built (no .site-trial in it)"
fi
if [ "$ONLY_CHECK" = 1 ]; then
  echo "build_site_trial: $OUT may be written"
  exit 0
fi

command -v flutter >/dev/null || die "no flutter"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/site-trial-build.XXXXXX")"
trap 'rm -rf -- "$WORK"' EXIT

"$ROOT/scripts/build_web_core.sh" "$WORK/core"

(
  cd "$ROOT/apps/flutter_app"
  flutter build web -t lib/main_web.dart --release \
    --no-web-resources-cdn --csp --no-wasm-dry-run -o "$WORK/web"
) || die "flutter build web failed"

ASSEMBLED="$WORK/site-trial"
cp -a "$WORK/web" "$ASSEMBLED"
rm -f -- "$ASSEMBLED/flutter_service_worker.js" "$ASSEMBLED/version.json" "$ASSEMBLED/.last_build_id"
rm -f -- "$ASSEMBLED"/canvaskit/skwasm* "$ASSEMBLED"/canvaskit/wimp*
rm -rf -- "$ASSEMBLED/canvaskit/experimental_webparagraph"
find "$ASSEMBLED" -name '*.symbols' -type f -delete
cp -- "$WORK/core/z_web.js" "$WORK/core/z_web_bg.wasm" "$ASSEMBLED/"
: > "$ASSEMBLED/.site-trial"

# What a page needs, checked before the folder is put in place.
for f in index.html flutter_bootstrap.js flutter.js main.dart.js _headers z_web.js z_web_bg.wasm \
         canvaskit/canvaskit.js canvaskit/canvaskit.wasm canvaskit/chromium/canvaskit.wasm \
         assets/FontManifest.json assets/assets/fonts/DejaVuSans.ttf; do
  [ -f "$ASSEMBLED/$f" ] || die "the assembled folder has no $f"
done
for f in flutter_service_worker.js version.json; do
  [ ! -e "$ASSEMBLED/$f" ] || die "the assembled folder still holds $f"
done

mkdir -p -- "$(dirname -- "$OUT")"
OLD=""
if [ -e "$OUT" ]; then
  OLD="$OUT.old.$$"
  mv -- "$OUT" "$OLD"
fi
mv -- "$ASSEMBLED" "$OUT"
if [ -n "$OLD" ]; then
  rm -rf -- "$OLD"
fi

echo "build_site_trial: $OUT ($(du -sh -- "$OUT" | cut -f1), $(find "$OUT" -type f | wc -l) files)"
