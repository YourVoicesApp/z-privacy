#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""A sentence the FAQ quotes from the app is the app's, byte for byte.

The lead, 26 October 2026, reading the Arabic draft: the FAQ quotes the
application, so the quote must be identical to what the application ships.
Three had drifted — the Arabic `thereIsNoWayBack` by four words, the German by
a word order, and the German button label by its first word — and every one of
them was a sentence somebody would check us on.

**Why a gate and not a careful reader.** A quotation is the one kind of
sentence that goes stale without anybody touching it: the app's wording moves
in some later round, and the FAQ goes on attributing the old words to a screen
that no longer says them. That is worse than an inaccuracy of our own, because
the reader can open the app and see us misquote ourselves. So the quote is read
from `apps/flutter_app/lib/l10n/app_<lang>.arb` **by key**, per language, and a
mismatch reds — the same binding as the site's §6 and `C-13`.

It reads the translation draft today and the published FAQ pages when they
exist. A quote is expected in every language the page is written in; a language
that has the question and not the quote is a language where somebody
paraphrased.

**What it does not check:** that the quote is the *right* sentence for the
answer. Naming the wrong key would pass here and is a reader's job.

  python3 scripts/check_the_quoted_app_text.py     # the exit status is the verdict
"""
import io
import json
import pathlib
import re
import sys

LANGS = ('en', 'de', 'ar')

# question -> the arb keys its answer quotes, in the order they appear.
QUOTED = {
    13: ('addAnAnswer',),
    16: ('thereIsNoWayBack',),
}

DRAFT = pathlib.Path('docs/faq-translation-draft.md')
PAGES = {lang: pathlib.Path('site/%s/faq/index.html' % lang) for lang in LANGS}
ARB = 'apps/flutter_app/lib/l10n/app_%s.arb'

TAG = {'en': 'EN', 'de': 'DE', 'ar': 'AR'}


def shipped(lang, key):
    path = pathlib.Path(ARB % lang)
    if not path.exists():
        return None
    return json.loads(io.open(path, encoding='utf-8').read()).get(key)


def drafted(lang):
    """Each question's answer in one language, from the draft."""
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
    """The published page, when there is one, as one blob per language."""
    page = PAGES[lang]
    if not page.exists():
        return None
    return io.open(page, encoding='utf-8').read()


def main():
    bad = 0
    checked = 0
    for lang in LANGS:
        answers = drafted(lang)
        page = served(lang)
        if not answers and page is None:
            print('  SKIP   %s: neither a draft nor a page in this tree' % lang)
            continue
        for n, keys in sorted(QUOTED.items()):
            for key in keys:
                want = shipped(lang, key)
                if want is None:
                    print('  FAIL   %s has no «%s» — the FAQ quotes a key the app '
                          'does not define' % (ARB % lang, key))
                    bad = 1
                    continue
                for where, body in (('draft', answers.get(n)), ('page', page)):
                    if body is None:
                        continue
                    checked += 1
                    if want in body:
                        print('  PASS   %s Q%-2d %s quotes «%s» as the app ships it'
                              % (lang.upper(), n, where, key))
                    else:
                        print('  FAIL   %s Q%-2d %s does not quote «%s» as the app '
                              'ships it — the app says: %s'
                              % (lang.upper(), n, where, key, want))
                        bad = 1
    print()
    print('%d quotations checked against the shipped sentences' % checked)
    print('A QUOTED SENTENCE IS NOT THE ONE THE APP SHOWS' if bad
          else 'every sentence the FAQ quotes is the app’s own, byte for byte')
    return bad


if __name__ == '__main__':
    sys.exit(main())
