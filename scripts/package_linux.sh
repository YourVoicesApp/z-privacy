#!/usr/bin/env bash
# Z Privacy for Linux, assembled by a script instead of by hand.
#
#     bash scripts/package_linux.sh
#
# The archive on beta was put together by hand on 30 September and never rebuilt,
# so what people have been downloading predates the PDF reader, the names, the
# language packs and the gateway. This script is how that stops being possible:
# the layout is in code, the build is from a clean tree, and the archive names
# the commit it came from.
#
# It writes two files and touches nothing else:
#
#     dist/zprivacy-v1-linux-x86_64.tar.gz
#     dist/zprivacy-v1-linux-x86_64.tar.gz.sha256
#
# A dirty tree is refused, because an archive whose contents are not in a commit
# cannot be rebuilt by anybody. `ALLOW_DIRTY=1` overrides it, and then BUILD-INFO
# says so in as many words.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
ROOT="$PWD"
NAME="zprivacy-v1-linux-x86_64"
OUT="$ROOT/dist"
STAGE="$OUT/$NAME"

step() { printf '\n== %s\n' "$1"; }
die() { printf '\n%s\n' "$1" >&2; exit 1; }

# ---------------------------------------------------------------- the tree
DIRTY=""
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  if [ "${ALLOW_DIRTY:-}" = "1" ]; then
    DIRTY="yes"
  else
    git status --short | head -20
    die "the tree is not clean. Commit, or set ALLOW_DIRTY=1 and the archive will say so."
  fi
fi
COMMIT=$(git rev-parse HEAD 2>/dev/null || echo unknown)
SUBJECT=$(git log -1 --format=%s 2>/dev/null || echo unknown)

# ------------------------------------------------- this machine's own paths
# **The archive may not carry the name of the machine that built it** (the
# independent attacker's خ3 and ن6, 17 October). Two halves, and this is the
# first: every dependency writes its panic locations into the binary as the
# absolute path it was compiled from, so the installed `libz_bridge.so` held
# **195** strings reading `/home/<user>/.cargo/registry/src/…`. Measured here:
# 195 before, 0 after.
#
# `--remap-path-prefix` and not Cargo's `trim-paths`, because that one is still
# unstable in the cargo of this build; and here and not in `Cargo.toml`,
# because the absolute paths it needs are different on every machine and a file
# in the repository cannot know them. Everything the compiler writes down is a
# relative-looking path that names nothing.
REMAP="--remap-path-prefix=$HOME/.cargo/registry/src=/crates"
REMAP="$REMAP --remap-path-prefix=$HOME/.rustup/toolchains=/rust"
REMAP="$REMAP --remap-path-prefix=$HOME/.pub-cache=/pub"
REMAP="$REMAP --remap-path-prefix=$ROOT=/zprivacy"
export RUSTFLAGS="${RUSTFLAGS:-} $REMAP"

step "building (release)"
( cd apps/flutter_app && flutter build linux --release ) || die "the Flutter build failed"
BUNDLE="$ROOT/apps/flutter_app/build/linux/x64/release/bundle"
[ -x "$BUNDLE/zprivacy" ] || die "no runner at $BUNDLE/zprivacy"

# The core's own stamp, read out of a binary built from this tree — the same
# line the window shows and the copied report carries.
STAMP=$(cargo run -q --release -p z_core --example check_document 2>/dev/null | head -1)
[ -n "$STAMP" ] || die "the core would not say its own stamp"

step "assembling $NAME"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -a "$BUNDLE/." "$STAGE/"

# The mark, for whoever wants a launcher.
mkdir -p "$STAGE/icons"
for size in 16 32 48 64 128 256 512; do
  src="$ROOT/apps/flutter_app/assets/brand/zprivacy-${size}.png"
  [ -f "$src" ] && cp -f "$src" "$STAGE/icons/zprivacy-${size}.png"
done
cp -f "$ROOT/packaging/linux/zprivacy.desktop" "$STAGE/zprivacy.desktop"
cp -f "$ROOT/packaging/linux/install-shortcut.sh" "$STAGE/install-shortcut.sh"
chmod +x "$STAGE/install-shortcut.sh"

# ------------------------------------------------- and out of the binaries
# The second half, and the one the compiler cannot do for us.
#
# * nothing in the archive keeps a symbol table. `[profile.release]` strips
#   what cargo builds; the Flutter engine, the GTK plugin and the runner are
#   built by other hands, and the GTK plugin carried the build directory of
#   this tree in its debug information.
# * the Dart snapshot in `libapp.so` holds the URI of the generated plugin
#   registrant — `file:///home/<user>/…/dart_plugin_registrant.dart` — and
#   there is no compiler switch for it. So the bytes are rewritten **in place
#   and to the same length**, which leaves every offset and every length inside
#   the snapshot exactly as it was: only the characters of a path that is used
#   for nothing but a stack trace change. The app is started from the finished
#   archive afterwards, because a rewrite nobody ran is a rewrite nobody knows.
step "taking this machine out of the binaries"
find "$STAGE" -type f -print | while IFS= read -r f; do
  case "$(file -b "$f" 2>/dev/null)" in
    *ELF*) strip --strip-unneeded "$f" 2>/dev/null || true ;;
  esac
done
command -v python3 >/dev/null || die "python3 is needed to redraw the paths inside the binaries"
python3 - "$STAGE" "$HOME" <<'REDRAW' || die "the paths inside the binaries could not be redrawn"
import pathlib
import sys

stage, home = pathlib.Path(sys.argv[1]), sys.argv[2].encode()
# The same number of bytes, so that nothing inside a snapshot moves.
neutral = (b"/build/" + b"z" * max(0, len(home) - 7))[: len(home)]
if len(neutral) != len(home):
    print(f"cannot redraw {home!r}: no neutral path of its length", file=sys.stderr)
    sys.exit(1)
for path in sorted(stage.rglob("*")):
    if not path.is_file() or path.is_symlink():
        continue
    data = path.read_bytes()
    found = data.count(home)
    if not found:
        continue
    out = data.replace(home, neutral)
    if len(out) != len(data):
        print(f"{path.name}: the rewrite changed its length", file=sys.stderr)
        sys.exit(1)
    path.write_bytes(out)
    print(f"  {path.name}: {found} path(s) redrawn")
REDRAW

cp -f "$ROOT/LICENSE" "$STAGE/LICENSE" 2>/dev/null || die "no LICENSE at the root"
cp -f "$ROOT/packaging/linux/README.txt" "$STAGE/README.txt" || die "no packaging/linux/README.txt"

# ---------------------------------------------------------------- third party
mkdir -p "$STAGE/third-party"
cp -f "$ROOT/site/third-party/flutter-engine-LICENSE.txt" "$STAGE/third-party/" \
  || die "no site/third-party/flutter-engine-LICENSE.txt"
for f in NOTICES.txt flutter-sdk-LICENSE.txt material-icons-LICENSE.txt \
         dejavu-LICENSE.txt dart-pdf-LICENSE.txt; do
  # Named, not counted, and loud: this was `[ -f … ] && cp`, which shipped a
  # tarball with a notice missing and said nothing. NOTICES.txt lists its
  # neighbours by name, so a missing one is a notice pointing at nothing.
  cp -f "$ROOT/packaging/third-party/$f" "$STAGE/third-party/" \
    || die "no packaging/third-party/$f"
done
# Generated, not copied from September: the crates are whatever this tree
# actually depends on today.
{
  echo "The Rust crates this build links, from the tree at $COMMIT."
  echo "Generated by scripts/package_linux.sh with cargo tree; no new tool."
  echo
  # `cargo tree` writes a workspace crate as «z_core v0.1.0 (/home/…/z_core)»,
  # and that parenthesis is this machine again — in a text file this time,
  # which is how the step below found it. The version is the news; where the
  # crate sat on the builder's disk is not.
  #
  # **The pattern is any parenthesis at the end, not a Unix one** — 098 item
  # 4(ج): this read `s| \(/[^)]*\)$||` until the Windows session found
  # `(D:\a\…)` sitting in the installed build's own copy of this file, which a
  # leading `/` can never match. One spelling, both platforms, and nothing else
  # is parenthesised there once ` (*)` has gone.
  ( cd "$ROOT" && cargo tree -p z_core --edges normal --prefix none 2>/dev/null \
      | sed 's/ (\*)$//' | sed -E 's| \([^)]*\)$||' | sort -u | grep -vE '^$' )
} > "$STAGE/third-party/rust-crates.txt"

# ---------------------------------------------------------------- build info
RUNNER_SHA=$(sha256sum "$STAGE/zprivacy" | cut -d' ' -f1)
BRIDGE_SHA=$(sha256sum "$STAGE/lib/libz_bridge.so" | cut -d' ' -f1)
{
  echo "Z Privacy V1 — release build"
  echo "============================"
  echo
  echo "core stamp       $STAMP"
  echo "product commit   $COMMIT"
  echo "                   \"$SUBJECT\""
  if [ -n "$DIRTY" ]; then
    echo "                 BUILT FROM A TREE THAT WAS NOT CLEAN (ALLOW_DIRTY=1)."
    echo "                 What is in this archive is not exactly what is in that"
    echo "                 commit, and cannot be rebuilt from it."
  else
    echo "                 The tree was clean when these binaries were built."
  fi
  echo
  echo "built            $(date -Iseconds), $(uname -s) $(uname -m)"
  echo "rustc            $(rustc --version 2>/dev/null)"
  echo "flutter          $(cd apps/flutter_app && flutter --version 2>/dev/null | head -1)"
  echo "profile          release, assembled by scripts/package_linux.sh"
  echo
  echo "the two files that are the product"
  echo "  zprivacy            $RUNNER_SHA"
  echo "  lib/libz_bridge.so  $BRIDGE_SHA"
  echo
  echo "These two hashes are the ones to check. The hash of the archive itself"
  echo "cannot be inside the archive: it travels beside it, in"
  echo "$NAME.tar.gz.sha256, and is printed on the download page."
  echo
  echo "  sha256sum -c $NAME.tar.gz.sha256"
} > "$STAGE/BUILD-INFO.txt"

# ---------------------------------------------------------------- the archive
# **Nothing goes out with a path from here in it.** The two steps above are
# what fixes it; this is what proves it, over every file that is about to be
# packed — the binaries, the notices, the crate list, BUILD-INFO. Gate
# «nothing in the archive names this machine» asks the same question of the
# finished `.tar.gz`, so the answer does not depend on this script having run.
step "checking that no path from this machine is left"
LEFT=$(grep -rlI --binary-files=binary "/home/" "$STAGE" 2>/dev/null)
if [ -n "$LEFT" ]; then
  printf '%s\n' "$LEFT" | sed 's|^|        |'
  die "the archive would carry paths from this machine. Nothing was written."
fi
printf '  no «/home/» in any of the %s files\n' "$(find "$STAGE" -type f | wc -l)"

step "writing the archive"
( cd "$OUT" && tar czf "$NAME.tar.gz" "$NAME" ) || die "tar failed"
( cd "$OUT" && sha256sum "$NAME.tar.gz" > "$NAME.tar.gz.sha256" )
rm -rf "$STAGE"

ARCHIVE_SHA=$(cut -d' ' -f1 < "$OUT/$NAME.tar.gz.sha256")
SIZE=$(du -h "$OUT/$NAME.tar.gz" | cut -f1)

printf '\n%s\n' "done"
printf '  %s\n' "$STAMP"
printf '  archive  dist/%s  (%s)\n' "$NAME.tar.gz" "$SIZE"
printf '  sha256   %s\n' "$ARCHIVE_SHA"
[ -n "$DIRTY" ] && printf '  note     built from a tree that was not clean\n'
exit 0
