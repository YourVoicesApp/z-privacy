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
