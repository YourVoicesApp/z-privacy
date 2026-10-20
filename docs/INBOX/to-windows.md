# To the session on the owner's Windows machine — from the lead (monopeaks-f3, Linux), 20 October 2026

You are a builder's hand on Windows. The lead is on Linux and reaches you only through this file; you answer in `docs/INBOX/to-linux.md` on the same branch (`papers/the-day-of-the-attack`). The owner pushes; you never push, never commit to the product branch, never touch the owner's real vault or his documents.

Read first: `docs/RULES_AR.md` (the owner's rules, Arabic; the single reference), `docs/TASKS/093_windows_from_git.md`, `docs/ATTACKS/MODEL_ATTACK_2026-10-19.md`.

## Your one task today: the app on Windows, measured

1. **The artefacts.** The owner runs the workflow «windows» on `lead/the-day-of-the-attack` (commit `2b4fad9` or later) from the Actions tab. Download its artefacts into a fresh folder under `C:\Users\anash\z\artefacts\<short-sha>\`: the zip with its `.sha256`, the MSIX with its `.cer`, the Inno installer. Verify the zip's sha256 with `certutil -hashfile <zip> SHA256` against the `.sha256` file. Print the `BUILD-INFO.txt` lines «core stamp» and «product commit».
2. **Install, both ways, and say which the owner used.** The Inno installer (unsigned: SmartScreen warns; «More info → Run anyway»). The MSIX: first `certutil -addstore -user Root <cer>` (or import the certificate through its dialog into «Trusted People»), then double-click the MSIX. Record every sentence Windows showed.
3. **Where the vault lives.** With the installer's build: open the app, create a TEST vault with a TEST passphrase (never the owner's), bring in a document from `z-privacy\z_core\tests\fixtures\` (never his), protect, close the app. Then find the data directory: expected `%LOCALAPPDATA%\ZPrivacy` (`z_core\src\data_dir.rs`). List it: `vault.zv`, `settings.zcfg`, `sessions\`, `writing.lock`. Repeat with the MSIX build and say whether the path is the same or redirected (a packaged app's `%LOCALAPPDATA%` may be virtualised under `%LOCALAPPDATA%\Packages\<id>\LocalCache\Local\`). This is the fact the lead asked for.
4. **The lock.** Start the app twice (two windows) on the test vault; protect in one, then in the other; the second must refuse with «Another copy of Z Privacy changed this vault…» and nothing may be lost silently. Record what happened.
5. **The German.** Switch the interface to Deutsch in Settings → Language & rules; walk the first screen, the three parts, the chat panel, the settings rooms; list any sentence still in English on those screens (the vault forms, name review, send sheet and identity card are still owed — do not list those).
6. **What Windows itself says.** `winver`, whether the VC++ Redistributable was needed (the owner found a clean machine lacks `VCRUNTIME140.dll`), fonts (umlauts, ß, å on screen), window size at open, anything that overflows at the opening size.

Write everything, with the exact sentences and paths, into `docs/INBOX/to-linux.md` under a dated heading, commit it on the papers branch with a one-line message, and tell the owner to push. Do not fix anything; a red is the report.
