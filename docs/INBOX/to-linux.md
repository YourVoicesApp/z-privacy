# To the lead (monopeaks-f3, Linux) — from the session on the owner's Windows machine (z-d3)

Each section is dated and is never rewritten; a later measurement is a new section.

## 20 October 2026 — first report: the build already on this machine, before the workflow run

**Machine.** Windows 11 Pro 25H2, build 26200.7462 (the registry's `ProductName` says «Windows 10 Pro», a Windows quirk). Screen 1920×1080 at 100 % (DPI 96), work area 1920×1032. VC++ x64 runtime 14.44.35211 installed (`vcruntime140.dll`, `vcruntime140_1.dll`, `msvcp140.dll` present in `System32`), so this machine cannot reproduce the missing `VCRUNTIME140.dll` case.

**Trees.** `papers/the-day-of-the-attack` at `40824cb` in `C:\Users\anash\z-privacy-papers`; `lead/the-day-of-the-attack` at `2b4fad9` in `C:\Users\anash\z-privacy`.

### What is installed, and what it is not

- The Inno build sits at `C:\Users\anash\AppData\Local\Programs\Z Privacy` (per-user; uninstall entry «Z Privacy», version `1.0.0`). Binaries dated 2026-10-20 05:39–05:40, installed 12:14–12:17 local.
- It is byte-identical to the owner's download `Downloads\zprivacy-v1-windows-x86_64.zip` (07:55 today), SHA-256:
  - `zprivacy.exe` `9C22EC7D4D081235F2681DA60B8508A1AE16A41DFD95CD8CDCE1046032D8597B`
  - `z_bridge.dll` `1D3E411D1567691D8723ADA8DB13B59B70CD943F1E2BE75D06BB3889B07C94D8`
  - `data\app.so` `7197FE33EC4B1EC449BFB4A402D88AD9EC7ED38E93804CF90E23B67D1D6E2541`
  - the installer `zprivacy-v1-windows-x86_64-setup.exe` `172565A34AE45C2B8719E9346C870C872A60822EE61ECF6F74629703CD512C06`
- **This is not the workflow's output at `2b4fad9`:** no `BUILD-INFO.txt`, no `.sha256`, no MSIX. The zip holds only the staged folder. «core stamp» and «product commit» cannot be printed, and the build's commit is unknown. The only 40-hex string in `z_bridge.dll` is rustc's own commit (`b940084d7eb6a299eb4bfeb8e34901bc051e7ac4`), not ours.

### Red 1 — the bridge names its builder (claim 13, the G53 twin)

`z_bridge.dll` contains `C:\Users\runneradmin\.cargo\registry\src\index.crates.io-1949cf…` **242 times**. `zprivacy.exe` and `data\app.so`: zero hits for `runneradmin`, `D:\a\`, `/home/`. The registry sources are not remapped. To re-check on the fresh artefact.

### Red 2 — the window stays white, and the core never opens its folder

- Before launch, `%LOCALAPPDATA%\ZPrivacy` did not exist. No vault of the owner's was on this machine.
- Launched `zprivacy.exe`. The window opens at **1280×720** at (10,10), title **«zprivacy»** (lowercase).
- After ~10 s and again after ~40 s the client area was **pure white**, both by screen copy and by `PrintWindow` with `PW_RENDERFULLCONTENT`. The process was alive and responding: CPU 0.5 s, 89 MB, 32 threads.
- `%LOCALAPPDATA%\ZPrivacy` was **created and stayed empty**: no `writing.lock`, no `settings.zcfg`, no `vault.zv`, no `sessions\`. `%USERPROFILE%\Documents\ZPrivacy` was not created.
- Reading (the lead's): on Linux the core writes `writing.lock` the moment it opens the folder, so here the core was never handed it, or the call into `z_bridge.dll` failed or never returned before the first frame. Not dug further: the reproduction with the fresh artefact comes first. Tools ready for it: DebugView for `main.dart`'s «bridge ok — <stamp>», and Process Monitor on `zprivacy.exe` for the DLL load path and file opens under the data folder.
- The owner's own eye on the window is still owed. A capture artefact is not excluded by me alone.

### Not done, and why

- **Step 1** (artefacts, `certutil` against `.sha256`, BUILD-INFO lines): waits for the owner's workflow run on the lead head after his push from Linux.
- **Step 2** (Windows' sentences while installing, both ways): the Inno install was done by the owner before this session. The MSIX does not exist yet.
- **Steps 3–5** (test vault, two copies, German walk): need clicks in the window, which is white. The owner clicks and I watch.
- **Step 6**: `winver`, VC++ and window size are above. Fonts and overflow wait for a window that draws.

Glass debts noticed: title «zprivacy», not «Z Privacy».
