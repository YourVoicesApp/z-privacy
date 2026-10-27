#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""The FAQ pages say what was approved, and the structured data says what the page says.

The owner's three conditions for publishing these pages were that they pass
the site gates, that the `FAQPage` JSON-LD match the published text exactly,
and that the quotations stay identical to the build offered for download. The
third is `scripts/check_the_quoted_app_text.py`; this file is the second, and
it carries the first half of something nobody asked for and the round needs:
**the visible answer must still be the approved one.**

Four questions, in the order they would go wrong:

  1. **one `FAQPage` per page, with 25 questions.** Two blocks, or a question
     dropped in one language, is a page that tells a crawler something its
     own reader cannot see.
  2. **every `name` and every `acceptedAnswer.text` equals the visible
     question and answer**, after the same strip. Structured data that says
     more, less or other than the page is the oldest trick on the web and we
     do not get to do it by accident either.
  3. **every visible question and answer equals the approved text** — the
     English from `docs/faq-review.md`, the German and the Arabic from
     `docs/faq-translation-draft.md`, which is where they were read and
     approved. A sentence improved while building a page is a sentence nobody
     approved, and this is what makes «no rewording» a measurement rather
     than an intention.
  4. **the three languages carry the same 25 questions**, so a language cannot
     quietly hold fewer.

**What it does not do:** judge whether an answer is true, or whether the
German means what the English means. The first is the tests' and the claims
file's; the second is the meaning check and, for Arabic, the owner.

  python3 scripts/check_the_faq_pages.py     # the exit status is the verdict
"""
import html as _html
import io
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
LANGS = ('en', 'de', 'ar')
TAG = {'en': 'EN', 'de': 'DE', 'ar': 'AR'}
COUNT = 25


def strip(s):
    """The visible text of a fragment: the one definition both sides use.

    A non-breaking space is a space. The pages bind the two words of the
    product's name so it cannot come apart at phone width, and that
    typography must not make the text differ from what was approved.
    """
    s = _html.unescape(re.sub(r'<[^>]+>', '', s))
    return s.replace('\u00a0', ' ').strip()


def approved():
    """What was read and approved, per language."""
    out = {}
    rev = io.open(ROOT / 'docs/faq-review.md', encoding='utf-8').read()
    out['en'] = {int(m.group(1)): (m.group(2).strip(), m.group(3).strip())
                 for m in re.finditer(
                     r'^## Q(\d+) · (.*?)\n\n\*\*Answer\.\*\* (.*?)\n',
                     rev, re.S | re.M)}
    draft = io.open(ROOT / 'docs/faq-translation-draft.md', encoding='utf-8').read()
    # The question headings live in their own block at the foot of the draft:
    # they were the one body of text a page needed and the draft did not hold.
    heads = {'de': {}, 'ar': {}}
    for m in re.finditer(r'^\*\*Q(\d+)\.\*\* .*?\n\n- \*\*DE\*\* — (.*?)\n'
                         r'- \*\*AR\*\* — <span[^>]*>(.*?)</span>', draft, re.S | re.M):
        heads['de'][int(m.group(1))] = m.group(2).strip()
        heads['ar'][int(m.group(1))] = m.group(3).strip()
    for lang in ('de', 'ar'):
        out[lang] = {}
        for m in re.finditer(r'^## Q(\d+) · .*?\n\n.*?\*\*%s[^*]*\.?\*\*\s*'
                             r'(?:<div[^>]*>\s*)?(.*?)(?:\n\n</div>|\n\n\*\*)'
                             % TAG[lang], draft, re.S | re.M):
            n = int(m.group(1))
            out[lang][n] = (heads[lang].get(n), m.group(2).strip())
    return out


def markup_to_text(s):
    """The draft's own markup as plain words, so a page and a draft compare."""
    s = re.sub(r'`([^`]+)`', r'\1', s)
    s = re.sub(r'\*\*([^*]+)\*\*', r'\1', s)
    return strip(s)


def main():
    src = approved()
    bad = 0
    seen = {}
    for lang in LANGS:
        page = ROOT / ('site/%s/faq/index.html' % lang)
        if not page.exists():
            print('  SKIP   %s: no page in this tree' % lang)
            continue
        t = io.open(page, encoding='utf-8').read()

        blocks = re.findall(r'<script type="application/ld\+json">(.*?)</script>',
                            t, re.S)
        faq = [json.loads(b) for b in blocks]
        faq = [d for d in faq if d.get('@type') == 'FAQPage']
        if len(faq) != 1:
            print('  FAIL   %s carries %d FAQPage blocks and there should be one'
                  % (TAG[lang], len(faq)))
            bad = 1
            continue
        entity = faq[0].get('mainEntity', [])
        if len(entity) != COUNT:
            print('  FAIL   %s: the structured data holds %d questions and the page '
                  'answers %d' % (TAG[lang], len(entity), COUNT))
            bad = 1

        visible = {}
        for m in re.finditer(r'<h2 class="q" id="q(\d+)">(.*?)</h2>\s*'
                             r'<p class="a">(.*?)</p>', t, re.S):
            visible[int(m.group(1))] = (strip(m.group(2)), strip(m.group(3)))
        if len(visible) != COUNT:
            print('  FAIL   %s: the page shows %d questions and should show %d'
                  % (TAG[lang], len(visible), COUNT))
            bad = 1
        seen[lang] = set(visible)

        for i, item in enumerate(entity, start=1):
            # The same strip both sides: the data is plain text already, so
            # this only normalises the space that binds «Z Privacy».
            q = strip(item.get('name', ''))
            a = strip(item.get('acceptedAnswer', {}).get('text', ''))
            shown = visible.get(i)
            if shown is None:
                print('  FAIL   %s: the structured data holds a question %d the '
                      'page does not show' % (TAG[lang], i))
                bad = 1
                continue
            if q != shown[0]:
                print('  FAIL   %s Q%-2d: the structured data names a question the '
                      'page does not show' % (TAG[lang], i))
                print('           the data says: %s' % q)
                print('           the page says: %s' % shown[0])
                bad = 1
            if a != shown[1]:
                print('  FAIL   %s Q%-2d: the structured data answers differently '
                      'from the page' % (TAG[lang], i))
                print('           the data says: %s' % a[:120])
                print('           the page says: %s' % shown[1][:120])
                bad = 1

        for n in sorted(visible):
            want = src.get(lang, {}).get(n)
            if want is None:
                print('  FAIL   %s Q%-2d is on the page and in no approved file'
                      % (TAG[lang], n))
                bad = 1
                continue
            if want[0] is not None and visible[n][0] != markup_to_text(want[0]):
                print('  FAIL   %s Q%-2d: the question on the page is not the '
                      'approved one' % (TAG[lang], n))
                bad = 1
            if visible[n][1] != markup_to_text(want[1]):
                print('  FAIL   %s Q%-2d: the answer on the page is not the '
                      'approved one' % (TAG[lang], n))
                print('           approved: %s' % markup_to_text(want[1])[:110])
                print('           the page: %s' % visible[n][1][:110])
                bad = 1
        if not bad:
            print('  PASS   %s: one FAQPage, %d questions, the data equal to the '
                  'page and the page equal to what was approved'
                  % (TAG[lang], COUNT))

    if len(seen) > 1:
        first = sorted(seen)[0]
        for lang in sorted(seen):
            if seen[lang] != seen[first]:
                print('  FAIL   %s and %s do not answer the same questions'
                      % (TAG[first], TAG[lang]))
                bad = 1
    print()
    print('%d FAQ pages checked' % len(seen))
    print('THE FAQ SAYS SOMETHING NOBODY APPROVED' if bad
          else 'the three pages say what was approved, and their structured data '
               'says what they say')
    return bad


if __name__ == '__main__':
    sys.exit(main())
