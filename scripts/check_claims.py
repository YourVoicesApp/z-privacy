"""Every claim in `docs/CLAIMS.md` has its four lines, and everything it names exists.

094, the owner's own order: a file in git naming what the product claims, with
each claim's limit and its proof, handed to an outside reader to attack. This is
the gate that keeps that file honest between reviews (**G56**).

What it refuses, and why each one is a way the file would rot quietly:

* **a section missing one of the four lines** — the limit is the line a hurried
  hand drops first, and a claim without its limit is the exaggeration this file
  exists to prevent;
* **a path that does not exist** — a proof pointing at a deleted test reads
  exactly like a proof;
* **a gate number that is in no gate** — the same, one layer out;
* **a `--test NAME` in the command that has no test file** — the command a
  stranger runs must run;
* **a sentence key that is not in `app_en.arb`** — «We say» must quote what the
  product actually says, not what we remember it saying;
* **a missing «What we do not claim» section** — the list of limits is part of
  the claim set, not an appendix.

A claim whose proof line begins with `unproven —` is **allowed** and counted
separately. That is the whole of the owner's instruction: a claim we cannot
measure stays in the file wearing that word, because a claim removed from the
list is a claim hidden rather than dropped. The pass line prints the two
numbers, so «how many of our claims are measured» is on the record of every
gate run.

Run it from anywhere:  python3 scripts/check_claims.py
Exit status is the verdict: 0 = every section is whole and everything it names
exists.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CLAIMS = ROOT / "docs" / "CLAIMS.md"
GATES = ROOT / "scripts" / "gates.sh"
ARB = ROOT / "apps" / "flutter_app" / "lib" / "l10n" / "app_en.arb"

# The four lines, in this order. The order is part of the shape: the limit comes
# before the proof so that a reader meets it before the reassurance.
LINES = ["**We say:**", "**The limit:**", "**The proof:**", "**Measure it yourself:**"]

UNPROVEN = "unproven —"

# A path-like token with an extension this tree actually uses. Deliberately not
# «anything with a slash»: prose names rules and keys too, and a checker that
# guesses would fail on a sentence rather than on a claim.
# A leading dot is part of the path, not a boundary: `.github/workflows/…` is
# the first thing this missed, and it missed it by agreeing with itself.
PATH = re.compile(r"(?<![A-Za-z0-9_])(\.?(?:[A-Za-z0-9_.-]+/)+[A-Za-z0-9_.-]+\.(?:rs|sh|py|dart|yml|yaml|md|html|txt|arb))\b")

# **Two roots, named.** A command that a stranger runs may begin `cd
# apps/flutter_app && flutter test test/…`, because that is how the Dart suite
# is run; the path after it is real, from there. So a path is looked for at the
# repository root and then inside the app, and nowhere else — a checker that
# searched every directory would stop refusing anything.
ROOTS = ["", "apps/flutter_app"]
GATE = re.compile(r"`(G\d+[a-z]?(?:/G\d+[a-z]?)*)`")
KEY = re.compile(r"key `([A-Za-z][A-Za-z0-9_]*)`")
TEST_FLAG = re.compile(r"--test\s+([a-z0-9_]+)")
SECTION = re.compile(r"^## (C-\d+) · (.+)$")


def gate_exists(gates_text: str, number: str) -> bool:
    """Is this gate number printed by a gate, under its own name?

    `gates.sh` labels one check «G50/G51» because the two numbers are one law
    with two halves, so a plain `"G50 ` search would miss it. Asked of the
    label, not of the file: the number must be one a gate prints, not one a
    comment mentions.
    """
    for part in number.split("/"):
        bare = part.rstrip("abcdefghijklmnopqrstuvwxyz")
        for name in (bare, part):
            # At the head of a label («"G43 …»), or as the second half of a
            # paired one («"G50/G51 …») — the pair is one check with two
            # numbers, and the second number is printed just as much as the
            # first.
            if re.search(r'"\s*' + re.escape(name) + r'[a-z]?[\s/"]', gates_text):
                return True
            if re.search(r'/' + re.escape(name) + r'[a-z]?[\s"]', gates_text):
                return True
    return False


def main() -> int:
    if not CLAIMS.is_file():
        print(f"  no {CLAIMS.relative_to(ROOT)} — 094 asks for it by name")
        return 1
    text = CLAIMS.read_text(encoding="utf-8")
    gates_text = GATES.read_text(encoding="utf-8") if GATES.is_file() else ""
    keys = set()
    if ARB.is_file():
        try:
            keys = {k for k in json.loads(ARB.read_text(encoding="utf-8")) if not k.startswith("@")}
        except ValueError as e:
            print(f"  {ARB.relative_to(ROOT)} is not readable as JSON: {e}")
            return 1

    lines = text.splitlines()
    sections: list[tuple[str, str, list[str]]] = []
    for i, line in enumerate(lines):
        m = SECTION.match(line)
        if not m:
            continue
        body: list[str] = []
        for after in lines[i + 1 :]:
            if after.startswith("## ") or after.startswith("---"):
                break
            if after.strip():
                body.append(after)
        sections.append((m.group(1), m.group(2), body))

    problems: list[str] = []
    proven = 0
    unproven: list[str] = []

    if not sections:
        problems.append("no «## C-NN · …» section in the file at all")

    seen: set[str] = set()
    for number, title, body in sections:
        where = f"{number}"
        if number in seen:
            problems.append(f"{where}: two sections carry this number")
        seen.add(number)

        # The four lines, in order, one each.
        found = [b for b in body if any(b.startswith(label) for label in LINES)]
        labels = [next(label for label in LINES if b.startswith(label)) for b in found]
        if labels != LINES:
            missing = [label for label in LINES if label not in labels]
            if missing:
                problems.append(f"{where} «{title}»: missing {', '.join(missing)}")
            else:
                problems.append(f"{where} «{title}»: the four lines are out of order: {labels}")
            continue

        proof = found[LINES.index("**The proof:**")][len("**The proof:**") :].strip()
        measure = found[LINES.index("**Measure it yourself:**")]
        if proof.startswith(UNPROVEN):
            unproven.append(number)
        else:
            proven += 1

        # Everything the section names has to exist.
        for text_of_line in found:
            for path in PATH.findall(text_of_line):
                if not any((ROOT / root / path).exists() for root in ROOTS):
                    problems.append(f"{where}: names {path}, which is not in the tree")
            for gate in GATE.findall(text_of_line):
                if not gate_exists(gates_text, gate):
                    problems.append(f"{where}: names gate {gate}, which no gate prints")
            for key in KEY.findall(text_of_line):
                if keys and key not in keys:
                    problems.append(f"{where}: quotes key «{key}», which is not in app_en.arb")
        for test in TEST_FLAG.findall(measure):
            if not (ROOT / "z_core" / "tests" / f"{test}.rs").is_file():
                problems.append(f"{where}: the command runs --test {test}, and z_core/tests/{test}.rs does not exist")

    if "## What we do not claim" not in text:
        problems.append("the closing «What we do not claim» section is gone")

    for problem in problems:
        print(f"  {problem}")
    print(f"  {len(sections)} claims · {proven} proven · {len(unproven)} unproven"
          + (f" ({', '.join(unproven)})" if unproven else ""))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
