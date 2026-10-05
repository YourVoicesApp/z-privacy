#!/usr/bin/env bash
# Put Z Privacy in this user's application menu — and nowhere else.
#
# Optional. The program runs perfectly well with `./zprivacy` from the folder
# you unpacked; this only makes it findable the way other applications are.
#
# It writes exactly two things, both inside your own home:
#   ~/.local/share/applications/zprivacy.desktop
#   ~/.local/share/icons/hicolor/<size>/apps/zprivacy.png
#
# Nothing is written outside your home, nothing asks for a password, and
# `--remove` takes both back.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
apps="$HOME/.local/share/applications"
icons="$HOME/.local/share/icons/hicolor"
entry="$apps/zprivacy.desktop"

if [ "${1:-}" = "--remove" ]; then
  rm -f "$entry"
  for size in 16 32 48 64 128 256; do
    rm -f "$icons/${size}x${size}/apps/zprivacy.png"
  done
  command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$apps" 2>/dev/null
  echo "removed: $entry and the icons"
  exit 0
fi

if [ ! -x "$here/zprivacy" ]; then
  echo "no zprivacy next to this script — run it from the folder you unpacked" >&2
  exit 1
fi

mkdir -p "$apps"
# The path is written in, because a .desktop file cannot be relative and this
# folder is wherever you chose to put it.
#
# And it is **quoted**, because `Exec=` is split on spaces by the specification:
# a folder called «a folder with spaces» would otherwise launch a program called
# «a» with three arguments. Measured by unpacking into exactly such a folder.
# The spec's own escaping inside a quoted argument is a backslash before `"`,
# `$`, backtick and backslash.
escaped=$(printf '%s' "$here/zprivacy" | sed 's/[\\"$`]/\\&/g')
sed "s|@EXEC@|\"$escaped\"|" "$here/zprivacy.desktop" > "$entry"
chmod 644 "$entry"

for size in 16 32 48 64 128 256; do
  src="$here/icons/zprivacy-${size}.png"
  [ -f "$src" ] || continue
  mkdir -p "$icons/${size}x${size}/apps"
  cp -f "$src" "$icons/${size}x${size}/apps/zprivacy.png"
done

command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$apps" 2>/dev/null
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q -t -f "$icons" 2>/dev/null

echo "Z Privacy is in your application menu."
echo "  entry: $entry"
echo "  icons: $icons/<size>/apps/zprivacy.png"
echo "To take it back: ./install-shortcut.sh --remove"
