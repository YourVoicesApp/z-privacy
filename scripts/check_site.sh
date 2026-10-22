#!/usr/bin/env bash
# The guard before publishing z-privacy.com: no unfilled build value, no third
# party reached, no script, and every outward link answering. Exit is the verdict.
# It lives outside site/ because site/ is what gets uploaded, and a guard is not
# part of what visitors are served.
set -uo pipefail
cd "$(dirname "$0")/../site" || exit 2
FAIL=0
say() { printf '  %-6s %s\n' "$1" "$2"; }

# **`--tree-only`: everything but the network.** The gates run this on every
# measurement (G59), and a gate that goes red because the machine is offline
# teaches nothing — it is the same lesson as a gate that reds because one of
# the owner's golden documents is on another laptop. The outward links are
# therefore asked of the network only when a person runs this script to
# publish, which is also the moment the answer matters.
TREE_ONLY=0
[ "${1:-}" = "--tree-only" ] && TREE_ONLY=1

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

# Code, not the word. This was a plain search for «analytics» until 9 October,
# and then the privacy page said in three languages that there is no analytics
# account here — an honest sentence turned the guard red. So the pattern names
# what a counter actually looks like: a script, an event handler, a cookie, or
# one of the vendors by their own hostnames. The first form would also have
# gone red the day a German page said «kein Analytics-Konto».
COUNTERS='<script|javascript:|document\.cookie|localStorage|on(click|load|error|submit|focus|change|input|mouseover|keyup|keydown)=|google-analytics|googletagmanager|gtag\(|analytics\.js|plausible\.io|matomo|fathom\.|hotjar|segment\.(io|com)|mixpanel'
if grep -rqiE "$COUNTERS" --include='*.html' . 2>/dev/null; then
  say FAIL "a script, a handler, a cookie or a counter is on a page:"
  grep -rniE "$COUNTERS" --include='*.html' . | sed 's/^/           /' | head -10
  FAIL=1
else
  say PASS "no JavaScript, no handler, no cookie, no counter"
fi

# A filled-in link is not a real link. The promise was that nothing goes public
# pointing at something that does not exist, so the page's outward destinations
# are asked whether they answer. No network, no verdict — and no publishing.
#
# Our **own** absolute addresses are left out, and the reason is worth writing
# down. Until 9 October the only absolute href on the site was the repository
# link, so this loop meant «outward». Then the canonical tags arrived and put
# nine `https://z-privacy.com/…` hrefs into the heads, and the loop quietly
# started asking the live site about pages that are not published yet — and
# passing, because its rule for anything but GitHub is «answered at all», so a
# 404 reads as PASS. A sentence that looks like proof and is not.
#
# These nine are proved where they can be: `check_sitemap.py` resolves every
# one of them to a file in the tree that is about to be uploaded. Whether they
# answer on the live site is the deploy's question, asked after it, not before.
DESTS=$(grep -rhoE '(href)="https?://[^"]+"' --include='*.html' . 2>/dev/null \
        | sed -E 's/^href="//; s/"$//' \
        | grep -vE '^https?://(www\.)?(apache\.org|w3\.org)' \
        | grep -vE '^https://z-privacy\.com/' | sort -u)
MINE=$(grep -rhoE 'href="https://z-privacy\.com/[^"]*"' --include='*.html' . 2>/dev/null | sort -u | wc -l)
say PASS "$MINE of our own addresses are checked against the tree, not asked of the network"
if [ "$TREE_ONLY" = 1 ]; then
  say SKIP "the outward links are not asked of the network, because --tree-only"
elif ! command -v curl >/dev/null 2>&1; then
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

# The four files the pages now ask a browser for. A page that links an icon
# which is not there shows a broken image to everyone who opens it, and the
# three pages ask for the same four.
MISSING=0
for f in assets/favicon-32.png assets/favicon-16.png assets/apple-touch-icon.png assets/logo-512.png; do
  if [ ! -f "$f" ]; then
    say FAIL "the pages link $f and it is not here"
    FAIL=1; MISSING=1
  fi
done
for page in en de ar; do
  for want in 'rel="icon"' 'apple-touch-icon' 'logo-512.png'; do
    grep -q "$want" "$page/index.html" || { say FAIL "$page/index.html has no $want"; FAIL=1; MISSING=1; }
  done
done
[ "$MISSING" = 0 ] && say PASS "the mark is on all three pages, and its four files are here"

# ---------------------------------------------------------------- the first screen
#
# The owner's ruling of 9 October, the same one that put the picture into the
# app's four heads: «أريد أن تظهر صورة الشعار في شاشات التطبيق». The site is a
# screen of this product too, so the mark here is not a lettered tile drawn in
# CSS and not a second picture made for the web — it is **the same file**, and
# that is checked by its fingerprint rather than by its name.
#
# A guard that compares names would have passed on the day the site carried a
# clay square with a Z in it.
MARKED=0
for pair in \
  "assets/logo-512.png:../apps/flutter_app/assets/brand/zprivacy-512.png" \
  "assets/favicon-32.png:../apps/flutter_app/assets/brand/zprivacy-32.png" \
  "assets/favicon-16.png:../apps/flutter_app/assets/brand/zprivacy-16.png"
do
  here="${pair%%:*}"; there="${pair##*:}"
  if [ ! -f "$here" ] || [ ! -f "$there" ]; then
    say FAIL "cannot compare $here with the app's own mark ($there)"; FAIL=1; MARKED=1
  elif [ "$(sha256sum "$here" | cut -d' ' -f1)" != "$(sha256sum "$there" | cut -d' ' -f1)" ]; then
    say FAIL "$here is not the app's own mark, byte for byte ($there)"; FAIL=1; MARKED=1
  fi
done
[ "$MARKED" = 0 ] && say PASS "the mark on the site is the app's own picture, byte for byte"

# One picture, and no lettered tile left anywhere. The app's rule, kept here:
# one mark per screen, never two — and the thing the owner replaced may not
# survive on a page nobody looks at twice.
TILED=0
if grep -rn '<span class="z"' --include='*.html' . 2>/dev/null; then
  say FAIL "a lettered tile is still drawn instead of the owner's picture (above)"
  FAIL=1; TILED=1
fi
for f in index.html en/index.html de/index.html ar/index.html license/index.html third-party/index.html; do
  n=$(grep -c 'assets/logo-512.png' "$f" 2>/dev/null || true); n=${n:-0}
  [ "$n" = 1 ] || { say FAIL "$f draws the mark $n times, and the rule is exactly once"; FAIL=1; TILED=1; }
  # The tab is a screen too, and three pages had no icon at all until today.
  grep -q 'rel="icon"' "$f" || { say FAIL "$f asks for no icon, so its tab wears nothing"; FAIL=1; TILED=1; }
done
[ "$TILED" = 0 ] && say PASS "every page draws the picture exactly once, and no lettered tile is left"

# The page a stranger actually opens first is «/» — the chooser. It is this
# site's First Run, so the mark is large there, by the lead's weighting. «Large»
# is a word; this is the number it was given, read off the attribute a browser
# lays the picture out with.
W=$(grep -o 'class="hero-mark"[^>]*width="[0-9]*"' index.html 2>/dev/null | grep -o 'width="[0-9]*"' | tr -cd '0-9')
if [ -n "$W" ] && [ "$W" -ge 64 ]; then
  say PASS "the first page a stranger opens carries the mark large (${W}px)"
else
  say FAIL "the chooser does not carry the mark large (read: '${W:-none}', wanted 64 or more)"; FAIL=1
fi

# What the first screen says, and what it does not offer.
#
# The idea sentence and the honest beta line are the owner's approved words;
# the beta line is quoted here in full because a sentence that drifts by one
# word stops being the one he approved.
#
# Until rule 81 this also refused an `href="#download"` on the first screen,
# because the download was a card on it and his ruling of 9 October took the
# card away. The download is a **page** from 103, so there is no card to refuse
# and that branch is gone rather than left standing over nothing: what it
# guarded — a file, a fingerprint or a verify command on this screen — is
# refused for every page but the three download pages further down this file,
# and the link to the page is required by `check_site_claims.py`.
SAID=0
grep -q 'class="beta"' index.html || { say FAIL "the chooser says nothing about the state of the build"; FAIL=1; SAID=1; }
for f in en/index.html de/index.html ar/index.html; do
  grep -q 'class="hero-idea"' "$f" || { say FAIL "$f has no idea sentence on its first screen"; FAIL=1; SAID=1; }
  grep -q 'class="hero-word"' "$f" || { say FAIL "$f does not say that nothing leaves without the reader's word"; FAIL=1; SAID=1; }
  grep -q 'class="beta"' "$f" || { say FAIL "$f says nothing about the state of the build"; FAIL=1; SAID=1; }
done
if ! grep -q 'Linux build, in beta — not yet released' en/index.html 2>/dev/null; then
  say FAIL "the English beta line is not the sentence that was approved"; FAIL=1; SAID=1
fi
[ "$SAID" = 0 ] && say PASS "the first screen carries the idea, the word, and the state of the build"

# An anchor that lands nowhere. The first screen's own button is a jump down
# the page, so this stops being a detail: a button that scrolls nowhere is the
# first thing a visitor would press.
#
# **And it counts what it walked** — 100, 22 October 2026. The first screen's
# «How it works» was the one jump on this site, and it became a link to the
# guide page; after that this loop ran over nothing and still said «every jump
# lands on something», which is true of no jumps and reads like a measurement.
# A control that no longer bites is a finding in this house, so the number is
# in the sentence and a zero says so.
JUMPS=0
WALKED=0
for f in index.html en/index.html de/index.html ar/index.html license/index.html third-party/index.html \
         en/guide/index.html de/guide/index.html ar/guide/index.html \
         en/download/index.html de/download/index.html ar/download/index.html; do
  for a in $(grep -o 'href="#[A-Za-z0-9_-]*"' "$f" 2>/dev/null | sed -E 's/href="#//; s/"//' | sort -u); do
    WALKED=$((WALKED + 1))
    grep -q "id=\"$a\"" "$f" || { say FAIL "$f jumps to #$a, and nothing on that page has that id"; FAIL=1; JUMPS=1; }
  done
done
if [ "$JUMPS" = 0 ] && [ "$WALKED" = 0 ]; then
  say PASS "no page carries an in-page jump at all — the first screen's own button went to the guide page in 100, so this walked none"
elif [ "$JUMPS" = 0 ]; then
  say PASS "every jump on every page lands on something ($WALKED walked)"
fi

# ---------------------------------------------------------------- the two menus
#
# The owner's word after the preview: «نجعل اللغات قائمةً منسدلةً من أعلى
# الشاشة تحت خيار اللغة، كما نجعل قاموسَ المفردات قائمةً منسدلةً تحت اسم
# hjälp». Two menus at the top of every page — the languages under the
# language's own name, and the vocabulary under Help in the page's own word.
#
# They are `<details>`, so the promise of no JavaScript survives them; the
# counter guard above already refuses a script, and this one refuses a page
# that quietly loses a menu.
MENUS=0
for pair in "index.html:" "en/index.html:Help" "de/index.html:Hilfe" "ar/index.html:مساعدة" \
            "en/privacy/index.html:Help" "de/privacy/index.html:Hilfe" "ar/privacy/index.html:مساعدة" \
            "en/terms/index.html:Help" "de/terms/index.html:Hilfe" "ar/terms/index.html:مساعدة" \
            "en/guide/index.html:Help" "de/guide/index.html:Hilfe" "ar/guide/index.html:مساعدة" \
            "en/download/index.html:Help" "de/download/index.html:Hilfe" "ar/download/index.html:مساعدة" \
            "license/index.html:Help" "third-party/index.html:Help"
do
  f="${pair%%:*}"; help="${pair##*:}"
  if [ -z "$help" ]; then
    # The chooser at «/» is the language menu, so it carries none.
    grep -q '<nav class="menus"' "$f" && { say FAIL "$f is the chooser and should carry no menu"; FAIL=1; MENUS=1; }
    continue
  fi
  n=$(grep -c '<details class="menu"' "$f" 2>/dev/null || true); n=${n:-0}
  [ "$n" = 2 ] || { say FAIL "$f has $n menus at the top, and there should be two"; FAIL=1; MENUS=1; }
  grep -qF "<summary>$help</summary>" "$f" || grep -qF ">$help</summary>" "$f" \
    || { say FAIL "$f does not call its second menu «$help»"; FAIL=1; MENUS=1; }
  for name in English Deutsch العربية; do
    grep -qF ">$name</a>" "$f" || grep -qF ">$name</summary>" "$f" \
      || { say FAIL "$f does not offer $name in its language menu"; FAIL=1; MENUS=1; }
  done
done
# The vocabulary moved under Help, and it moved — it was not copied. One table
# per language, and none anywhere else.
for f in en/index.html de/index.html ar/index.html; do
  n=$(grep -c '<div class="vocab">' "$f" 2>/dev/null || true); n=${n:-0}
  [ "$n" = 1 ] || { say FAIL "$f holds $n vocabulary tables, and there should be one"; FAIL=1; MENUS=1; }
  grep -q '<div class="menu-panel wide">' "$f" || { say FAIL "$f does not keep its vocabulary under Help"; FAIL=1; MENUS=1; }
done
for f in index.html en/privacy/index.html de/privacy/index.html ar/privacy/index.html en/terms/index.html de/terms/index.html ar/terms/index.html en/guide/index.html de/guide/index.html ar/guide/index.html en/download/index.html de/download/index.html ar/download/index.html license/index.html third-party/index.html; do
  grep -q '<div class="vocab">' "$f" && { say FAIL "$f carries a second copy of the vocabulary"; FAIL=1; MENUS=1; }
done
[ "$MENUS" = 0 ] && say PASS "two menus on every page but the chooser, and one vocabulary, under Help"

# ---------------------------------------------------------------- the privacy page
#
# Three pages, one per language, and the rule they are written under: **every
# promise names the file where it can be checked.** That rule is worth nothing
# if the file has moved, so the paths are read off the pages and asked for by
# name. A page that points at `z_core/tests/something_renamed.rs` is a page
# telling a visitor to go and look at nothing.
PRIV=0
for f in en/privacy/index.html de/privacy/index.html ar/privacy/index.html; do
  if [ ! -f "$f" ]; then
    say FAIL "there is no $f"; FAIL=1; PRIV=1; continue
  fi
  # Every path the page shows in a code span must exist in the repository.
  for path in $(grep -oE '<code>[A-Za-z0-9_./-]+</code>' "$f" | sed -E 's|</?code>||g' | grep '/' | sort -u); do
    [ -e "../$path" ] || { say FAIL "$f names $path, and there is no such file"; FAIL=1; PRIV=1; }
  done
done

# And no language gets a weaker page than another: the three name the same
# proving files. A promise dropped in translation is the oldest way for two
# pages to disagree about one product.
if [ "$PRIV" = 0 ]; then
  for f in de/privacy/index.html ar/privacy/index.html; do
    if ! diff -q \
         <(grep -oE '<code>[A-Za-z0-9_./-]+</code>' en/privacy/index.html | sort -u) \
         <(grep -oE '<code>[A-Za-z0-9_./-]+</code>' "$f" | sort -u) >/dev/null; then
      say FAIL "$f does not name the same proving files as the English page"
      diff <(grep -oE '<code>[A-Za-z0-9_./-]+</code>' en/privacy/index.html | sort -u) \
           <(grep -oE '<code>[A-Za-z0-9_./-]+</code>' "$f" | sort -u) | sed 's/^/           /'
      FAIL=1; PRIV=1
    fi
  done
fi

# Each language page must lead to its own privacy page, and the chooser's three
# cards to the three language pages. A privacy page nobody can reach from the
# site is a file in a repository, not a published policy.
for page in en de ar; do
  grep -q "href=\"/$page/privacy/\"" "$page/index.html" \
    || { say FAIL "$page/index.html does not link its privacy page"; FAIL=1; PRIV=1; }
done
# And the same count of things said. The paths above are one way a translation
# can lose a promise; dropping a whole line is the other, and it leaves no
# missing file behind to notice. On 9 October one of the three named blanks
# became a fact — the origin server's host and country — and it had to leave
# all three pages or none.
if [ "$PRIV" = 0 ]; then
  n_en=$(grep -c '<li class="promise">' en/privacy/index.html)
  for f in de/privacy/index.html ar/privacy/index.html; do
    n=$(grep -c '<li class="promise">' "$f")
    [ "$n" = "$n_en" ] || { say FAIL "$f says $n things where the English page says $n_en"; FAIL=1; PRIV=1; }
  done
fi
[ "$PRIV" = 0 ] && say PASS "three privacy pages, reachable, saying the same things and naming the same files — and every file is there"

# ---------------------------------------------------------------- the terms page
#
# 097, rule 78. Three pages under the same rule as the privacy page's — every
# promise names the file where it can be checked, and the three languages name
# one set — plus the one thing the privacy page does not do: this page **quotes
# another file**, `docs/CLAIMS.md`, and may never say more than it.
#
# A gate cannot read for sense, so it holds what it can be sure of: the file is
# named, the file is there, the three languages name one set of proofs and say
# the same number of things, every page of the set is reachable, and the commit
# the page says it was written against is a commit this repository holds. That
# last one is the page's own promise — «a change to these terms is a new
# commit» — and a page naming a commit that was rebased away sends a reader to
# nothing.
TERMS=0
for f in en/terms/index.html de/terms/index.html ar/terms/index.html; do
  if [ ! -f "$f" ]; then
    say FAIL "there is no $f"; FAIL=1; TERMS=1; continue
  fi
  for path in $(grep -oE '<code>[A-Za-z0-9_./-]+</code>' "$f" | sed -E 's|</?code>||g' | grep '/' | sort -u); do
    [ -e "../$path" ] || { say FAIL "$f names $path, and there is no such file"; FAIL=1; TERMS=1; }
  done
  grep -qF '<code>docs/CLAIMS.md</code>' "$f" \
    || { say FAIL "$f does not name docs/CLAIMS.md, the file it quotes"; FAIL=1; TERMS=1; }
  for sha in $(grep -oE '<code>[0-9a-f]{7,40}</code>' "$f" | sed -E 's|</?code>||g' | sort -u); do
    git -C .. cat-file -e "$sha^{commit}" 2>/dev/null \
      || { say FAIL "$f says it was written against $sha, and this repository has no such commit"; FAIL=1; TERMS=1; }
  done
done
if [ "$TERMS" = 0 ]; then
  for f in de/terms/index.html ar/terms/index.html; do
    if ! diff -q \
         <(grep -oE '<code>[A-Za-z0-9_./-]+</code>' en/terms/index.html | sort -u) \
         <(grep -oE '<code>[A-Za-z0-9_./-]+</code>' "$f" | sort -u) >/dev/null; then
      say FAIL "$f does not name the same proving files as the English terms page"
      diff <(grep -oE '<code>[A-Za-z0-9_./-]+</code>' en/terms/index.html | sort -u) \
           <(grep -oE '<code>[A-Za-z0-9_./-]+</code>' "$f" | sort -u) | sed 's/^/           /'
      FAIL=1; TERMS=1
    fi
  done
  n_en=$(grep -c '<li class="promise">' en/terms/index.html)
  for f in de/terms/index.html ar/terms/index.html; do
    n=$(grep -c '<li class="promise">' "$f")
    [ "$n" = "$n_en" ] || { say FAIL "$f says $n things where the English terms page says $n_en"; FAIL=1; TERMS=1; }
  done
fi
for page in en de ar; do
  for f in "$page/index.html" "$page/privacy/index.html" "$page/terms/index.html"; do
    grep -q "href=\"/$page/terms/\"" "$f" \
      || { say FAIL "$f does not link the $page terms page"; FAIL=1; TERMS=1; }
  done
done
[ "$TERMS" = 0 ] && say PASS "three terms pages, reachable, naming one set of proofs and the commit they were written against"

# ------------------------------------------------- being told of a new release
#
# 097, rule 79. **No form, and not because we chose not to build one**: this
# site's own policy refuses one — `site/_headers` carries `form-action 'none'`,
# so a form here would be blocked by the browser we told to block it. The way
# to ask is therefore a `mailto:` with the subject already in it, and the way
# off it is a word a person can send back.
#
# Read from the **tree** and never from the wire. Cloudflare rewrites a mailto
# into its own obfuscated form on the way out — measured on yourvoicesapp.com —
# so a `curl` of the live page cannot see the address, and a guard that fetched
# the page would go red on a link that works.
UPD=0
for f in en/index.html de/index.html ar/index.html \
         en/terms/index.html de/terms/index.html ar/terms/index.html; do
  grep -qF 'mailto:zprivacy@mono-peak.com?subject=Updates' "$f" \
    || { say FAIL "$f offers no way to be told of a new release"; FAIL=1; UPD=1; }
  grep -qF '«stop»' "$f" \
    || { say FAIL "$f does not say how to be taken off it, which is the word «stop»"; FAIL=1; UPD=1; }
done
# A language's two copies are one block, byte for byte, like the publisher's.
for page in en de ar; do
  a=$(grep -oE '<p class="note">[^<]*«stop»[^<]*</p>' "$page/index.html" | head -1)
  b=$(grep -oE '<p class="note">[^<]*«stop»[^<]*</p>' "$page/terms/index.html" | head -1)
  if [ -z "$a" ] || [ "$a" != "$b" ]; then
    say FAIL "the release block differs between $page/index.html and $page/terms/index.html"
    FAIL=1; UPD=1
  fi
done
FORMS=$(grep -rniE '<form|<input|<textarea|<button' --include='*.html' . 2>/dev/null || true)
if [ -n "$(printf '%s' "$FORMS" | tr -d '[:space:]')" ]; then
  say FAIL "a form control is on this site, and site/_headers says form-action 'none':"
  printf '%s\n' "$FORMS" | cut -c1-120 | sed 's/^/           /'
  FAIL=1; UPD=1
fi
[ "$UPD" = 0 ] && say PASS "one way to be told of a release — a mailto with its subject, the same block on six pages — and no form on this site"

# ------------------------------------------------- no character nobody can see
#
# G55's law, over the pages instead of over the one list, through **the same
# script**: the categories are the point, and a second copy of them is a copy
# that can fall behind. The site is where a sentence of ours is read by
# somebody who cannot ask us what it says, so an invisible character matters
# more here than in the app, not less.
if command -v python3 >/dev/null 2>&1; then
  if OUT=$(cd .. && python3 scripts/check_no_invisible_sentence.py --served site 2>&1); then
    say PASS "$(printf '%s' "$OUT" | tail -1)"
    printf '%s\n' "$OUT" | grep 'directional mark:' | sed 's/^/         /' || true
  else
    say FAIL "a served page carries a character nobody can see:"
    printf '%s\n' "$OUT" | sed 's/^/           /'
    FAIL=1
  fi
fi

# ---------------------------------------------------------------- the publisher
#
# The same four facts, in every place that states them, with no place able to
# drift: the company, its registration number, its registered address and the
# address a person writes to. Wherever two places can disagree about a fact, one
# of them is already wrong.
#
# The old contact was `yourvoices.app@mono-peak.com` — the platform's own
# mailbox, reached from Z's pages in all three languages. The owner's ruling of
# 9 October replaced it everywhere, so «everywhere» is counted rather than
# trusted.
LEGAL=0
if grep -rn 'yourvoices.app@mono-peak.com' --include='*.html' . 2>/dev/null; then
  say FAIL "the platform's mailbox is still on a Z page (above)"; FAIL=1; LEGAL=1
fi
for f in en/index.html de/index.html ar/index.html en/privacy/index.html de/privacy/index.html ar/privacy/index.html en/terms/index.html de/terms/index.html ar/terms/index.html en/guide/index.html de/guide/index.html ar/guide/index.html en/download/index.html de/download/index.html ar/download/index.html; do
  [ -f "$f" ] || continue
  # The country's name is translated on purpose — «Schweden» on the German page —
  # so the guarded part of the address is the street, the postcode and the city,
  # which may never drift in any language.
  for fact in 'Faruk AB' '559473-3494' 'Hotellgatan 3, 311 31 Falkenberg' 'zprivacy@mono-peak.com'; do
    grep -qF "$fact" "$f" || { say FAIL "$f does not state «$fact»"; FAIL=1; LEGAL=1; }
  done
done
# A language's two pages carry one block, byte for byte. The block is
# translated, so the comparison is within a language and not across the three.
# Five pages a language now — 097's terms page, 100's guide and 103's download:
# the block is one block wherever a language states it, and the comparison is
# against that language's first page in every case, so a drift names the two
# pages that disagree and not a chain.
for page in en de ar; do
  a=$(grep -oE '<div class="legal">.*</div>' "$page/index.html" | head -1)
  if [ -z "$a" ]; then
    say FAIL "$page/index.html carries no publisher block at all"; FAIL=1; LEGAL=1; continue
  fi
  for other in privacy terms guide download; do
    [ -f "$page/$other/index.html" ] || continue
    b=$(grep -oE '<div class="legal">.*</div>' "$page/$other/index.html" | head -1)
    if [ "$a" != "$b" ]; then
      say FAIL "the publisher block differs between $page/index.html and $page/$other/index.html"
      FAIL=1; LEGAL=1
    fi
  done
done
[ "$LEGAL" = 0 ] && say PASS "one publisher block, four facts, the same in every place that states them"

# ---------------------------------------------------------------- the colophon
#
# One line, repeated on every page, naming the product, the company that
# publishes it and the licence. It was wrong in one word until 9 October: it
# said «A Mono Peaks project» while the domain, the mark and the mailbox all
# say **mono-peak**, singular. Nobody reads a colophon twice, which is exactly
# why it drifts — and a name our own source spells two ways is a fact one of
# the two places already has wrong.
#
# The guard is positive rather than a search for the old spelling: all nine
# copies must be the identical string, and that string must be this one. A
# search for «Mono Peaks» would pass the day somebody invents a third spelling.
WANT='<p class="colophon" lang="en">Z Privacy &#183; A mono-peak project by Faruk AB &#183; Apache-2.0</p>'
COLO=$(grep -rho '<p class="colophon"[^>]*>[^<]*</p>' --include='*.html' . 2>/dev/null | sort -u)
NC=$(grep -rc '<p class="colophon"' --include='*.html' . 2>/dev/null | grep -vc ':1$' || true); NC=${NC:-0}
if [ "$NC" != 0 ]; then
  say FAIL "a page carries no colophon, or more than one:"
  grep -rc '<p class="colophon"' --include='*.html' . | grep -v ':1$' | sed 's/^/           /'
  FAIL=1
elif [ "$(printf '%s\n' "$COLO" | wc -l)" != 1 ]; then
  say FAIL "the colophon is not one string: the pages carry"
  printf '%s\n' "$COLO" | sed 's/^/           /'
  FAIL=1
elif [ "$COLO" != "$WANT" ]; then
  say FAIL "the colophon reads"
  say "" "  $COLO"
  say "" "and the company spells its name the way its domain does:"
  say "" "  $WANT"
  FAIL=1
else
  say PASS "one colophon, the same on every page, spelling the company as its domain does"
fi

# ------------------------------------------- the download, and everywhere it is not
#
# **Rule 81, and 81-أ of 22 October: the download comes back.** From 9 October
# this section refused a download anywhere on the site — «نحذف الحزمَ القديمة
# جميعَها ونوقف وضعَ أي حزمٍ جديدة — الموقعُ للتعريف حتى نرى أين نصل مع
# كارلوس، لا تنزيلَ فقط تعريفٌ بالمنتج» — and the owner's word of the 21st
# ended that rule for publishing day: z-privacy.com carries the two files
# itself, each with its fingerprint beside it.
#
# So the refusal is **narrowed rather than deleted**. A file link, a
# fingerprint or a verify command belongs on the three download pages and
# nowhere else on this site: the first screen, the privacy page and the terms
# page may not grow a second copy of it, and two places printing two
# fingerprints for one file is the defect this whole file exists for.
# `beta.z-privacy.com` stays in the pattern because that host is dead, and an
# `href="#download"` stays because the download is a page now and a jump to a
# card that no longer exists lands nowhere.
#
# It still does not search for the **word** «download» — that lesson cost a red
# build on 9 October, when a guard looking for «analytics» went red on a
# privacy page honestly saying there was none. And now that the word is a
# heading on three pages and a button on three more, searching for it would be
# a guard that cannot be green.
#
# What the three pages must themselves carry — both artefacts, a
# 64-character fingerprint for each, measured against the real file in the
# deploy tree, and the same honest sentences in all three languages — is
# `check_site_claims.py`'s half, because it hashes files and that is more than
# a shell script should do.
GONE=$(grep -rniE 'zprivacy-v1-|href="[^"]*\.(tar\.gz|tgz|zip|exe|deb|rpm|AppImage|dmg|msi)"|class="sha"|class="dlt"|href="#download|sha256sum|Get-FileHash|beta\.z-privacy\.com' \
       --include='*.html' . 2>/dev/null \
       | grep -vE '^\./(en|de|ar)/download/index\.html:' || true)
if [ -n "$(printf '%s' "$GONE" | tr -d '[:space:]')" ]; then
  say FAIL "a page that is not one of the three download pages offers something to download:"
  printf '%s\n' "$GONE" | cut -c1-120 | sed 's/^/           /'
  FAIL=1
else
  say PASS "no file, no fingerprint and no verify command outside the three download pages"
fi

[ "$FAIL" = 0 ] && say PASS "all pages present"

# ------------------------------------------------- what a crawler is told
#
# The owner wants z-privacy.com in Google. Before a crawler reads a word of a
# page it asks three questions — which address is this page's real one, which
# pages exist, and what am I allowed to fetch — and this section is where each
# answer is measured against the tree that will be uploaded.

# One page, one address. The address is **derived from the path**, never read
# from the page and compared with itself: a canonical copied from a sibling
# and left unedited is the ordinary way this goes wrong, and a guard that
# trusted the page's own word would pass on it.
CANON=0
while IFS= read -r f; do
  rel="${f#./}"; want="https://z-privacy.com/${rel%index.html}"
  n=$(grep -cE '<link[^>]+rel="canonical"' "$f" 2>/dev/null || true); n=${n:-0}
  if [ "$n" != 1 ]; then
    say FAIL "$rel carries $n canonical links, and a page has exactly one address"
    FAIL=1; CANON=1; continue
  fi
  got=$(grep -oE '<link[^>]+rel="canonical"[^>]*>' "$f" \
        | grep -oE 'href="[^"]*"' | sed -E 's/^href="//; s/"$//')
  if [ "$got" != "$want" ]; then
    say FAIL "$rel calls $got its own address, and its own address is $want"
    FAIL=1; CANON=1
  fi
done < <(find . -name index.html | sort)
[ "$CANON" = 0 ] && say PASS "every page names itself as canonical, at the absolute address its own path gives it"

# A set of translations is a set: every page in it names the same members,
# itself included, and a page with no translation names none.
#
# Found by measuring the live site on 9 October, not by reading the markup:
# /license/ and /third-party/ exist in English only, and each told Google that
# its German version was the German **home page** and its Arabic version the
# Arabic home page. Google ignores an annotation the other page does not
# return, so the lie was harmless to the ranking and still a lie in our own
# source. The chooser at / had the mirror fault: it pointed at the three homes
# and none of them pointed back, because what it needed was to be the
# x-default of that set rather than a fourth language.
#
# The guard asks each page's set of its members, so a page cannot be the only
# one telling the truth.
sets_of() {
  grep -oE '<link[^>]+rel="alternate"[^>]*>' "$1" 2>/dev/null \
  | sed -E 's/.*hreflang="([^"]+)"[^>]*href="([^"]+)".*/\1 \2/' | sort
}
HREF=0
h_fail() { say FAIL "$1"; FAIL=1; HREF=1; }
while IFS= read -r f; do
  rel="${f#./}"; me="/${rel%index.html}"
  mine=$(sets_of "$f")
  if [ -z "$mine" ]; then
    # A page under a language folder is a translation of something, so it may
    # not be the one page that keeps quiet about its siblings.
    case "$rel" in
      en/*|de/*|ar/*) h_fail "$rel is a translation and names no language version at all" ;;
    esac
    continue
  fi
  printf '%s\n' "$mine" | awk '{print $2}' | grep -qxF "$me" \
    || h_fail "$rel lists language versions and leaves itself ($me) out of them"
  for a in $(printf '%s\n' "$mine" | awk '{print $2}' | sort -u); do
    tgt=".${a}index.html"
    if [ ! -f "$tgt" ]; then
      h_fail "$rel names $a as a language version of itself, and no page is there"
      continue
    fi
    if [ "$(sets_of "$tgt")" != "$mine" ]; then
      h_fail "$rel and $a disagree about who is in their set, so Google believes neither"
    fi
  done
done < <(find . -name index.html | sort)
[ "$HREF" = 0 ] && say PASS "every set of translations names the same members on every page in it"

# What a crawler is allowed to fetch.
#
# It allows everything and names the sitemap — and it names **nothing else**,
# which is the part worth a guard. A path written here is published to every
# reader of the file, so the rule is not «no secret path» but «no path but
# the root». The owner's private preview folder is kept out of the index by a
# header on the server instead, which tells nobody where it is.
#
# Measured on the live site on 9 October before this was written: /robots.txt
# already answered 200 with 1248 bytes of Cloudflare's content-signals
# preamble — comments only, no User-agent, no Allow, no Sitemap. The origin
# tree has no such file, so the edge is writing it. Ours goes to the origin;
# whether the edge keeps our Sitemap line beside its own text is a question
# only the deploy can answer, and it is the first thing to re-measure after.
ROBOTS=0
r_fail() { say FAIL "$1"; FAIL=1; ROBOTS=1; }
if [ ! -f robots.txt ]; then
  r_fail "there is no robots.txt, so a crawler reaching the root is told nothing"
else
  grep -qE '^[Uu]ser-agent:[[:space:]]*\*[[:space:]]*$' robots.txt \
    || r_fail "robots.txt speaks to no crawler: no «User-agent: *» line"
  grep -qE '^[Aa]llow:[[:space:]]*/[[:space:]]*$' robots.txt \
    || r_fail "robots.txt does not allow the site: no «Allow: /» line"
  grep -qE '^[Ss]itemap:[[:space:]]*https://z-privacy\.com/sitemap\.xml[[:space:]]*$' robots.txt \
    || r_fail "robots.txt does not name the sitemap at its absolute address"
  [ -f sitemap.xml ] \
    || r_fail "robots.txt sends a crawler to a sitemap that is not in this tree"

  # Every path this file mentions, whatever the verb. Only «/» and the empty
  # value (the long way of saying «nothing is disallowed») may survive.
  NAMED=$(grep -iE '^[[:space:]]*(allow|disallow):' robots.txt \
          | sed -E 's/^[^:]*:[[:space:]]*//; s/[[:space:]]*$//' \
          | grep -vxE '/?' || true)
  if [ -n "$(printf '%s' "$NAMED" | tr -d '[:space:]')" ]; then
    r_fail "robots.txt names a path of its own, and so publishes it:"
    printf '%s\n' "$NAMED" | sed 's/^/           /'
  fi

  # A folder nobody is meant to find is named after a fingerprint. No run of
  # eight hex characters belongs in a file served to every crawler on earth.
  HEXY=$(grep -nE '[0-9a-f]{8}' robots.txt || true)
  if [ -n "$HEXY" ]; then
    r_fail "robots.txt carries a fingerprint-shaped name, which is how a private path leaks:"
    printf '%s\n' "$HEXY" | sed 's/^/           /'
  fi
fi
[ "$ROBOTS" = 0 ] && say PASS "robots.txt allows every crawler, names the sitemap, and names no path of its own"

# ---------------------------------------------------------------- the numbers
#
# Every number on the site, and every word it borrowed from the app, against
# the thing it is about. It lives in its own file because it reads Cargo.lock,
# the app's Dart and the served stylesheets, which is more than a shell script
# should do — but the verdict belongs here, so one command still answers.
if command -v python3 >/dev/null 2>&1; then
  # The mode travels, and it is written out rather than expanded cleverly:
  # `${TREE_ONLY:+--tree-only}` reads as «if it is set», and TREE_ONLY is set
  # to the string «0» on a publishing run, so that form would have handed the
  # python half --tree-only on every run and quietly switched off the two
  # checks that only a publishing run makes.
  MODE=""
  [ "$TREE_ONLY" = 1 ] && MODE="--tree-only"
  if python3 ../scripts/check_site_claims.py $MODE; then
    :
  else
    FAIL=1
  fi
  # The list of pages handed to a crawler, walked against the pages that exist.
  # It needs an XML parser and it reads the tree, so it keeps its own file —
  # and the verdict still comes back here, because one command answers.
  if python3 ../scripts/check_sitemap.py; then
    :
  else
    FAIL=1
  fi
else
  say FAIL "no python3, so no number on this site was checked against its deed"; FAIL=1
  say FAIL "no python3, so the list of pages was never compared with the pages"; FAIL=1
fi

# The closing line says which question was answered. «site ready to publish»
# was printed by `--tree-only` too until 103, and from 103 that would be a
# sentence claiming a measurement this mode deliberately did not make: the
# outward links are not asked of the network here, and neither is the download
# section's own bar — whether the two real files are in the deploy tree with
# the fingerprints the pages print. A round on a workstation answers the first
# question; only the hand that publishes answers the second.
echo
if [ "$FAIL" != 0 ]; then
  echo "SITE NOT READY"
elif [ "$TREE_ONLY" = 1 ]; then
  echo "the tree says nothing false — the publishing questions were not asked, because --tree-only"
else
  echo "site ready to publish"
fi
exit "$FAIL"
