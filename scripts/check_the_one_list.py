#!/usr/bin/env python3
"""**The sentences in one list** — 092's two gates, G50 and G51.

The owner, 18 October 2026: «نحتاج الآن أن نعقد قوائم الجمل قائمة باللغة
الإنكليزية، ثم نقوم بنسخها إلى اللغات الأخرى، ثم نقوم بتفعيل الترجمة داخل
التطبيق». The list is `apps/flutter_app/lib/l10n/app_en.arb` and its copies.

## G50 — no user-facing sentence outside the list, and a floor for what is owed

A migrated file has **none**. A file that has not been migrated yet is named
below with the number of sentences it still holds, and the gate refuses a count
that **rises**: the list is the debt in writing, and the next branch empties it.
That is the shape G41's own allowed list has, and the reason is the same — a
gate that forbids everything on the day the work starts is a gate somebody
turns off.

The named exceptions inside a migrated file, each with its reason:

  * **`\\u2068` and `\\u2069`** — the isolate marks `theirOwnWord` puts around a
    person's own word. Not a sentence: two code points of grammar, and ICU has
    no placeholder for them.
  * **keys, ids and codes** — `'workspace-question'`, `'de'`, `'fake'`: a test
    reaches by them and no person reads them.
  * **token grammar** — `'__Z_'` and what tests it: the shape of a token is a
    fact about the format, not a sentence.
  * **the core's own English** — a `detail` the core wrote and the glass quotes
    (`_sentence`, `_lower`): it is the core's sentence, and 092 does not move
    the core's own language into the app's list.
  * **product names** — `'Z Privacy'`, `'z-pdf'`: the same in every language,
    and the paper says so.

## G51 — the copies carry every key, and the German is German

Every key in the English file is in the German and the Swedish. A German value
identical to the English is a key nobody translated — refused, except for the
named list below (product names, «OK», bare numbers). The **Swedish** is
allowed to be identical, and that is 56-أ: the file exists so this gate can
count it, and the first screen does not offer Svenska until the values differ.
"""
import json
import pathlib
import re
import sys

LIB = pathlib.Path('apps/flutter_app/lib')
L10N = LIB / 'l10n'

# **The migrated files**: these must hold no sentence of their own.
#
# `going_to_a_word.dart` is in the list and was never migrated: it holds no
# sentence of its own at all, and a file at zero belongs where zero is the law
# rather than in a debt list that would let one be added.
MIGRATED = {
    'core/going_to_a_word.dart',
    'core/messages.dart',
    'screens/first_run.dart',
    'screens/settings.dart',
    'screens/vault.dart',
    'screens/workspace.dart',
    'widgets/entity_detail.dart',
    'widgets/name_review.dart',
    'widgets/send_sheet.dart',
    'widgets/the_chat.dart',
    'widgets/vault_forms.dart',
    'widgets/why_sheet.dart',
}

# **The debt, file by file, as it stands.** Each number is what that file still
# holds; the gate refuses a rise. The owner's own order was the first screen,
# the work surface's three parts and the chat — those are done, and the numbers
# below were measured again against the tree rather than left as the floors
# they were: a floor that is looser than the truth is a gate that would let a
# sentence be added back.
#
# 854 sentences stood in 27 files when this round began; 180 stand in 16 now.
#
# **Five of the 185 were never sentences**, and finding that out was the
# first act of sitting five rather than a tidy-up: the literal *pattern*
# mis-paired quotes, so four fragments in `protected_pdf.dart` and one in
# `document_text.dart` were counted as sentences a translator owed, while the
# real sentences they were cut out of were counted as their own fragments.
# `strings_on` replaced the pattern and the numbers below are its
# measurement. No migrated file gained a sentence by the change, which is
# the result that had to be checked: a mis-pairing can hide a real sentence
# as easily as invent one, and a file claimed empty is where that would have
# mattered.
#
# **Sitting five, the two items.** The first is the rest of this table: the
# eleven small files, `core/session_state.dart`'s 29, and
# `core/protected_pdf.dart`'s 13 — those last drawn with the **session's**
# locale and never the interface's, because a z-pdf footer is a file that
# leaves (rule 33) and what a file holds is not what the person at the screen
# reads.
#
# The second is **«a guard may not type a sentence this list owns»**, measured
# on 20 October 2026 over `apps/flutter_app/test`:
#
#     458 finders reach for a typed sentence
#     284 of them name a value that now lives in lib/l10n/app_en.arb
#         — by its exact text, or by the shape of a placeholder sentence
#           («Page 2» for `pageNumber`)
#
# They are correct while the suite reads English, and they are second copies of
# sentences whose home is this list: a reworded value turns a guard red for the
# wrong reason, and where the assertion is `findsNothing` it leaves the guard
# **green** for the wrong reason, which is the half that teaches nothing until
# something has already shipped. The form that does not rot is
# `find.text(sentences.theKey)` — the guard reading the one place instead of
# remembering it.
#
# Found by the gutter guard, which typed «Protect this column in the 4 held
# lines» and could not find it: `docs/A_FILE_THAT_REDS_ONLY_IN_COMPANY.md`
# holds that measurement. Not before 096's glass half, by the lead's order.
#
# **Two more items, three and four, added 21 October after 096 stood.** Neither
# is about this list; they are here because this is where the sitting is
# counted, and an item nobody numbered is an item nobody does.
#
#   three — «a source that changed is measured by the one command». The lesson
#           of 096's own regression: the first part moved from `doc.marks` to
#           `entered.marks`, every `MarkState::Suggested` fell off the screen,
#           and five guards reddened in three files that were never opened. The
#           measurement, the A/B that named its owner and the order to follow
#           next time are written in `A_FILE_THAT_REDS_ONLY_IN_COMPANY.md`.
#   four  — «the Dart record stays on green too». `gates.sh` deleted its log
#           and its event file the moment the suite passed, so the count a
#           green round reports — the one `MEASURED_ON_LINUX.txt` is compared
#           against — could not be re-examined afterwards. One fixed place per
#           worktree, named in the PASS line, with `G7-record` asking that the
#           file is really there.
#
# Both are done; they are written down here because the sitting is the ledger.
OWED = {
    'core/protected_pdf.dart': 9,
    'core/session_state.dart': 29,
    'core/the_clipboard.dart': 1,
    'screens/shell.dart': 3,
    'widgets/acts.dart': 28,
    'widgets/bits.dart': 12,
    'widgets/connect_form.dart': 22,
    'widgets/conversation_view.dart': 10,
    'widgets/document_text.dart': 1,
    'widgets/find_in_document.dart': 14,
    'widgets/language_list.dart': 6,
    'widgets/line_gutter.dart': 2,
    'widgets/reveal.dart': 2,
    'widgets/review.dart': 23,
    'widgets/the_way_back.dart': 3,
    'widgets/tokens.dart': 15,
}

# **Values the German is allowed to share with the English, by name** — each
# with its reason, because «the translator skipped it» and «German says the
# same» are the same bytes and only one of them is honest.
#
#   * `OK`, the product names, a bare number, a dash or a middle dot — nothing
#     to translate.
#   * **`Person`** — German spells it the same, capital and all. It is the one
#     kind word of the five that does not move.
#   * **`Passphrase`** — the loan word German uses for it; «Kennwort» is a
#     password, and this is deliberately not one.
#   * **`Name`** — the same word, same case.
#   * **`Nordstern Consulting GmbH`** — a greyed example *of a name*, and a
#     name does not translate (the lead's ruling, 19 October).
#   * **`Mandantenkennung`** — a greyed example of a real German field name. It
#     stands in the **English** screen *because* it is German: that is what it
#     demonstrates, and an English example would stop demonstrating it.
#   * **`Herr Müller`** and **`Lindqvist`** — greyed examples of a spelling and
#     of a surname. Names, and a name does not translate.
#   * **`{act} · {needs}`** — not a sentence at all: a frame that joins two
#     keys on one button («Add a name · Needs a vault»), and both halves are
#     their own keys with their own German.
SAME_IN_EVERY_LANGUAGE = re.compile(
    r'^(?:OK|Z Privacy|z-pdf|Grok|xAI|Person|Passphrase|Name'
    r'|Nordstern Consulting GmbH|Mandantenkennung|Herr Müller|Lindqvist'
    r'|\{act\} · \{needs\}|\d+|[-—·]|)$'
)

# **Both of Dart's quotes**, and the honest account of why.
#
# This read only `'…'` until 19 October, and fourteen double-quoted literals
# with words in them were found outside it — «One place is», «value stands»,
# «Local AI», the ` and ` that joins two names. It looked like fourteen
# sentences the gate had never seen. **It was not**: every one of them sits
# *inside* an interpolation of a single-quoted string
# (`'${n == 1 ? "value stands" : "values stand"}'`), so each was already
# counted as part of that sentence, and the measurement said so — the totals
# before and after this change are the same 559 in 22 files, to the digit.
#
# The alternative is kept anyway, because the gap it closes is real even
# though nothing has fallen into it: the day somebody writes `Text("Hello")`
# this sees it. A census that matches a quoting style is not a census of
# sentences, which was the right thought about the wrong evidence.
def strings_on(line: str) -> list[str]:
    """Every Dart string literal on one line, interpolations blanked.

    **Why this is a scanner and not a pattern.** It was
    `'((?:[^'\\\n]|\\.){3,})'`, and a regex cannot pair quotes it is not
    allowed to see. Two kinds of literal were invisible to it, and both donated
    their closing quote to whatever came next:

      * **a literal shorter than three characters.** `padLeft(2, '0')` — the
        `'0'` never matched, so the quote that closes it opened a match that ran
        to the next quote on the line. `'${d.year.toString().padLeft(4, '`
        was counted as a sentence owed by `protected_pdf.dart`, and
        `' || text[k] == '` as one owed by `document_text.dart`, out of
        `text[k] == '\n' || text[k] == '\r'`. The `{3,}` was never a rule about
        sentences anyway — the `[A-Za-z]{3,}` test below is — it only stopped
        the pairing from working.
      * **a literal inside an interpolation.** `'… ${turn.unresolved.join(', ')}.'`
        is one sentence holding one expression; the pattern saw a string ending
        at `join(`.

    So the three fragments were counted as three sentences a translator owed,
    and the real sentences around them were counted as their own fragments. A
    census that mis-pairs quotes measures its own punctuation — the fault this
    house already wrote down once, over a door census that stopped seeing a
    door when one statement became two.

    `${…}` becomes the marker `${}`: an expression is code, and the filters
    below already strip it to ask whether any words are left. A `$name` without
    braces is kept as it stands, because the exceptions that read a filename
    (`'$into/$stem.pdf'`) are written against that spelling.
    """
    out: list[str] = []
    i, n = 0, len(line)
    while i < n:
        c = line[i]
        # A raw string takes no escapes and no interpolation.
        if c == 'r' and i + 1 < n and line[i + 1] in "'\"":
            q, j = line[i + 1], i + 2
            while j < n and line[j] != q:
                j += 1
            out.append(line[i + 2:j])
            i = j + 1
            continue
        if c not in "'\"":
            i += 1
            continue
        q, j, buf = c, i + 1, []
        while j < n:
            d = line[j]
            if d == '\\':                      # an escape, two characters
                buf.append(line[j:j + 2])
                j += 2
                continue
            if d == q:
                break
            if d == '$' and j + 1 < n and line[j + 1] == '{':
                depth, k = 1, j + 2
                while k < n and depth:
                    e = line[k]
                    if e == '{':
                        depth += 1
                    elif e == '}':
                        depth -= 1
                    elif e in "'\"":          # a literal inside the expression
                        qq, k = e, k + 1
                        while k < n and line[k] != qq:
                            k += 2 if line[k] == '\\' else 1
                    k += 1
                buf.append('${}')
                j = k
                continue
            buf.append(d)
            j += 1
        out.append(''.join(buf))
        i = j + 1
    return out

# **Product names.** The same in every language, and the paper says so: a list
# that held «Z Privacy» in three files would be three chances to rename the
# product in two of them. Matched whole, never as a part — «Z Privacy keeps
# nothing» is a sentence.
PRODUCT_NAMES = {'Z Privacy', 'z-pdf', 'YourVoices', 'Grok', 'xAI', 'Ollama'}

# Phrases the glass looks for **inside a sentence the core wrote**. Each is a
# match and never a thing drawn — see the exception that reads this.
READ_FROM_THE_CORE = {
    # `why_sheet.dart`: a taught *rule* carries no entity and no value, so the
    # sheet asks the core's headline whether the person taught it.
    'taught Z Privacy this rule',
}

# What a file holds, by shape: a MIME type, anything that ends in an
# extension, and a comma-separated row of lowercase field names.
A_FILES_OWN_WORDS = (
    re.compile(r'[a-z]+/[a-z0-9.+-]+'),                    # text/csv
    # **No white space**, because a name is one word. This was `.*\.[a-z]{2,4}`
    # for an afternoon, and `.*` crosses spaces: every one of «Saved to
    # Downloads/report.pdf», «Gespeichert als bericht.pdf» and «The list was
    # written to names.csv» was exempt under it, measured. The first of those
    # is this app's own `savedToWhere`, so the hole was one sentence wide and
    # that sentence exists. An exception that can swallow a sentence is the
    # same fault as a gate that reads a sentence's English, which is the fault
    # this round is about. The four it is here for hold no space: two asset
    # paths, the built `$stem.pdf`, and `${list.name}.csv`.
    re.compile(r'\S*\.[a-z]{2,4}'),                        # «…».csv
    re.compile(r'[a-z_]+(?:,[a-z_]*)+\\n?'),                # name,type,source,licence
)

# An `intl` date pattern: only pattern letters, spaces and date punctuation.
DATE_PATTERN = re.compile(r'[yMdEHhmsaz., /:-]+')


def sentences_in(path: pathlib.Path) -> list[str]:
    """Every literal in one file that a person could read.

    Comment lines are dropped first: the prose in this house's doc comments is
    longer than its sentences, and it is not on anybody's screen.
    """
    out = []
    for line in path.read_text(encoding='utf-8').split('\n'):
        stripped = line.strip()
        # Both kinds of comment: this house's doc comments hold more prose than
        # its screens do, and none of it is on anybody's glass.
        if stripped.startswith('//'):
            continue
        for v in strings_on(line):
            if not re.search(r'[A-Za-z]{3,}', v):
                continue
            # An import URI is not a sentence: `package:…`, `dart:async`, and
            # any path that ends in a Dart file.
            if v.startswith(('package:', 'dart:')) or v.endswith('.dart'):
                continue
            if re.fullmatch(r'[a-z0-9_\-]+', v):      # keys, ids, codes
                continue
            if v.startswith('__Z_') or v == '__Z_':   # token grammar
                continue
            if v.strip() in PRODUCT_NAMES:            # product names
                continue
            # **A date pattern is not a sentence.** `'d MMM y'` is what `intl`
            # is asked for, and the words it puts in it come from the locale's
            # own table — so the pattern is the shape and the sentence is
            # `intl`'s. Twelve month names used to be written out here instead.
            if DATE_PATTERN.fullmatch(v):
                continue
            # **The core's own English, matched and not shown.** The glass asks
            # whether a sentence the *core* wrote contains a phrase — it draws
            # nothing, so there is nothing to translate, and translating it
            # would break the match. Listed one by one, because each is a seam
            # worth seeing: a `.contains` over a core sentence fails silently
            # the day the core rewords it, and that is a debt of its own.
            if v in READ_FROM_THE_CORE:
                continue
            # **What a file holds is not what a person reads.** A CSV header
            # row, a MIME type, a name built from an extension: translating any
            # of them would write a file this app cannot read back. The same
            # decision as `name_review.dart`'s `_kindIdForAFile`, which exists
            # because the export wrote the *glass's* word into the `type`
            # column — «Vorname» the day the glass spoke German.
            if any(r.fullmatch(v) for r in A_FILES_OWN_WORDS):
                continue
            if '\\u2068' in v or '\\u2069' in v:      # the isolate marks
                continue
            # **A frame is not a sentence.** `«${theirOwnWord(c.name)}»` holds
            # no word of its own: take the interpolations out and nothing with
            # three letters is left. The guillemets and the isolate marks are
            # grammar around a person's own word, which is `theirOwnWord`'s
            # whole job, and ICU has no placeholder for either.
            bare = re.sub(r'\$\{[^}]*\}|\$[A-Za-z_][A-Za-z_0-9]*', '', v)
            if not re.search(r'[A-Za-z]{3,}', bare):
                continue
            # **A key that counts is still a key.** `'the-chat-bubble-$at'` is
            # how a test reaches the third bubble; the number in it does not
            # make it a sentence, so the same shape as the line above is asked
            # of what is left when the interpolations are taken out.
            if re.fullmatch(r'[a-z0-9_\-]*', bare):
                continue
            # **Not a fragment of Dart.** A line with two literals on it hands
            # the quote-pairing above whatever lies between them — `') ? lowered
            # : '` from a ternary. A sentence does not begin with a closing
            # bracket nor end in a bare `?` or `:`.
            if v.lstrip().startswith((')', '(', ',')):
                continue
            if v.rstrip().endswith((' ?', ' :')):
                continue
            out.append(v)
    return out


def g49() -> list[str]:
    bad = []
    for path in sorted(LIB.rglob('*.dart')):
        rel = str(path.relative_to(LIB))
        # The generated list itself, and the generated bridge: neither is
        # written by hand and neither is a place a sentence is decided.
        if rel.startswith('l10n/') or rel.startswith('src/'):
            continue
        if rel == 'main.dart':
            continue
        found = len(sentences_in(path))
        if rel in MIGRATED:
            if found:
                bad.append(f'{rel} is migrated and still holds {found} sentence(s)')
            continue
        floor = OWED.get(rel)
        if floor is None:
            if found:
                bad.append(f'{rel} holds {found} sentence(s) and is in no list — '
                           f'migrate it, or write it as owed')
            continue
        if found > floor:
            bad.append(f'{rel} holds {found} sentence(s), and the list says {floor} '
                       f'— a sentence was added outside the one list')
    return bad


def g50() -> list[str]:
    bad = []
    en = json.loads((L10N / 'app_en.arb').read_text(encoding='utf-8'))
    de = json.loads((L10N / 'app_de.arb').read_text(encoding='utf-8'))
    sv = json.loads((L10N / 'app_sv.arb').read_text(encoding='utf-8'))
    keys = [k for k in en if not k.startswith('@')]
    for k in keys:
        if k not in de:
            bad.append(f'«{k}» is in the English list and not in the German')
        if k not in sv:
            bad.append(f'«{k}» is in the English list and not in the Swedish')
    for k in keys:
        if k in de and de[k] == en[k] and not SAME_IN_EVERY_LANGUAGE.match(en[k]):
            bad.append(f'«{k}» is the English sentence in the German file — '
                       f'nobody translated it')
    for extra in [k for k in de if not k.startswith('@') and k not in en]:
        bad.append(f'«{extra}» is in the German file and in no English key')
    return bad


def main() -> int:
    nine, fifty = g49(), g50()
    for line in nine:
        print(f'G50 {line}')
    for line in fifty:
        print(f'G51 {line}')
    if not nine and not fifty:
        keys = [k for k in json.loads((L10N / 'app_en.arb').read_text(encoding='utf-8'))
                if not k.startswith('@')]
        owed = sum(OWED.values())
        print(f'{len(keys)} sentences in the one list · {len(MIGRATED)} file(s) '
              f'migrated · {owed} sentences owed in {len(OWED)} files')
    return 1 if (nine or fifty) else 0


if __name__ == '__main__':
    sys.exit(main())
