# Independent adversarial review — Z Privacy at 2b4fad9

Written once. Not edited after generation.

## Preamble

| Field | Value |
|---|---|
| Target repository | github.com/YourVoicesApp/z-privacy |
| Target branch | `lead/the-day-of-the-attack` |
| Target commit | `2b4fad93cc26b282e6fa9773ad2275544dcc7ee8` |
| Attack-plan file | `docs/ATTACKS/THE_ATTACK_PLAN.md` |
| Attack-plan commit | `b02a63a73d16233fb4efe261fa355b6ec7e85dfb` (`papers/the-day-of-the-attack`) |
| Previous attacker evidence | `docs/ATTACKS/REPORT_2_on_84832a0.md` and `docs/ATTACKS/findings/*` at the same papers commit |
| Model | Grok 4.7 500k xhigh |
| Review date | 2026-10-19 |
| OS / kernel | Ubuntu Linux, `Linux monopeaks 7.0.0-38-generic #38-Ubuntu SMP PREEMPT_DYNAMIC Fri Sep 4 09:10:14 UTC 2026 x86_64` |
| rustc | 1.98.0 (88d9e12ae 2026-08-18) |
| cargo | 1.98.0 (797e8a9bc 2026-08-05) |
| Flutter | 3.44.2 stable, framework `c9a6c48423`, engine `77e2e94772`, Dart 3.12.2 |
| Python | 3.14.4 |
| Display | `DISPLAY=:0` `WAYLAND_DISPLAY=wayland-0` `XDG_SESSION_TYPE=wayland` |
| Network access | available (`ping 8.8.8.8` succeeded). No real provider was called. |
| cargo-audit | absent |
| Scratch data | `XDG_DATA_HOME=/home/monopeaks/z-attack-2b4fad9-data` for gates; per-probe dirs under `/home/monopeaks/z-attack-2b4fad9-evidence/scratch/{b1,b2,b3,b4,b567}`. Never `~/.local/share/zprivacy`. |
| Isolated source tree | git worktree `/home/monopeaks/z-attack-2b4fad9` detached at `2b4fad93cc26b282e6fa9773ad2275544dcc7ee8` |
| Core stamp measured | `z_core 0.1.0 · 2026-10-19 · 2b4fad9` |
| Initial git status (live `/home/monopeaks/mono-privacy`) | branch `lead/the-day-of-the-attack`, HEAD `2b4fad93cc26b282e6fa9773ad2275544dcc7ee8`, porcelain empty |
| Initial git status (papers) | branch `papers/the-day-of-the-attack`, HEAD `b02a63a73d16233fb4efe261fa355b6ec7e85dfb`, porcelain empty |
| Real vault fingerprint before | `vault.zv` `760da2625e3b23e02a24509326af5c6c2c5e9257c25ff66359153c3b725bc203`; `settings.zcfg` `d685ad41cb251a046843ff5ff1a1cd6436cc7aea046db51326419f53bbdd09b0`; mtime 2026-10-19 06:17:31 +0200 |
| Real vault fingerprint after | identical hashes, identical mtime |
| Live tree after review | still clean at `2b4fad9` |
| Isolated worktree after review | still detached at `2b4fad9`, porcelain empty (build artefacts gitignored) |
| Gates | `./scripts/gates.sh` from the isolated tree: **594 checks, 0 failed, 4 skipped, exit 0**. Rust tests **792** (matches `docs/MEASURED_ON_LINUX.txt`). Dart half skipped (no `apps/flutter_app/build/linux/x64/debug/bundle/lib`). |
| Raw evidence | `docs/ATTACKS/evidence/2026-10-19/` on this papers branch |

The target commit was treated as immutable. No product file was modified, formatted, or regenerated. Defects were recorded, not fixed.

---

## Method

Attack plan sections B1–B7 were run against public `z_core` APIs and source inspection, with path-dependent harnesses retargeted at `/home/monopeaks/z-attack-2b4fad9/z_core` and `CARGO_TARGET_DIR` under the evidence directory (never the worktree `target/` while gates owned it).

Section A (live glass) was not driven on a 2b4fad9 GUI: there is no packaged binary of this commit on the machine (installed `~/.local/opt/zprivacy` is still `84832a0`), and `flutter build linux` / `flutter test` were not run in the immutable tree. First-run behaviour was measured from ARB files, `first_run.dart`, `sentences.dart`, `language_list.dart`, `settings.dart`, and the product’s own guards in `vault_screen_test.dart` / `the_sentences_are_in_one_list_test.dart` (unread by this run because G7-dart skipped).

Documents: copies of `~/نصوص التجربة` under evidence fixtures, plus the previous attacker’s PDF/DOCX bombs, plus read-only golden corpus `/home/monopeaks/ZPrivacy-lib/parity-corpus`.

---

# 1. Findings

Count on this commit from this review: **BLOCKER 0 · SERIOUS 3 · NOTE 16**. Failures of attacks (the product refused as specified) are listed as held, not as findings.

## SERIOUS (open)

### خ3 / B5-1 / B5-2 · Zero-width and NFD still blind the German salutation

- **Attack:** pack `de`, `Sehr geehrter Herr Mar<U+200B>kus Weber,` and `Herr` + NFD `Müller` (`u` + combining diaeresis). NFC control.
- **Files:** `z_core/src/scanner/packs/people.rs` (`name_shaped`); `logs/b567/b5-escapes.txt`.
- **Should:** the salutation Auto-protects the name as in the golden letter. NFC and NFD are one value (G3 / `text::nfc`).
- **Actual:** ZWSP inside Markus: no finding. NFD: Thomas Auto, Müller missed. NFC: both Auto. Combining mark fails `char::is_alphabetic`; ZWSP is not a letter.
- **Commands:** `CARGO_TARGET_DIR=…/target-b567 cargo run --release --bin b5_escapes` with scratch `tmp-data-escapes`.
- **Evidence:** `docs/ATTACKS/evidence/2026-10-19/logs/b567/b5-escapes.txt`; findings `B5-detection.md`.
- **Grade:** SERIOUS
- **Deterministic:** yes

### خ4 · English pack still drops values after the person has answered

- **Attack:** import إنجليزي 2, pack `en`, answer the single suggestion (company), then search the payload. Isolated probes for PAN / NI / DOB / employee number.
- **Files:** `z_core/src/scanner/packs/` English rows; `en-34` still `Validator::Number`; `languages.rs` still comments «card» with no detector; `logs/b567/b5-scan.txt`.
- **Should:** what the pack or its comments promise is protected or asked.
- **Actual:** after Protect on the one ASK, payload still contains `James`, `12/04/1985`, `NGE-20417`, `QQ 12 34 56 C`, `4111 1111 1111 1111`, `7 Elm Terrace`. `Mr Whitaker` Auto on the surname only. Isolated Luhn/NI/DOB/employee probes: nothing. `is_numberish` still rejects letters, so NI is dropped after the label matches.
- **Grade:** SERIOUS
- **Deterministic:** yes

### خ5 / B1-1 / B1-2 · Postfach and Sparkasse still leave after a finished review

- **Attack:** ألماني 1, pack `de`, Protect on every suggestion (including address span `04179 Leipzig`), then `payload_to_take_out`, `chat_to_take_out`, and a product-reader round-trip of a PDF of that payload.
- **Files:** scanner address rule; `Bankverbindung:` cuts IBAN/BIC and ignores the bank name; `logs/B1-payload-take-out.txt`.
- **Should:** Protect on that address line takes the postal identity, or review asks about `Postfach 4410`. A bank identity on `Bankverbindung:` is offered like the GmbH that *was* offered.
- **Actual:** zero open suggestions. Line still `Kundenservice · Postfach 4410 · <ADDR token>`. `Sparkasse Leipzig` still stands next to tokenised IBAN and BIC. Neither was a finding. Same leftovers on the new fourth door `chat_to_take_out`.
- **Evidence:** `logs/B1-payload-take-out.txt` lines 2 and last; `logs/B1-leftovers-payload.txt`; `logs/B1-chat-to-take-out.txt`.
- **Grade:** SERIOUS
- **Deterministic:** yes

## NOTE (open, including new)

### ن1 · `whatCameBack` still names two causes on a tail mutated in this build

- **Attack:** protect Thomas and Anna (`Scope::Conversation`) after `block_count=2`. Mutate last hex of Thomas’s tail. `read_a_document_that_came_back`. Apply `messages.dart` `whatCameBack` to the measured fields.
- **Should:** Thomas does not return from the forged tail (held). The glass does not state a cause the core has not proved.
- **Actual:** `brought_back=1` (Anna), `unresolved=[mutated Thomas]`, `thomas_back=false`, `anna_back=true`. Glass: «two different things do that: the word was protected before Z Privacy began keeping every protected word, **or** this token was changed after the file left…» Cause 1 is false on this run. Cause 2 is what happened. Core still cannot tell them apart.
- **PASS=29 FAIL=0** on the rest of B4 (no wrong-person restore).
- **Grade:** NOTE
- **Deterministic:** yes

### ن2 · Argon2id guess cost

- Measured on this machine, release, same parameters as `vault/crypto.rs` (m=65536 KiB, t=3, p=1): **14.63–14.72 tries/s**. Eight-digit PIN ≈ 79 days. No attempt counter (intentional).
- **Grade:** NOTE (cost, not a defect of the KDF choice)
- **Deterministic:** timing varies slightly; order of magnitude stable

### ن3 · Pack / shape debts (not the خ3/خ4/خ5 subset)

Ligature `ﬁscher` missed; `Ms.Thornton` glued missed; `Müller,person` nothing; bankgiro / Moms / Swedish plate; Swedish lexicon narrower than Brev_Lindqvist; Arabic names with no pack (rule 56); `Abteilung` / `Vertragswesen` false Auto; `Kollege` as Person.
- **Grade:** NOTE
- **Deterministic:** yes

### ن4 · Band 6 vs footer 7 after confirm

After Protect on the one suggestion of the truthfulness fixture: `snap.autoProtected=6`, `payload.protected_count=7`, `ScanReport.auto=7`. Glass labels are true of two facts. `WHERE_EVERY_NUMBER_COMES_FROM.md` still names the band as `ScanReport.auto`.
- **Grade:** NOTE
- **Deterministic:** yes

### ن5 · Cumulative compression-bomb glass still says «a part»

`pdf_nine_pages_cumul.pdf` → core `CompressionBomb { ratio: 64 }` detail «the parts … in all … past the 16 MiB». Glass / `refusalCompressionBomb`: «A **part** of this file unpacks to more than 64 times…». Refusal is correct and named; the sentence drops «in all» and 16 MiB.
- **Grade:** NOTE
- **Deterministic:** yes

### ن6 · Zip entry 8 MiB+1 detail still floors

`docx_entry_over_8mib_store.docx` refused `TextTooLarge { limit_mib: 8 }`. Glass «more than 8 MiB». Core detail still «would be **8** MiB once unpacked, past the **8** MiB limit» (`uncompressed / 1024 / 1024`).
- **Grade:** NOTE
- **Deterministic:** yes

### ن7 · rustls still 0.23.45

Product `Cargo.lock`: rustls **0.23.45**, rustls-webpki 0.103.15, ring 0.17.14. crates.io stable on review day: rustls **0.23.46** (2026-10-14, four GHSA). `cargo-audit` absent. ureq+ring, no brotli feature, no ECH: brotli and ECH advisories do not apply to this link. The lock is still not on the patched crate.
- **Grade:** NOTE
- **Deterministic:** yes (lock file)

### ن8 · Mailbox split

`packaging/linux/README.txt` and root `README.md`: `yourvoices.app@mono-peak.com`. Site and privacy pages: `zprivacy@mono-peak.com`. First-run prints neither.
- **Grade:** NOTE
- **Deterministic:** yes

### ن10 · Panic across FRB: no `catch_unwind` in the wrapper

Zero `catch_unwind` in `bridges/native/z_bridge/src`. `setup_default_user_utils` remains. Generated codec still `.unwrap()`.
- **Grade:** NOTE
- **Deterministic:** yes (source)

### ن11 · `writing.lock` as a directory still drops the flock

Source still `open_the_lock(...).ok()?` then `file.lock().ok()?` → `None` → `with_core` proceeds without flock. This run: 8 trials, **silent_lost=0** (previous 1/8). `ensure_disk_unchanged` caught the race here. Hole remains; honest two-copy path still 0/40 silent loss.
- **Grade:** NOTE
- **Deterministic:** the hole is in source; silent loss was not reproduced this time

### ن14 · Amount and date-line city still leave

`184,60 €` and `Leipzig, 14. Oktober 2026` remain after finished review. Matches the written product limit (identified values, not all context).
- **Grade:** NOTE
- **Deterministic:** yes

### A1-1 · First screen still has no Svenska — now an explicit unwritten-interface debt

`theListIsWrittenIn('sv')` is false: 7/7 promise keys in `app_sv.arb` are byte-identical to English; the only sv≠en value is `thisLanguageName=Svenska` (313 identical keys, 1 differing). First screen: `offeredLanguages.where(theListIsWrittenIn)` → Deutsch and English only. Session/settings still offer `sv`. `theLocaleOf('sv')` returns `en`. Language card draws `theInterfaceIsEnglishUntilTranslated`. Dead Interface card is gone. A Svenska button on first-run would still hand English promises (including «The English privacy rules will be enabled.»); that button is not drawn.
- **Grade:** NOTE (the SERIOUS lie of English-under-a-Swedish-name is closed; Swedish UI is still unwritten)
- **Deterministic:** yes

### A1-2 · Packaging README still says the interface is English

`packaging/linux/README.txt`: «The interface is English. The detection packs are German, Swedish and English.» German is a written list (promise keys differ; 314 sentences this stage). A person who taps Deutsch gets a German glass. The archive README is the quieter, now-stale copy.
- **Grade:** NOTE
- **Deterministic:** yes

### N-README-PACKS · Root README omits the Swedish pack that G38 and the packaging README name

Root `README.md`: «The interface is English; the detection packs are German and English.» Packaging README and gate G38: de, en, sv. `offeredLanguages = ['de','en','sv']`. Three public sentences for one fact.
- **Grade:** NOTE
- **Deterministic:** yes

### N-ZCFG-DOC · `SECURITY_INVARIANTS.md` still says four ZCFG fields; the file has eight

G18a at this commit: allowlist of **8** names. `config.rs` `ALLOWED` adds `original_pane_percent`, `columns_in_step`, `safe_column_open`, `review_panel_wide` (layout bits, no client names). The contract paper still says four names and a struct of four fields. Extra fields were not observed to hold user work.
- **Grade:** NOTE (stale contract, not a leak)
- **Deterministic:** yes

### N-GATES-DART · Dart / G7-dart / archive path-scan skipped

Gates skipped four checks: no linux debug bundle, so no G7-dart; no `dist/` archive, so no «`/home/` in the archive»; Dart count not compared to `MEASURED_ON_LINUX.txt`. Rust 792 compared and matched.
- **Grade:** NOTE (coverage hole of this run, not a product defect)
- **Deterministic:** yes on this machine without a prior `flutter build linux --debug`

## Held (attacks that did what the plan required)

- Direct Mode absent. `send` / `ask_model` take `PayloadHandle` only. Gate G2 / G2b passed. «The original text» chip is a deletion comment plus `findsNothing` tests.
- خ2 / B1-3 IBAN-as-Person jam: `set_question("Was schuldet Markus Feldmann Frau Katrin Sommer? IBAN DE89…")` after Protect-all minted **no** Person token whose value is `"IBAN"`. Safe question keeps the label. `build_payload` succeeded. Previous error `a protected value still stands 5 time(s) where at most 2 was expected` did not occur. Hand-protect of the word `IBAN` (2 places) still built. Product test `the_label_is_not_a_value.rs` exists and this independent probe agrees.
- Empty 0-byte `vault.zv` is `Absent`; create writes 235 bytes. Truncated / magic xor / last-byte xor / trailing data refused without overwrite.
- Two writers, 40 trials: silent_lost=0, honest `VaultChangedElsewhere=40`. Session turns 20/20 both on disk. Product test `two_copies_never_lose_a_write` 3/3.
- `delete_entity`: `entities=0`, `blocks=1`; next document `protected=0`. `a_block_is_never_deleted` 10/10. No `blocks.remove` path on vault blocks.
- MODEL_VERSION=15. Older reader vs newer vault names «written by a newer version». Conversation(7) from model 14 survives.
- PDF Flate 9 MiB and 946×: `CompressionBomb { ratio: 201 }`, not imported, not named as a scan. Real scan: `ScannedPdfNoTextLayer { pages: 3 }`. ObjStm bomb: CompressionBomb 201, RSS 4868 KiB. 25 MiB+1: `DocumentTooLarge { mib: 26, limit_mib: 25 }`. 25 MiB exact accepted. XXE listener: 0 connections.
- B4 forged tokens: PASS=29 FAIL=0. Foreign vault z-pdf: `brought_back=0`. Repeat×100 / cut token: no panic, no wrong restore.
- Disk after ألماني 1 journey: **NO HITS** UTF-8/UTF-16 for originals, passphrase, or probe key in `vault.zv` / `settings.zcfg` / `*.zs` / `writing.lock`.
- B7: ten number-pairs agreed and moved with scan/answer.
- `chat_to_take_out` is present (fourth door, not on 84832a0). Copy is tokenised; it carries the same خ5 leftovers, not a new class of leak.
- Gates: 594/594 non-skipped passed, including golden documents and rule 62.

---

# 2. Previous Findings Retest

Previous report: `REPORT_2_on_84832a0.md` on installed `84832a015f74952556f5d512187a8d5f99673d9d` (مانع 0 / خطير 8 / ملاحظة 14). Closed six blockers from `5f5bef1` are retested here too.

| ID | Previous (84832a0) | How retested at 2b4fad9 | Status | Evidence |
|---|---|---|---|---|
| م1 Direct Mode vs first-run promise | FIXED | Grep contract/gateway/Dart/glass; G2/G2b; gate «rule 62» | **STILL FIXED** | `findings/B1-leaks.md`, `logs/B1-direct-mode.txt`, gates G2/G2b |
| م2 PDF Flate cut and imported | FIXED | `check_document` + `import_document` on `pdf_flate_over_8mib.pdf` | **STILL FIXED** | `CompressionBomb { ratio: 201 }`, RSS 5688 KiB, no 100% readable |
| م3 Flate bomb named as scan | FIXED | ratio-946 fixture vs `pdf_scanned_no_text.pdf` | **STILL FIXED** | bomb CompressionBomb 201; scan `ScannedPdfNoTextLayer { pages: 3 }` |
| م4 Mutated token, single false cause | closed as BLOCKER; remained ن1 | B4 driver: mutate Thomas tail after `block_count=2` | **STILL FIXED** as blocker (two-cause wording). ن1 still NOTE | `logs/B4-run.txt`, `findings/RETEST-B4.md` |
| م5 Two copies silent loss | FIXED 0/40 | b2-harness 40 trials + product test | **STILL FIXED** | silent_lost=0, VaultChangedElsewhere=40 |
| م6 Delete identity lie | FIXED | `delete_entity` then new session | **STILL FIXED** | entities=0 blocks=1, next protected=0 |
| خ3 host paths in binaries | FIXED on 84832a0 archive | This commit’s archive was not built; `package_linux.sh` now remaps `$ROOT`→`/zprivacy` for rustc; Dart rewrite still `$HOME` only | **NOT TESTED** on 2b4fad9 bytes | `scripts/package_linux.sh`; ن9 |
| خ4 ObjStm ~75 MiB | FIXED | `pdf_objstm_bomb.pdf` | **STILL FIXED** | CompressionBomb 201, RSS 4868 KiB |
| خ5 generic size sentence | FIXED | `messages` / `DocumentTooLarge` 26 vs 25 | **STILL FIXED** | glass «about 26 MiB … up to 25 MiB» |
| خ6 empty vault trap | FIXED | 0-byte vault.zv | **STILL FIXED** | Absent; create 235 B |
| خ9 `.zs` silent loss | FIXED by measurement | 20 turn races | **STILL FIXED** | both_on_disk=20 |
| ن16 25==25 | FIXED | `pdf_over_25mib.pdf` | **STILL FIXED** | mib: 26, limit_mib: 25, eq25=false |
| **خ1** Swedish missing on first-run | SERIOUS | ARB compare; `theListIsWrittenIn`; first_run filter; Language card | **PARTIALLY FIXED** | Lie (English UI under Svenska name) closed. First screen still de/en. Remaining A1-1 NOTE |
| **خ2** IBAN label as Person jams exits | SERIOUS | Independent ألماني 1 + attacker question; `the_label_is_not_a_value.rs` | **STILL FIXED** | no IBAN Person token; `build_payload` ok; old error absent |
| **خ3** ZWSP/NFD | SERIOUS | `b5_escapes` | **REGRESSED? no — still OPEN** (unchanged) | still SERIOUS |
| **خ4** en pack drops | SERIOUS | `b5` on إنجليزي 2 | **still OPEN** | still SERIOUS |
| **خ5** Postfach / Sparkasse | SERIOUS | B1 take-out + B5 expected list | **still OPEN** | still SERIOUS |
| ن1 two-cause whatCameBack | NOTE | B4 mutated tail + `whatCameBack` | **still OPEN** | NOTE |
| ن2 Argon cost | NOTE 13.74/s | argon_bench release | **still OPEN** (measured 14.63–14.72/s) | NOTE |
| ن3 shape/pack debts | NOTE | b5 + b5_escapes | **still OPEN** | NOTE |
| ن4 band 6 vs footer 7 | NOTE | b7.rs | **still OPEN** | NOTE |
| ن5 bomb glass «part» | NOTE | `pdf_nine_pages_cumul.pdf` | **still OPEN** | NOTE |
| ن6 zip 8 MiB floor | NOTE | `docx_entry_over_8mib_store.docx` | **still OPEN** | NOTE |
| ن7 rustls 0.23.45 | NOTE | Cargo.lock vs crates.io 0.23.46 | **still OPEN** | NOTE |
| ن8 mailbox mismatch | NOTE | packaging README vs site | **still OPEN** | NOTE |
| ن9 `libapp.so` `mono-privacy` | NOTE on 84832a0 archive | archive of 2b4fad9 not built | **NOT TESTED** | package_linux.sh source only |
| ن10 FRB panic policy | NOTE | grep catch_unwind | **still OPEN** | NOTE |
| ن11 lock-as-directory | NOTE silent_lost=1/8 | 8 trials | **still OPEN** (silent_lost=0/8 this run; hole remains) | NOTE |
| ن12 first-run network promise | held on 84832a0 live window | GUI of 2b4fad9 not launched | **NOT TESTED** live; ureq-only by source | — |
| ن13 leak tests in core | held | gates cargo test + disk search | **STILL FIXED** / held | NO HITS; G3 tests present |
| ن14 amounts leave | NOTE | B1 leftovers | **still OPEN** | NOTE |

Vocabulary: STILL FIXED / REGRESSED / PARTIALLY FIXED / NOT REPRODUCIBLE as required. Open scanner debts are **still OPEN** (reproduced), not «REGRESSED» — they were never closed.

---

# 3. Overall Attack Result

`scripts/gates.sh` on an isolated copy of `2b4fad93cc26b282e6fa9773ad2275544dcc7ee8` exited 0 (594 checks, 4 skipped, Rust 792). The six blockers closed on `84832a0` remain closed. خ2 (IBAN-as-Person jamming every exit) is closed on this commit: the label stays text, the audit skips token spans, and `build_payload` succeeds. خ1’s English-under-Svenska-name lie is closed by `theListIsWrittenIn` + `theLocaleOf` + a disclosure; Swedish UI is still unwritten and first-run still offers Deutsch and English only.

Three SERIOUS scanner debts from the previous report still reproduce: ZWSP/NFD vs the salutation, the English pack after the person has answered, and Postfach / Sparkasse after a finished review. The fourth door `chat_to_take_out` is present and carries those same leftovers, not a new leak class. Disk files of a scratch vault did not contain the letter’s originals. No BLOCKER was measured. The real vault hash did not change.

This is not a claim that the product is secure. It is the set of attacks that were run, what they did, and what they did not reach.

---

# 4. Not Touched / Could Not Test

- Real vault `~/.local/share/zprivacy` (hashes only). `~/Documents/zprivacy`. Real user documents.
- Live tree `/home/monopeaks/mono-privacy` (preserve-only).
- GUI of commit 2b4fad9: no packaged binary of this SHA; installed binary is `84832a0`. AT-SPI first-run, vault create, wrong passphrase, idle lock, recovery path, drag-and-drop, Not now, Undo, Forget on glass, clipboard, z-pdf writer (`protected_pdf.dart`), live Send to a real provider, pcap of a full session.
- `flutter build linux` and `flutter test` (would write the immutable tree’s `.dart_tool` / `build/`). Gates G7-build, G7-dart, and the Dart half of `MEASURED_ON_LINUX.txt` skipped for that reason.
- Linux archive of 2b4fad9 (`dist/`, `package_linux.sh` was not run). ن9 path-leak on this commit’s `libapp.so` therefore unmeasured. Installed `~/.local/opt/zprivacy` was not treated as this target.
- `cargo audit` (tool absent). Network live Send. Real API keys.
- Windows / macOS (no runner in this product). Android / iOS.
- Provider implementations other than the fake echo and source of `providers/http.rs` (redirects, `localhost` name, TLS). No packet capture.
- Recovery / shamir / paper backup if any UI path exists beyond vault passphrase create/unlock.
- Concurrent GUI two-windows (core two-process race was measured without the glass).
- Golden corpus write (read-only). ZPrivacy-lib other than parity-corpus fixtures.
- Arabic pack as a product offer (rule 56: unoffered). Full site XSS/hosting review.
- Sub-processors, update channel, CI on GitHub beyond reading workflows in source.
- Threat classes: evil maid / rollback of a *valid older* vault (the contract itself says freshness is not guaranteed), DMA, compromised OS, screenshot of restored values, clipboard after Copy Restored.

---

## Appendix — gates skips (verbatim reasons)

```
G7-build the library the Dart half speaks through (skipped: no apps/flutter_app/build/linux/x64/debug/bundle/lib yet)
G7-dart contract callable from Dart (skipped: run: cd apps/flutter_app && flutter build linux --debug)
no «/home/» anywhere in the archive (skipped: no archive in dist/ on this machine)
and the Dart half (skipped: the suite did not run here, so its number was not checked)
```

## Appendix — real vault

Before and after this review:

```
760da2625e3b23e02a24509326af5c6c2c5e9257c25ff66359153c3b725bc203  vault.zv
d685ad41cb251a046843ff5ff1a1cd6436cc7aea046db51326419f53bbdd09b0  settings.zcfg
mtime 2026-10-19 06:17:31 +0200
```
