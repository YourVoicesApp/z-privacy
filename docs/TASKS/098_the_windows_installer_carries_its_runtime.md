# 098 — The Windows installer carries its runtime, and the MSIX says where the vault lives

**Owner, 20 October:** on a clean Windows machine `VCRUNTIME140.dll` was missing — Node's own installer failed on it. A Flutter application on Windows needs the same runtime (`vcruntime140.dll`, `vcruntime140_1.dll`, `msvcp140.dll`), and `flutter build windows` does not copy it beside the executable: a person who double-clicks our installer on such a machine gets Windows' own dialogue about a missing DLL, or nothing at all — the silence `packaging/windows/zprivacy.iss` was written to remove.
**Base:** lead line at `e610c63` or later. Branch `fix/the-installer-carries-its-runtime`. No push.
**Builder:** ed (Windows is the core seat's). Before the Windows release; it does not touch Linux behaviour.
**Law:** `zprivacy.iss` promises **no administrator prompt** (`PrivilegesRequired=lowest`, per-user into `%LOCALAPPDATA%\Programs`); «a release says nothing about its builder»; `docs/THIRD_PARTY` and its gate name every file we ship that we did not write; «a gate that matches a name is not a gate on a shape» — the measurement lives where the files are made, the tree gate only reads that it is there.

## 1 · The runtime ships app-local

Two shapes exist and only one keeps the promise. Running `vc_redist.x64.exe` from the installer installs machine-wide and asks for an administrator — that breaks `lowest`. The other shape is Microsoft's own «app-local deployment»: the three DLLs are copied beside `zprivacy.exe`, the loader finds them there first, and nothing is installed. Microsoft permits redistributing them with an application (the Visual Studio redistribution terms, `redist.txt`, list them); that permission is written in the third-party notice with the version the runner had.

- **The step that prepares the bundle** (`scripts/package_windows.sh` if that is where the folder is assembled, else `.github/workflows/windows-core.yml` — one place, say which) copies the three from the runner's redistributable folder (`$env:VCToolsRedistDir\x64\Microsoft.VC143.CRT\` — read the variable, do not type a Visual Studio path) into the Flutter bundle **before** Inno and before `msix:create`, so both packages carry them. A step after the copy asserts each of the three is in the bundle and prints its file version; a missing one fails the job out loud (the workflow's own rule, line 237).
- **The notice:** `packaging/third-party/` (or wherever the Linux round put the obligations — read the tree) gains the Microsoft runtime entry with its redistribution terms; the workflow's obligations check (line 266) counts it.
- **The tree gate:** `scripts/gates.sh` reads that the workflow names the three DLLs in the copy step and in the assert — a check on the text, said so in its sentence, because Linux cannot run the installer. Pinned red by removing one name.
- **The Windows README** (`packaging/windows/README*` or the installer's summary step) says in one sentence that the runtime ships with the application and nothing is installed system-wide.

## 2 · The MSIX says where the vault lives

The workflow's comment (line ~418) names the expected difference and does not guess it: a packaged app's `%LOCALAPPDATA%` is virtualised, so `z_core/src/data_dir.rs`'s `%LOCALAPPDATA%\ZPrivacy` becomes `%LOCALAPPDATA%\Packages\<family>\LocalCache\Local\ZPrivacy` for the MSIX and stays plain for the Inno install. Two installs on one machine would then hold **two vaults**, and a person who moves from the `.exe` to the Store build loses sight of the first.

- **Measure, do not reason:** add to `docs/INBOX/to-windows.md` the two commands the Windows session runs after installing each shape (print the data folder the app reports; `dir` both candidate paths). The paper does not decide the outcome.
- **Make the truth visible:** the app already knows its data folder (`set_data_dir` / `default_data_dir`); if no screen shows it, the Settings room gains one sentence «Your vault is in …» through the one list (092), so the person can see which vault they are in. No second mechanism, no migration in this round — a migration is its own paper once the measurement is read.
- **Write the honest sentence** in the Windows README from the measurement, with the commit it was measured at.

## 3 · A release says nothing about its builder, on Windows too

**Measured by the Windows session (z-d3) on 20 October:** the `z_bridge.dll` installed on the owner's machine carries `C:\Users\runneradmin\.cargo\registry\src\index.crates.io-…` **242 times**. `zprivacy.exe` and `app.so` beside it are clean of `runneradmin`, of `D:\a\` and of `/home/`. The file measured is **not** the workflow's own output at `2b4fad9` — it carries no `BUILD-INFO.txt`, no `.sha256` and no MSIX, and was built at 05:39 that day from another path — so what produced it is not known. The verdict does not depend on knowing: a release that names the machine that built it is the attacker's خ3 and ن6, the Linux script answers it in two halves, and the second platform must answer it in the same two.

- **The remap is told where cargo really is.** The job exports `--remap-path-prefix` before the build (line ~230) and spells the registry as `$USERPROFILE\.cargo\registry\src` — a typed path for a folder that has a variable: `$env:CARGO_HOME`. It gains `$env:CARGO_HOME\registry\src` and `$env:CARGO_HOME\git\checkouts` (and keeps the toolchains and the workspace), read from the variable with the typed path only as the fallback the variable's absence needs. «Read the variable, never a typed path» is already item 1's rule in this paper; this is its second case.
- **G53's twin runs in the job, on the artefact itself.** After the build and before anything packages it, the job searches `zprivacy.exe`, `z_bridge.dll` and every other binary in the Release folder for `runneradmin`, `D:\a\`, `\.cargo\registry` and `/home/`, prints what it found with counts, and **fails loudly**. `scripts/package_windows.sh` already searches the staged folder for three of those four needles — but it gates the zip alone, and `msix:create` reads the Release folder the script never sees, so the law lived at one door out of two. The fourth needle (`\.cargo\registry`) goes in both lists, which are one list.
- **The tree gate** reads that the job carries that step and names the four needles, as item 1's does and for the same reason: Linux cannot run that job. Pinned red by removing one needle.

## Measurement

Rust: `cargo test`, clippy, both targets (G4c). `scripts/gates.sh` green from a plain debug build; the three numbers written by the merging hand. The workflow run (owner's hand, Actions → windows → Run workflow) shows the assert step green with three versions; the installed `.exe` on the clean machine starts without a DLL dialogue — the owner's measurement, written into `docs/INBOX/to-linux.md`.
