#!/usr/bin/env bash
# The guard before publishing: the site must carry no unfilled build value and
# must reach no third party. Exit status is the verdict.
set -uo pipefail
cd "$(dirname "$0")" || exit 2
FAIL=0
say() { printf '  %-6s %s\n' "$1" "$2"; }

LEFT=$(grep -rlE '\{\{[A-Z0-9_]+\}\}' --include='*.html' . 2>/dev/null || true)
if [ -n "$LEFT" ]; then
  say FAIL "build values still unfilled:"
  grep -rhoE '\{\{[A-Z0-9_]+\}\}' --include='*.html' . | sort -u | sed 's/^/           /'
  printf '           in: %s\n' $LEFT
  FAIL=1
else
  say PASS "every build value is filled"
fi

# Only what a browser FETCHES on its own counts: src=, a stylesheet link,
# url() and @import in CSS. A plain <a href> to another site is a hyperlink a
# person chooses, and a URL printed inside a licence text is just text.
OUT=$(grep -rnoE '(src|href)="https?://[^"]+"' --include='*.html' . 2>/dev/null \
      | grep -vE '<a |rel="alternate"' \
      | grep -E 'src=|rel="stylesheet"' || true)
OUT="$OUT$(grep -rnoE '(url\(|@import)[^;]*https?://[^)"'"'"' ;]+' --include='*.css' . 2>/dev/null || true)"
OUT="$OUT$(grep -rnoE '<link[^>]+rel="(stylesheet|preconnect|dns-prefetch|preload)"[^>]*https?://' --include='*.html' . 2>/dev/null || true)"
if [ -n "$(printf '%s' "$OUT" | tr -d '[:space:]')" ]; then
  say FAIL "a request would leave this site:"; printf '%s\n' "$OUT" | sed 's/^/           /'
  FAIL=1
else
  say PASS "no third-party request: fonts and styles are served from here"
fi

if grep -rqiE '<script|onclick=|analytics|gtag|document\.cookie' --include='*.html' . 2>/dev/null; then
  say FAIL "script, handler, analytics or cookie found"; FAIL=1
else
  say PASS "no JavaScript, no analytics, no cookie"
fi

for f in index.html en/index.html de/index.html ar/index.html license/index.html third-party/index.html; do
  [ -f "$f" ] || { say FAIL "missing $f"; FAIL=1; }
done
[ "$FAIL" = 0 ] && say PASS "all pages present"

echo
[ "$FAIL" = 0 ] && echo "site ready to publish" || echo "SITE NOT READY"
exit "$FAIL"
