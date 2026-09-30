#!/usr/bin/env python3
"""G21 — the captured attacker has not been edited.

The Hardening phase closes on one condition: *the same harness, re-run, with
no change in our favour.* That sentence is only worth anything if «the same»
can be proved six months from now, when nobody remembers what the attacker
looked like.

So `redteam/<date>/original/` is hashed, and this checks every file on every
build. A commit that quietly softens an old attack — removes a case, loosens
an assertion, widens a bound — fails here rather than passing while we go on
saying the test still holds.

Missing files and **extra** files both count: an attacker with a file added
to it is not the attacker that ran either.
"""

import hashlib
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
REDTEAM = ROOT / "redteam"


def digest(path: pathlib.Path, algorithm: str) -> str:
    data = path.read_bytes()
    return hashlib.new(algorithm, data).hexdigest()


def check(run: pathlib.Path) -> list[str]:
    manifest = run / "HASHES.txt"
    original = run / "original"
    if not manifest.is_file():
        return [f"{run.name}: no HASHES.txt beside original/"]
    if not original.is_dir():
        return [f"{run.name}: no original/ to check"]

    problems = []
    listed: set[str] = set()
    for line in manifest.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split(None, 2)
        if len(parts) != 3:
            problems.append(f"{run.name}: cannot read this line of HASHES.txt: {line[:60]}")
            continue
        algorithm, expected, relative = parts
        listed.add(relative)
        target = original / relative
        if not target.is_file():
            problems.append(f"{run.name}: original/{relative} is gone")
            continue
        actual = digest(target, algorithm)
        if actual != expected:
            problems.append(
                f"{run.name}: original/{relative} changed\n"
                f"            {algorithm} expected {expected}\n"
                f"            {algorithm} found    {actual}"
            )

    present = {
        p.relative_to(original).as_posix()
        for p in original.rglob("*")
        if p.is_file()
    }
    for extra in sorted(present - listed):
        problems.append(f"{run.name}: original/{extra} is not in HASHES.txt")
    return problems


def main() -> int:
    if not REDTEAM.is_dir():
        print("G21 no captured harness to check")
        return 0

    runs = sorted(p for p in REDTEAM.iterdir() if p.is_dir())
    if not runs:
        print("G21 no captured harness to check")
        return 0

    problems: list[str] = []
    files = 0
    for run in runs:
        problems += check(run)
        original = run / "original"
        if original.is_dir():
            files += sum(1 for p in original.rglob("*") if p.is_file())

    if problems:
        print("G21 the captured red-team harness was edited:")
        for p in problems:
            print(f"        {p}")
        return 1
    print(f"G21 the captured harness is unchanged ({files} files, {len(runs)} run)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
