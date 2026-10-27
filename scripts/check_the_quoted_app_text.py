#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""A sentence the FAQ quotes from the app is the app's, byte for byte —
**as the published build says it**, not as the working tree does.

The lead, 26 October 2026, reading the Arabic draft: the FAQ quotes the
application, so the quote must be identical to what the application ships.
Three had drifted — the Arabic `thereIsNoWayBack` by four words, the German by
a word order, the German button label by its first word — and every one of
them was a sentence somebody would check us on by opening the app.

**The owner's amendment, the same day:** compare with the version a person can
download, not with unreleased code changes. A quote is a claim about what a
reader will see on their own screen, and that screen is the released build. So
the sentences are read with `git show <sha>:apps/flutter_app/lib/l10n/app_<lang>.arb`,
and **`<sha>` is whatever the three download pages themselves say they are
offering** — the text inside their `data-built-from` elements. The site names
its build in one place and this gate believes that place:

  * the six values (three languages, two platforms) must agree, or the pages
    disagree about what they are offering and nothing else here can be
    trusted;
  * the sha must resolve in this repository, or the pages name a build this
    tree has never seen;
  * and when the arb in the working tree differs from the released one for a
    quoted key, that is a **NOTE** and not a failure: an app wording change is
    on its way, and the FAQ follows the release until it ships.

**What this buys on the day it matters.** A new build is published, the
download pages' sha moves, and any FAQ sentence the new app no longer says
reds **before the site deploys** — which is why it runs inside
`scripts/check_site.sh` and not only as a script somebody remembers.

**What it does not check:** that the quote is the *right* sentence for the
answer. Naming the wrong key would pass here, and that is a reader's job.

  python3 scripts/check_the_quoted_app_text.py     # the exit status is the verdict
"""
import io
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
LANGS = ('en', 'de', 'ar')
TAG = {'en': 'EN', 'de': 'DE', 'ar': 'AR'}

# question -> the arb keys its answer quotes, in the order they appear.
QUOTED = {
    13: ('addAnAnswer',),
    16: ('thereIsNoWayBack',),
}

DRAFT = ROOT / 'docs/faq-translation-draft.md'
ARB = 'apps/flutter_app/lib/l10n/app_%s.arb'


def released():
    """The commit the download pages say they are offering, and where they say it."""
    seen = {}
    for lang in LANGS:
        page = ROOT / ('site/%s/download/index.html' % lang)
        if not page.exists():
            continue
        text = io.open(page, encoding='utf-8').read()
        for m in re.finditer(r'<[^>]*data-built-from="([^"]*)"[^>]*>([^<]*)<', text):
            seen.setdefault(m.group(2).strip(), []).append('%s · %s' % (lang, m.group(1)))
    return seen


def at(sha, lang):
    """One language's sentences as that build shipped them."""
    try:
        out = subprocess.run(['git', 'show', '%s:%s' % (sha, ARB % lang)],
                             cwd=str(ROOT), capture_output=True, check=True)
    except subprocess.CalledProcessError:
        return None
    return json.loads(out.stdout.decode('utf-8'))


def in_the_tree(lang):
    path = ROOT / (ARB % lang)
    if not path.exists():
        return None
    return json.loads(io.open(path, encoding='utf-8').read())


def drafted(lang):
    if not DRAFT.exists():
        return {}
    text = io.open(DRAFT, encoding='utf-8').read()
    out = {}
    for m in re.finditer(r'^## Q(\d+) · .*?\n\n.*?\*\*%s[^*]*\.?\*\*\s*'
                         r'(?:<div[^>]*>\s*)?(.*?)(?:\n\n</div>|\n\n\*\*)'
                         % TAG[lang], text, re.S | re.M):
        out[int(m.group(1))] = m.group(2)
    return out


def served(lang):
    page = ROOT / ('site/%s/faq/index.html' % lang)
    return io.open(page, encoding='utf-8').read() if page.exists() else None


def main():
    builds = released()
    if not builds:
        print('  FAIL   no download page names a build, so there is no release to '
              'compare the quotations with')
        return 1
    if len(builds) > 1:
        print('  FAIL   the download pages name %d different builds, so they '
              'disagree about what is being offered:' % len(builds))
        for sha, where in sorted(builds.items()):
            print('           %s — %s' % (sha, ', '.join(where)))
        return 1
    sha = next(iter(builds))
    resolved = subprocess.run(['git', 'rev-parse', '--verify', '--quiet',
                               '%s^{commit}' % sha],
                              cwd=str(ROOT), capture_output=True)
    if resolved.returncode != 0:
        print('  FAIL   the download pages offer build %s and this repository has '
              'no such commit' % sha)
        return 1
    print('  PASS   the three download pages agree: the released build is %s' % sha)

    bad = 0
    checked = 0
    for lang in LANGS:
        shipped = at(sha, lang)
        if shipped is None:
            print('  FAIL   %s has no %s, so that language has no released '
                  'sentences to quote' % (sha, ARB % lang))
            bad = 1
            continue
        here = in_the_tree(lang) or {}
        answers = drafted(lang)
        page = served(lang)
        if not answers and page is None:
            print('  SKIP   %s: neither a draft nor a page in this tree' % lang)
            continue
        for n, keys in sorted(QUOTED.items()):
            for key in keys:
                want = shipped.get(key)
                if want is None:
                    print('  FAIL   %s does not define «%s» in %s — the FAQ quotes '
                          'a sentence that build does not say' % (sha, key, lang))
                    bad = 1
                    continue
                if key in here and here[key] != want:
                    print('  NOTE   %s «%s» is being reworded in the tree; the FAQ '
                          'follows the release until that ships' % (TAG[lang], key))
                for where, body in (('draft', answers.get(n)), ('page', page)):
                    if body is None:
                        continue
                    checked += 1
                    if want in body:
                        print('  PASS   %s Q%-2d %s quotes «%s» as %s ships it'
                              % (TAG[lang], n, where, key, sha))
                    else:
                        # **Both texts, not only ours.** A red that says «this
                        # does not match» sends the reader to two files to find
                        # out how; a red that prints the build's sentence and
                        # the page's beside it is read once and acted on.
                        quoted = re.findall(r'«([^»]{20,})»', body)
                        said = max(quoted, key=len) if quoted else None
                        print('  FAIL   %s Q%-2d %s does not quote «%s» as %s '
                              'ships it' % (TAG[lang], n, where, key, sha))
                        print('           the build says: %s' % want)
                        print('           the %s says:   %s'
                              % (where, said if said else
                                 '— nothing in guillemets, so the quotation is '
                                 'not marked as one'))
                        bad = 1
    print()
    print('%d quotations checked against build %s' % (checked, sha))
    print('A QUOTED SENTENCE IS NOT THE ONE THE RELEASED APP SHOWS' if bad
          else 'every sentence the FAQ quotes is the released app’s own, byte for byte')
    return bad


if __name__ == '__main__':
    sys.exit(main())
