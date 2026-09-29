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
# inside a lock is the same mistake at one remove.
#
# This list used to be written by hand — and on 29 September that is exactly how
# M7.10B deadlocked: `create_profile` called `default_pack_id()`, a new helper
# nobody had added here, from inside a held lock. The gate passed and the test
# suite hung. A hand-kept list of dangerous functions always lags the code, so
# the list is now **read out of the source**: any `fn` in `z_core/src` whose own
# body takes the lock is a locking helper, whether or not anyone remembered it.
def locking_helpers() -> dict[str, set[str]]:
    found: dict[str, set[str]] = {}
    for path in sorted(OPS.rglob("*.rs")):
        text = strip_strings_and_comments(path.read_text())
        for match in re.finditer(r"\bfn\s+([a-z_][a-z0-9_]*)\s*[(<]", text):
            name = match.group(1)
            brace = text.find("{", match.end())
            if brace < 0:
                continue
            depth = 0
            j = brace
            while j < len(text):
                if text[j] == "{":
                    depth += 1
                elif text[j] == "}":
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            body = text[brace:j]
            if any(opener in body for opener in TAKES_THE_LOCK):
                # Which module defines it, so a same-named function in another
                # module is not reported. `scanner::scan` is a pure function
                # that shares a name with `ops::scan`, which locks.
                module = path.parent.name if path.name == "mod.rs" else path.stem
                found.setdefault(name + "(", set()).add(module)
    # `with_core` and `with_session` are the openers themselves, and a closure
    # argument named after them would only duplicate a report.
    found.pop("with_core(", None)
    found.pop("with_session(", None)
    return found


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


def nested_locks(path: pathlib.Path, helpers: dict[str, set[str]]) -> list[str]:
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
            for inner in list(TAKES_THE_LOCK) + sorted(helpers):
                where = -1
                # Only a **free** call counts. `vault.entity(..)` and
                # `payload.finish_send(..)` are methods that merely share a
                # name with a locking helper, and reporting them would train
                # everyone to ignore this gate.
                # A whole name, not a substring: `reserve_send(` is not `send(`.
                pattern = r"(?<![A-Za-z0-9_])" + re.escape(inner)
                for m in re.finditer(pattern, body):
                    before = body[: m.start()].rstrip()
                    # `x.foo()` is a method that merely shares a name. But
                    # `crate::ops::foo()` is a free call through a path, and
                    # that is precisely how M7.10B deadlocked — so a `::`
                    # prefix counts, it does not excuse.
                    if before.endswith("."):
                        continue
                    # A qualified call must name the module that defines the
                    # locking helper, or it is a different function entirely.
                    if before.endswith("::"):
                        segment = re.search(r"([A-Za-z0-9_]+)::$", before)
                        owners = helpers.get(inner, set())
                        if owners and (not segment or segment.group(1) not in owners):
                            continue
                    if re.search(r"\bfn\s*$", before):
                        continue
                    where = m.start()
                    break
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
    helpers = locking_helpers()
    for path in sorted(OPS.rglob("*.rs")):
        problems += nested_locks(path, helpers)
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
