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
MIGRATED = {
    'core/messages.dart',
}

# **The debt, file by file, as it stands.** Each number is what that file still
# holds; the gate refuses a rise. The next branch takes them to zero in the
# order the owner reads them: the first screen, the work surface's three parts
# and the chat, then the settings rooms, then the widgets.
OWED = {
    'core/going_to_a_word.dart': 1,
    'core/protected_pdf.dart': 20,
    'core/session_state.dart': 33,
    'core/the_clipboard.dart': 1,
    'screens/first_run.dart': 36,
    'screens/settings.dart': 154,
    'screens/shell.dart': 4,
    'screens/vault.dart': 69,
    'screens/workspace.dart': 107,
    'widgets/acts.dart': 29,
    'widgets/bits.dart': 13,
    'widgets/connect_form.dart': 22,
    'widgets/conversation_view.dart': 10,
    'widgets/document_text.dart': 3,
    'widgets/entity_detail.dart': 38,
    'widgets/find_in_document.dart': 15,
    'widgets/language_list.dart': 7,
    'widgets/line_gutter.dart': 2,
    'widgets/name_review.dart': 75,
    'widgets/review.dart': 23,
    'widgets/reveal.dart': 3,
    'widgets/send_sheet.dart': 51,
    'widgets/the_chat.dart': 41,
    'widgets/the_way_back.dart': 3,
    'widgets/tokens.dart': 16,
    'widgets/vault_forms.dart': 79,
    'widgets/why_sheet.dart': 65,
}

# Values the German is allowed to share with the English, by name.
SAME_IN_EVERY_LANGUAGE = re.compile(
    r'^(?:OK|Z Privacy|z-pdf|Grok|xAI|\d+|[-—·]|)$'
)

LITERAL = re.compile(r"'((?:[^'\\]|\\.){3,})'")


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
        for m in LITERAL.finditer(line):
            v = m.group(1)
            if not re.search(r'[A-Za-z]{3,}', v):
                continue
            if v.startswith('package:') or v.endswith('.dart'):
                continue
            if re.fullmatch(r'[a-z0-9_\-]+', v):      # keys, ids, codes
                continue
            if v.startswith('__Z_') or v == '__Z_':   # token grammar
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
