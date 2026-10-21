#!/usr/bin/env python3
"""**A guard may not type a sentence this list owns** — 092, sitting five, item 2.

Measured on 20 October 2026, before this item: **458** finders in
`apps/flutter_app/test` reached for a typed sentence and **284** of them named a
value that lives in `lib/l10n/app_en.arb`. After sitting five's first item moved
eighteen more files into the list the figure was **342 of 646** — the debt grew
because the list did, which is the clearest possible argument for closing it.

While the suite reads English every one of them is *correct*. They are a debt
anyway, and the same debt as the screens': each is a second copy of a sentence
whose home is the list, so a reworded value turns a guard red for the wrong
reason — or, where the assertion is `findsNothing`, leaves it **green** for the
wrong reason, which is worse. The form that does not rot is
`find.text(sentences.theKey)`: the guard reading the one place instead of
remembering it.

## What this refuses, and the two things it allows by name

Every finder that types a string equal to a value in the one list is a failure
**unless** the string is named below. There is no floor: at the end of this item
the thirty-three that remain are all in one of these two classes, and a
thirty-fourth means somebody typed a sentence again.

**`DRAWN_ELSEWHERE` — matching by value is not matching by source.** The
automated pass over this item rewrote 323 finders, and nineteen of them were
**wrong**, each because the text on the glass comes from somewhere that is not
this list and only happens to equal a value in it:

  * `'English'` — the first-run picker labels each row from the **core's** own
    language table. `sentences.thisLanguageName` is «what this interface calls
    its own language», which is `English` today and `Deutsch` in a German
    interface: the converted test would have pressed a different row.
  * `'Nordstern Consulting GmbH'` and `'Lindqvist'` — the list holds these as
    the *greyed examples* in a form. The tests seed them as a **value the
    person taught** and then assert the value appears, or (worse) that it is
    gone. A finder on the example's key would be asking about the hint text.
  * `'Documents'` — two `findsNothing` assertions about a screen this product
    removed. The key of that name is the file chooser's own type-group label,
    which is drawn by the operating system and never on our glass.

**`ONE_ENGLISH_TWO_KEYS` — a sentence a finder cannot name.** «Cancel» is both
`cancel` (leaves a question) and `cancelForm` (leaves a form); «Rename» is three
keys; «Keep it» and «Unlock» are two each. The English is identical on purpose,
so a finder *by text* cannot say which widget it means, and choosing one would
point the test at a widget it was not written for the day German tells them
apart. Where the screen was determinable it was converted — `vault_screen_test`
presses the vault's forms (`cancelForm`), the review's own dialog is `cancel`.
The rest want a finder **by key**, which is a different item from this one.

## What this item costs, said out loud

A finder that reads the key cannot notice a **reworded** value. Before this
item, changing «Protect» to «Delete» in the list reddened ten guards; after it,
nothing in the suite moves. That is the trade the item was ruled for — the
noise was reddening guards for the wrong reason, and `findsNothing` over a
typed sentence was going green for the wrong reason — but the other half of it
should not be discovered later: `the_sentences_are_in_one_list_test.dart`
measures the list's **shape** (every key in every language, the German saying
something else, no invisible character), and nothing measures its **meaning**.
What still catches a changed meaning is the review of the list itself, the site
pages that quote a sentence by its English, and `docs/CLAIMS.md`. The smaller
counter-measure, if it is wanted, is one guard over the handful of sentences a
claim in that file depends on, pinned by their exact English with the claim
named beside each — not 333 of them, which is what this item removed.

Proved when the conversion was made: all **333** converted calls render exactly
the literal they replaced, checked against the ARB by rendering each one and
comparing with the line the diff took out. So no guard in the English suite
changed what it asserts.

## The debt this item left behind, and the ruling that closed it

**A sentence with no word of three letters was invisible to the census.**
`check_the_one_list.py` told a sentence from a key by `[A-Za-z]{3,}`, so
`find_in_document.dart`'s «Go to it» was never in any count of what the screens
owed — it reached the list in sitting five's first item only because the file
happened to be open. Widening that test changes what every file owes, so it was
written down here rather than decided here.

**Closed on 21 October 2026, item 2-ج, by the lead's ruling:** a literal reads
as a sentence when it has a **space between two runs of letters** *or* a word
of three letters or more — «Go to it» by the space, and a key or an id, having
no space, stays out. The definition is `it_reads_as_a_sentence` in
`check_the_one_list.py`, **one test in one place**, and this file imports it
rather than keeping a second opinion about what a sentence is: two gates about
the same list that disagreed on that would be the quietest possible fault.

Measured when it was widened, over the whole tree: **it newly admits nothing.**
Zero literals in `lib` (before any of the shape filters, so this is not «zero
after the exceptions»), and zero of the finder strings below. The hole was real
and had already been paid by hand. The control is in `the_test_itself`, which
reds if the definition is ever narrowed back or widened past the ruling.

**What it still cannot see, named with the list's own example:** a **single**
word shorter than three letters and no space — `roomAi`, «AI», a room's name on
the glass. It cannot be closed by this rule without admitting every two-letter
code (`de`, `en`, `sv`, `ar`), which is what the no-space half is there to keep
out. So it is this gate's named edge, and `docs/CLAIMS.md` C-15 says so where
the claim is made.
"""
import collections
import importlib.util
import json
import pathlib
import re
import sys

TEST = pathlib.Path('apps/flutter_app/test')
L10N = pathlib.Path('apps/flutter_app/lib/l10n')
ONE_LIST = pathlib.Path('scripts/check_the_one_list.py')


def it_reads_as_a_sentence():
    """**The one definition of a sentence, borrowed from the gate that owns it.**

    Loaded by path rather than imported by name, which is how
    `scripts/check_site_claims.py` already reads this same file: these scripts
    are run as `python3 scripts/<name>.py` from the repository root, and a
    plain `import` would depend on which directory the caller happened to be
    in. A missing or broken `check_the_one_list.py` throws here on purpose —
    this gate must not fall back to an opinion of its own about what a
    sentence is.
    """
    spec = importlib.util.spec_from_file_location('one_list', ONE_LIST)
    one = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(one)
    return one.it_reads_as_a_sentence

DRAWN_ELSEWHERE = {
    'English': "the first-run picker labels its rows from the core's language table",
    'Nordstern Consulting GmbH': 'the tests teach this as a value; the list holds it as a form’s example',
    'Lindqvist': 'the tests teach this as a name; the list holds it as a form’s example',
    'Documents': 'a removed screen’s title in a findsNothing; the key is the file chooser’s label',
}

ONE_ENGLISH_TWO_KEYS = {
    'Cancel': 'cancel (a question) and cancelForm (a form) are one English on purpose',
    'Rename': 'rename, renameIt2 and renameHead are one English on purpose',
    'Keep it': 'keepIt and keepItIdentity are one English on purpose',
    'Unlock': 'unlock (opens a vault) and unlockTheVault (submits a passphrase)',
}

FINDER = re.compile(
    r"""find\.(?:text|widgetWithText|textContaining)\("""
    r"""\s*(?:[A-Za-z_][\w.<>]*\s*,\s*)?(['"])(.*?)\1""")


def main() -> int:
    reads_as_a_sentence = it_reads_as_a_sentence()
    en = json.loads((L10N / 'app_en.arb').read_text(encoding='utf-8'))
    owned = {v for k, v in en.items()
             if not k.startswith('@') and isinstance(v, str)}
    typed = prose = 0
    allowed = collections.Counter()
    bad = []
    for path in sorted(TEST.rglob('*.dart')):
        for n, line in enumerate(path.read_text(encoding='utf-8').split('\n'), 1):
            if line.strip().startswith('//'):
                continue
            for m in FINDER.finditer(line):
                s = m.group(2)
                typed += 1
                # **Said with the same test the census uses**, so «what a
                # sentence is» has one answer in both gates. It is a count and
                # not a floor: a finder may type prose the list does not own —
                # a seeded document's own words, a model's answer, a German
                # fixture — and that is not this gate's business. What the
                # number is for is the shape of the debt: nearly every string
                # a finder types is something a person could read, which is
                # why reading the key instead was the whole item.
                if reads_as_a_sentence(s):
                    prose += 1
                if s not in owned:
                    continue
                if s in DRAWN_ELSEWHERE or s in ONE_ENGLISH_TWO_KEYS:
                    allowed[s] += 1
                    continue
                bad.append(f'{path.relative_to(TEST)}:{n} types «{s}», which is a '
                           f'value in the one list — read the key instead')
    for line in bad:
        print(f'G65 {line}')
    if not bad:
        print(f'{typed} finders type a string · {prose} of them type something a '
              f'person could read · {sum(allowed.values())} name a value in the '
              f'list, all {len(allowed)} allowed by name · 0 unexplained')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
