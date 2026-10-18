#!/usr/bin/env python3
"""**G55 — no sentence carries a character nobody can see.**

19 October 2026. The lead, reading the ninety German values of 092's third
sitting, found `deviceBoundProtection` drafted as «Geräte­gebundener
Schutz» — a **soft hyphen** inside a word on the glass. It is invisible in
every editor, in every diff and in every review; it came from the hand that
wrote the value and it would have shipped. One pair of eyes caught it, which is
not a method.

So the whole class is refused in the one place sentences now live:

  * **`Cf` — format.** The soft hyphen, the zero-width joiner and non-joiner,
    the word joiner, the byte-order mark, and the bidirectional controls
    (`U+202A`…`U+202E`, `U+2066`…`U+2069`). Every one of them changes how a
    sentence lays out or how a reviewer reads it, while changing nothing a
    person can point at.
  * **`Cc` — control.** A newline or a tab in a value: no value holds one
    today, and a sentence that needs two lines is two sentences or a list the
    screen joins. Measured before this was written, so the rule costs nothing
    it is not owed.
  * **`Co` — private use** and **`Cs` — surrogate.** A code point with no
    meaning outside one font, and a half of a pair that should never stand
    alone in decoded text.

## The isolate marks are in this class, and that is not an exception

`U+2068` and `U+2069` are `Cf`, and the house **needs** them: a word the person
chose, quoted inside a sentence of ours, is isolated or the bidirectional
algorithm pulls the punctuation into it (G44, the owner's "ألماني 1"). They
live at the **call site**, in `theirOwnWord`, and G44's own half over this same
file checks that every value quoting a placeholder has a caller that wraps it.

So this gate forbids the whole class with no exception, and the two gates
together say the law exactly: the sentence carries the quotation marks, the
caller carries the isolate.

It cannot drift the other way either. Putting the pair inside a value was
tried on 19 October: `gen-l10n` writes the raw code points into the generated
Dart and the analyzer flags each one (`text_direction_code_point_in_literal`)
in a file nobody can edit — so the appealing version is already refused by the
toolchain, and this gate and that refusal cannot disagree.
"""
import json
import pathlib
import sys
import unicodedata

L10N = pathlib.Path('apps/flutter_app/lib/l10n')
REFUSED = ('Cc', 'Cf', 'Co', 'Cs')


def main() -> int:
    files = sorted(L10N.glob('*.arb'))
    if not files:
        print(f'G55 there is no list to read at {L10N}')
        return 1
    bad = []
    values = 0
    for path in files:
        data = json.loads(path.read_text(encoding='utf-8'))
        for key, value in data.items():
            if key.startswith('@') or not isinstance(value, str):
                continue
            values += 1
            for i, ch in enumerate(value):
                if unicodedata.category(ch) not in REFUSED:
                    continue
                # What a reader would see, with the offender named: the value
                # cannot show it, so the message says where it is and what it
                # is rather than printing it.
                around = value[max(0, i - 20):i] + '⟨here⟩' + value[i + 1:i + 20]
                bad.append(
                    f'{path.name} · «{key}» carries '
                    f'U+{ord(ch):04X} {unicodedata.name(ch, "an unnamed code point")} '
                    f'at character {i}: …{around}…')
    for line in bad:
        print(f'G55 {line}')
    if bad:
        return 1
    print(f'{values} values in {len(files)} lists, and not one invisible character '
          f'in any of them')
    return 0


if __name__ == '__main__':
    sys.exit(main())
