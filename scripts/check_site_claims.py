#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Every number on the site, and every word it borrowed, checked against the thing it is about.

The owner's rule for this round, in the lead's words: «لا رقمَ قبل فعله —
وقاعدةُ "كل جملة قياس" تسري على الموقع كما على التذييل». No number before its
deed, and «every sentence is a measurement» holds for the site as it does for
the footer.

A page is where a number goes to drift. The four it makes:

  1. **the crate table** — 142 names and versions of other people's work, which
     is an attribution and not decoration. Checked against `Cargo.lock` in both
     directions. On 9 October it was short by one row: `windows-sys 0.59.0` was
     in the lock and not on the page, while `0.52.0` was on both.
  2. **the font faces** — 6 · 18 · 12 · 10 per family, checked against the
     `@font-face` rules the site actually serves.
  3. **the glossary** — 29 words that the page claims are the app's own and not
     a second wording invented here. Checked against the string literals the
     app really prints. On 9 October three of them («Found by rule», «Found by
     pack», «Found by vault») were nowhere in the product: the app's own badges
     read `Rule`, `Pack`, `Vault` and `You`, and the page had invented a
     sentence for three of them and omitted the fourth.
  4. **the path** — Import → Scan → Review → Protect → Review what will leave →
     AI → Restore, said to be «as it appears in the app».

Two words in the glossary are **not** printed by any screen, and they are named
here rather than quietly allowed: a word that the product does not say is a word
this page has to account for.

  python3 scripts/check_site_claims.py        # the exit status is the verdict
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The glossary's two honest exceptions, with the reason each one is allowed.
NOT_ON_A_SCREEN = {
    'Safe payload': 'the core’s own name for the text that leaves — `SafePayload`',
    'Local model': 'a model on your own machine, which the app lets you reach without naming it',
}


def read(*parts):
    with io.open(os.path.join(ROOT, *parts), encoding='utf-8') as fh:
        return fh.read()


def say(verdict, line):
    print('  %-6s %s' % (verdict, line))


def dart_strings():
    out = []
    for base, _, files in os.walk(os.path.join(ROOT, 'apps/flutter_app/lib')):
        for name in files:
            if name.endswith('.dart'):
                with io.open(os.path.join(base, name), encoding='utf-8') as fh:
                    src = fh.read()
                out += re.findall(r"'([^'\n]*)'", src) + re.findall(r'"([^"\n]*)"', src)
    return [s.lower() for s in out]


def crates():
    page = set(re.findall(r'<span class="cn">([a-z0-9_-]+)</span><span class="cv">([^<]+)</span>',
                          read('site/third-party/index.html')))
    lock = set(re.findall(r'\[\[package\]\]\nname = "([^"]+)"\nversion = "([^"]+)"',
                          read('Cargo.lock')))
    # Our own two crates are the thing being licensed, not a third party.
    lock = {(n, v) for n, v in lock if n not in ('z_core', 'z_bridge')}
    missing, extra = sorted(lock - page), sorted(page - lock)
    bad = 0
    for n, v in missing:
        say('FAIL', 'the build uses %s %s and the notices page does not name it' % (n, v))
        bad = 1
    for n, v in extra:
        say('FAIL', 'the notices page names %s %s, which this build does not use' % (n, v))
        bad = 1
    if not bad:
        say('PASS', 'all %d crates on the notices page are exactly what Cargo.lock says' % len(page))
    return bad


def fonts():
    css = read('site/assets/fonts.css')
    served = {}
    for fam in re.findall(r"font-family: '([^']+)'", css):
        served[fam] = served.get(fam, 0) + 1
    page = re.findall(r'<span class="cn">([A-Za-z ]+)</span><span class="cv">(\d+)</span>',
                      read('site/third-party/index.html'))
    bad = 0
    for fam, said in page:
        n = served.get(fam)
        if n is None:
            say('FAIL', 'the page names the family %s, which this site does not serve' % fam)
            bad = 1
        elif int(said) != n:
            say('FAIL', 'the page says %s has %s faces; the site serves %d' % (fam, said, n))
            bad = 1
    if not page:
        say('FAIL', 'the notices page names no font family at all')
        bad = 1
    elif not bad:
        say('PASS', 'the face counts are the faces served: ' +
            ', '.join('%s %d' % (f, served[f]) for f, _ in page))
    return bad


def glossary(lits):
    page = read('site/en/index.html')
    terms = re.findall(r'<div class="ven"[^>]*><span class="vlab"[^>]*>EN</span>([^<]+)</div>', page)
    exact = inside = 0
    bad = 0
    for term in terms:
        k = term.lower()
        if any(l == k for l in lits):
            exact += 1
        elif any(k in l for l in lits):
            inside += 1
        elif term in NOT_ON_A_SCREEN:
            pass
        else:
            say('FAIL', 'the glossary says the app calls it «%s», and no screen '
                        'prints those words' % term)
            bad = 1
    if not terms:
        say('FAIL', 'there is no glossary on the English page')
        bad = 1
    elif not bad:
        say('PASS', 'the glossary is the app’s own words: %d of %d printed as a label, '
                    '%d inside a longer one, %d named as not on a screen'
            % (exact, len(terms), inside, len(NOT_ON_A_SCREEN)))
    return bad


def path(lits):
    steps = re.findall(r'<span class="step">([^<]+)</span>', read('site/en/index.html'))
    bad = 0
    for step in steps:
        if not any(step.lower() == l or step.lower() in l for l in lits):
            say('FAIL', 'the path shows the step «%s», which the app does not print' % step)
            bad = 1
    if not steps:
        say('FAIL', 'the path chain is not on the English page')
        bad = 1
    elif not bad:
        say('PASS', 'every step of the path is a word the app prints (%s)' % ' → '.join(steps))
    return bad


def main():
    lits = dart_strings()
    if len(lits) < 200:
        say('FAIL', 'only %d strings were read out of the app, so nothing was really compared' % len(lits))
        return 1
    bad = crates() | fonts() | glossary(lits) | path(lits)
    print()
    print('every number on the site has a deed behind it' if not bad
          else 'A NUMBER ON THE SITE HAS NO DEED BEHIND IT')
    return bad


if __name__ == '__main__':
    sys.exit(main())
