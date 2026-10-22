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

## 21 October 2026 (morning) — fourth report: step 3 measured, step 4 cannot be run on this build

**The 235-byte `vault.zv` in the real data folder is a test vault** (the owner, asked directly: «خزنة تجربة»). It stays untouched. Every step below ran in a separate data folder. The app was started with `LOCALAPPDATA=C:\Users\anash\z\testdata\LocalAppData`, and the core followed it to `…\testdata\LocalAppData\ZPrivacy`, so the owner's folder was not read or written. Build: the 4bb202f staged folder (no installer or MSIX exists yet, see the second report).

### Step 3 — where the vault lives (folder build; the MSIX half waits for an MSIX)

The owner, in the test instance: created a vault with the test passphrase `test-zd3-2026`, brought in `z_core\tests\fixtures\Brief_Weber.txt`, protected, and closed the window. Afterwards the data folder holds:

| file | bytes | written |
|---|---|---|
| `writing.lock` | 0 | 05:57:29 (at launch) |
| `settings.zcfg` | 179 | 05:58:26 |
| `vault.zv` | 364 | 06:00:06 |
| `sessions\1.zs` | 8163 | 06:00:06 |

- Path: `%LOCALAPPDATA%\ZPrivacy`, as `z_core\src\data_dir.rs` says, with no roaming. `%USERPROFILE%\Documents\ZPrivacy` was not created.
- Disk scan after close, UTF-8 and UTF-16, every file: none of 15 words from the fixture is in the clear (Betreff, Nachfrage, Rechnung, Katharina, Lindemann, Schreiben, September, Vertrag, Kundennummer, Tobias, Reinhardt, Filiale, Bahnhofstraße, München, Ihrer). The test passphrase is not on disk either.
- `writing.lock` stays at 0 bytes after close. The file remains, and the lock is the OS lock on it.
- The MSIX half of step 3 (is a packaged app's `%LOCALAPPDATA%` redirected under `Packages\<id>\LocalCache\Local\`?) cannot be measured until the job builds an MSIX.

### Step 4 — the lock: not run

Two instances started on the same test folder (A pid 13964, B pid 11044), side by side. **Both open and run together.** That is expected: the lock guards a write, not a launch. `vault.zv` (`CD451D7C38512B79…`, 364 bytes) and `sessions\1.zs` stayed unchanged while both were open.

The protect-in-A-then-in-B sequence was **not performed**. The owner, in his words: «هذه الحالة لم يتم إصلاحها بعد ولا يمكنني تجربة الحماية», this case has not been fixed yet and I cannot try the protection. So whether the second copy refuses with «Another copy of Z Privacy changed this vault…» on Windows is **not measured**. The `core` job's «One writer at a time» step (run 39508181140, green) remains the only Windows measurement of the lock.

**The lead's correction, recorded:** two instances opening together is not «expected». It is the finding step 4 exists for: paper 074's debt W4c, the Windows halves of the vault-file contracts, never measured. The two facts it asks for:

1. **What the second window showed: a normal surface, no refusal and no error.** The owner, with both open: «النافذتان تعملان معاً» (the two windows work together). My own screen copies of A and B could not be taken, because Windows kept the owner's browser in front and refused `SetForegroundWindow`.
2. **`writing.lock` while both ran, and after closing A then B.** Probed from PowerShell with `File.Open(…, ReadWrite, FileShare.None)` and then `FileStream.Lock(0,1)`:
   - with A and B both open: the exclusive open **succeeds** and the range lock **succeeds**. **Neither instance holds `writing.lock` open, let alone locked, while idle.**
   - A closed by `CloseMainWindow`: the same, free.
   - B closed the same way: the same, free. The file stays behind (0 bytes, unchanged since 05:57:29). `vault.zv` and `1.zs` are unchanged.

Reading, not a measurement: 093 says the lock is `std::fs::File::lock` taken in `session::with_core`, which would be per write, not held while open. If so, an idle second copy is not refused by design, and the refusal can only show at a write. That write the owner could not perform on 4bb202f.

*Amended (the lead, from `z_core/src/secure_file.rs:224–247`):* the lock is held for one core call and released after it, on Linux too, so both facts above are the design and not a W4c red. What stands between two copies is `Vault::ensure_disk_unchanged` at the next write (`VaultChangedElsewhere`). Step 4 on the new head is therefore: protect in A, then in B. B's disk-changed sentence is the pass, a silent success in B is the red, and A must keep working after.

### Step 5 — the German walk: waits for the next head (the lead: 096 and 680 sentences against 556 here)

## 21 October 2026 — fifth report: run 39548354872 on 17109b5

Dispatched by this session on `lead/the-day-of-the-attack` at `17109b5eab17b3cedccd79edd53b436075d126c5`, with the owner's GitHub login. **Red.** Job «build and test z_core on Windows» is green. Job «build the desktop app on Windows» is red.

### Item 1 (the runtime beside the exe): the new step fails on the runner's newer Visual Studio, and every artefact step after it is skipped

Step 9, «The runtime the application needs, beside the application»:
```
redistributable folder: C:\Program Files\Microsoft Visual Studio\18\Enterprise\VC\Redist\MSVC\14.51.36231
Exception: no CRT folder at C:\Program Files\Microsoft Visual Studio\18\Enterprise\VC\Redist\MSVC\14.51.36231\x64\Microsoft.VC143.CRT
```
The runner image now carries **Visual Studio 18 with MSVC 14.51**. The step hard-codes the folder name `Microsoft.VC143.CRT`, which is the VS 2022 toolset's name. Under a newer toolset the folder carries a newer number. (Not checked on the runner; this machine has VS 2022 17.14 Build Tools only.) Smallest fix: find the folder by pattern (`x64\Microsoft.VC14*.CRT`, exactly one match, else fail by name) instead of naming it.

Because step 9 threw, steps 10–13, 15 and 17 were **skipped**: the three DLLs and their versions, the needle search on the three built files, staging, BUILD-INFO and the zip, the installer, the MSIX. The uploads «archive, hash and MSIX» and «the folder» **failed** for lack of files. So:
- **Step 1 of the order (098 item 4's first red): still no artefact.** No zip, `.sha256`, BUILD-INFO, installer or MSIX.
- **Item 3 (the four needles, text notices included): not measurable.** Nothing staged was uploaded.
- **Item 1 (three runtime DLLs beside the exe, versions in the log): red at its first line**, as above.

### Item 4b (the Dart half, with its JSON): uploaded, and it reads 405 passed · 4 failed

The artefact `dart-tests-windows-17109b5` arrived. The JSON `dart.json` has 409 tests: **405 passed, 4 failed** (at 4bb202f the log showed +112 −71). The four, from the JSON:

1. `a_pdf_keeps_the_promise_test.dart` :: «the stated folder is the core's answer, and on Linux it is this one»
   `Expected: 'C:\Users\runneradmin/Documents/zprivacy'` · `Actual: 'C:\Users\runneradmin\Documents\ZPrivacy'`. The test builds the Linux shape (forward slash, lowercase). The core answers the Windows shape that `data_dir.rs` documents (`%USERPROFILE%\Documents\ZPrivacy`). The test's expectation is wrong on Windows, not the core.
2. `a_pdf_keeps_the_promise_test.dart` :: «the saved file carries the tokens and no original value»
   `Found 0 widgets with text containing C:\Users\RUNNER~1\AppData\Local\Temp/zprivacy-pdf-out-8708\text-protected-2026-10-21.pdf` — «the file was written without a word about where». The expected string mixes `/` and `\` (joined with `/` in the test), so it cannot match the glass's path. Same family as 1. Whether the glass names the folder at all is not proven either way by this test on Windows.
3. `messages_test.dart` :: «no widget interprets an ApiError by itself»
   `Expected: empty`, actual lists `lib\core\messages.dart: ApiError_OpenSuggestions(…)`, `…InputRefused…`, `…NotFound…`, `…StorageRefused…`. The guard exempts `messages.dart` by a forward-slash path, so on Windows the one sanctioned file is reported against itself. Same family: path separator in a test.
4. `contract_test.dart` :: «a document protects itself, driven from Dart»
   `Expected: <Instance of 'NetworkRefusal_NotConnected'>` · `Actual: NetworkRefusal_VaultLocked`. **Not a path.** On Windows the refusal comes back as «vault locked» where Linux answers «not connected». Either the order of the refusals differs, or the vault is locked at that moment on Windows (auto-lock clock, or a vault left by an earlier test). Not diagnosed further.

### Not done on this head

The Inno install in the test folder, step 4 as amended, and the German walk all wait for an artefact. None exists from this run.

## 21 October 2026 — sixth report: run 39586867441 on 268b964

Dispatched by this session on `lead/the-day-of-the-attack` at `268b96402be3df3b8d935e5eec764aaeb437e945`. **Red, one step from green.** Job «build and test z_core on Windows» is green. Job «build the desktop app on Windows» is red at step 13.

### Item 1 (the runtime beside the exe): green

The glob found exactly one folder: `C:\Program Files\Microsoft Visual Studio\18\Enterprise\VC\Redist\MSVC\14.51.36231\x64\Microsoft.VC145.CRT`, the toolset VS 18 carries. The three DLLs are beside the exe, their versions in the log and confirmed on the files: `vcruntime140.dll`, `vcruntime140_1.dll`, `msvcp140.dll`, all **14.51.36247.0**, Authenticode-valid (Microsoft Windows Software Compatibility Publisher).

### Step 1 (the three artefacts): BUILD-INFO exists, the archive does not

`package_windows.sh` got through the stamp, BUILD-INFO and the needle check, then failed on the zip:
```
== writing the archive
Compress-Archive : The path '/d/a/_temp/staging/zprivacy-v1-windows-x86_64' either does not exist or is not a valid file system path.
Compress-Archive failed
```
The script hands PowerShell's `Compress-Archive` an MSYS path (`/d/a/...`) from Git Bash. PowerShell needs `D:\a\...`. Smallest fix: convert with `cygpath -w` (or `pwd -W`) before the call. So again **no zip, no `.sha256`, no installer, no MSIX**: «Package an installer» and «An MSIX for sideloading» were skipped, and «Upload the archive, its hash and the MSIX» failed. **Step 1 is still blocked**, on its fourth attempt.

What did arrive is the folder artefact `zprivacy-v1-windows-x86_64-folder-268b964` (36 files), and it now carries **`BUILD-INFO.txt`** for the first time:
- `core stamp       z_core 0.1.0 · 2026-10-21 · 268b964`
- `product commit   268b96402be3df3b8d935e5eec764aaeb437e945`, «The tree was clean when these binaries were built.»
- built 2026-10-21T10:55:15Z, rustc 1.99.1, Flutter 3.44.2
- `zprivacy.exe` `e972f9ee0916c7e2dbc4ebbb3fa187477d0b161c220cfdbf7b8ef5502ecc4ec0` and `z_bridge.dll` `d988135e55fc5fd6c8da95d2aa5296b580e2462276e88c3c43690ff0ff3a37e5`. **Both hashes match the files in the folder.**

### Item 3 (the four needles over every file, text notices included)

The job's own check reports «no builder path in any of the 33 files searched» and names the three runtime DLLs as not searched («we did not compile them»). Searched here over all 36 files, ASCII and UTF-16: **zero** in every file we build and in every text notice. `rust-crates.txt` no longer carries `D:\a\`. The only hits are `D:\a\` once in each Microsoft runtime DLL, and they are Microsoft's own build path, not ours: `D:\a\_work\1\s\binaries\amd64ret\bin\amd64\\vcruntime140.amd64.pdb` (and `msvcp140.amd64.pdb`). That reading is right; the claim should keep saying «the files we compile».

### Item 4b (the Dart half): 414 passed, 0 failed

`dart-tests-windows-268b964/dart.json`: **414 passed · 0 failed**. The four reds of the fifth report (three path shapes, one VaultLocked for NotConnected) are gone.

### Not done on this head

The Inno install and the MSIX wait for the archive step. Step 4 (protect in A, then in B) and the German walk could run on the folder build in the test data folder now, with the owner's clicks, if the lead prefers not to wait for the installer.

## 22 October 2026 — seventh report (new Windows session): run 39719891044 on a70cfe9 — the zip is green, the MSIX step is red, the installer was built and not uploaded

**Session.** A new Claude session on the owner's Windows machine; z-d3 is offline. Trees pulled: product `lead/the-day-of-the-attack` at `a70cfe9` in `C:\Users\anash\z-privacy`, papers at `2340869` in `C:\Users\anash\z-privacy-papers`. Machine: Windows 11 Pro 25H2, now build **26200.9711** (the first report measured .7462; Windows updated in between). System32 VC++ x64 still 14.44.35211.

**Source-identical binaries.** `git diff --stat 268b964 a70cfe9` touches five files only: `docs/CLAIMS.md`, `docs/MEASURED_ON_LINUX.txt`, `scripts/package_windows.sh`, `scripts/gates.sh` and the new `scripts/check_powershell_paths.py`. Nothing under `lib/`, `z_core/src/` or `windows/`. The exe, the bridge DLL and `app.so` built at a70cfe9 are therefore built from the same source as 268b964's; only the packaging changed.

**How the run was started.** This session cannot read the owner's GitHub token (the permission classifier refuses to materialise it), and `gh` is not installed on this machine. The lead's session on Linux was blocked the same way. The owner dispatched from the Actions tab in the browser. His first click went to `main` at `c6cab87` (the branch picker's default), run `39719586362`, which is of no use here; the second, with the branch switched, is **run `39719891044` on `a70cfe9be8358d455d170bfa09df37291e50d532`**, created 2026-10-22 ~04:00Z. Note for the order's step 1: the public API lists runs, jobs, steps and artefact names without a token; job logs answer `403 Must have admin rights to Repository`, and artefact downloads need a token, so both went through the owner (downloads) and the lead (`gh` on Linux, logs). Unauthenticated polling is 60 calls an hour: a 45-second poll loop burns it in that time.

### Step colours

Job «build and test z_core on Windows»: **green throughout**, every step `success` by the API (04:00:00Z–04:28:30Z); the app job completed `failure` at 04:33:06Z with step 17 the only `failure` and step 20 the only `skipped`. Three artefacts: the archive (44,121,088 bytes), the folder (18,441,811), `dart-tests-windows-a70cfe9` (32,678). Job «build the desktop app on Windows»:

| # | step | colour |
|---|---|---|
| 1–7 | checkout, Flutter 3.44.2, Versions, the paths, staging folder, Flutter doctor | green |
| 8 | Build | green |
| 9 | The runtime the application needs, beside the application | green |
| 10 | The three are in the bundle, and these are their versions | green |
| 11 | Nothing in the three files we built says who built them | green |
| 12 | Stage the folder | green |
| **13** | **Stamp it, prove it carries no runner path, and zip it** | **green — first time.** Item 6 (`cygpath -w` at the one crossing) holds. |
| 14 | What is in it, and its hashes | green |
| 15 | Package an installer | green |
| 16 | What the installer is, and its hash | green |
| **17** | **An MSIX for sideloading** | **red** |
| 18 | How to install the MSIX (`if: always()`) | green (prints nothing: no MSIX) |
| 19 | Upload the archive, its hash and the MSIX (`if: always()`) | green → `zprivacy-v1-windows-x86_64-a70cfe9`, 44,121,088 bytes |
| **20** | **Upload the installer** | **skipped** |
| 21 | Upload the folder (`if: always()`) | green → `zprivacy-v1-windows-x86_64-folder-a70cfe9`, 18,441,811 bytes |
| 22 | The library the Dart half speaks through | green |
| 23–24 | Dart tests, upload of the record | green → `dart-tests-windows-a70cfe9`: **414 passed · 0 failed** (the lead, from the JSON) |

### Red 1 — step 17, the MSIX (the lead's reading of the log; this session could not fetch it)

`msix:create` asked the console «Do you want to install the certificate: "zprivacy-test.pfx" ? (y/N)»: its signing path looks for the certificate in `CurrentUser\Root`, and the job's throw-away certificate sits in `CurrentUser\My`. On a runner nobody answers; the prompt timed out with null and the tool exited **255**. The same step also ran `flutter build windows` a second time, after the needle search of step 11, so the files it would have packed are not the files that were searched. Paper 098 item 7 (the lead).

### Red 2 — step 20, the installer upload has no `if: always()`

Steps 19 and 21 carry `if: always()`; step 20 «Upload the installer» does not. When step 17 threw, step 20 was skipped although steps 15–16 had built `zprivacy-v1-windows-x86_64-setup.exe` and printed its hash. The installer exists on the runner only and is in no artefact. So on this head **there is still no installer and no MSIX to install**: the order's step 3 (SmartScreen sentences, the MSIX's sentences, the certificate store) and the MSIX half of step 4 wait for the next run. Also 098 item 7 (the lead).

**Two install texts disagree, for when an MSIX exists.** The workflow's own summary (step 18) says: in PowerShell **as administrator**, `Import-Certificate -FilePath .\zprivacy-test-certificate.cer -CertStoreLocation Cert:\LocalMachine\TrustedPeople`, then double-click. The lead's order says `certutil -addstore -user Root <cer>` with no administrator. The lead asks which store actually lets the MSIX sideload — per-user TrustedPeople or Root first, machine TrustedPeople second — so the summary can follow the fact. To be measured on the first MSIX.

### Step 2 of the order — the three artefacts, downloaded by the owner into `C:\Users\anash\z\artefacts\a70cfe9\`

**The archive and its hash: green.** `zprivacy-v1-windows-x86_64.zip.sha256` says `4f335283c2b12ccd3bdb55ea77e8e58c2ca90ff63907ac59a7940916c956f3a6 *zprivacy-v1-windows-x86_64.zip`; `certutil -hashfile … SHA256` answers the same, and `sha256sum -c` as BUILD-INFO instructs prints `OK`. The archive holds 36 files under `zprivacy-v1-windows-x86_64\`, **byte-identical** to the 36 files of the folder artefact (`diff -rq`), BUILD-INFO included.

**BUILD-INFO.txt** (first time it ships inside the archive):
```
core stamp       z_core 0.1.0 · 2026-10-22 · a70cfe9
product commit   a70cfe9be8358d455d170bfa09df37291e50d532
                 The tree was clean when these binaries were built.
built            2026-10-22T04:07:33+00:00, MINGW64_NT-10.0-26100 x86_64
rustc            rustc 1.99.0 (b940084d7 2026-09-28)
flutter          Flutter 3.44.2 • channel stable
  zprivacy.exe        509ffef96cd41a8b560239cc8532bf74dfafd3e14b8d0e0230bcf1e54053470f
  z_bridge.dll        2269dbb225a3a5b1e60e8d43d88c045a01c45b9fb806580f354d95020a27d2d6
```
Both hashes match the files (`sha256sum` here). `data\app.so` is `6e472c4f…5ead1`. The sixth report's BUILD-INFO said rustc 1.99.1; this one says 1.99.0: the runner image changed between the two runs.

**One glass debt in the zip itself.** Every one of the 37 entries is written with a backslash separator (`zprivacy-v1-windows-x86_64\BUILD-INFO.txt`), which is what `Compress-Archive` does. Windows Explorer and `Expand-Archive` read it fine. Info-ZIP `unzip` (Git Bash, Linux) warns «appears to use backslashes as path separators» and exits 1 after extracting; the lead should check on Linux whether his `unzip` flattens or nests them. The zip spec wants forward slashes.

**The runtime beside the exe: green, and it is the one loaded.** `vcruntime140.dll`, `vcruntime140_1.dll`, `msvcp140.dll` are in the folder, all **14.51.36247.0**, Authenticode valid (Microsoft Windows Software Compatibility Publisher). With the folder build running, `Get-Process` lists the three as loaded **from the application folder**, not from `System32` (which holds 14.44.35211). No VC++ dialogue at start.

**The four needles** (`runneradmin`, `D:\a\`, `\.cargo\registry`, `/home/`), ASCII and UTF-16, over all 36 files: zero in every file we build and every text notice. The only hits are Microsoft's own PDB paths inside the three runtime DLLs (`D:\a\_work\1\s\binaries\amd64ret\bin\amd64\vcruntime140.amd64.pdb` and siblings), as in the sixth report.

**Dart on Windows:** `dart-tests-windows-a70cfe9/dart.json` — **414 passed · 0 failed · 0 skipped**, `done.success = true`.

### An MSIX exists after all — unsigned, and with a bridge DLL the needle search never saw

The archive artefact `zprivacy-v1-windows-x86_64-a70cfe9` (dist/) holds four files, not three: the zip, its `.sha256`, **`zprivacy-test-certificate.cer`** (778 bytes, `CN=Z-privacy` self-signed, thumbprint `524C8713FE37013B3B0DCE58BE348568ACCDFBB4`, valid 2026-10-22 05:57 → 2027-10-22 06:17 local) and **`zprivacy-v1-windows-x86_64.msix`** (26,133,252 bytes). `msix:create` packed the MSIX before it died at the certificate prompt; what it never did is sign it:

- `Get-AuthenticodeSignature` on the MSIX: **`NotSigned`** — «The file … is not digitally signed.» There is no `AppxSignature.p7x` among its 115 entries. Windows will not install an unsigned MSIX by double-click, whatever store the `.cer` goes into, so the certificate-store question (per-user Root / TrustedPeople vs machine TrustedPeople) cannot be answered on this file. What the App Installer window says to an unsigned package is measurable and is below if the owner's eye reaches it.
- `AppxManifest.xml` identity: `Name=com.zprivacy.app`, `Publisher=CN=Z-privacy`, `Version=1.0.0.0`, matching pubspec's `msix_config`. The package family name, when it installs one day, will be `com.zprivacy.app_<hash of CN=Z-privacy>`.
- Content: `zprivacy.exe` and `data\app.so` are **byte-identical** to the folder's. **`z_bridge.dll` is not**: folder `2269dbb225a3a5b1…`, MSIX `78973af759a05e7f…`; same size (8,749,568), 23 bytes differ, the first at offset 257 (the PE header's link timestamp and the PDB signature — a relink of the same source by step 17's second `flutter build windows`). Its core stamp still reads `z_core 0.1.0 · 2026-10-22 · a70cfe9`, and the four needles over all 115 MSIX files give the same answer as the folder (zero in ours, Microsoft's PDB paths in the three runtime DLLs, which the MSIX also carries). So the second build did not leak a path this time — but the files in the MSIX are, by construction, not the files step 11 searched. 098 item 7 should make the MSIX pack the staged folder instead of rebuilding.
- The MSIX carries no `BUILD-INFO.txt`, `LICENSE` or `third-party\`: 115 entries are the Flutter bundle, the three runtime DLLs, `Images\` (the generated tiles) and the `resources*.pri`.

### Step 3 of the order (the two installs): not run on this head

No installer artefact (step 20 skipped) and the MSIX unsigned (above). The owner, finding the Start-menu «Z Privacy» (the `main`-branch Inno build of 20 October, which never opened its folder) would neither create a vault nor unlock his, asked for it to be removed: `unins000.exe /VERYSILENT` exited 0, `%LOCALAPPDATA%\Programs\Z Privacy` is gone, and `%LOCALAPPDATA%\ZPrivacy` (his 235-byte test vault) is untouched — the Inno script has no `UninstallDelete`, so the data folder survives an uninstall, which is the right behaviour and now measured. Only one Z Privacy exists on the machine now: the a70cfe9 folder build, started by a desktop shortcut «Z Privacy a70cfe9 (TEST)» that sets `LOCALAPPDATA=C:\Users\anash\z\testdata\a70cfe9\LocalAppData-A` before `zprivacy.exe`, as z-d3 did.

### Step 4 — where the vault lives (folder build, fresh test data folder)

Launch, before any click: `%LOCALAPPDATA%\ZPrivacy` (the test one) is created with **`writing.lock` (0 bytes) at once**, console prints `bridge ok — z_core 0.1.0 · 2026-10-22 · a70cfe9`, window 1280×720 at (10,10), title «zprivacy» (the glass debt stands). The owner, in the window: created a vault with a TEST passphrase, brought in `z_core\tests\fixtures\Brief_Weber.txt`, protected, named the session «الجلسة الاولى ويندز», and saved a z-pdf twice. The folder afterwards:

| file | bytes | written |
|---|---|---|
| `writing.lock` | 0 | 07:24:04 (launch) |
| `settings.zcfg` | 179 | 07:34:15 |
| `vault.zv` | 235 → **359** | 07:34:45 (created) → 07:43:20 (first protect) |
| `sessions\1.zs` | **50** | 07:43:20 |

- Path: `%LOCALAPPDATA%\ZPrivacy`, no roaming, as `data_dir.rs` says. `vault.zv` sha256 `dea53e0a384127bf…`, `1.zs` `93586744c56d1d14…`.
- Every file scanned, UTF-8 and UTF-16, for 15 fixture words and the test passphrase's prefix: **none in the clear.**
- `1.zs` is 50 bytes against z-d3's 8163 on 4bb202f. Whether that is a different session shape on this head or a session with less in it is for the lead to read; the fixture's text is not in it either way.
- **The z-pdf goes to the real Documents folder.** `C:\Users\anash\Documents\ZPrivacy\` did not exist before; it now holds `الجلسة الاولى ويندز-protected-2026-10-22.pdf` (07:49:03) and `…-2026-10-22-2.pdf` (07:50:06), 17,690 bytes each, differing only near the end (byte 17,410 on: the trailer). `%USERPROFILE%\Documents` is not under `LOCALAPPDATA`, so the test override does not reach it — by design of `data_dir.rs`, and worth knowing for any Windows test plan: the z-pdf lands in the owner's real Documents even when the vault is redirected.
- The z-pdf, read with `pdftotext`: PDF 1.5, one font `DejaVuSans`, umlauts and ß intact (für, München, Grüßen, Lindenstraße, Düsseldorf). Page 1 is the letter with **21 tokens** (`__Z_407A_PERSON_…`, `_IBAN_`, `_BIC_`, `_PHONE_`, `_EMAIL_`, `_CUSTOM_`): the protected values (Katharina, Lindemann, Tobias, Reinhardt, Bahnhofstraße, the IBAN, phones, e-mails) are **not in the text**. Words left in the clear are the ones the owner did not protect (Markus Weber, Sophie Brandt, Yusuf Demir, Augsburg, Lindenstraße 8, the ID-card number L01X00T47, the plate A-MW 2041, the tax numbers) — a fact about his clicks, not about the core. Page 2 is the added page (rule 80): `z-pdf · protected copy · z_core 0.1.0 · 2026-10-22 · a70cfe9 · 21 places replaced, 18 values (BIC ×1, E-mail ×2, IBAN ×1, Person ×6, Phone ×3, Something else ×5) · sha256 of the protected text 4a4f99ed…`. **The added page's first line** is `Z-pdf : __Z_407A_CUSTOM_18680BFB__`, a 19th token not among the 18 counted. It is the glass's `zPdfAnswerLine` («Z-pdf : {token}», the same in `app_de.arb`), so it is by design, not a leak of the Arabic session name; what the token stands for is for the lead to say if it matters.
- What Settings shows as the vault folder: owed from the owner's eye (asked).
- The owner's eye on the rest of step 4: Settings shows the vault folder as `C:\Users\anash\z\testdata\a70cfe9\LocalAppData-A\ZPrivacy` (his words: «هذا الرابط هو موقع الخزنة على الجهاز»), i.e. the redirected `%LOCALAPPDATA%`, so the glass reads the folder from the core and does not type it. The z-pdf save sentence named the document and its place in Documents.
- After the window closed (07:57:58): `vault.zv` **1620** bytes (07:48:55), `1.zs` 50 (07:49:03); exclusive `File.Open(ReadWrite, FileShare.None)` on `writing.lock` succeeds, so nothing holds the lock between calls, as `secure_file.rs` says.

### Step 5 — the lock, two copies on one test folder: no refusal sentence was seen, and both copies' writes landed

Both copies were started by the launcher on the same `LocalAppData-A`, A placed left and B right, and the folder was hashed every 2 s. Two runs.

**Run 1 (07:58–08:11) did not test the lock**: the owner, in his words, did everything in A «without any problem», **then closed A**, moved to B, reopened the document from the session («تم بنجاح»), then brought the file in again from disk, «نعم بنجاح دون أي اعتراض أو إزعاج» — with no objection. B was alone with the vault by then. Disk: A's writes 08:03:10–08:05:04 (`vault.zv` 1620 → 1681 → 1741 → 1805, three protects; `1.zs` rewritten each time), then B's session writes 08:06:15 and 08:06:33 (`1.zs` 3557 → 7121 → 7130, `vault.zv` unchanged: reopening and importing write the session, not the vault).

**Run 2 (08:12–, both windows open throughout)**, relaunched with the instruction «protect in A, then protect in B, close nothing». The disk, from the 2-second hash watch:

| time | `vault.zv` | `1.zs` | `2.zs` | reading |
|---|---|---|---|---|
| 08:12:41 | 1805 | 7130 | — | baseline, both copies on the locked screen |
| 08:14:09 | **1867** | 7192 | — | a protect, by the copy holding session 1 |
| 08:14:35 | **2646** | 7192 | **3687 (new)** | a protect from a copy that opened a *second* session |
| 08:14:44 | **2705** | 7192 | 3811 | another protect from session 2 |
| 08:15:36 | **2735** | **7316** | 3811 | a protect from session 1 again — 52 s after session 2 changed the vault |
| 08:20:12, 08:20:20 | 2735 | 10953, 10962 | 3811 | session 1 writes, no vault write |

Every one of these writes succeeded on disk; none left a torn file (sizes grow, hashes change, no 0-byte or `.tmp` ever seen in the listing). The owner's account of what the windows showed, in his words: «الحماية من نفس الجلسة وعلى نفس الوثيقة انتقلت مباشرة» — a protection made in one window, same session and same document, **appeared in the other window at once**; «ولكن عند أضفت حماية على جلسة جديدة لم تنتقل مباشرة إلى الجلسة السابقة، وكذلك لم تنتقل بين وثيقتين من نفس الجلسة» — a protection added in a new session did **not** appear at once in the older session, nor between two documents of one session; and when he then made a new session and brought the same document in, **all earlier protections were present in it**. **He reports no refusal sentence in either window at any point** («دون أي اعتراض») — «Another copy of Z Privacy changed this vault. Close that window, or lock and unlock here to take in its work.» was not seen.

Reading, for the lead, not a verdict: `Vault::with_open_mut` refuses when `vault.zv` on disk differs from the bytes this copy last read or wrote (`ensure_disk_unchanged`, `vault/mod.rs:791`). The 08:15:36 write by session 1, 52 s after session 2 had rewritten the file twice, went through — so either the glass had re-read the vault from disk before writing (the owner saw the other window's protections «at once», which says the glass does rescan the file and take the change in), or the two sessions sat in the same window and the order of windows is not what the table assumes. The owner's sequence of clicks is his account, not a measurement; what is measured is: with two copies open on one vault, **writes from both interleaved on disk, nothing was lost that he could see, and no refusal sentence was shown.** Whether a copy that re-reads before writing is the 050/A design on this head, or a silent success that 050/A forbids, is the lead's to read in `session_state.dart`'s rescan.

A wish of the owner's, for the glass list: the session's name shown at the top of the window («لو استطعنا أن يظهر اسم الجلسة في أعلى الشاشة»); today the title bar says «zprivacy».

### Step 7 — `winver` and the runtime at start

`winver` (registry): Windows 11 Pro, DisplayVersion **25H2**, build **26200.9711** (the first report measured 26200.7462 on 20 October; the machine updated). The a70cfe9 folder build started six times today without any VC++ dialogue; each time `Get-Process` showed `vcruntime140.dll`, `vcruntime140_1.dll` and `msvcp140.dll` loaded from the application's own folder (14.51.36247.0), never from `System32` (14.44.35211). The Flutter console printed once, on one of the six starts: `[ERROR:flutter/lib/ui/window/platform_configuration.cc(448)] Reported frame time is older than the last one; clamping.` — Flutter's own engine notice, no effect seen.

### Step 6 — the German walk

Static half, before the owner's eye: `app_de.arb` has all 686 keys of `app_en.arb`, none missing; nine values are identical to the English and legitimately so (`Person`, `Passphrase`, `Name`, the example names, `{act} · {needs}`, `Z-pdf : {token}`). So any English sentence the owner finds on screen in Deutsch is typed outside the arb files, which is what the walk is for.

## 22 October 2026 — eighth report: run 39734294387 on 8eb7fc8 — the installer travels, the MSIX still does not sign

Dispatched by the owner from the Actions tab after the lead's push of 098 item 7 (`8eb7fc8`). Core job **green throughout**. App job red at two steps, by the API: **17 «An MSIX for sideloading» failure**, 18 «What the MSIX packed is what was measured» skipped, **19 «An unsigned package is not handed to anybody» failure** — the new guard doing its work: no MSIX in any artefact. Every other step green, uploads included (all `if: always()` now). Four artefacts: `zprivacy-v1-windows-x86_64-setup-8eb7fc8` (**15,041,217 bytes — the Inno installer, uploaded for the first time**), `zprivacy-v1-windows-x86_64-8eb7fc8` (18,089,461: zip + `.sha256` + BUILD-INFO, no MSIX, no `.cer`), `zprivacy-v1-windows-x86_64-folder-8eb7fc8` (18,441,799), `dart-tests-windows-8eb7fc8` (32,730).

**Step 17's cause (the lead, from the log):** the certificate was selected this time, then `SignerSign() failed (0x80096005)`. The msix tool appends `/tr http://timestamp.digicert.com` (no `/td sha256`) to every pfx signing — a SHA-1 timestamp request that server no longer answers. A throw-away certificate needs no timestamp; 098 item 8 (ed) passes the signtool options through the tool's own door without `/tr`.

Unauthenticated job logs remain 403 here; the lead reads them with `gh` on Linux. Polling note: 4-minute polls on the public API stayed within the 60/hour limit for the whole run.

## 22 October 2026 — ninth report: run 39761244511 on 78988fd — the app job is green end to end; the core job hit its 30-minute clock

Measured from this Windows session with the public API only (no token, no job logs). Started by the owner from the browser at 10:11:39Z, actor YourVoicesApp.

**Job «build the desktop app on Windows» — success**, 10:11:46Z → 10:44:42Z. Every step green, including the three that were red or skipped on a70cfe9 and 8eb7fc8:

| step | name | colour | ended |
|---|---|---|---|
| 17 | An MSIX for sideloading | green | 10:22:44Z |
| 18 | What the MSIX packed is what was measured | green | 10:22:44Z |
| 19 | An unsigned package is not handed to anybody | green | 10:22:45Z |
| 20 | How to install the MSIX (new step on this head) | green | 10:22:45Z |
| 21–23 | Upload the archive, its hash and the MSIX / the installer / the folder | green | 10:22:48–54Z |
| 25 | Dart tests | green | 10:44:36Z |

Only annotation on this job: the Node.js 20 deprecation warning for actions/checkout@v4 and actions/upload-artifact@v4.

**Job «build and test z_core on Windows» — cancelled**, 10:11:44Z → 10:43:02Z. All ten named steps green; the job's annotation reads exactly: «The job has exceeded the maximum execution time of 30m0s». `timeout-minutes: 30` at line 35 of `.github/workflows/windows-core.yml`. Step 6 «Rust tests» took the clock:

| run | head | Rust tests | One writer at a time | core job total | conclusion |
|---|---|---|---|---|---|
| 39719891044 | a70cfe9 | 1404 s | 158 s | 28 m 30 s | success |
| 39734294387 | 8eb7fc8 | 1533 s | 139 s | 29 m 28 s | success |
| 39761244511 | 78988fd | 1611 s | 155 s | 31 m 18 s | cancelled (clock) |

The three runs were on the same sources for z_core; the Rust test step grew 1404 → 1533 → 1611 s with no change in the tree, i.e. the runner's speed, not ours. The job was already past the 30-minute line when step 10 finished, so the clock cut it after the last named step — nothing was skipped, nothing was red. Reading: the 30-minute budget is too tight for this suite on a GitHub-hosted Windows runner; the next run with a slower runner will be cut before step 9, and the lock test will not run.

**Artefacts (4):**

| name | bytes |
|---|---|
| dart-tests-windows-78988fd | 32 640 |
| zprivacy-v1-windows-x86_64-78988fd | 44 167 519 |
| zprivacy-v1-windows-x86_64-setup-78988fd | 15 041 851 |
| zprivacy-v1-windows-x86_64-folder-78988fd | 18 441 818 |

The main archive grew from 18 089 461 (8eb7fc8) to 44 167 519 bytes: it now carries the MSIX and the `.cer` beside the zip, per the lead's reading of the log. The installer is 634 bytes larger than the 8eb7fc8 one (stamp only; same sources).

The install measurements (Inno installer, MSIX certificate store, vault folder under the MSIX, winver) follow below once the owner has downloaded these artefacts.

## 22 October 2026 — tenth report: the 78988fd artefacts on this machine — hashes, the signed MSIX, the Inno installer, SmartScreen, and the first vault-survival measurements (paper 101)

Everything below ran on this Windows 11 Pro machine (build 26200.9711, display language Swedish) with TEST data folders reached through the `LOCALAPPDATA` override, as z-d3 did. The owner's real `%LOCALAPPDATA%\ZPrivacy` (settings 179 B, vault.zv 235 B, writing.lock 0 B; last write 07:31:15) was checked after every step and never changed. No passphrase, no fixture words, no document of the owner appears here.

### Step 2 of the order — the artefacts of run 39761244511

The owner downloaded the four artefacts from the run page in the browser (18:54–18:55 local); I moved them into `C:\Users\anash\z\artefacts\78988fd\`.

| artefact | bytes | inside |
|---|---|---|
| zprivacy-v1-windows-x86_64-78988fd.zip | 44 167 519 | `zprivacy-v1-windows-x86_64.zip` 18 159 979 · `.zip.sha256` 97 · `zprivacy-v1-windows-x86_64.msix` 26 178 614 · `zprivacy-test-certificate.cer` 778 |
| zprivacy-v1-windows-x86_64-setup-78988fd.zip | 15 041 851 | `zprivacy-v1-windows-x86_64-setup.exe` 15 543 717 |
| zprivacy-v1-windows-x86_64-folder-78988fd.zip | 18 441 818 | not expanded (the zip's contents were checked instead) |
| dart-tests-windows-78988fd.zip | 32 640 | `dart.json` 308 007 |

- `certutil -hashfile` of the inner zip: `b5ea39613214b9007e5f33e593b6e38ffb5bc4fd83b92278870147e218ce3d7c` — **equals the `.sha256` line**.
- BUILD-INFO.txt: `core stamp  z_core 0.1.0 · 2026-10-22 · 78988fd`; `product commit  78988fdad8405154b88193281bc9531026605113  "Merge 098 item 8 (ed): the MSIX is signed by a command this job wrote, and no timestamp is asked of anybody"`; «The tree was clean when these binaries were built.»; built `2026-10-22T10:22:14+00:00`, rustc 1.99.0, Flutter 3.44.2.
- The two product hashes in BUILD-INFO match the files: `zprivacy.exe eeeddaad…0eb99`, `z_bridge.dll 0907c1e0…247d92`.
- Installer `sha256 859906a9bb9360a6a3b972f7f3e6db4648a62fff8ba39be786e111b4f750e0f3`; `Get-AuthenticodeSignature` → **NotSigned** (as designed; it is 634 bytes larger than the 8eb7fc8 installer, stamp only).
- **The MSIX is signed.** `sha256 febe746a1006c589c795273db7fbff1c7b016a4dd2efd1320b7b4060a8672299` (the lead's reading of the log, confirmed on disk). `Get-AuthenticodeSignature` → Status **UnknownError**, StatusMessage in the machine's Swedish: «En certifikatkedja bearbetades men avslutades med ett rotcertifikat som inte är betrott av modulen för kontroll av förtroende» (a chain was built but ends in a root the trust provider does not trust — the expected reading before the `.cer` is installed; it is **not** NotSigned, which is what a70cfe9's MSIX said). Signer `CN=Z-privacy`, thumbprint `B66B86FA1917697A1066B471BF3375647737F57A`, no timestamper (098 item 8 asked none).
- `zprivacy-test-certificate.cer`: self-signed, Subject = Issuer = `CN=Z-privacy`, sha256RSA, NotBefore 2026-10-22 12:12, NotAfter 2027-10-22 12:32 (local time), sha1 `b66b86fa…f57a` = the signer above, sha256 `790e0a33…cde43`. Different from a70cfe9's throw-away cert (`524C8713…DFBB4`): each run mints its own.
- AppxManifest inside the MSIX: Name `com.zprivacy.app`, Publisher `CN=Z-privacy`, Version `1.0.0.0`, x64, Application Id `zprivacy`, Executable `zprivacy.exe`; 117 entries.
- **The six files inside the MSIX hash the same as the zip's copies**: zprivacy.exe, z_bridge.dll, data/app.so, vcruntime140.dll, vcruntime140_1.dll, msvcp140.dll — all SAME. (On a70cfe9 the MSIX's z_bridge.dll differed from the folder's; on 78988fd it does not.)

**What the Dart numbers count.** `dart.json` is the `dart test --reporter json` event stream. Counting `testDone` events: **414 visible tests, all `success`, 0 skipped** — the same 414 on a70cfe9 and 78988fd. A further **205 `testDone` events carry `hidden: true`**: these are not tests of ours but the runner's bookkeeping entries — 75 «loading <file>» entries (one per test file; 75 suites) and 130 `setUpAll`/`tearDownAll` hook entries. So «414 · 0» means 414 real tests passed and none failed or were skipped; the 205 hidden entries are the plumbing and are listed here only so the 619 raw `testDone` lines in the file are accounted for. Final `done` event: `success: true`, 1 197 868 ms.

### Expand-Archive drops the Mark of the Web — the SmartScreen measurement, stated both ways

This has its own heading because it is the path our users will take.

- The downloaded artefact zip carries the mark: `Get-Content -Stream Zone.Identifier` on `zprivacy-v1-windows-x86_64-setup-78988fd.zip` → `[ZoneTransfer] ZoneId=3 ReferrerUrl=https://github.com/YourVoicesApp/z-privacy/actions/runs/39761244511 HostUrl=https://productionresultssa15.blob.core.windows.net/…`.
- I expanded that zip with PowerShell 5.1 `Expand-Archive`. The extracted `zprivacy-v1-windows-x86_64-setup.exe` had **no Zone.Identifier stream**. `Expand-Archive` does not propagate the mark (Explorer's «Extrahera alla» does).
- **Consequence, first way:** the owner double-clicked that exe twice and saw **no SmartScreen at all** — no blue screen, no «Mer information», no admin prompt; the installer simply ran. His first reading («the app was already on the machine») was not the cause; the missing stream was. My error, recorded as such.
- I then wrote the stream back onto the exe (`Set-Content -Stream Zone.Identifier`: ZoneId=3 + the run's ReferrerUrl) — the state a browser-downloaded `.exe` is in.
- **Consequence, second way:** on the third double-click the owner saw the SmartScreen screen («Windows skyddade datorn» — the owner confirmed the screen and the two clicks; he did not transcribe the body text), needed **«Mer information» → «Kör ändå»**, then the installer ran. **No administrator prompt** (`PrivilegesRequired=lowest`). After the run the exe's Zone.Identifier stream was **gone** — Windows removes it on «Kör ändå», so a second launch of the same file shows nothing.
- Reading for rule 81's download-page sentence: a bare `.exe` downloaded by a browser **will** show SmartScreen once and need «More info → Run anyway»; an `.exe` extracted from a zip by PowerShell `Expand-Archive` will **not** show it; one extracted by Explorer will. Whether the unsigned installer is ever blocked outright (no «Run anyway» offered) was not seen on this machine: the button was offered every time.

### Step 3 — the Inno installer, three installs

- All three installs (the two without SmartScreen and the one with) completed with no error sentence, no administrator prompt, no VC++ redistributable dialogue.
- Install folder `C:\Users\anash\AppData\Local\Programs\Z Privacy\` (= `{autopf}` at lowest privilege = `%LOCALAPPDATA%\Programs`), 14 entries: BUILD-INFO.txt, LICENSE, README.txt, `data\`, `third-party\`, file_selector_windows_plugin.dll, flutter_windows.dll, **msvcp140.dll, vcruntime140.dll, vcruntime140_1.dll beside zprivacy.exe**, z_bridge.dll, zprivacy.exe, unins000.dat, unins000.exe.
- Registry `HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\…`: DisplayName «Z Privacy», DisplayVersion «1.0.0», InstallLocation the folder above, InstallDate 20261022, Publisher **«Faruk AB»** (the `Publisher` define handed to `zprivacy.iss`; recording the value, not judging it), UninstallString `"…\Z Privacy\unins000.exe"`.
- Shortcuts: `Z Privacy.lnk` on the desktop (OneDrive-redirected `Skrivbord`) and in the user Start menu, target the installed exe, working directory the install folder.
- **The installer's final «Launch Z Privacy» box, left ticked, opened the app on the owner's real `%LOCALAPPDATA%\ZPrivacy`** (no override possible from an installer-launched process). He closed it without unlocking; the real vault.zv stayed 235 bytes, last write 05:50:34. Worth one line on the download page: untick «Launch» if you want to start it yourself.
- Installed copy launched by me with `LOCALAPPDATA=C:\Users\anash\z\testdata\78988fd\LocalAppData-inno` (launcher `C:\Users\anash\z\testdata\78988fd\launch-inno.ps1`): console line **«bridge ok — z_core 0.1.0 · 2026-10-22 · 78988fd»**; `writing.lock` 0 B appeared at 19:40:10 in the test folder. The owner made a TEST vault: at 19:57:35 `vault.zv` 235 B and `settings.zcfg` 179 B — a fresh vault with no session and no protected words (same sizes as a fresh vault on a70cfe9). No `sessions\` folder, nothing new under `Documents\ZPrivacy`.
- **Settings → the vault-location line** showed the overridden path `C:\Users\anash\z\testdata\78988fd\LocalAppData-inno\ZPrivacy` (the owner: «the same line you wrote»). So the installed copy follows `%LOCALAPPDATA%`, plain, no redirection — the Inno half of paper 101 item 3's question.
- **German walk on this copy** (Settings → Language & rules → Deutsch, then the session screen, settings, the button bar; vault forms, name review, send sheet and identity card skipped): the owner reports no English leftovers, window size fine, no text out of its box; «راضٍ» (satisfied). The static half from the seventh report stands: 686 keys, 0 missing, 9 identical to English.

### Open finding — stored language vs applied language

`settings.zcfg` in the test folder, printable bytes only (no secret values exist in this file): `ZCFG1 · schema_version=1 · first_run_completed=true · ui_language=sv · default_privacy_pack=sv · original_pane_percent=50 · columns_in_step=true · safe_column_open=true · review_panel_wide=false`. The stored `ui_language` is **sv** (the machine's display language). The owner's eye: **the interface appeared in English from the first screen**, and he later switched to Deutsch and back. The owner did not read the «selected language» control in Settings before switching, so what the control showed is not known. **Not resolved here**: it needs a clean measurement — a fresh data folder, no clicks, read Settings' language control and the on-screen language, then read `settings.zcfg` — stored value vs applied value is the seam. Note also the owner's a70cfe9 settings file was 179 bytes too, so the same content very likely stood there.

### Paper 101 item 2 — Inno uninstall: the test vault stands

Done by the owner through Inställningar → Appar → Installerade appar → Z Privacy → Avinstallera, at about 20:11 local, with no copy of the app running (he closed his real-folder window first).

- The owner's words: **no administrator prompt**; the remover **asked once whether he was sure about the removal** (Inno's standard confirmation, «Är du säker på att du vill ta bort Z Privacy och alla dess komponenter?» in this machine's language — the owner confirmed the question, not the wording). No question about user data, no error sentence.
- After it: `C:\Users\anash\AppData\Local\Programs\Z Privacy\` **gone** (parent `Programs` last write 20:11:48); the HKCU uninstall entry **gone**; the desktop and Start-menu `Z Privacy.lnk` **gone** (my `Z Privacy a70cfe9 (TEST).lnk` stays, it is not the installer's).
- **The TEST vault folder stands untouched**: `C:\Users\anash\z\testdata\78988fd\LocalAppData-inno\ZPrivacy` still holds settings.zcfg 179 B, vault.zv 235 B, writing.lock 0 B, all with their 19:40/19:57 times. Nothing in `zprivacy.iss` names the data folder (no `UninstallDelete`), and the remover did not look for it.
- The owner's real `%LOCALAPPDATA%\ZPrivacy`: unchanged (07:31:15 / 05:50:34 / 01:16:52).

Reading: with the Inno installer, uninstalling the program leaves the vault where it was, as paper 101 expects. The MSIX half of the same question follows.

### Step 3b — the MSIX: which certificate store lets it sideload

Before any store was touched: `certutil -user -store TrustedPeople`, `-user -store Root` and the machine `-store TrustedPeople` held **0** `Z-privacy` entries; no `HKLM\…\AppModelUnlock` key (no developer mode), no Appx sideload policy values; `Get-AppxPackage *zprivacy*` empty; no `com.zprivacy.app*` folder under `%LOCALAPPDATA%\Packages`. The owner gave his yes for the certificate («موافق على الشهادة») before the first rung.

What the test certificate can do, from `certutil -dump`: Key Usage **Digital signature** only (critical); Extended Key Usage **Code signing (1.3.6.1.5.5.7.3.3)** only; Basic Constraints **end entity** (not a CA), critical; so trusting it anchors nothing but code signed with this one key, for one year.

The manifest, for the record: `runFullTrust` and **`internetClient`** capabilities (the App Installer shows the latter to the user as «Använda din Internetanslutning» — a privacy app announcing it may use the internet connection; recording it, it is `msix_config`'s default), `EntryPoint="Windows.FullTrustApplication"`, `MinVersion 10.0.17763.0`, `MaxVersionTested 10.0.22621.2506`, no `desktop6:FileSystemWriteVirtualization` / `RegistryWriteVirtualization` element (so both stay at their default, enabled).

**Rung 1 — `certutil -addstore -user TrustedPeople <cer>`** (no administrator, no dialogue): `Certificate "Z-privacy" added to store.` `Get-AuthenticodeSignature` on the MSIX still **UnknownError** (chain ends in an untrusted root). The owner double-clicked the MSIX. App Installer («Appinstallerare») showed — from his screenshot, read from the clipboard, saved as `C:\Users\anash\z\testdata\78988fd\shot-clipboard-1.png`:

> **Installera Z Privacy?** · Utgivare: **Okänt** · Version: 1.0.0.0 · Källa: C:\Users\anash\z\artefacts\78988fd\dist\zprivacy-v1-windows-x86_64.msix · Funktioner: • Använda alla systemresurser • Använda din Internetanslutning
>
> (red box) **«Appaketets utgivarcertifikat är inte signerat med ett betrott certifikat. Kontakta systemadministratören eller apputvecklaren för att få ett nytt app-paket med betrodda certifikat. Rotcertifikatet och alla omedelbara certifikat för signaturen i App-paketet måste…»** (cut by the box; the English original is 0x800B010A's «The root certificate and all immediate certificates of the signature in the app package must be trusted.»)
>
> «Installera» **greyed out**, «Avbryt» active.

**Result: user TrustedPeople is not enough on this machine** — the publisher reads «Okänt» and the Install button is dead.

**Rung 2 — `certutil -addstore -user Root <cer>`** (no administrator; Windows showed its security-warning box about installing a root certificate from «Z-privacy», thumbprint B66B86FA…F57A, and the owner clicked «Ja»): `Certificate "Z-privacy" added to store.` `Get-AuthenticodeSignature` on the MSIX now **Valid — «Signature verified.»** The user Root store now lists the certificate (certutil counts 2 lines for the one entry: Issuer and Subject).

After rung 2 the owner double-clicked the MSIX again. App Installer now showed (screenshot `02-appinstaller-user-root-install-enabled.png`, 20:42): **«Installera Z Privacy? · Utgivare: Z-privacy · Version: 1.0.0.0 · Källa: …\zprivacy-v1-windows-x86_64.msix · Funktioner: • Använda alla systemresurser • Använda din Internetanslutning»**, checkbox **«Starta när du är redo»** ticked by default, **«Installera» enabled**, «Avbryt».

**Ladder answer on this machine:** user TrustedPeople alone — refused; **user Root — accepted**, no administrator; machine TrustedPeople — not reached, not tried.

### Finding 1 — `internetClient` in the manifest

- Source, precisely: **`apps/flutter_app/pubspec.yaml` line 93, `capabilities: internetClient`**, inside `msix_config`, written explicitly by commit 816da44 (2026-10-19, «Windows from git: the app job stamps, proves, zips, packs an MSIX, and runs the Dart half»). It is not the msix package's silent default: the line is in our file (the `msix` package, 3.16.8, would also put `internetClient` in when the key is absent, so removing the line alone may not remove the capability — to be measured, not assumed).
- What the manifest carries: `<Capability Name="internetClient" />` and `<rescap:Capability Name="runFullTrust" />`.
- What App Installer announced to the user, verbatim: **«Funktioner: • Använda alla systemresurser • Använda din Internetanslutning»** (the first line is `runFullTrust`, the second is `internetClient`).
- Nothing changed. Debt for ed: whether a `runFullTrust` desktop-bridge package needs `internetClient` at all (full-trust code reaches classic Winsock regardless of the capability sandbox; Z uses the network for send-via-key, so the question is whether the line is needed, not whether the app may connect), and what App Installer announces when the line is absent.

### Finding 2 — the Root-store rung is a finding about the download page

What the owner did to make «Installera» light up was `certutil -addstore -user Root` on a self-signed certificate, answered «Ja» to Windows' own warning box. That is a real trust grant in his account: anything signed by that key is trusted code on this machine for a year. Its reach on this particular certificate is bounded by what the cert says about itself — EKU **code signing only**, end entity — and Windows honours a root's EKU when it builds chains, so this one cannot vouch for a TLS server or an e-mail signer; but it does vouch for any executable signed by a private key that lived on a GitHub runner for the length of one job. An honest download page cannot instruct ordinary users to add a root certificate for us. **Reading for rule 81:** the MSIX route waits for a real signing certificate (the Microsoft application) or the Store; on publishing day the Inno installer with the honest SmartScreen sentence (one blue screen, «Mer information» → «Kör ändå», no administrator) is the route that carries. The ladder was measured so the page is written from measurement, not hope.

**Correction to the ladder answer, two minutes later — rung 2 lights the button but the deployment is refused.** The owner clicked «Installera» (20:44). App Installer then showed (screenshot `03-appinstaller-user-root-deploy-0x800B0109.png`):

> **Installationen av Z Privacy misslyckades** · Utgivare: Z-privacy · Version: 1.0.0.0 · Källa: … · Funktioner: (the same two) · **Orsak: «Appinstallationen misslyckades med felet: error 0x800B0109: The root certificate of the signature in the app package or bundle must be trusted. (0x800b0109)»**

and a toast from «Appinstallationsprogram» with the same sentence. `Get-AppxLog` for 20:44:47, in order: 603 «Started deployment Add operation … Options ForceApplicationShutdownOption,ForceTargetApplicationShutdownOption,ForceUpdateFromAnyVersion,NormalPriorityRequest»; 154 «error 0x800B0109: The root certificate of the signature in the app package or bundle must be trusted.»; 465 «Opening the package from location … failed.»; 497 «Error 0x80070002: Opening the Msixvc package … failed. Please check whether the Msixvc support services are installed.» (a side probe, not the cause); 403 «Failure to get staging session»; 404 «AppX Deployment operation failed for package with error 0x800B0109»; 613 «Failed to reach state DeQueued, overall time 141 ms».

Reading: App Installer's front page validates the signature in the **user's** context (user Root made it say «Utgivare: Z-privacy» and enabled the button), but the AppX deployment service validates in the **machine's** context and never looks at the user's Root store. So the per-user stores — TrustedPeople and Root both — do not let this MSIX install on a stock Windows 11 Pro; the ladder goes on to the machine TrustedPeople store, which needs an administrator. Nothing was installed: `Get-AppxPackage com.zprivacy.app` empty, no `Packages\com.zprivacy.app_*` folder, no process.

**Rung 3 — machine TrustedPeople, as administrator.** The owner asked first what the certificate is and whom it binds (answer given: this machine only, a throw-away test certificate minted by the run, not anything a web user would ever see), then gave «موافق على مخزن الجهاز». `certutil -addstore TrustedPeople <cer>` through a UAC-elevated process (the owner clicked «Ja» on the administrator prompt): exit 0, the certificate listed in the machine's «Betrodda personer»; machine Root untouched (0). The owner double-clicked the MSIX, unticked «Starta när du är redo», clicked «Installera». App Installer (screenshot `04-appinstaller-machine-trustedpeople-installed.png`, 20:51): **«Z Privacy är redo!»** · Utgivare: Z-privacy · Version: 1.0.0.0 · the same two Funktioner lines · buttons **«Installera om»** and **«Starta»**. No error sentence, no further prompt.

**The ladder's final answer on stock Windows 11 Pro 26200:** user TrustedPeople — refused (button dead); user Root — button lit, deployment refused with 0x800B0109; **machine TrustedPeople — installs, and only after an administrator prompt.** The machine Root store was never needed and never touched.

### The installed package, read from disk (paper 101 item 3, first half)

- `Get-AppxPackage com.zprivacy.app`: PackageFamilyName **`com.zprivacy.app_56bmvq0rv2zhp`** (the real name, read from the system, not guessed), PackageFullName `com.zprivacy.app_1.0.0.0_x64__56bmvq0rv2zhp`, InstallLocation `C:\Program Files\WindowsApps\com.zprivacy.app_1.0.0.0_x64__56bmvq0rv2zhp`, SignatureKind **Developer**, IsDevelopmentMode False. Start-menu entry «Z Privacy», AUMID `com.zprivacy.app_56bmvq0rv2zhp!zprivacy`.
- The install folder is readable by the user and holds exactly the bundle: zprivacy.exe 143 872, z_bridge.dll 8 749 568, flutter_windows.dll, file_selector_windows_plugin.dll, the three runtime DLLs, `data\`, `Images\`, AppxManifest.xml 3 691, AppxBlockMap.xml, AppxSignature.p7x 1 582, resources*.pri.
- The package's per-user folder `%LOCALAPPDATA%\Packages\com.zprivacy.app_56bmvq0rv2zhp\` was created at **20:51:32** with the empty standard skeleton (`AC\`, `AppData\`, `LocalCache\Local`, `LocalCache\Roaming`, `LocalState\`, `RoamingState\`, `Settings\settings.dat` 8 192, `SystemAppData\Helium\*.dat`, `TempState\`).

**Where the vault bytes would land — measured with a probe, not with a vault.** `Invoke-CommandInDesktopPackage -PackageFamilyName com.zprivacy.app_56bmvq0rv2zhp -AppId zprivacy -Command cmd.exe` runs a command with the package's identity, i.e. under the same file-system rules the app itself gets. Inside it, `%LOCALAPPDATA%` reads as the plain `C:\Users\anash\AppData\Local`, and `mkdir %LOCALAPPDATA%\ZPrivacy-probe` + `echo … > …\a.txt` succeeded — but on disk:

| path | exists after the probe |
|---|---|
| `C:\Users\anash\AppData\Local\ZPrivacy-probe\a.txt` (plain) | **no** |
| `C:\Users\anash\AppData\Local\Packages\com.zprivacy.app_56bmvq0rv2zhp\LocalCache\Local\ZPrivacy-probe\a.txt` | **yes** |

So **file-system virtualisation is on for this package** (the manifest has no `desktop6:FileSystemWriteVirtualization="disabled"`): the app believes it writes `%LOCALAPPDATA%\ZPrivacy\…`, Windows puts the bytes under `Packages\<family>\LocalCache\Local\ZPrivacy\…`, and reads are a merged view of the real folder plus the LocalCache copy (copy-on-write). A user who makes a vault in the MSIX build has it inside the package folder.

**Why the MSIX copy of the app was not launched.** Probe B: with `LOCALAPPDATA` overridden in the calling shell, the packaged child still saw the plain `C:\Users\anash\AppData\Local` — the override does not pass through a package launch, so there is no way to point the MSIX copy at a TEST data folder. Launched at all, it would read (merged view) the owner's real `%LOCALAPPDATA%\ZPrivacy` and show the unlock screen of his vault. The standing rule says never, so the Settings «your vault is in» line of the MSIX copy, the two-window lock on the MSIX copy, and a vault's own bytes under LocalCache were **not run**. The lock and the Settings line are measured instead on the hash-identical folder build (same six files, see above). The owner's real folder after the probes: unchanged (07:31:15 / 05:50:34 / 01:16:52).

### The ladder in one table (so the conclusion can be read without the prose)

| rung | store | admin? | App Installer front page | «Installera» click | screenshot |
|---|---|---|---|---|---|
| 0 | none | — | (not opened; `Get-AuthenticodeSignature` UnknownError) | — | — |
| 1 | user TrustedPeople | no | «Utgivare: Okänt», red box «…inte signerat med ett betrott certifikat…», button **greyed** | impossible | 01 |
| 2 | user Root (+ rung 1) | no (Windows' own root warning, owner's «Ja») | «Utgivare: Z-privacy», button **enabled**, signature now Valid | **refused**: «Installationen av Z Privacy misslyckades … error 0x800B0109: The root certificate of the signature in the app package or bundle must be trusted.» | 02, 03 |
| 3 | machine TrustedPeople (+ rungs 1, 2) | **yes** (UAC) | «Utgivare: Z-privacy», button enabled | **installed**: «Z Privacy är redo!» | 04 |

The user-Root rung changed what the front page says and lit the button; it did not let the deployment service accept the package. The install completed only after the certificate was in the **machine** TrustedPeople store, which took an administrator prompt. Whether machine TrustedPeople alone (without rungs 1 and 2) would also light the front page was not measured; the rungs were cumulative, as agreed.

### The probe, verbatim

Run from an ordinary PowerShell (no administrator), with the package installed:

```
Invoke-CommandInDesktopPackage -PackageFamilyName com.zprivacy.app_56bmvq0rv2zhp -AppId zprivacy -Command cmd.exe -Args "/c (echo LOCALAPPDATA=%LOCALAPPDATA% & mkdir %LOCALAPPDATA%\ZPrivacy-probe 2>nul & echo probe-a > %LOCALAPPDATA%\ZPrivacy-probe\a.txt & dir /b %LOCALAPPDATA%\ZPrivacy-probe) > C:\Users\anash\z\testdata\78988fd\probe-a.txt 2>&1"
```

- What the command inside the package saw and printed: `LOCALAPPDATA=C:\Users\anash\AppData\Local` and `dir` listing `a.txt`.
- The path it wrote, as it believed: `C:\Users\anash\AppData\Local\ZPrivacy-probe\a.txt`.
- Where the file appeared: `C:\Users\anash\AppData\Local\Packages\com.zprivacy.app_56bmvq0rv2zhp\LocalCache\Local\ZPrivacy-probe\a.txt` (and `b.txt` from the second probe). `C:\Users\anash\AppData\Local\ZPrivacy-probe\` does not exist.
- Second probe, same command with `$env:LOCALAPPDATA = 'C:\Users\anash\z\testdata\78988fd\LocalAppData-msix'` set in the calling shell first: the child still printed `LOCALAPPDATA=C:\Users\anash\AppData\Local`, and `b.txt` landed in the same LocalCache folder; nothing under the override path. The override does not pass through a package launch.

### Measured debt for ed — rule 84's sentence is per installer

«Deleting the app does not delete your vault» is true of the Inno build (item 2 above: the test vault stood after Avinstallera) and, as packaged today, **not** true of the MSIX build: a vault made by the MSIX copy lives at `Packages\com.zprivacy.app_<hash>\LocalCache\Local\ZPrivacy\` and goes with the package (the look-again after the owner's uninstall, below, is the measurement). If the MSIX ever ships for real, the vault must escape virtualisation — `desktop6:FileSystemWriteVirtualization="disabled"` on the Application element (and `RegistryWriteVirtualization` likewise), or a vault home outside AppData — ed's item, named here, not built.

### Paper 101 item 3, second half — remove the MSIX and look again: the package folder, and everything written through it, is gone

The owner removed the package through Inställningar → Appar → Installerade appar → Z Privacy → Avinstallera at 21:01:39. His words: it asked him nothing and showed no sentence; no administrator prompt. `Get-AppxLog` 21:01:39: id 400 «Deployment Remove operation with target volume C: on Package com.zprivacy.app_1.0.0.0_x64__56bmvq0rv2zhp … finished successfully.», id 472 «Moving package folder \\?\C:\Program Files\WindowsApps\com.zprivacy.app_1.0.0.0_x64__56bmvq0rv2zhp to \\?\C:\Program Files\WindowsApps\Deleted\…».

| place | before removal | after removal |
|---|---|---|
| `Get-AppxPackage com.zprivacy.app` | installed | **none** |
| `C:\Program Files\WindowsApps\com.zprivacy.app_1.0.0.0_x64__56bmvq0rv2zhp\` | the bundle | **gone** (moved to `WindowsApps\Deleted\…` by the service) |
| `%LOCALAPPDATA%\Packages\com.zprivacy.app_56bmvq0rv2zhp\` | skeleton + `LocalCache\Local\ZPrivacy-probe\a.txt`, `b.txt` | **gone, the probe files with it** |
| Start-menu entry «Z Privacy» (AUMID …!zprivacy) | present | **gone** |
| plain `%LOCALAPPDATA%\ZPrivacy-probe\` | never existed | never existed |
| the owner's real `%LOCALAPPDATA%\ZPrivacy` | 07:31:15 / 05:50:34 / 01:16:52 | **unchanged** |
| TEST vault `…\LocalAppData-inno\ZPrivacy` | 19:57:35 | **unchanged** |

**The finding, recorded not fixed:** a file the packaged app writes to «`%LOCALAPPDATA%\ZPrivacy\…`» lives in the package's LocalCache and is deleted by the ordinary uninstall, with no question asked. For the MSIX build as packaged today, deleting the app deletes the vault. For the Inno build it does not (item 2). The packaged app was never launched, so no vault bytes were ever in that LocalCache — the probe file stood in their place and went the same way.

### The certificate is out again — three stores, verified

Thumbprint `B66B86FA1917697A1066B471BF3375647737F57A` (`CN=Z-privacy`), removed in the order it went in, each store read back with `certutil -store` afterwards:

| store | command | certutil said | read-back |
|---|---|---|---|
| user TrustedPeople | `certutil -delstore -user TrustedPeople B66B86FA…F57A` | «Deleting Certificate 0: CN=Z-privacy:b66b86fa…f57a — command completed successfully.» | **0** Z-privacy entries |
| user Root | `certutil -delstore -user Root B66B86FA…F57A` (Windows asked the owner to confirm deleting a root certificate; he clicked «Ja») | the same two lines | **0** |
| machine TrustedPeople | `certutil -delstore TrustedPeople B66B86FA…F57A`, elevated (UAC, owner's «Ja») | exit 0 | **0** |
| machine Root | never added | — | **0** |

`Get-AuthenticodeSignature` on the MSIX is back to **UnknownError** (untrusted root), i.e. the machine trusts nothing it did not trust this morning. No `Z-privacy` certificate remains in any of the four stores.

### Step 5 — the lock, two windows of the hash-matched folder build on one TEST vault: no refusal sentence, a stale session overwrite, and seven minutes of silent in-memory work

Binaries: `C:\Users\anash\z\artefacts\78988fd\dist\unzipped\zprivacy-v1-windows-x86_64\zprivacy.exe` (the six files hash the same as the MSIX's; the MSIX copy itself cannot be pointed at a test folder, see above). Both windows started by my launcher with `LOCALAPPDATA` overridden to one test folder; the folder watched every 2 s (round 1, size only) and every 1 s (round 2, size + mtime). Fixtures only; the passphrase is a test one and appears nowhere.

**Round 1 (21:12–21:29) — typed text, no document.** A started 21:12:19, the owner made the TEST vault (vault.zv 235 B at 21:14:15) and a session; B started 21:15; both unlocked. The owner typed «بسم الله الرحمن الرحيم» in the first part of each window (no document: tab label «Typed text», status badge **«Not scanned yet»**, the text standing in the Original column as line 1 «All 1 line» and in the Safe column tokenised), hand-protected one word in A («Protected as __Z_C64C_CUSTOM_89C5__», Safe column showing `__Z_966C_CUSTOM_32F9F9A4__`, «1 values were replaced», Tokens 1) and two in B (`__Z_F4FC_CUSTOM_5267__`, `__Z_F4FC_CUSTOM_FCD6__`, «2 values were replaced», Tokens 2). Screenshots 05 (A) and 05b (B). Nothing was sent; no key is configured in the test vault. **Disk: not one byte written between 21:16:26 (the session births: vault.zv 526 B, `1.zs` and `2.zs` 50 B each) and 21:29**, with both windows showing «Protected as …». No refusal sentence either. I then closed both windows with `Stop-Process -Force` (my own processes) to relaunch with logging, so «lost on close» was not measured in round 1 — only «not written while typing and protecting». No `*.new` or other temp file was left in that folder by the force-kills. (The lead's code walk on Linux, 7fb59b1, later read the same from the code: the typed-text path writes nothing and no close or lock hook writes from the bench; the scanner does run on typed text and «Not scanned yet» is a badge reading the document's scan origin. Recorded here as seen, not judged.)

The owner's account of round 1, as he gave it: he opened session 1 in A, protected, then went to B and the session showed nothing of it («أنشأت جلسة في A ولم تظهر في B»); later «لم ترفض B ولا أي شيء ولكن لم يتم حفظ البلوكات، الكلمات المحمية في الخزنة».

**Round 2 (21:29–22:15) — a document, by the 1-second watch (size@mtime).** The round-1 folder was copied to a fresh folder (vault.zv 526 B, `1.zs` 50 B, `2.zs` 50 B, all @21:29:07); A and B started 21:29; both unlocked; B told to stop. The owner's answers afterwards: when B was first unlocked its session list **showed both sessions** (1 and 2) «but what was missing was the sessions' content»; he **chose** session 1 from the list, did not create one; B **never locked itself** at any moment.

| time | vault.zv | sessions\1.zs | sessions\2.zs | what happened (owner's clicks) |
|---|---|---|---|---|
| 21:29:23 | 526 | 50 | 50 | baseline |
| 21:33:53 | **1099** | **2017** | 50 | A brings in `z_core\tests\fixtures\Risala_Alharbi.txt` into session 1 |
| 21:34:05 | 1166 | 2074 | 50 | A hand-protects (each press written within 2 s) |
| 21:34:07 | 1232 | 2131 | 50 | A protects |
| 21:34:13 | 1296 | 2193 | 50 | A protects |
| 21:34:29 | 1357 | 2255 | 50 | A protects |
| 21:34:33 | 1424 | 2317 | 50 | A protects |
| 21:34:43 | 1491 | 2379 | 50 | A protects |
| 21:34:47 | 1552 | 2441 | 50 | A protects |
| 21:34:51 | 1616 | 2565 | 50 | A protects |
| 21:34:59 | 1679 | 2627 | 50 | A protects |
| 21:35:03 | **1743** @21:35:03 | **2937** | 50 | A's last protect |
| **21:35:11** | 1743 (mtime unchanged, 21:35:03) | **50** @21:35:11 | 50 | the owner closes A with the window's × button and, in B, picks session 1 from the list — in that order, seconds apart; B then shows session 1 **empty** |
| 21:35:11 → 21:59:20 | 1743 | 50 | 50 | **B imports `Brev_Lindqvist.txt` into session 1** — glass: «Scanned on import · 8 protected automatically · 0 need your word · 185 normal» — and hand-protects up to **Tokens 18**, «23 values were replaced», «Protected as __Z_6466_CUSTOM_A6900AC7__, in 5 places», «Already protected as … from You · selected by you» (screenshot 07 at 21:41). **Not one byte reaches the disk in those 24 minutes. No refusal sentence anywhere on B's screen.** |
| ~21:55 | 1743 | 50 | 50 | B: Vault → lock, then unlock with the test passphrase, open session 1: **«Nothing is open.» · Tokens «Nothing is protected yet»** · session 1 «0 exchanges · the one you are in» (screenshot 08). Nothing written. The lead's recovery idea (one press after the unlock) had nothing to press on. |
| **21:59:20** | 1743 (unchanged) | **3164** | 50 | B imports `Brev_Lindqvist.txt` again into session 1: «Scanned on import · **23 protected automatically** · 0 need your word · 170 normal», Tokens 18, «23 values were replaced», sessions panel «doc2 · Brev_Lindqvist.txt · 23 protected places» (screenshot 09). The 15 extra automatic protections are B's own earlier hand-protections, with the **same token names** as at 21:41 (`__Z_6466_CUSTOM_89044CCB__`, `_A6900AC7_`, `_F19BA63C_`, `_96C516DE_`, `_CD2DA88E_`, …). **The session file is written; vault.zv is not.** |
| ~22:01 | 1743 | 3164 | 50 | B closed by the owner with the × button: nothing written, no temp file left |
| 22:04–22:15 | 1743 | 3164 | 50 | a fresh single window on the same folder: the owner unlocks, opens session 1, opens doc2 — **the document is there** («تم ظهور المستند. ممتاز»); no error sentence. Nothing written. |

(One false alarm in between, mine: at 22:02 my launcher opened the fresh window on the **round-1** folder by mistake; the owner saw an empty session 1 there and read it as «closing and reopening emptied the session». Closed and reopened on the right folder; the round-2 folder was never touched by that window. Recorded so the owner's sentence at 22:02 is not read as a finding.)

**What the disk says, in order of weight:**

1. **No refusal sentence was ever seen**, in either round, in either window — «Another copy of Z Privacy changed this vault…» did not appear on this build. The owner's one-word answer to the lead's question is **no**.
2. **A's session file was overwritten with an empty body at 21:35:11** (2937 → 50 B) while vault.zv kept A's blocks (1743 B, mtime 21:35:03 — it did not move at all at 21:35:11). The two candidate writers are A's × close and B's list click on session 1, seconds apart; the disk alone does not say which. No crash, no `.new` leftover: two healthy windows and a click sufficed. The vault births happened in round 1 (21:16:26), so B's click was on an existing row, not a birth.
3. **B's import and 18 tokens lived in memory for 24 minutes with «Protected as …» on the glass and nothing on disk**; the lock+unlock cleared the bench but not the blocks (the re-import found all 23 «automatically»), and the following session-file write landed while vault.zv still did not move — so `sessions\1.zs` now names 23 protected places whose blocks are, on disk, not in `vault.zv` (1743 B = A's Arabic blocks from Risala). The fresh window at 22:15 nevertheless showed doc2; whether its 23 places are shown protected or as unknown tokens is the one thing the owner did not report in detail (he said «the document appeared, excellent»; no screenshot of that window reached the clipboard).
4. **Typed text without a document writes nothing while it happens** (round 1, 13 minutes, two windows). Whether it is lost on an ordinary close was not measured here (force-kill); the lead reports the code says it is.
5. **A document path writes at the press**: 11 hand-protects in 70 s, each 61–67 B on vault.zv and 57–62 B on the session file, every one within 2 s.

Owner's wish, repeated tonight as in the morning: the session's name should stand in the window's title bar; in round 2 he noted that when he picked session 1 the name did not show at the top until a document was brought in.

## 22 October 2026, 22:50 — addendum for paper 102 §6: the round-2 folder listed with `dir /a`, no leftover temp file

Exact lines, hidden and system entries included (`dir /a`):

```
 Directory of C:\Users\anash\z\testdata\78988fd\LocalAppData-lock-r2\ZPrivacy\sessions

2026-10-22  21:59    <DIR>          .
2026-10-22  21:35    <DIR>          ..
2026-10-22  21:59             3 164 1.zs
2026-10-22  21:29                50 2.zs
               2 File(s)          3 214 bytes

 Directory of C:\Users\anash\z\testdata\78988fd\LocalAppData-lock-r2\ZPrivacy

2026-10-22  21:35    <DIR>          .
2026-10-22  21:33    <DIR>          ..
2026-10-22  21:59    <DIR>          sessions
2026-10-22  21:29               179 settings.zcfg
2026-10-22  21:35             1 743 vault.zv
2026-10-22  21:29                 0 writing.lock
               3 File(s)          1 922 bytes
```

And the round-1 folder (the one the force-kills hit), for completeness: `sessions\` holds only `1.zs` 50 and `2.zs` 50 (both 21:16); `ZPrivacy\` holds `settings.zcfg` 179 (21:13), `vault.zv` 526 (21:16), `writing.lock` 0 (21:12).

- **No `*.new`, no other temp file, nothing hidden** in either folder. The create-new-and-refuse-forever candidate is out for this folder.
- Directory mtimes: `sessions\` 21:59 (its last entry change, the 21:59:20 write of `1.zs`); `ZPrivacy\` 21:35 (its last entry change — consistent with `vault.zv` being replaced through a rename at 21:35:03, A's last protect). Whether the 21:35:11 50-byte `1.zs` arrived by rename or by in-place truncate the listing cannot say now, since the 21:59 write refreshed the directory time.
- Writers outside our code, named so they can be weighed: the folder lives under `C:\Users\anash\z\testdata\` — not under OneDrive, no sync client on it; Microsoft Defender real-time protection is on (default), no exclusions were set; the folder itself was made by my `cp -r` of the round-1 folder at 21:29:07, *before* the timeline, and `1.zs` was already 50 bytes in the source then. Nothing of mine wrote into it after 21:29:07; the watcher only read.
