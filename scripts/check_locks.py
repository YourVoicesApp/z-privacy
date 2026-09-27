#!/usr/bin/env python3
"""G19 — no nested lock in the core.

The owner's rule of 27 September, after the project's first deadlock:

    No public API in the core calls another public API while under the same
    Mutex. Split an internal helper that assumes the lock is held, or arrange
    the state access so the Mutex is not a hidden call graph.

It matters more than an ordinary bug because a deadlock **does not shout**. The
program simply stops, with no panic, no log, nothing to read. `reveal_ttl_ms()`
took the core's lock from inside `reveal()`, which already held it, and the test
suite hung for ten minutes before anyone knew why.

What this checks, by walking braces rather than by grepping lines:

  1. Inside a `with_core(...)` or `with_session(...)` closure there is no second
     `with_core(` / `with_session(` — directly or through a helper known to take
     the lock itself.
  2. Nothing in `z_core/src/ops/` calls `crate::api::` — the public surface calls
     inwards, never the other way round, or a lock taken at the top would be
     taken again at the bottom.
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OPS = ROOT / "z_core" / "src"

# Functions that take the core's lock on their own behalf. A call to one of
# these from inside a held lock is the deadlock.
TAKES_THE_LOCK = ("with_core(", "with_session(")

# Helpers that are themselves written as `with_core(...)`, so calling one from
# inside a lock is the same mistake at one remove. Kept by name because Rust
# has no way to say «this function locks» in its type.
LOCKING_HELPERS = (
    "reveal_ttl_ms(",
    "login_in_vault(",
    "login_for(",
    "row_for(",
    "settings(",
    "save_settings(",
    "providers(",
)


def strip_strings_and_comments(text: str) -> str:
    """Blank out anything a brace-walk should not see."""
    out = []
    i = 0
    n = len(text)
    while i < n:
        two = text[i : i + 2]
        if two == "//":
            j = text.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i))
            i = j
        elif two == "/*":
            j = text.find("*/", i)
            j = n if j < 0 else j + 2
            out.append(" " * (j - i))
            i = j
        elif text[i] == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == "\\" else 1
            j = min(j + 1, n)
            out.append(" " * (j - i))
            i = j
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


def nested_locks(path: pathlib.Path) -> list[str]:
    raw = path.read_text()
    text = strip_strings_and_comments(raw)
    lines = raw.split("\n")
    bad = []

    for opener in TAKES_THE_LOCK:
        start = 0
        while True:
            at = text.find(opener, start)
            if at < 0:
                break
            start = at + 1
            # Walk to the matching close paren of this call.
            depth = 0
            j = at + len(opener) - 1
            while j < len(text):
                if text[j] == "(":
                    depth += 1
                elif text[j] == ")":
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            body = text[at + len(opener) : j]
            for inner in TAKES_THE_LOCK + LOCKING_HELPERS:
                where = body.find(inner)
                if where < 0:
                    continue
                line_no = raw[: at + len(opener) + where].count("\n") + 1
                bad.append(
                    f"{path.relative_to(ROOT)}:{line_no}: `{inner.rstrip('(')}` "
                    f"called inside `{opener.rstrip('(')}` — {lines[line_no - 1].strip()[:70]}"
                )
    return bad


def api_called_inwards() -> list[str]:
    bad = []
    for path in sorted((OPS / "ops").rglob("*.rs")):
        for n, line in enumerate(path.read_text().split("\n"), 1):
            stripped = line.strip()
            if stripped.startswith("//"):
                continue
            if re.search(r"\bcrate::api::[a-z_]+\s*\(", line):
                bad.append(f"{path.relative_to(ROOT)}:{n}: {stripped[:70]}")
    return bad


def main() -> int:
    problems = []
    for path in sorted(OPS.rglob("*.rs")):
        problems += nested_locks(path)
    problems += api_called_inwards()

    if problems:
        print("G19 a lock is taken inside a lock, or the surface is called inwards:")
        for p in problems:
            print(f"        {p}")
        return 1
    print("G19 no nested lock in z_core, and no call back into the public surface")
    return 0


if __name__ == "__main__":
    sys.exit(main())
