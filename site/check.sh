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

# A filled-in link is not a real link. The promise was that nothing goes public
# pointing at something that does not exist, so the page's outward destinations
# are asked whether they answer. No network, no verdict — and no publishing.
DESTS=$(grep -rhoE '(href)="https?://[^"]+"' --include='*.html' . 2>/dev/null \
        | sed -E 's/^href="//; s/"$//' \
        | grep -vE '^https?://(www\.)?(apache\.org|w3\.org)' | sort -u)
if ! command -v curl >/dev/null 2>&1; then
  say FAIL "curl is missing, so no destination could be checked"; FAIL=1
else
  for u in $DESTS; do
    # One request, one code. `-I -L` writes a code per hop and «000000» once
    # read as an answer — a guard that mis-reads a dead host is worse than none.
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$u" 2>/dev/null || true)
    case "$code" in
      [0-9][0-9][0-9]) : ;;
      *) code=000 ;;
    esac
    case "$u" in
      # A link on a public page must be reachable by a stranger, so 200 —
      # a private repository reads as 404 here, and would to a visitor too.
      *github.com*) ok=$([ "$code" = "200" ] && echo yes || echo no) ;;
      # Behind Cloudflare Access a redirect to its login is a real answer.
      *) ok=$([ "$code" != "000" ] && echo yes || echo no) ;;
    esac
    if [ "$ok" = yes ]; then
      say PASS "answers ($code): $u"
    else
      say FAIL "does not answer yet ($code): $u"; FAIL=1
    fi
  done
fi

for f in index.html en/index.html de/index.html ar/index.html license/index.html third-party/index.html; do
  [ -f "$f" ] || { say FAIL "missing $f"; FAIL=1; }
done
[ "$FAIL" = 0 ] && say PASS "all pages present"

echo
[ "$FAIL" = 0 ] && echo "site ready to publish" || echo "SITE NOT READY"
exit "$FAIL"
