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

## G51 — the copies carry every key, and each one speaks its own language

Every key in the English file is in the German, the Swedish and the Arabic, and
a value identical to the English is a key nobody translated — refused in **all
three** files, except for the named list below (product names, «OK», bare
numbers, and the few words a language really does spell the English way).

**And the Arabic adds no list of its own** — paper 115, 25 October 2026. The
Swedish needed four names beside the common list, because Swedish spells four of
the house's words the English way. Arabic shares no word with English at all, so
the six values it keeps in Latin letters — the two greyed examples of a German
field and a German spelling, the two surnames, the frame that joins two keys and
the answer page's own top line — are **already** in
[SAME_IN_EVERY_LANGUAGE]: every one of them is a name or a product's own
spelling, which is what that list is for. Measured, not assumed: the six were
read off the written file.

The Swedish was allowed to be the English until 23 October 2026, which was
56-أ: the file existed so this gate could count it. Paper 106 wrote the
Swedish words on the owner's word, so the exception is gone and the rule is
the same for both languages. What is **not** closed by that paper is the
owner's own reading of them: he is the only native reviewer and his review is
a round of its own, so nothing here or on the site says Swedish is reviewed —
this gate measures that the words exist and are not the English, which is a
statement about shape and not about quality.
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
    'core/protected_pdf.dart',
    'core/session_state.dart',
    'core/the_clipboard.dart',
    # Holds no sentence of its own and never will: it hands the machine an
    # address and nothing a person reads. In the list for the same reason
    # `going_to_a_word.dart` is — a file at zero belongs where zero is the law,
    # not in a debt table that would let one be added.
    'core/the_system_browser.dart',
    # One constant and its reason — the mailbox a person writes to (paper 108
    # item 5). An address is not a sentence, and this file holds nothing else,
    # so zero is its law from the day it was written.
    'core/the_address_to_write_to.dart',
    'screens/first_run.dart',
    'screens/settings.dart',
    'screens/shell.dart',
    'screens/vault.dart',
    'screens/workspace.dart',
    'widgets/acts.dart',
    'widgets/bits.dart',
    'widgets/connect_form.dart',
    'widgets/conversation_view.dart',
    'widgets/document_text.dart',
    'widgets/entity_detail.dart',
    'widgets/find_in_document.dart',
    'widgets/language_list.dart',
    'widgets/line_gutter.dart',
    'widgets/the_name_for_the_file.dart',
    'widgets/name_review.dart',
    'widgets/reveal.dart',
    'widgets/review.dart',
    'widgets/send_sheet.dart',
    'widgets/the_chat.dart',
    'widgets/the_way_back.dart',
    'widgets/tokens.dart',
    'widgets/vault_forms.dart',
    'widgets/why_sheet.dart',
}

# **The debt is empty, and it was emptied by a word rather than by work** —
# 21 October 2026, the owner, law 80 in `docs/RULES_AR.md`.
#
# 854 sentences stood in 27 files when this round began. The table below held
# the five that were left when sitting five's work was done, and both entries
# said «waiting on a word» rather than «waiting on a hand»:
#
#   * `core/protected_pdf.dart`'s **4** all go *into the file* — the footer's
#     one line, the `z-pdf · protected copy` mark, and the answer page's top
#     line. Rule 33 and the note at `theSentencesAreNow`'s second reader said
#     those are read in the **session's** language and never through the
#     holder, and the question nobody but the owner could answer was which
#     language a file carries when its session has none.
#   * `widgets/document_text.dart`'s **1** was `'Page ${edges[i].page}'`, the
#     page marker in the Original column — one line in a file that is not
#     opened without his word.
#
# **His answer, both halves of it:** the footer, the mark and the added page's
# title are in the language of the session the file left, and English where
# that session has none; the added page may carry any *fact* about the file and
# never a real value, and no new fact was added — only the language. And «Page
# N» joins the list under the key `pageNumber` it already had.
#
# So the table is empty. What that is worth saying out loud: a floor of zero in
# `MIGRATED` is a stronger statement than a floor in a debt list, because a
# file in `MIGRATED` may not hold **one** sentence, while a file in the table
# below was only forbidden to hold **more**. Every file the glass draws from is
# now in the first kind.
#
# **Five of the 185 this table once held were never sentences**, and finding
# that out was the first act of sitting five rather than a tidy-up: the literal
# *pattern* mis-paired quotes, so four fragments in `protected_pdf.dart` and
# one in `document_text.dart` were counted as sentences a translator owed,
# while the real sentences they were cut out of were counted as their own
# fragments. `strings_on` replaced the pattern. No migrated file gained a
# sentence by the change, which is the result that had to be checked: a
# mis-pairing can hide a real sentence as easily as invent one, and a file
# claimed empty is where that would have mattered.
#
# **What is still owed is not a sentence outside the list — it is this
# census's own reach**, and it is written down where it was found
# (`scripts/check_no_typed_sentence.py`): a sentence with no three-letter word
# is invisible here, because `[A-Za-z]{3,}` is what tells a sentence from a
# key. «Go to it» would pass this gate today. Widening the test changes what
# every file owes, so it is a named debt and not a quiet edit.
#
# **Sitting five's four items, as they were numbered and as they ended.**
#
#   one   — the rest of this table: eighteen files and 183 literals, the one
#           list 558 → 680, the debt 185 → 5. Done.
#   two   — «a guard may not type a sentence this list owns». Done, with its
#           own gate G65 in `scripts/check_no_typed_sentence.py`, which allows
#           nothing by a floor and eight things by name. Its own cost is
#           written in that file: a finder that reads a key cannot notice a
#           **reworded** value, which is why item 2-ب pins the sentences a
#           claim in `docs/CLAIMS.md` leans on (G66).
#   three — «a source that changed is measured by the one command». The lesson
#           of 096's own regression: the first part moved from `doc.marks` to
#           `entered.marks`, every `MarkState::Suggested` fell off the screen,
#           and five guards reddened in three files that were never opened. The
#           measurement, the A/B that named its owner and the order to follow
#           next time are in `A_FILE_THAT_REDS_ONLY_IN_COMPANY.md`.
#   four  — «the Dart record stays on green too». `gates.sh` deleted its log
#           and its event file the moment the suite passed, so the count a
#           green round reports — the one `MEASURED_ON_LINUX.txt` is compared
#           against — could not be re-examined afterwards. One fixed place per
#           worktree, named in the PASS line, with `G7-record` asking that the
#           file is really there.
#
# They are written here because the sitting is the ledger, and an item nobody
# numbered is an item nobody does.
OWED: dict[str, int] = {}

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
#   * **`Z-pdf : {token}`** — the answer page's own top line, and there is no
#     word in it: a product name, a colon and the token of «Zprivacy-svara».
#     It is in the list because it is written **into a file** and the owner's
#     law names the added page's title beside the footer, so one place words
#     all three. The day it gains a word, that word is German here.
SAME_IN_EVERY_LANGUAGE = re.compile(
    r'^(?:OK|Z Privacy|z-pdf|Grok|xAI|Person|Passphrase|Name'
    r'|Nordstern Consulting GmbH|Mandantenkennung|Herr Müller|Lindqvist'
    r'|\{act\} · \{needs\}|Z-pdf : \{token\}|\d+|[-—·]|)$'
)

# **And the four the Swedish adds, by name** — paper 106, each with the reason
# it is not a skipped line:
#
#   * **`AI`** — Swedish says AI, exactly as English does. German's «KI» is the
#     outlier here, not the Swedish. It is also the one word C-15's census
#     cannot see, so it is named in two places on purpose.
#   * **`person`** — the lower-case kind word. Swedish spells it the same, as
#     German does the capitalised one above.
#   * **`Session {number}`** and **`Session {number} «{name}»`** — the line the
#     send sheet draws for a session nobody named. «Session» is the word the
#     **core** writes as that name (`A_SESSION_CALLED`, which G37 measures
#     against the Dart side), and Swedish happens to spell it the same — so in
#     this one language the label on the glass and the name in the file agree.
#     Translating it would be translating data, and the German file shows what
#     that seam looks like when the two words differ.
SAME_IN_SWEDISH = re.compile(
    r'^(?:AI|person|Session \{number\}|Session \{number\} «\{name\}»)$'
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
        sentences anyway — [it_reads_as_a_sentence] below is — it only stopped
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
PRODUCT_NAMES = {'Z Privacy', 'z-pdf', 'YourVoices', 'Grok', 'xAI', 'Ollama',
                 # A model's own name, which is the same in every language and is
                 # typed into a field rather than read as a sentence.
                 'llama3.2'}

# **A name the core and the glass must spell the same is not a sentence.**
# `session_state.dart`'s «Session» is *written into the core* as the name of a
# session nobody named, and `conversation.rs` spells it too — G37 measures the
# two against each other. Translating it on one side would name a German
# person's sessions «Sitzung 3» while the core wrote «Session 3», and the name
# is **stored**, so the halves would disagree about which sessions are unnamed.
# A name is data, and data does not cross a language seam. It was in the list
# for one afternoon of sitting five and G37 reddened, which is the gate doing
# exactly what it was written for.
#
# **It became a table on 25 October 2026** — paper 117, the owner looking at the
# Arabic screens: a person working in Arabic was handed a list of sessions
# called «Session 1», «Session 2» in the middle of their own language. So the
# house now writes the name in the language the session was **born** with, and
# both halves hold the same four words — G37 compares the tables row for row.
# Each word below is therefore the same kind of thing «Session» was: a name
# written into the vault, not a sentence drawn on a screen. The one that reads
# oddest is «Session» appearing twice over — it is English's word and Swedish's,
# which is the same coincidence `SAME_IN_SWEDISH` already names.
A_NAME_BOTH_HALVES_SPELL = {'Session', 'Sitzung', 'جلسة'}

# **An address is not a sentence.** `connect_form.dart` puts
# `http://127.0.0.1:11434` into the field as a default and shows `https://…`
# as the shape of one — a German reader sees the same characters, because an
# address is what it is. Matched whole and only with a scheme in front, so no
# sentence can fall in here: none of them is a bare URL.
#
# **And a mailbox is an address too** — paper 108 item 5, 24 October 2026:
# `core/the_address_to_write_to.dart` holds `zprivacy@mono-peak.com`, the one
# address a person writes to, which the settings draw in a box to copy. It was
# already exempt here by accident — `A_FILES_OWN_WORDS` reads `…@mono-peak.com`
# as «a name built from an extension» — and an exemption that holds by accident
# is one nobody can rely on, so it is named. No sentence can fall in: a mailbox
# holds no space either, and the shape demands the `@` and a domain after it.
AN_ADDRESS = re.compile(
    r'https?://\S*|mailto:\S*|[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z]{2,})+')

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

# **A command the machine reads is not a sentence.** `core/the_system_browser.dart`
# hands `rundll32` the argument `url.dll,FileProtocolHandler` — the name of a
# Windows system library and the entry point in it that opens an address. It is
# read by the operating system and never by a person, and a German copy of it
# would simply fail to open the browser. Named rather than shaped: there is one,
# and a pattern wide enough to hold it would hold a sentence too.
A_COMMAND_THE_MACHINE_READS = {'url.dll,FileProtocolHandler'}

# An `intl` date pattern: only pattern letters, spaces and date punctuation.
DATE_PATTERN = re.compile(r'[yMdEHhmsaz., /:-]+')


# **What makes a literal a sentence** — the lead's ruling of 21 October 2026,
# sitting five's item 2-ج, and the one place both gates ask.
#
# It was `[A-Za-z]{3,}` alone, and that is a rule about *word length* standing
# in for a rule about *sentences*. It worked because almost every sentence has
# a long word in it, and it has one named hole: **«Go to it»**, which
# `find_in_document.dart` really draws. Three words, no word of three letters,
# and so it was never in any count of what the screens owed — it reached the
# list in sitting five's first item only because the file happened to be open.
# A census that cannot see a sentence is worse than a census that counts a key:
# the first is silent.
#
# So a literal reads as a sentence when **either** holds:
#
#   * it has a **space between two runs of letters** — «Go to it», «OK then»,
#     «No ads». Two words are a sentence whatever their length, and this is
#     what the old test could not see;
#   * or it has a **word of three letters or more** — which keeps every
#     single-word sentence the old test caught («Protect», «Cancel»).
#
# And what it still refuses, which is the half that makes it usable: a key, an
# id, a code and a file name hold **no space**, so the first test cannot reach
# them, and the filters below take them out by their own shapes anyway. The
# ruling's own words: «فـ«Go to it» تُرى بالفراغ، والمفتاح والمعرّف بلا فراغ
# يبقيان خارجها».
#
# **An escaped newline is not a space here.** `strings_on` keeps an escape as
# the two characters it is written with, so `'Go\nto'` holds a backslash and an
# «n» rather than a break — and a literal whose only gap is an escape is a
# sentence by neither test. Measured when this was widened: no literal in the
# tree is in that state, so the question is written down rather than answered
# by a rule nothing needs.
A_WORD_OF_THREE_LETTERS = re.compile(r'[A-Za-z]{3,}')
A_SPACE_BETWEEN_TWO_WORDS = re.compile(r'[A-Za-z]\s+[A-Za-z]')


def it_reads_as_a_sentence(v: str) -> bool:
    """Is this literal something a person could read as a sentence?

    The one test, asked in two places by this file and by G65's checker, so
    that «what a sentence is» cannot be two answers in two gates.
    """
    return bool(A_SPACE_BETWEEN_TWO_WORDS.search(v)
                or A_WORD_OF_THREE_LETTERS.search(v))


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
            if not it_reads_as_a_sentence(v):
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

            if AN_ADDRESS.fullmatch(v):               # an address, with its scheme
                continue
            if v in A_NAME_BOTH_HALVES_SPELL:         # one name, two halves
                continue
            if v in A_COMMAND_THE_MACHINE_READS:      # an argument, not a word
                continue            # **A date pattern is not a sentence.** `'d MMM y'` is what `intl`
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
            # no word of its own: take the interpolations out and the one test
            # reads nothing in what is left. The guillemets and the isolate marks are
            # grammar around a person's own word, which is `theirOwnWord`'s
            # whole job, and ICU has no placeholder for either.
            bare = re.sub(r'\$\{[^}]*\}|\$[A-Za-z_][A-Za-z_0-9]*', '', v)
            if not it_reads_as_a_sentence(bare):
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
    ar = json.loads((L10N / 'app_ar.arb').read_text(encoding='utf-8'))
    keys = [k for k in en if not k.startswith('@')]
    for k in keys:
        if k not in de:
            bad.append(f'«{k}» is in the English list and not in the German')
        if k not in sv:
            bad.append(f'«{k}» is in the English list and not in the Swedish')
        # **The Arabic, since paper 115** — read in its own loop rather than
        # folded into a list of three, because what each language is allowed to
        # share with the English differs and a single loop would need a table
        # of exceptions per language anyway. The messages are what a reader of
        # a red line gets, and each one names its own file.
        if k not in ar:
            bad.append(f'«{k}» is in the English list and not in the Arabic')
    for k in keys:
        if k in de and de[k] == en[k] and not SAME_IN_EVERY_LANGUAGE.match(en[k]):
            bad.append(f'«{k}» is the English sentence in the German file — '
                       f'nobody translated it')
        if (k in sv and sv[k] == en[k]
                and not SAME_IN_EVERY_LANGUAGE.match(en[k])
                and not SAME_IN_SWEDISH.match(en[k])):
            bad.append(f'«{k}» is the English sentence in the Swedish file — '
                       f'nobody translated it (paper 106 closed 56-أ)')
        # No `SAME_IN_ARABIC`, and the docstring says why: Arabic shares no
        # word with English, so the common list is the whole of its exception.
        if k in ar and ar[k] == en[k] and not SAME_IN_EVERY_LANGUAGE.match(en[k]):
            bad.append(f'«{k}» is the English sentence in the Arabic file — '
                       f'nobody translated it (paper 115 wrote the Arabic)')
    for extra in [k for k in de if not k.startswith('@') and k not in en]:
        bad.append(f'«{extra}» is in the German file and in no English key')
    for extra in [k for k in ar if not k.startswith('@') and k not in en]:
        bad.append(f'«{extra}» is in the Arabic file and in no English key')
    return bad


def the_test_itself() -> list[str]:
    """**Before the subject, the instrument.**

    What a sentence is was one regular expression for three weeks and it had a
    hole the size of a sentence in it. The hole is closed by a ruling now, and
    a ruling that nothing measures is a comment: narrowing
    [it_reads_as_a_sentence] back would make every count below smaller and
    every gate greener, which is the direction a quiet regression always goes.

    So the definition answers for itself here, on the two sides it has to get
    right at once — the sentence with no long word in it, and the short code
    that is neither.

    **And on what this test is not responsible for**, which the first draft of
    this control got wrong and is worth keeping: `workspace-question` and
    `the-chat-bubble-3` *do* read as sentences here, because «workspace» and
    «chat» are words. They are taken out by the **shape** filters in
    `sentences_in` — a key fullmatches `[a-z0-9_-]+` — and not by this test.
    One test says «could a person read words in this»; the filters say «and is
    it nevertheless a key, an address, a file's own name». Asserting the keys
    here would have been asserting the wrong mechanism, and it would have gone
    red on a correct tree.
    """
    bad = []
    for v in ('Go to it', 'No ads', 'OK then', 'Protect', 'Add a name'):
        if not it_reads_as_a_sentence(v):
            bad.append(f'«{v}» is a sentence and the test does not see one — '
                       f'every count in this file is smaller than the truth')
    # Neither a space between two runs of letters nor a word of three: a
    # language code, a number, a bare escape, a version.
    for v in ('de', 'ar', '0', '\\n', 'x.y', '1.2'):
        if it_reads_as_a_sentence(v):
            bad.append(f'«{v}» has no word and no space, and the test reads a '
                       f'sentence in it — the widening took in more than the ruling')
    return bad


def main() -> int:
    instrument = the_test_itself()
    for line in instrument:
        print(f'G50 the test itself: {line}')
    nine, fifty = g49(), g50()
    for line in nine:
        print(f'G50 {line}')
    for line in fifty:
        print(f'G51 {line}')
    if not instrument and not nine and not fifty:
        keys = [k for k in json.loads((L10N / 'app_en.arb').read_text(encoding='utf-8'))
                if not k.startswith('@')]
        owed = sum(OWED.values())
        print(f'{len(keys)} sentences in the one list · {len(MIGRATED)} file(s) '
              f'migrated · {owed} sentences owed in {len(OWED)} files')
        # **And what each copy actually says**, printed because paper 106 put
        # the Swedish words in: «the file carries every key» and «the file is
        # translated» are different facts, and the second one is the one a
        # reader of the README wants. A value counted here is one that differs
        # from the English, with the handful that legitimately do not named
        # above — so these two numbers are «written», never «reviewed».
        en_v = json.loads((L10N / 'app_en.arb').read_text(encoding='utf-8'))
        for code in ('de', 'sv', 'ar'):
            other = json.loads((L10N / f'app_{code}.arb').read_text(encoding='utf-8'))
            written = sum(1 for k in keys if other.get(k) != en_v.get(k))
            print(f'  {code}: {written} of {len(keys)} values say something other '
                  f'than the English (written, not reviewed)')
    return 1 if (instrument or nine or fifty) else 0


if __name__ == '__main__':
    sys.exit(main())
