# 114 — The MSIX carries the NOTICE: the guard 113 added caught its own paper

**Source:** Windows run `40128478018` on `8969d74` (24 October 2026, the run the owner dispatched for publishing). Builder: **e2**. Branch off `8969d74`. One file: `.github/workflows/windows-core.yml`.

## What was measured

The job failed at «What the MSIX packed is what was measured»: the six binaries in the package matched the staged six hash for hash, then `##[error]NOTICE is in the MSIX 0 time(s), not once`. Everything before it passed, including the zip, the Inno installer and the Dart suite, and the setup artifact was uploaded.

The cause is in the job itself. `msix:create --build-windows false` packs Flutter's **Release folder** (`apps/flutter_app/build/windows/x64/runner/Release`), not the staging folder that 113 copies NOTICE into. The six binaries agree because staging copies them **from** that Release folder. A file that exists only in staging never reaches the package. 113's report said «the MSIX is packed from the staged folder». That is true of the installer (`{#SourceDir}\*`), not of the MSIX. 113 named that its listings came from the job's own run and claimed nothing more, and the comparison it added is what found this. The guard worked on its first run.

## The ruling

- Before `msix:create`, copy `NOTICE` **and** `LICENSE` from the repository root into the Release folder the tool packs. Apache §4(a) asks for the licence with every redistribution, and §4(d) asks for the NOTICE. The MSIX is not published today (it waits for a real code-signing certificate), but a package that carries our code without either is our own condition broken in the one artefact no Linux gate can open.
- The comparison step checks `LICENSE` once beside `NOTICE`, with the same sentence shape.
- **Fix the record in the same commit:** the comment(s) that say the MSIX is built from the staging folder become the truth. The installer packs staging, the MSIX packs Release, and this step copies the two files across.

## Measurement

The workflow runs only on Windows, so Linux measures what it can: the gates (G-numbers that read the workflow file) green, and the comment truthful. The real measurement is the next Windows run on the merged tip, which the owner dispatches. The publishing run of the site waits for it.
