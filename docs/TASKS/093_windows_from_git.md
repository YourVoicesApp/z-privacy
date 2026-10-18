# 093 — Windows from git: the app job finishes, stamps, packs an MSIX, and runs the Dart half

**Owner, 18 October:** «ويندوز، أبل، نشر» — and: 83% of the market is Windows, so the German version is the Windows version. He has a Windows machine now; the lead will be moved there to measure. Apple waits for Tuesday.
**Base:** lead line at `1d9cd7a` (587 · 0 · 0, rust 792, dart 403), installed and pushed.
**Builder:** ed — the Windows half is his. Branch `fix/windows-from-git` from `1d9cd7a`. No push: the owner pushes and runs the workflow from the Actions tab (it is manual by his 5 Oct ruling and stays manual).
**Touches:** `.github/workflows/windows-core.yml` (rename allowed), a new `scripts/package_windows.ps1` or `.sh`, `apps/flutter_app/pubspec.yaml` (msix), `docs/`. No sentence on the glass: e2's 092 sitting three is in `settings.dart` and the ARB files; you will not meet.

## What exists today, measured

- `windows-core.yml`, manual: job `core` (Rust build + tests with the two test features, the storage contracts, the stamp, «what Linux says» from `docs/MEASURED_ON_LINUX.txt`); job `app` (Flutter 3.44.2, `flutter build windows --release`, «Stage the folder»).
- The data directory on Windows is `%LOCALAPPDATA%\ZPrivacy` (`z_core/src/data_dir.rs`). The one-writer lock is `std::fs::File::lock` (LockFileEx there) — G43 measured on Linux only.
- The CI runs no Dart test on Windows (074 desk audit). The release hygiene (`strip`, `--remap-path-prefix`, «no /home/ in the archive») lives in `scripts/package_linux.sh` and has no Windows twin.

## The four items

**1. The `app` job produces a release the way Linux does.** A `BUILD-INFO.txt` with the same five lines as Linux (core stamp, product commit and its message, built-at, toolchains, profile) and the two product hashes (`zprivacy.exe`, `z_bridge.dll`); the staged folder zipped as `zprivacy-v1-windows-x86_64.zip` with a `.sha256` beside it; both uploaded as artifacts named by the short sha. The hygiene twin: no runner path (`D:\a\`, `C:\Users\runneradmin`) and no `/home/` in any file of the folder — grep the binaries as the Linux gate does; `strip = "symbols"` already applies; the remap for the bridge is the same flag. Measure: the Linux stamp gate's logic, applied to the staged folder, as a step that fails the job by name.

**2. The Dart half runs on Windows.** Before `flutter test`, build the bridge with the test features exactly as G7-build does on Linux (`cargo build -p z_bridge --features z_core/fake_provider,z_core/test_clock,z_core/measuring`) and place it where the Windows runner's debug bundle keeps `z_bridge.dll`; then `flutter test --concurrency=1`. A red here is the report we are asking for (CRLF, paths, fonts, `Platform.isWindows` branches): the step must not be `continue-on-error`. If it reds, the job reds, and the failures are listed by file in the summary the way gates.sh lists them. Whatever is red goes to the owner as a measured list, not as a fix in this round, unless it is one line.

**3. An MSIX for sideloading.** The `msix` pub package in `pubspec.yaml`, configured for a test package: display name «Z Privacy», publisher display name «Z-privacy» (the owner's working choice until the Store approval names it), identity name placeholder, a self-signed test certificate generated **in the job** and thrown away (never committed), `msix:create` on the release build, the `.msix` uploaded as an artifact. The job's summary prints the one line the owner needs to install it on his machine (import the test cert, double-click). The Store's own signing comes later and is not this round (the house's note: Store + MSIX free, no EV needed).

**4. The storage contracts measured where they live.** The `core` job already runs `check_storage_contracts.sh` on Windows; add the one-writer measurement (two processes, one `writing.lock`, LockFileEx, no silent loss) as a Windows run of the same guard that G43 is on Linux, and have the summary say «9 storage contracts + one writer at a time: measured on Windows» or name what it could not run.

## What the owner does

Push, open Actions → «windows» → Run workflow on `lead/the-day-of-the-attack`, download the two artifacts, install the MSIX on his machine, open a document, protect, ask Grok, read a z-pdf back. The lead then moves to that machine for the vault measurement (data dir, lock, auto-lock, two copies).

## Measurement

Linux gates stay green (`scripts/gates.sh` from a plain debug build) — this round adds no Linux code path, so 587 should not move except for any gate you add on the workflow file itself (a gate that the workflow names the features `TEST_FEATURES` names, G23's shape). Report the branch head, the three numbers, and what the paper got wrong about the workflow. The Windows numbers come from the run the owner triggers; write them into `docs/` as a measured table in the next commit, not as a promise.
