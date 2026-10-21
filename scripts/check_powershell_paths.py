#!/usr/bin/env python3
"""**A path crosses into PowerShell once, and is converted where it crosses** —
098 item 6, from run 39586867441.

That run was the first to reach the stamp: the runtime libraries were beside the
application, `BUILD-INFO.txt` named the commit, the four builder needles were
zero in all 36 files we compile. Then step 13 died, and the whole release with
it:

    Compress-Archive : The path '/d/a/_temp/staging/zprivacy-v1-windows-x86_64'
    either does not exist or is not a valid file system path.

`scripts/package_windows.sh` runs under bash on the runner, so its paths are
spelled the way bash spells them — `$(cd "$STAGE/.." && pwd)` answers
`/d/a/_temp/staging`. PowerShell reads Windows' spelling and cannot see such a
path at all. Nothing is wrong with either half; what was missing was the
translation at the seam between them, and because the zip is where the `.sha256`
and the uploads hang, one unconverted path cost the fourth run in a row with no
artefact.

## What this refuses

A `powershell` or `pwsh` command in `scripts/` that interpolates a shell
variable which was **not** produced by `cygpath`. That is the whole rule, and it
is deliberately strict: the alternative — guessing which interpolation is a path
— is how the one that mattered was missed.

Two ways to satisfy it:

  * `WIN_X=$(cygpath -w "$X")` and interpolate `$WIN_X`. The conversion is then
    at the one crossing, which is the other half of the rule: **a path converted
    twice is a path broken twice**, so converting a variable that is already
    converted is refused as well.
  * a variable that is honestly not a path: write `# not-a-path: NAME` in the
    same file, by name, next to the reason. An allowance somebody has to type is
    an allowance somebody has read.

## The other crossing, in the job itself

There are two places a path this house builds in bash reaches PowerShell: the
command above, and `$GITHUB_ENV`. A `shell: bash` step in
`.github/workflows/windows-core.yml` writes a name, a `shell: pwsh` step later
reads it as `$env:NAME`, and a name written from `pwd` would arrive there in
exactly the spelling that killed step 13. Today the staging names are written
from `$RUNNER_TEMP` with the backslashes turned round — `D:/a/_temp`, which both
shells read — and the Inno step turns them back with `-replace '/', '\\'`. That
is correct, and it is one `pwd` away from not being, so it is held here too.

Linux cannot run PowerShell, so this is a check on the text — the same sentence
`G60`, `G64` and `G67` carry. What it measures is not «the zip works» but «no
path reaches PowerShell in bash's spelling», which is the fault that happened.

Exit status is the verdict; the last line is the count the gate prints.
"""
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
SCRIPTS = HERE / "scripts"

# A shell invocation of Windows' own shell, by any of the names it answers to.
CALLS = re.compile(r"(?:^|[|&;(]|\s)(powershell|powershell\.exe|pwsh|pwsh\.exe)\s")
# `$NAME` and `${NAME}`, which is every way these scripts interpolate one.
USES = re.compile(r"\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?")
# `NAME=$(cygpath …)`, with or without quotes around the substitution.
CONVERTS = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)=\"?\$\((.*cygpath[^)]*)\)\"?\s*$")
ALLOWED = re.compile(r"#\s*not-a-path:\s*([A-Za-z_][A-Za-z0-9_]*)")
# The shell's own names, which are not ours to convert and never a path we built.
SHELL_OWN = {"PATH", "IFS", "HOME", "PWD", "OLDPWD", "SHELL", "USER", "TMPDIR"}

# The job, and the two halves of its own crossing: a name a pwsh step reads, and
# the bash line that wrote it.
JOB = HERE / ".github/workflows/windows-core.yml"
READS_ENV = re.compile(r"\$env:([A-Za-z_][A-Za-z0-9_]*)")
WRITES_ENV = re.compile(r'^\s*(?:echo\s+")?([A-Za-z_][A-Za-z0-9_]*)=(.*?)"?\s*(?:>>\s*"?\$GITHUB_ENV"?)?\s*$')
# What a path must never be built from when the other shell will read it.
BASH_SPELLING = re.compile(r"\$\(\s*cd\b|\bpwd\b")


def logical_lines(text):
    """The file's commands, with a trailing backslash joined to the next line."""
    out = []
    held, start = None, None
    for n, raw in enumerate(text.split("\n"), start=1):
        line = raw.rstrip()
        if held is None:
            held, start = line, n
        else:
            held = held + " " + line.strip()
        if held.endswith("\\"):
            held = held[:-1].rstrip()
            continue
        out.append((start, held))
        held, start = None, None
    if held is not None:
        out.append((start, held))
    return out


def main():
    faults = []
    crossings = 0
    for path in sorted(SCRIPTS.glob("*.sh")):
        text = path.read_text(encoding="utf-8")
        rel = path.relative_to(HERE)
        converted = {m.group(1) for m in (CONVERTS.match(l) for l in text.split("\n")) if m}
        allowed = set(ALLOWED.findall(text))

        # A path converted twice is a path broken twice.
        for n, line in logical_lines(text):
            m = CONVERTS.match(line)
            if m and any(f"${{{v}}}" in m.group(2) or f"${v}" in m.group(2) for v in converted - {m.group(1)}):
                faults.append(f"{rel}:{n}: {m.group(1)} converts a path that is already converted")

        for n, line in logical_lines(text):
            code = line.split("#", 1)[0]
            if not CALLS.search(code):
                continue
            crossings += 1
            for name in USES.findall(code):
                if name in converted or name in allowed or name in SHELL_OWN:
                    continue
                faults.append(
                    f"{rel}:{n}: ${name} is handed to PowerShell in bash's spelling"
                    f" — convert it with cygpath -w, or say «# not-a-path: {name}» and why"
                )

    # And the job's own crossing: a name pwsh reads, written by bash from a path
    # only bash can spell.
    if JOB.exists():
        text = JOB.read_text(encoding="utf-8")
        rel = JOB.relative_to(HERE)
        read_by_pwsh = set(READS_ENV.findall(text))
        for n, line in enumerate(text.split("\n"), start=1):
            m = WRITES_ENV.match(line.strip())
            if not m:
                continue
            name, value = m.group(1), m.group(2)
            if name not in read_by_pwsh:
                continue
            crossings += 1
            if BASH_SPELLING.search(value):
                faults.append(
                    f"{rel}:{n}: {name} is read by a pwsh step and written from this shell's own"
                    f" spelling — the Compress-Archive fault, one seam over"
                )

    for fault in faults:
        print(fault)
    print(f"  {crossings} bash→PowerShell crossing(s) · {len(faults)} unconverted")
    return 1 if faults else 0


if __name__ == "__main__":
    sys.exit(main())
