#!/usr/bin/env python3
"""Every sentence a person reads is one line of prose, not a wrapped literal.

046/D, from the owner's own screen: `protect` with `Scope::Profile` and no
profile refused with **nineteen spaces inside the sentence** —

    this conversation is not in a profile, so there is no profile to remember it
                          for - choose «always», or open a profile first

— because the Rust literal was wrapped across two lines **without** the
backslash that tells the compiler the newline and the indentation are not part
of the string. The result is a sentence with a hole in it, on screen, in front
of whoever is looking. It is the kind of thing a jury sees before it hears
anything.

The sweep found three, not one: that refusal, the Why card's sentence for a
protection whose reason no longer exists (two holes of eighteen spaces each),
and the home screen's own line about what is uploaded (three spaces between two
sentences, in Dart, on the first screen of the product). Three sentences were
the fix. This is what stops the fourth.

It reads every string literal in the core and in the hand-written Flutter code,
works out the **value** rather than the source, and fails on a value that
carries a hole. What it deliberately skips: `//` and `/* */` comments, whose
tables are aligned on purpose; `#[cfg(test)] mod tests`, whose fixtures are
data (`text.rs` holds `"Yn-\n   nerman"` because 038-I is about a name a page
broke); and the generated bridge, which nobody reads.
"""

import io
import os
import re
import sys

ESCAPES = {'n': '\n', 't': '\t', 'r': '\r', '"': '"', '\\': '\\', "'": "'", '0': '\0'}


def test_blocks(src):
    """The byte ranges of every `#[cfg(test)] mod tests { ... }`.

    A fixture is **data**, not a sentence. Flagging one would make this gate
    something people switch off, and a gate people switch off is the
    second-worst kind.
    """
    out = []
    for match in re.finditer(r'#\[cfg\(test\)\]\s*mod\s+\w+\s*\{', src):
        depth, i = 0, match.end() - 1
        while i < len(src):
            if src[i] == '{':
                depth += 1
            elif src[i] == '}':
                depth -= 1
                if depth == 0:
                    break
            i += 1
        out.append((match.start(), i))
    return out


def skip_comment(src, i, line):
    """If a comment starts at `i`, step over it. Returns `(i, line, stepped)`."""
    n = len(src)
    if src[i] == '/' and i + 1 < n and src[i + 1] == '/':
        while i < n and src[i] != '\n':
            i += 1
        return i, line, True
    if src[i] == '/' and i + 1 < n and src[i + 1] == '*':
        end = src.find('*/', i + 2)
        end = n if end == -1 else end + 2
        return end, line + src.count('\n', i, end), True
    return i, line, False


def rust_literals(src):
    """Yield `(offset, line, value)` for every Rust literal, as rustc reads it.

    Char literals, lifetimes and comments are stepped over: a `'"'` inside a
    character literal used to open a string that ran to the end of the file,
    which is how the first version of this script reported a false defect in
    `text.rs`. A checker that cannot be trusted about three is not a checker.
    """
    i, line, n = 0, 1, len(src)
    while i < n:
        i, line, stepped = skip_comment(src, i, line)
        if stepped:
            continue
        c = src[i]
        if c == '\n':
            line += 1
            i += 1
            continue
        if c == "'":
            # A character literal, or a lifetime.
            m = re.match(r"'(\\.|[^\\'])'", src[i:])
            i += len(m.group(0)) if m else 1
            continue
        if c == 'r' and i + 1 < n and src[i + 1] in '"#':
            at, j, hashes = i, i + 1, 0
            while j < n and src[j] == '#':
                hashes += 1
                j += 1
            if j < n and src[j] == '"':
                close = '"' + '#' * hashes
                end = src.find(close, j + 1)
                if end == -1:
                    return
                body = src[j + 1:end]
                yield at, line, body
                line += body.count('\n')
                i = end + len(close)
                continue
        if c == '"':
            at, j, out, start = i, i + 1, [], line
            while j < n:
                ch = src[j]
                if ch == '\\':
                    nxt = src[j + 1] if j + 1 < n else ''
                    if nxt == '\n':
                        # The one way to wrap a long sentence correctly: the
                        # newline and the whitespace after it are not in the
                        # value.
                        line += 1
                        j += 2
                        while j < n and src[j] in ' \t':
                            j += 1
                        continue
                    out.append(ESCAPES.get(nxt, nxt))
                    j += 2
                    continue
                if ch == '"':
                    break
                if ch == '\n':
                    line += 1
                out.append(ch)
                j += 1
            yield at, start, ''.join(out)
            i = j + 1
            continue
        i += 1


def dart_literals(src):
    """Yield `(offset, line, value)` for every Dart string literal.

    Dart has no backslash-newline continuation: a long sentence is wrapped as
    **adjacent literals**, so each piece sits on its own line and a hole inside
    a piece is a hole in the sentence. Four quote forms, and `r` for raw.
    """
    single = chr(39)
    double = chr(34)
    quotes = single + double
    i, line, n = 0, 1, len(src)
    while i < n:
        i, line, stepped = skip_comment(src, i, line)
        if stepped:
            continue
        c = src[i]
        if c == '\n':
            line += 1
            i += 1
            continue
        at, raw = i, False
        if c == 'r' and i + 1 < n and src[i + 1] in quotes:
            raw = True
            i += 1
            c = src[i]
        if c not in quotes:
            i = at + 1
            continue
        triple = src[i:i + 3] in (single * 3, double * 3)
        close = src[i:i + 3] if triple else c
        j = i + len(close)
        out, start = [], line
        while j < n:
            ch = src[j]
            if not raw and ch == '\\':
                nxt = src[j + 1] if j + 1 < n else ''
                out.append(ESCAPES.get(nxt, nxt))
                j += 2
                continue
            if not raw and ch == '$':
                # **An interpolation is code, not a sentence.** Its own padding
                # is deliberate — the send sheet's «  (key kept for this run
                # only)» is a separator a caller asked for — so the braces and
                # what is between them become one placeholder. It is a
                # non-space, so a hole that straddles it is still a hole:
                # «a ${x}  b» reads as two spaces between two characters, and
                # is reported.
                j += 1
                if j < n and src[j] == '{':
                    depth = 0
                    while j < n:
                        if src[j] == '{':
                            depth += 1
                        elif src[j] == '}':
                            depth -= 1
                            if depth == 0:
                                j += 1
                                break
                        elif src[j] == '\n':
                            line += 1
                        j += 1
                else:
                    while j < n and (src[j].isalnum() or src[j] in '_.'):
                        j += 1
                out.append('\u0000')
                continue
            if src[j:j + len(close)] == close:
                break
            if ch == '\n':
                line += 1
                if not triple:
                    # An unterminated literal. Not this script's business to
                    # diagnose, and the analyzer already refuses it.
                    break
            out.append(ch)
            j += 1
        yield at, start, ''.join(out)
        i = j + len(close)


# **Two shapes, because the same defect can be written two ways** — and the
# first version of this checker caught only one of them, which is the failure
# this project has already paid for twice: a guard that does not bite is worse
# than none.
#
#   1. a run of two or more spaces inside the sentence. The owner's own case:
#      the literal sat on one long line, so the hole is spaces between two
#      ordinary characters.
#   2. a newline followed by a space or a tab. The *same* literal written
#      across two source lines with no trailing backslash — the newline and the
#      indentation are both in the value, and shape 1 misses it because what
#      sits before the spaces is the newline.
#
# Measured: putting the owner's sentence back in shape 2 left the first version
# of this file reporting nothing at all.
#
# A run at the very start or the very end of a value is left alone: that is
# padding a caller asked for — the send sheet's «  (key kept for this run
# only)» is one — and this gate is about a hole in the middle.
HOLES = (
    re.compile(r'\S {2,}\S'),
    re.compile(r'\n[ \t]'),
)


def main() -> int:
    roots = sys.argv[1:] or ['z_core/src', 'apps/flutter_app/lib']
    bad = []
    for root in roots:
        for dirpath, _, names in os.walk(root):
            # Generated Dart is the bridge's, not ours, and nobody reads it.
            if f'{os.sep}src{os.sep}rust' in dirpath:
                continue
            for name in sorted(names):
                rust = name.endswith('.rs')
                dart = name.endswith('.dart')
                if not rust and not dart:
                    continue
                path = os.path.join(dirpath, name)
                src = io.open(path, encoding='utf-8').read()
                skip = test_blocks(src) if rust else []
                found = rust_literals(src) if rust else dart_literals(src)
                # Shape 2 is Rust's alone: a Dart literal cannot carry the
                # indentation of the next source line.
                shapes = HOLES if rust else HOLES[:1]
                for at, line, value in found:
                    if any(start <= at <= end for start, end in skip):
                        continue
                    if any(hole.search(value) for hole in shapes):
                        bad.append((path, line, value))
    for path, line, value in bad:
        shown = value if len(value) <= 200 else value[:200] + '...'
        print(f'{path}:{line}: a sentence with a hole in it: {shown!r}')
    if bad:
        print(
            f'{len(bad)} literal(s) carry a run of spaces, or a newline with '
            'indentation after it. Wrap a long sentence with a trailing '
            'backslash in Rust, or as two adjacent literals in Dart. The two are not '
            'interchangeable: Rust does not join adjacent literals, so that advice is '
            'Dart-only and a Rust sentence wraps with a trailing backslash, which eats '
            'the newline and the indentation after it.'
        )
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
