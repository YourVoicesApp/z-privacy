#!/usr/bin/env bash
# The guard before publishing z-privacy.com: no unfilled build value, no third
# party reached, no script, and every outward link answering. Exit is the verdict.
# It lives outside site/ because site/ is what gets uploaded, and a guard is not
# part of what visitors are served.
set -uo pipefail
cd "$(dirname "$0")/../site" || exit 2
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
# word stops being the one he approved. And the first screen offers no
# download: his ruling, and the reason the four buttons that stood here are
# gone.
SAID=0
grep -q 'class="beta"' index.html || { say FAIL "the chooser says nothing about the state of the build"; FAIL=1; SAID=1; }
for f in en/index.html de/index.html ar/index.html; do
  grep -q 'class="hero-idea"' "$f" || { say FAIL "$f has no idea sentence on its first screen"; FAIL=1; SAID=1; }
  grep -q 'class="hero-word"' "$f" || { say FAIL "$f does not say that nothing leaves without the reader's word"; FAIL=1; SAID=1; }
  grep -q 'class="beta"' "$f" || { say FAIL "$f says nothing about the state of the build"; FAIL=1; SAID=1; }
  if sed -n '/<div class="hero">/,/<section id="idea"/p' "$f" | grep -q 'href="#download'; then
    say FAIL "$f offers a download on the first screen"; FAIL=1; SAID=1
  fi
done
if ! grep -q 'Linux build, in beta — not yet released' en/index.html 2>/dev/null; then
  say FAIL "the English beta line is not the sentence that was approved"; FAIL=1; SAID=1
fi
[ "$SAID" = 0 ] && say PASS "the first screen carries the idea, the word, and the state of the build"

# An anchor that lands nowhere. The first screen's own button is a jump down
# the page, so this stops being a detail: a button that scrolls nowhere is the
# first thing a visitor would press.
JUMPS=0
for f in index.html en/index.html de/index.html ar/index.html license/index.html third-party/index.html; do
  for a in $(grep -o 'href="#[A-Za-z0-9_-]*"' "$f" 2>/dev/null | sed -E 's/href="#//; s/"//' | sort -u); do
    grep -q "id=\"$a\"" "$f" || { say FAIL "$f jumps to #$a, and nothing on that page has that id"; FAIL=1; JUMPS=1; }
  done
done
[ "$JUMPS" = 0 ] && say PASS "every jump on every page lands on something"

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
for f in index.html en/privacy/index.html de/privacy/index.html ar/privacy/index.html license/index.html third-party/index.html; do
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
for f in en/index.html de/index.html ar/index.html en/privacy/index.html de/privacy/index.html ar/privacy/index.html; do
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
for page in en de ar; do
  [ -f "$page/privacy/index.html" ] || continue
  a=$(grep -oE '<div class="legal">.*</div>' "$page/index.html" | head -1)
  b=$(grep -oE '<div class="legal">.*</div>' "$page/privacy/index.html" | head -1)
  if [ -z "$a" ] || [ "$a" != "$b" ]; then
    say FAIL "the publisher block differs between $page/index.html and $page/privacy/index.html"
    FAIL=1; LEGAL=1
  fi
done
[ "$LEGAL" = 0 ] && say PASS "one publisher block, four facts, the same in every place that states them"

# ---------------------------------------------------------------- no download
#
# The owner's ruling of 9 October: «نحذف الحزمَ القديمة جميعَها ونوقف وضعَ أي
# حزمٍ جديدة — الموقعُ للتعريف حتى نرى أين نصل مع كارلوس، لا تنزيلَ فقط تعريفٌ
# بالمنتج.» We delete every old package and stop putting up new ones; the site
# introduces the product and offers nothing to download.
#
# Watched red against the site as it stood: two cards with live files behind
# them, their fingerprints, and a section teaching a stranger how to verify
# what they had downloaded.
#
# It does not search for the **word** «download». That lesson cost a red build
# an hour earlier: a guard that searched for «analytics» went red when the
# privacy page honestly said there was none. A download is a link to a file, a
# fingerprint beside it, or a command for checking one — so those are what this
# asks for, in any language, including the ones nobody has written yet.
GONE=$(grep -rniE 'zprivacy-v1-|href="[^"]*\.(tar\.gz|tgz|zip|exe|deb|rpm|AppImage|dmg|msi)"|class="sha"|class="dlt"|href="#download|sha256sum|Get-FileHash|beta\.z-privacy\.com' \
       --include='*.html' . 2>/dev/null || true)
if [ -n "$(printf '%s' "$GONE" | tr -d '[:space:]')" ]; then
  say FAIL "the site offers something to download:"
  printf '%s\n' "$GONE" | cut -c1-120 | sed 's/^/           /'
  FAIL=1
else
  say PASS "nothing on this site is offered for download"
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

# ---------------------------------------------------------------- the numbers
#
# Every number on the site, and every word it borrowed from the app, against
# the thing it is about. It lives in its own file because it reads Cargo.lock,
# the app's Dart and the served stylesheets, which is more than a shell script
# should do — but the verdict belongs here, so one command still answers.
if command -v python3 >/dev/null 2>&1; then
  if python3 ../scripts/check_site_claims.py; then
    :
  else
    FAIL=1
  fi
else
  say FAIL "no python3, so no number on this site was checked against its deed"; FAIL=1
fi

echo
[ "$FAIL" = 0 ] && echo "site ready to publish" || echo "SITE NOT READY"
exit "$FAIL"
