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

## 21 October 2026 — second report: the workflow on the lead head, run 39508181140

**Why the first build had no stamp.** Every earlier «windows» run was on `main` at `c6cab87`: 2026-10-20 05:27Z, 05:34Z (the one the owner installed) and 22:11Z. None ran on the lead line. At the owner's request this session dispatched the workflow on `lead/the-day-of-the-attack`, using his GitHub login: run `39508181140`, head `4bb202f`.

**Result: the run is red.** Job «build and test z_core on Windows» is green. Job «build the desktop app on Windows» is red in two steps:

1. **Step 9, «Stamp it, prove it carries no runner path, and zip it», refuses on its own staging folder:**
   ```
   ?? staging/
   the tree is not clean. Commit, or set ALLOW_DIRTY=1 and the archive will say so.
   ```
   The workflow stages into `staging/` inside the checkout, and `scripts/package_windows.sh`'s clean-tree check sees that untracked folder. So no `BUILD-INFO.txt`, no zip, no `.sha256`. «Package an installer» and «An MSIX for sideloading» were **skipped**, and «Upload the archive, its hash and the MSIX» failed with `No files were found with the provided path: dist`. **Still no MSIX and no installer exist.** Steps 1 and 2 of the order remain blocked.
2. **Step 19, «Dart tests»: `+112 -71`, «Some tests failed».** The step prints only the last 40 lines, and the JSON record stays on the runner. In those 40 lines the visible cause is the test harness looking for the Linux bridge on Windows, in `setUpAll`, five times:
   ```
   Bad state: no build/linux/x64/debug/bundle/lib/libz_bridge.so — run `flutter build linux --debug` first
   ```
   Seen in `the_vault_before_the_work_test.dart:44`, `the_way_in_is_at_the_top_test.dart:68` and others, plus one `LateInitializationError: Local 'dir' has not been initialized.` (the teardown of a setUpAll that never set it). The bridge itself built with the test features, and the step confirmed «the DLL the suite will speak through carries the echo provider». The full list by file needs the JSON uploaded as an artefact, or more than `tail -40`.

**What did arrive:** the artefact `zprivacy-v1-windows-x86_64-folder-4bb202f` (the staged folder, 30 files), unpacked under `C:\Users\anash\z\artefacts\4bb202f\folder\`. Hashes match the run's own log:
- `zprivacy.exe` `d62b0459f2ab16ce218b8954d6f7933e88e8cad0dfbbeb03c97917ce249dad24`
- `z_bridge.dll` `8568a6b27619ba0bfa83518f2957f18bc5feb03aa1f04f29a4262118a442b366`

The folder now carries `LICENSE` and `third-party\` (eight notices). It carries no VC++ runtime DLLs: the app-local runtime of 098 would ride in the installer, which was not built.

### Red 1 of the first report — closed in the binaries, one line left in a notice

The four needles (`runneradmin`, `D:\a\`, `\.cargo\registry`, `/home/`), searched in ASCII and UTF-16 across all 30 files: **zero** in `zprivacy.exe`, `z_bridge.dll`, `app.so` and every DLL. The job's `RUSTFLAGS` now remaps `C:\Users\runneradmin\.cargo\registry\src=/crates`, `.rustup\toolchains=/rust`, `AppData\Local\Pub\Cache=/pub` and `D:\a\z-privacy\z-privacy=/zprivacy`. **One hit remains**, in a text file:
```
third-party\rust-crates.txt:62: z_core v0.1.0 (D:\a\z-privacy\z-privacy\z_core)
```
That is `cargo tree`'s own path for the workspace crate, written into the crate notice.

### Red 2 of the first report — the core now opens its folder; the window still captures white

- Launched `zprivacy.exe` from the unpacked folder. After 15 s the process was alive and responding (CPU 0.6 s), title still «zprivacy».
- **`%LOCALAPPDATA%\ZPrivacy` now holds `settings.zcfg` (179 bytes) and `writing.lock` (0 bytes).** The core was handed its folder and opened it, unlike the `main` build of the first report.
- Window at open: **1044×720** at (10,10). The first build opened at 1280×720.
- `PrintWindow(PW_RENDERFULLCONTENT)` still returns a pure white client area. A screen copy was not possible: the owner's screen was locked during this measurement (the screen reported 1024×768 and showed the lock image, against 1920×1080 in the first report). So **white by `PrintWindow` alone is not proof.** Flutter draws through D3D11/DirectComposition, which `PrintWindow` may not see. The owner's eye on the unlocked screen decides it.
- Loaded modules: `d3d11.dll`, `dxgi.dll`, `d3dcompiler_47.dll` and `OPENGL32.dll`, with VC++ from `System32` (`VCRUNTIME140.dll`, `VCRUNTIME140_1.dll`, `MSVCP140.dll`). `z_bridge.dll` comes from the app's own folder, so guess (b), a different DLL resolved, is excluded for this build.
- GPU: AMD Radeon Vega 8 (driver 31.0.21918.2005), HP EliteDesk 705 G5 Desktop Mini.

### Still owed

- A green app job (the dirty-tree refusal) and then the MSIX and the installer. Only then come steps 1–2 and the MSIX data-path question of step 3.
- The owner's eye on the window. If it draws, steps 3–5 follow with his clicks.

## 21 October 2026 (morning) — third report: the 4bb202f window paints; the white was the first minutes, not the build

**The owner's eye.** Asked on waking, he answered «الشاشة بيضاء» («the screen is white»). Then, asked which window and when: the window he had used was «ممتازة ولكنها كانت مفتوحة من البارحة», excellent, but open since last night. That was the instance started at ~01:16 (when `writing.lock` was written). In it he created a vault: `vault.zv`, 235 bytes, 05:50:34. That instance was killed by this session's `Stop-Process` seconds later, while preparing a relaunch. I did not know he was using it.

**Console.** Started from Git Bash, the build prints one line in 20 s and nothing after: `bridge ok — z_core 0.1.0 · 2026-10-20 · 4bb202f`. No exception and no FlutterError.

**A fresh launch, measured by screen copy on the unlocked screen (1920×1080).**
- About 10 s after launch, before any resize: **painted**. «Z Vault · Locked», «The vault is locked», a PASSPHRASE field and «Unlock». The owner was typing his passphrase into it at that moment.
- After a resize to 1200×760, minimize and restore, maximize (1936×1048) and restore: painted every time. The main surface shows «Z Privacy», VAULT «Unlocked», «+ Add a document — or write to the AI in the first part, with no document at all.», and the three parts ORIGINAL — LOCAL ONLY / SAFE — AI WILL RECEIVE / THE CHAT, with «What would you like to ask the AI?».
- UI Automation reports a single `Pane 'FLUTTERVIEW'` **while painting too**. The absence of a semantics tree is not evidence of no frame. Strike that inference from the morning's message.

**Reading.** The white of the first report (the `main` build) and of last night's 4bb202f captures was measured by `PrintWindow`, which does not see this window's content. For the second capture the screen was locked. The owner's own window from last night drew well. So **no white window is proven on 4bb202f.** What stays unexplained is the owner's «white» on waking. I did not ask which window that was, and I will not guess.

**Glass debts, unchanged:** title «zprivacy»; window opens at 1280×720 (1044×720 once).

**Not asked yet:** whether `vault.zv` is a test vault or the owner's real one. It is not touched either way.
