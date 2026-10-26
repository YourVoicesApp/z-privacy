#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Every absolute on the FAQ, and the evidence that covers it.

The owner, 26 October 2026, after reading all 25 answers: «a consistency test
of the promises across the answers». An answer that says **always**, **never**,
**nothing leaves** or anything of that shape is making a claim about *every*
case, and a test that measured one request, one door or one build does not
cover every case. Where the two do not match, the sentence has to be qualified
— and the one thing that must never happen is an absolute arriving in the text
without anybody noticing it is one.

**How it works, and why it is a register rather than a cleverer scan.** The
script finds absolute words mechanically and then refuses any it has not been
told about. Every hit must appear in `REGISTER` with one of two verdicts:

  * **a proof** — the claim (`C-NN`), test or gate that covers the absolute as
    stated, or
  * **`QUALIFIED`** — the sentence carries its own limit in the same breath, so
    the absolute is bounded by the words around it.

Nothing is allowed through for being obviously fine. «No account», «only the
protected version», «every door» each had to be looked at once and written
down, and the cost of that is a line in a table; the thing it buys is that a
**new** absolute cannot enter the file quietly. It also reds when a registered
phrase disappears, so a sentence cannot be softened while this file goes on
claiming it was checked.

It reads `docs/faq-review.md` today and the published FAQ pages when they
exist: the same absolutes have to survive translation, and a translator who
drops a qualifier is exactly the accident this guards against.

**What passing means, and what it does not** — the owner, 27 October 2026,
adopting this as a publishing gate. It is an **editorial** gate. Green means
every absolute on the page has been found and classified, and that no new one
arrived unnoticed. It does **not** mean the evidence named beside each one is
sufficient, and it is not a security certificate: whether `C-11` really covers
the sentence that cites it is the job of the tests and of the engineering
review, and this script cannot and does not ask it. A register that was
mistaken for a proof would be worse than no register, so the distinction is
written here rather than left to be inferred from a green line.

  python3 scripts/check_the_absolutes.py        # the exit status is the verdict
"""
import io
import pathlib
import re
import sys

QUALIFIED = 'QUALIFIED'
# The absolute is not about Z Privacy's behaviour at all — it is about the law,
# about somebody else's product, or about the world — so no test of ours could
# cover it and none is claimed. It still has to be written down, because the
# reason an absolute is safe is exactly the thing a later reader will want.
NOT_OURS = 'NOT_OURS'

# The shapes that claim every case. Deliberately short: this is the owner's
# list — «always», «never», «nothing leaves» and their equivalents — and not
# every strong word in English. A longer list would drown the register and
# teach the next reader to skim it.
ABSOLUTE = re.compile(
    r'\b(always|never|nothing|nobody|no one|none|impossible|cannot|can’t|'
    r'guarantees?|guaranteed|ensures?|entirely|completely|wholly|'
    r'every|everything|all of|any means|any other|no other|only)\b',
    re.I)

# question -> ((phrase as it appears, verdict), ...)
# The phrase is matched case-insensitively and must be a substring of that
# question's answer. One line per absolute, and it is meant to be read.
REGISTER = {
    2: (("the only reliable source is the provider's own current terms", NOT_OURS),),
    3: (("only your machine can reverse it",
         "C-06 — the mapping is the vault, and the written file holds none of "
         "the names it was taught (the_vault_file_says_nothing.rs); and the "
         "next sentence says what this does NOT mean"),),
    4: (("none of them substitutes for another", NOT_OURS),),
    5: (("only where the person can no longer be identified", NOT_OURS),
        ("a standard that takes account of what others might reasonably do, "
         "and not only of what you would do", NOT_OURS),
        ("with every name removed can still be about one identifiable person",
         QUALIFIED)),
    6: (("everything else stays in the text exactly as you approved it",
         "z_core/tests/round_trip.rs:59 asserts the safe payload equals the "
         "original sentence with only the chosen values swapped, character for "
         "character"),),
    9: (("a PDF carries every page", NOT_OURS),),
    10: (("accepted only for a **literal** loopback IP address, never for a "
          "name like \u00ablocalhost\u00bb, so a hosts file cannot be what decides "
          "that plaintext is safe",
          "is_loopback_url in z_core/src/providers/http.rs, measured by "
          "plain_http_is_refused_unless_the_host_is_a_literal_loopback_address"),
         ("it says nothing about what other programs on your computer do",
          QUALIFIED)),
    11: (("nothing leaves while a suggestion is unanswered",
          "C-11 (nothing_leaves_while_a_word_waits.rs); the refusal is one "
          "function that gate G28 reads, asked of every door gate G36 counts "
          "from the source"),),
    12: (("not a proof that no other program or path exists", QUALIFIED),),
    13: (("every token that chat has carried turns back into its name",
          "C-13 — the_chat_remembers.rs, "
          "the_copy_is_the_current_point_and_still_brings_home_a_name_from_the_first_turn"),),
    14: (("the interface cannot open a socket at all, and no Z Privacy address "
          "appears anywhere in it \u2014 so the only address this program is "
          "built to speak to",
          "C-03 — one HTTP client (G1), the interface cannot open a socket "
          "(G5), one reader behind the gateway (G16), and no Z Privacy address "
          "in the tree. Shape checks over the source, which is what \u00abis "
          "built to\u00bb says; C-04 stays unproven for the running case"),
         ("a settings file that never holds your work",
          "z_core/tests/zcfg_leak.rs searches the one unencrypted file for the "
          "names it was taught"),
         ("nothing is written to the system's temporary directory",
          QUALIFIED)),
    15: (("a passphrase that never leaves the machine",
          "C-06 and gate G8 — no function in the whole contract returns a key "
          "or a passphrase"),
         ("finds none", "z_core/tests/the_vault_file_says_nothing.rs"),
         ("only as strong as the passphrase you choose", QUALIFIED),
         ("refuses to write if it cannot be",
          "z_core/src/secure_file.rs and its own tests")),
    16: (("The vault cannot be opened", "C-06 and gate G8"),
         ("and nothing on our side could recover the vault without the "
          "passphrase",
          "C-06 — the passphrase is never stored; gate G8"),
         ("Nobody holds a copy of this", "the shipped sentence, key "
          "thereIsNoWayBack; the claim behind it is C-06"),
         ("the passphrase never leaves this device", "C-06, gate G8"),
         # The same absolute twice: once in our words and once inside the
         # shipped sentence the answer quotes. Both are registered, because
         # a quotation is still a thing this page says.
         ("and nothing on our side could recover the vault without it",
          "the shipped sentence, key thereIsNoWayBack; C-06 and gate G8")),
    17: (("Every connection is made at an address you can change",
          "C-17 — the_bundle_of_six.rs; every base address comes from the "
          "person's own login"),),
    18: (("who agreed to nothing with your provider", NOT_OURS),),
    19: (("every value you have taught it is matched wherever it appears",
          QUALIFIED),
         ("All of that depends on two things upstream of any rule", QUALIFIED),
         ("nothing leaves while a suggestion is unanswered",
          "C-11; gate G28 asks it of every door gate G36 finds"),
         ("is asked of every door that takes text out of the app",
          "gate G36 counts the doors from what the functions do, not from a "
          "list — which is why the count has moved twice")),
    21: (("nothing to subscribe to",
          "an absence, stated as one: no price, no billing code and no "
          "purchase path anywhere in the tree"),
         ("on your own computer costs nothing at all",
          "C-17 — a local model reports connected with no credential "
          "(truthfulness_regressions.rs::lie_a_keyless_login_claims_a_key)")),
    22: (("ask nobody", NOT_OURS),),
    23: (("lists every claim with the same four lines each",
          "gate G56 refuses a section missing one of its four lines"),
         ("the interface cannot open a socket",
          "gate G5 — and this very sentence is explaining what a shape check "
          "is, so the reader is told its kind as they read it"),
         ("that every door obeys a law", "gates G28 and G36")),
    24: (("nothing has signed this installer",
          "site/en/download/index.html, data-fact=windows-will-warn-you; the "
          "Windows job deletes an unsigned package rather than hand it over "
          "(C-14), and the installer carries no signature by construction"),
         ("it says nothing about who published the file", QUALIFIED)),
    25: (("nothing is collected on this site",
          "scripts/check_site.sh refuses a handler, a cookie, a counter or any "
          "script but a declared data block, and there is no form on any page"),),
}


def answers(path):
    """Each question's proposed answer text, by number."""
    text = io.open(path, encoding='utf-8').read()
    out = {}
    for m in re.finditer(r'^## Q(\d+) · .*?\n\n\*\*Answer\.\*\* (.*?)\n',
                         text, re.S | re.M):
        out[int(m.group(1))] = m.group(2)
    return out


def main():
    src = pathlib.Path('docs/faq-review.md')
    if not src.exists():
        print('  FAIL   %s is not here, so no absolute could be checked' % src)
        return 1
    found = answers(src)
    if not found:
        print('  FAIL   %s holds no answers in the shape this reads' % src)
        return 1

    bad = 0
    seen = {}
    for n in sorted(found):
        body = found[n]
        hits = []
        for m in ABSOLUTE.finditer(body):
            start = max(0, m.start() - 55)
            end = min(len(body), m.end() + 55)
            hits.append((m.group(0), body[start:end].replace('\n', ' '), m.start()))
        registered = REGISTER.get(n, ())
        # **A hit is bound to the entry whose phrase covers it, by position.**
        # The first version asked whether the phrase was anywhere in the answer
        # and held the same word, which let one entry answer for two different
        # absolutes — Q21's «nothing to subscribe to» swallowed «costs nothing
        # at all», and the second was then reported as having vanished. A
        # register that can be satisfied by the wrong line is not a register.
        spans = []
        for phrase, why in registered:
            at = body.lower().find(phrase.lower())
            if at >= 0:
                spans.append((at, at + len(phrase), phrase, why))
        for word, context, at in hits:
            verdict = None
            for lo, hi, phrase, why in spans:
                if lo <= at and at + len(word) <= hi:
                    verdict = (phrase, why)
                    break
            if verdict is None:
                print('  FAIL   Q%-2d «%s» is an absolute nothing in the register '
                      'covers — …%s…' % (n, word, context))
                bad = 1
            else:
                seen[(n, verdict[0])] = True
                mark = 'qualified in the sentence' if verdict[1] == QUALIFIED else verdict[1]
                print('  PASS   Q%-2d «%s» — %s' % (n, word, mark))

    for n, entries in sorted(REGISTER.items()):
        for phrase, _ in entries:
            if (n, phrase) not in seen:
                print('  FAIL   Q%-2d the register still claims «%s» was checked, '
                      'and no such absolute is in that answer any more' % (n, phrase))
                bad = 1

    total = sum(len(v) for v in REGISTER.values())
    print()
    print('%d absolutes registered across %d answers' % (total, len(REGISTER)))
    print('AN ABSOLUTE ON THE PAGE HAS NO EVIDENCE BEHIND IT' if bad
          else 'every absolute on the page is covered or qualified')
    return bad


if __name__ == '__main__':
    sys.exit(main())
