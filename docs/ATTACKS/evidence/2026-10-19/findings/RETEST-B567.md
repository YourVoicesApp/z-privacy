# RETEST B5/B6/B7 + Swedish first-run on 2b4fad9

**Tree:** `/home/monopeaks/z-attack-2b4fad9` (read)  
**Commit:** `2b4fad93cc26b282e6fa9773ad2275544dcc7ee8`  
**Stamp:** `z_core 0.1.0 · 2026-10-19 · 2b4fad9`  
**Wrote:** `/home/monopeaks/z-attack-2b4fad9-evidence/` only  
**Did not touch:** the worktree sources, `/home/monopeaks/.local/share/zprivacy` (vault mtime 06:17, probes at 06:44), `/home/monopeaks/mono-privacy`  
**Installed archive:** still `84832a0` — this review did not rebuild it.

Merge message claimed: one law for an untranslated language, so Svenska no longer hands an English interface under a Swedish name; dead Interface card deleted. Measured below. Do not take the message as evidence.

Logs: `logs/b567/b5-scan.txt` · `b5-escapes.txt` · `b7-truth.txt` · `cargo-build.txt` · `pub-outdated.txt`.

---

## Status rollup

| id | was (84832a0) | on 2b4fad9 | note |
|---|---|---|---|
| **خ1** | خطير — first screen has no Swedish | **FIXED as the lie; remaining NOTE** | `theListIsWrittenIn('sv')=false` (7/7 promise keys == English; only `thisLanguageName` differs). First screen: Deutsch/English only. Session list still `['de','en','sv']`. `theLocaleOf('sv')` → `en`. Language card offers Svenska + disclosure. Dead Interface card gone. English promises under a Swedish **first-run** name are not drawn. Swedish UI is still unwritten. |
| **خ3** | خطير — ZWSP/NFD blind the salutation | **OPEN** | ZWSP in Markus: nothing. NFD Müller after Herr: Thomas Auto, Müller missed. NFC still Auto both. |
| **خ4** | خطير — en pack drops after the person answered | **OPEN** | إنجليزي 2 after the one ASK: `James`, `12/04/1985`, `NGE-20417`, `QQ 12 34 56 C`, `4111 1111 1111 1111` still in payload. Isolated Luhn/NI/DOB/employee probes: nothing. `en-34` still `Validator::Number`; `is_numberish` still rejects letters. `languages.rs` still says «card»; no detector. |
| **خ5** | خطير — Postfach / Sparkasse after review | **OPEN** | ألماني 1, every suggestion Protected: `Postfach 4410` and `Sparkasse Leipzig` MISS. |
| **ن2** | ملاحظة — Argon2id guess cost | **SKIP** | Argon bench not re-run this pass. |
| **ن4** | ملاحظة — band 6 vs footer 7 after confirm | **OPEN** | After Protect: band `snap.autoProtected=6`, footer `payload.protected_count=7`, `ScanReport.auto=7`. `WHERE_EVERY_NUMBER_COMES_FROM.md` still names `ScanReport.auto`. `workspace.dart:1696` still draws the snapshot. |
| **ن7** | ملاحظة — rustls 0.23.45, no cargo-audit | **OPEN** | Product `Cargo.lock` still rustls **0.23.45**. crates.io 0.23.46 (four GHSA, 2026-10-14). `cargo-audit` **absent**. |
| **ن8** | ملاحظة — README mailbox ≠ site | **OPEN** | Archive + root README: `yourvoices.app@mono-peak.com`. Site: `zprivacy@mono-peak.com`. |
| **ن9** | ملاحظة — `libapp.so` still names `mono-privacy` under `/build/z…` | **NOT TESTED** on this commit's archive (installed binary is 84832a0). Source of `package_linux.sh`: rustc remaps `$ROOT`→`/zprivacy`; Python still rewrites **`$HOME` only**. Dart snapshot folder name would still survive. |
| **ن10** | ملاحظة — panic on the bridge is FRB policy, no `catch_unwind` | **OPEN** | `setup_default_user_utils` still. Zero `catch_unwind` in `z_bridge/src`. Generated `.unwrap()` still. |

---

## Counts vs 84832a0

Detection counts on the golden five and the experiment texts are **unchanged to the digit** (auto/asked/hidden on the previous expected lists). Adding Postfach/Sparkasse to ألماني 1's expected list turns that row into hidden=12 missed=2; those two were خ5 already.

B7 ten pairs still agree. Band/footer split after confirm still 6 vs 7.

B6 lock: rustls 0.23.45, archive 4.3.0, image 4.10.1, http 1.6.0 (http is current). `flutter pub outdated` on a lock **copy**: archive→4.5.2, image→4.12.0.

---

## Grades this pass

| | مانع | خطير | ملاحظة |
|---|---:|---:|---:|
| A1 Swedish first-run | 0 | 0 | 2 |
| B5 detection | 0 | 7 | 4 |
| B6 build | 0 | 0 | 5 |
| B7 truth | 0 | 0 | 3 |

خ1 is no longer خطير: the merge closed the English-under-Swedish-name path (filter + `theLocaleOf` + disclosure + deleted Interface card). It did not put Svenska on the first screen and did not write `app_sv.arb`.

Scanner debts خ3 خ4 خ5 are the same findings, same payloads.

---

## What was not done

- Live first-run window / AT-SPI (source + ARB only; `flutter test` would dirty the tree).
- Argon2id timing (ن2 skip).
- Linux archive rebuild; ن9 not measured on 2b4fad9 bytes.
- Real vault, real provider, `mono-privacy` HEAD.
