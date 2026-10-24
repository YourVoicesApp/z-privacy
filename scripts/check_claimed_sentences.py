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
    # **Named by C-15 as the one sentence its own census cannot see**, which
    # is why it is pinned: the claim's example is the value itself, and a
    # reword — «AI room», «Models» — would leave the claim naming a shape that
    # is no longer the shape it is about.
    'roomAi': (
        'C-15',
        'AI',
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
        'What has already left this session protected can never be unprotected again — not by you, and not by Z Privacy. The key was the only thing that could have done it, and it will not exist. «Undo protection» takes a cover off the text in front of you, never off what has gone.',
    ),
    # **The door the outside review of 23 October 2026 answered C-05 with**, and
    # the reason that claim now has a boundary: this button exists, it takes a
    # cover back inside the request, and a sentence that said «never, not by
    # you» was false while it is drawn. Pinned by its own name, because C-05's
    # boundary quotes it: rename the button and the claim quotes a control
    # nobody can find.
    'undoProtection': (
        'C-05',
        'Undo protection',
    ),
    # **The sentence that said «A vault is the only file this app writes»** —
    # the second verdict of that review, false beside `sessions/*.zs` and
    # `settings.zcfg`. It says what the vault is now, and it is pinned so that
    # the shorter, false shape cannot come back as a tidy-up.
    'yourNamesLiveInOneVaultFile': (
        'C-06',
        'Your names live in one encrypted vault file. It holds your people and their values, encrypted with a passphrase that never leaves this device. Without one, nothing is recognised by name.',
    ),
    'onePassphrase': (
        'C-06',
        'One passphrase, kept on this device. Everything Z learns while you work — your names, your lists, your decisions — is kept in it.',
    ),
    'troubleVaultChangedElsewhere': (
        'C-07',
        'Another copy of Z Privacy changed this vault. Close that window, or lock and unlock here to take in its work.',
    ),
    # **111, the owner's own Windows test of 24 October 2026.** The sentence
    # kept what it says about tokens and lost what it let a reader expect: he
    # stood in Session 1, read a z-pdf saved from another session, and twenty
    # names came back. The last clause is the one that says where the wall is,
    # and it is pinned so that a tidy-up cannot drop it again.
    'eachSessionHasItsOwnEncryption': (
        'C-09',
        'Each session has its own encryption. The same name in two sessions takes two different tokens, and in one session it takes the same one wherever it appears — so a session is how you choose what an AI can line up and what it cannot. The keys are all in your vault, so reading a protected file back is the vault’s own door and not a session’s: anything saved from any session in this vault comes back in its real names, and the reading says which session they came from.',
    ),
    'languageAndRulesWhat': (
        'C-11',
        'A privacy pack is a detection engine, not the language of the interface — and more than one pack can run in a single scan, so this is a starting point rather than the only rules allowed.',
    ),
    'answerEverySuggestionWhat': (
        'C-11',
        'Not a setting. A suggestion that has not been answered is never quietly treated as safe, and there is no «send anyway» — not here, not in a hidden flag, not anywhere in the code.',
    ),
    # **110, the owner's rulings of 24 October 2026.** Not «the chat»: both
    # doors send one payload — the question as it would leave, protected — and
    # the in-app door adds the exchange before it on top. A sentence that still
    # said «the chat» would promise the whole conversation at the one door that
    # hands over the payload.
    'theChatIsOnYourClipboard': (
        'C-13',
        'What would leave is on your clipboard, protected — the question as an AI would receive it. Bring the answer back with «Add an answer».',
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
