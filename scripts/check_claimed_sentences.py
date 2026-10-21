#!/usr/bin/env python3
"""**A sentence a claim leans on may not be reworded quietly** — 092, sitting
five, item 2-ب.

Item 2 turned 347 finders from a typed sentence into `sentences.theKey`, and
said out loud what that cost: a guard reading the key cannot notice a
**reworded** value. Before it, «Protect» → «Delete» reddened ten guards; after
it, nothing in the suite moves. `the_sentences_are_in_one_list_test.dart`
measures the list's **shape** — every key in every language, the German saying
something else, no invisible character in it — and nothing measured its
**meaning**.

This is the smaller counter-measure rather than 333 typed sentences: the few
sentences a claim in `docs/CLAIMS.md` actually depends on, pinned by their exact
English with the claim named beside each. A reword that touches a claim reddens
here and says which claim it touches; a reword anywhere else does not, which is
the whole point — the noise item 2 removed does not come back.

## What reddens

  * **a pinned sentence whose English moved.** The claim is named, because the
    question is never «who changed this string» but «is C-05 still true».
  * **a claim that leans on a sentence nobody pinned.** The pairs are read out
    of `docs/CLAIMS.md` itself — every backticked identifier that is a key in
    the one list — so a claim that starts naming a new key brings it in here or
    reddens. A pin nobody can forget to add.
  * **a pin no claim names any more**, which is a pin that has stopped
    measuring anything, and a pinned key that has left the list altogether.

Fixing a red is two deliberate edits: the value, and the copy here. That is the
cost, and it is the reason the table is small.
"""
import json
import pathlib
import re
import sys

L10N = pathlib.Path('apps/flutter_app/lib/l10n/app_en.arb')
CLAIMS = pathlib.Path('docs/CLAIMS.md')

# key -> (the claim that leans on it, its English at the commit this was written)
PINNED: dict[str, tuple[str, str]] = {
    'onlyTheProtectedVersionIsSent': (
        'C-01',
        'Only the protected version is sent to AI through Z Privacy.',
    ),
    'originalDataStaysHere': (
        'C-02',
        'Your original data stays on this device unless you explicitly copy restored content.',
    ),
    'copyRestoredTextQuestion': (
        'C-02',
        'Copy restored text?',
    ),
    'thisWillPlaceTheRealValues': (
        'C-02',
        'This will place the real protected values on your system clipboard. Other applications may be able to read the clipboard.',
    ),
    'noAccount': (
        'C-03',
        'No account.',
    ),
    'noAnalytics': (
        'C-03',
        'No analytics.',
    ),
    'aiWhat': (
        'C-03',
        'Three ways to ask a model. The first needs no account at all.',
    ),
    'everyDocumentCanNeverBeUnprotected': (
        'C-05',
        'Every document and every message protected in it can never be unprotected again — not by you, and not by Z Privacy. The key was the only thing that could have done it, and it will not exist.',
    ),
    'onePassphrase': (
        'C-06',
        'One passphrase, kept on this device. Everything Z learns while you work — your names, your lists, your decisions — is kept in it.',
    ),
    'troubleVaultChangedElsewhere': (
        'C-07',
        'Another copy of Z Privacy changed this vault. Close that window, or lock and unlock here to take in its work.',
    ),
    'eachSessionHasItsOwnEncryption': (
        'C-09',
        'Each session has its own encryption. The same name in two sessions takes two different tokens, and in one session it takes the same one wherever it appears — so a session is how you choose what an AI can line up and what it cannot.',
    ),
    'languageAndRulesWhat': (
        'C-11',
        'A privacy pack is a detection engine, not the language of the interface — and more than one pack can run in a single scan, so this is a starting point rather than the only rules allowed.',
    ),
    'answerEverySuggestionWhat': (
        'C-11',
        'Not a setting. A suggestion that has not been answered is never quietly treated as safe, and there is no «send anyway» — not here, not in a hidden flag, not anywhere in the code.',
    ),
    'theChatIsOnYourClipboard': (
        'C-13',
        'The chat is on your clipboard, protected — bring the answer back with «Add an answer».',
    ),
}


def claims_and_their_keys(text: str, in_the_list: set[str]) -> dict[str, str]:
    """Every key a claim names, by the claim that names it — read from the file."""
    out: dict[str, str] = {}
    claim = None
    for line in text.split('\n'):
        head = re.match(r'^##+ (C-\d+)', line)
        if head:
            claim = head.group(1)
        for ident in re.findall(r'`([A-Za-z_][\w.]*)`', line):
            if ident in in_the_list and ident not in out:
                out[ident] = claim
    return out


def main() -> int:
    en = json.loads(L10N.read_text(encoding='utf-8'))
    vals = {k: v for k, v in en.items()
            if not k.startswith('@') and isinstance(v, str)}
    named = claims_and_their_keys(CLAIMS.read_text(encoding='utf-8'), set(vals))

    bad = []
    for key, (claim, english) in PINNED.items():
        if key not in vals:
            bad.append(f'«{key}» is pinned for {claim} and is no longer in the one list')
            continue
        if vals[key] != english:
            bad.append(
                f'«{key}» was reworded, and {claim} leans on it:\n'
                f'          pinned: {english}\n'
                f'          now:    {vals[key]}')
        if key not in named:
            bad.append(f'«{key}» is pinned for {claim}, and no claim names it any '
                       f'more — the pin measures nothing')
    for key, claim in named.items():
        if key not in PINNED:
            bad.append(f'{claim} leans on «{key}», which nobody pinned — add it with '
                       f'its English, or the claim can be reworded out from under')

    for line in bad:
        print(f'G66 {line}')
    if not bad:
        print(f'{len(PINNED)} sentences carry a claim, pinned by their English '
              f'across {len(set(c for c, _ in PINNED.values()))} claims')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
