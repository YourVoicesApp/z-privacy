#!/usr/bin/env bash
# **The Windows twin of `scripts/package_linux.sh`** — 093 item 1.
#
# What the Linux archive has carried since it had a script at all, and the
# Windows folder had none of: a `BUILD-INFO.txt` naming the build, the two
# product hashes inside it, a proof that **no path from the machine that built
# it** is left in any file, and a `.zip` with its `.sha256` beside it.
#
# **It takes the staged folder rather than staging it itself**, which is the one
# place it deliberately differs from its twin. The Windows job already assembles
# that folder — the runner, the DLLs, `data/`, the licences, the five
# third-party notices and the generated crate list — and the installer step
# reads the same folder afterwards. A second stager here would be two answers to
# «what is in a Windows release», and the first time they disagreed the
# installer would ship what nobody measured. So: one stager (the job), one
# stamper and one hygiene check (this file).
#
# Run:  bash scripts/package_windows.sh <staged folder> [<output folder>]
#
# Exit status is the verdict. A path from this machine in any file is a refusal,
# and nothing is written: an archive that names the builder cannot be unwritten
# once it is downloaded.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
ROOT="$PWD"
NAME="zprivacy-v1-windows-x86_64"

STAGE="${1:-}"
OUT="${2:-$ROOT/dist}"
[ -n "$STAGE" ] || { echo "usage: package_windows.sh <staged folder> [<output folder>]" >&2; exit 2; }
[ -d "$STAGE" ] || { echo "no staged folder at $STAGE" >&2; exit 2; }

step() { printf '\n== %s\n' "$1"; }
die() { printf '\n%s\n' "$1" >&2; exit 1; }

# The two files that **are** the product, asked for by name: the folder is
# thirteen files and these are the two a person checks.
RUNNER="$STAGE/zprivacy.exe"
BRIDGE="$STAGE/z_bridge.dll"
[ -s "$RUNNER" ] || die "no zprivacy.exe in $STAGE — there is nothing to stamp"
[ -s "$BRIDGE" ] || die "no z_bridge.dll in $STAGE — the runner alone does not start"

# ---------------------------------------------------------------- the tree
# The same question the Linux script asks, and for the same reason: a build
# from a tree that was not clean cannot be rebuilt by anybody. In CI the tree
# is a fresh checkout, so this is silent there and speaks on a desk.
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

# ---------------------------------------------------------------- the stamp
# **Read out of a binary built from this tree**, never worked out from the
# run's own variables — the Linux script's own rule, and the reason the owner
# can tell yesterday's installer from today's. A stamp that names another
# commit is worse than none, so the job compares it with the commit it is
# building; this file only reports what the core says.
step "asking the core for its own stamp"
STAMP=$(cargo run -q --release -p z_core --example check_document 2>/dev/null | head -1)
[ -n "$STAMP" ] || die "the core would not say its own stamp"
printf '  %s\n' "$STAMP"

# ---------------------------------------------------------------- build info
step "writing BUILD-INFO.txt"
RUNNER_SHA=$(sha256sum "$RUNNER" | cut -d' ' -f1)
BRIDGE_SHA=$(sha256sum "$BRIDGE" | cut -d' ' -f1)
FLUTTER_LINE=$( (cd apps/flutter_app && flutter --version 2>/dev/null | head -1) || true)
{
  echo "Z Privacy V1 — release build (Windows)"
  echo "======================================"
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
  # What the machine says it is, never what this file assumes: run from a
  # desk, the line above said «Windows x86_64» on a Linux box, which is the
  # kind of small lie a release carries for a year.
  echo "built            $(date -Iseconds), $(uname -s) $(uname -m)"
  echo "rustc            $(rustc --version 2>/dev/null)"
  echo "flutter          $FLUTTER_LINE"
  echo "profile          release, assembled by scripts/package_windows.sh"
  echo
  echo "the two files that are the product"
  echo "  zprivacy.exe        $RUNNER_SHA"
  echo "  z_bridge.dll        $BRIDGE_SHA"
  echo
  echo "These two hashes are the ones to check. The hash of the archive itself"
  echo "cannot be inside the archive: it travels beside it, in"
  echo "$NAME.zip.sha256."
  echo
  echo "  sha256sum -c $NAME.zip.sha256"
} > "$STAGE/BUILD-INFO.txt"
printf '  %s\n' "zprivacy.exe  $RUNNER_SHA"
printf '  %s\n' "z_bridge.dll  $BRIDGE_SHA"

# ------------------------------------------------- this machine's own paths
# **The archive may not carry the name of the machine that built it** — the
# independent attacker's خ3 and ن6 of 17 October, which the Linux script
# answers in two halves: the compiler is told to write relative-looking paths
# (`--remap-path-prefix`, exported by the job **before** the build, because the
# absolute paths differ on every machine and a file in the repository cannot
# know them), and then every file about to be packed is searched for what is
# left.
#
# This is that second half, and the needles are the Windows ones beside the
# Linux one:
#
#   * `D:\a\` — every GitHub runner's workspace root;
#   * `C:\Users\runneradmin` — its home, where the cargo registry and the pub
#     cache live;
#   * `/home/` — because the Dart snapshot and the crate list are built from
#     text that may have crossed from a Linux desk, and a needle that costs
#     nothing to ask for is one nobody has to remember;
#   * `\.cargo\registry` — 098 item 3, the fourth: the Windows session found
#     `C:\Users\runneradmin\.cargo\registry\src\index.crates.io-…` 242
#     times in an installed `z_bridge.dll`, and the needle above it only
#     catches that path while the runner's user is named `runneradmin`. A
#     registry path with any other name in it is the same leak, so the needle
#     is the part that does not change. One list with the job's own, because
#     they are one list.
#
# **And the three files we did not write are not searched** — 098 item 1 put
# Microsoft's C++ runtime in this folder, and a binary from Microsoft's own
# build agents may well record `D:\a\…` of its own. We cannot remap a file we
# did not compile; what it says about its builder is its builder's business,
# and `third-party/msvc-runtime-NOTICE.txt` names whose it is. The promise is
# about the name of **our** machine, so the exclusion is by name and is
# printed, never a quiet `|| true`.
#
# Searched with `grep -a`, so a DLL is read as text rather than skipped: the
# Linux twin learned that from 195 strings nobody had looked inside a binary
# for.
step "checking that no path from the builder is left"
LEFT=""
THEIRS="--exclude=vcruntime140.dll --exclude=vcruntime140_1.dll --exclude=msvcp140.dll"
for needle in 'D:\a\' 'C:\Users\runneradmin' '/home/' '\.cargo\registry'; do
  # shellcheck disable=SC2086 # three separate --exclude words, on purpose
  found=$(LC_ALL=C grep -rla --binary-files=binary $THEIRS -F "$needle" "$STAGE" 2>/dev/null)
  if [ -n "$found" ]; then
    LEFT="$LEFT
    «$needle»:
$(printf '%s\n' "$found" | sed 's|^|        |')"
  fi
done
if [ -n "$LEFT" ]; then
  printf '%s\n' "$LEFT"
  die "the archive would carry paths from the machine that built it. Nothing was written."
fi
printf '  no builder path in any of the %s files searched\n' \
  "$(($(find "$STAGE" -type f | wc -l) - 3))"
printf '  %s\n' "3 files not searched, because we did not compile them:" \
  "    vcruntime140.dll, vcruntime140_1.dll, msvcp140.dll (see third-party/)"

# ---------------------------------------------------------------- the archive
# A zip, because this is Windows and a `.tar.gz` is a second program to install
# before the first one can be opened. It holds the folder by name, so it
# unpacks into its own place instead of scattering thirteen files wherever it
# was opened.
step "writing the archive"
mkdir -p "$OUT"
rm -f "$OUT/$NAME.zip" "$OUT/$NAME.zip.sha256"
PARENT=$(cd "$STAGE/.." && pwd)
FOLDER=$(basename "$STAGE")
if command -v zip >/dev/null 2>&1; then
  ( cd "$PARENT" && zip -q -r -9 "$OUT/$NAME.zip" "$FOLDER" ) || die "zip failed"
else
  # Git Bash on a runner has no `zip`; PowerShell is always there. Same
  # archive, one folder inside it.
  powershell -NoProfile -NonInteractive -Command \
    "Compress-Archive -Path '$PARENT/$FOLDER' -DestinationPath '$OUT/$NAME.zip' -Force" \
    || die "Compress-Archive failed"
fi
[ -s "$OUT/$NAME.zip" ] || die "the archive was not written"
( cd "$OUT" && sha256sum "$NAME.zip" > "$NAME.zip.sha256" )

ARCHIVE_SHA=$(cut -d' ' -f1 < "$OUT/$NAME.zip.sha256")
SIZE=$(du -h "$OUT/$NAME.zip" | cut -f1)

printf '\n%s\n' "done"
printf '  %s\n' "$STAMP"
printf '  archive  %s/%s  (%s)\n' "$(basename "$OUT")" "$NAME.zip" "$SIZE"
printf '  sha256   %s\n' "$ARCHIVE_SHA"
[ -n "$DIRTY" ] && printf '  note     built from a tree that was not clean\n'
exit 0
