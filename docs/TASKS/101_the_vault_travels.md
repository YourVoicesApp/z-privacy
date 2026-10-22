# 101 — The vault travels: it lives outside the app, moves by its folder, and no uninstall may eat it

**Owner, 22 October (rule 84, «نعم»):** «نقل الخزنة من جهاز إلى جهاز هذا خيار لم نفكر به» — and the Settings button: «يمكننا وضعها خيار بالإعدادات بشرط وجود USB بحيث نؤكد مسح الخزنة القديمة».
**What the code already says (measured 22 October, lead):** `config.rs` stores five scalars and **no path**; `vault.zv` carries its own KDF parameters and nothing that names a machine or a folder; the app hands the folder at start (`set_data_dir`, `data_dir.rs`: `%LOCALAPPDATA%\ZPrivacy` on Windows, `$XDG_DATA_HOME/zprivacy` else `~/.local/share/zprivacy` on Linux). So the move is already: **lock, copy the folder, place it where the other machine's Settings line says, open with the same passphrase.** This paper is the measurement that turns that sentence from design into fact, plus one guide section. The Settings button is a later paper.

## 1 · The claims to measure (test vault only, never the owner's)

1. **Cross-platform move.** A test vault created on Linux (fixtures from `z_core/tests/fixtures/`, a handful of protected words, one saved z-pdf) is copied to Windows, opened there with the same passphrase: the blocks answer, names come back in the two columns, the z-pdf reads back. Then the reverse direction once. Byte-portability of the format is measured here, not assumed.
2. **USB as the carrier.** The same folder crosses on a FAT/exFAT stick. Two separate questions, measured separately: (a) the folder survives the copy on→off the stick intact (hashes equal); (b) what `secure_file::secure_dir` says if a vault is *opened in place* on such a filesystem — its mode check (`mode & 0o700`) meets FAT's fabricated permissions. Whatever it answers is written down; the guide promises only what was green. The carrier needs no permissions story: the file is encrypted, and a stick holding the folder reveals existence and size, nothing else.
3. **Uninstall never eats the vault.** On Linux: remove the app bundle, the folder under `~/.local/share/zprivacy` stands. On Windows, two installers, two answers:
   - **Inno:** uninstall from Settings → Apps; then look at `%LOCALAPPDATA%\ZPrivacy` with the eyes.
   - **MSIX:** this is the live question. MSIX may virtualise writes to `%LOCALAPPDATA%` into the package's own `Packages\<id>\LocalCache`, **and removing an MSIX removes that folder**. After sideloading, find where the vault bytes actually landed (the plain path, or the package path), note what the Settings «your vault is in» line shows, uninstall, and look again. If the MSIX half eats the vault, that is a finding to fix (or an honest sentence in the guide and on the download page: which installer to pick if your vault must outlive the app), not a silence.
4. **A move is not a sync.** After the move, the old copy is a frozen backup: a word protected on the new machine does not appear in the old folder. One measurement, so the guide's sentence has a run behind it.

## 2 · Who measures what

- **Linux halves (1, 2a, 3-Linux, 4):** the lead's hands, test vault, this machine.
- **Windows halves (1-receive, 3-Inno, 3-MSIX):** the Windows session, inside the owner's eye round on the `78988fd` artefacts — it already carries «vault folder plain vs virtualised» as an item; this paper gives that item its weight and its uninstall step. Test vault only; the owner's real vault and documents are never touched; every Windows sentence recorded under a dated heading in `docs/INBOX/to-linux.md`.
- **2b (FAT in place):** lead, Linux, a real stick; the mount's fabricated mode is read with `stat`, the app's answer with the eyes.

## 3 · The guide section (e2, only after §1 is green)

One section on the three guide pages, «Back up or move your vault»: your vault is one folder, Settings shows where [`yourVaultIsIn`]; to move it — lock [`lockNow`], quit Z, copy the folder, place it on the other machine, open with your passphrase; a copy on a USB stick is a locked backup no one can read without Z and your passphrase; a move is a move, not a sync — after it, the old folder is a frozen backup; deleting the app does not delete your vault (the sentence carries whatever the MSIX measurement forced it to say). Keys join the pages' comment blocks; `the_guide()` reads them as it reads the rest.

## 4 · Not in this round

The Settings «Move your vault» button (copy → **open the copy to verify** → confirmed delete of the old, worded «removed», never «shredded» — on SSDs no program erases bytes, the encryption is the real protection of what remains): its own feature paper, after publishing. The central vault and attached device (zprivacy-E2E): after that, one line in rule 84 and nowhere else. Any sync between two live vaults: not designed, not promised.

## Record — 22 October, the Linux halves (lead's hand + the owner's, test vault only)

- **The test vault was born isolated and measured so:** the app launched with `XDG_DATA_HOME=~/z-share/vault-101` on the debug bundle at `b20e6fd`; the running process's environment was read to prove which folder it held (the first attempt had no override and sat on the real folder — caught before any step, window closed, relaunched). A fresh `vault.zv` of 235 B appeared in the test folder; the real vault's mtime never moved all night.
- **The full cycle in the origin:** the owner imported a German letter, protected by hand, saved a z-pdf (`Session 1-protected-2026-10-22.pdf`, 15 699 B) and read it back in the same vault: **«15 names came back from Session 1»**. The vault grew 235 → 1405 B; the session file returned to the 50-byte empty body when the document left by the PDF door — rule 54(هـ) measured working.
- **A bonus the plan never asked for:** the owner first opened an OLD z-pdf made by his real vault (14 October, session F610) inside the test vault — and the glass answered the designed sentence: «This document carries 12 names from a session this vault does not hold. Nothing here can put them back.» A z-pdf is readable only by the vault that made it, measured.
- **The move itself:** window locked and closed; the folder copied whole; `sha256(vault.zv)` identical on both sides. The copy opened **with the passphrase alone** — session listed with its birth time — and the read-back of the same z-pdf in the copy returned the names (owner: «تم كل شيء على أكمل وجه»). A kept document in the moved vault also reopened «As it was kept» with its protections and no new scan.
- **Move-not-sync, first half:** the origin's `vault.zv` bytes and mtime are unchanged after the whole session in the copy (hash equal, mtime 22:49:12 both) — nothing in the copy reached back. The sharper half (new work in the copy never appearing in the origin) rides along with the Windows move-in, where new protections will be made.
- **Staged for Windows:** the locked test vault folder and its z-pdf sit in `docs/INBOX/vault-101-transfer/` on this branch; the Windows session places the `zprivacy` folder under its LOCALAPPDATA-override test folder and opens it with the test passphrase (named in the hand-over message, kept out of reports).
- **Still open:** the USB/FAT carrier measurement (no stick was present tonight); the Windows move-in (§1's receive half); the MSIX answer is already closed by the tenth report (eats the vault — per-installer sentence stands in rule 84's debt).

## Measurement

Linux halves by the lead's hand with a test vault, written here as they run; Windows halves land in `docs/INBOX/to-linux.md` and are copied into this paper's record; the guide section only after §1 is green on both platforms; `bash scripts/gates.sh` green when the guide keys land. No product code is expected by this paper — if a measurement reds (FAT mode check, MSIX virtualisation), the finding becomes its own item with its own builder.
