# B1 — leaks

Commit `2b4fad93cc26b282e6fa9773ad2275544dcc7ee8` (immutable tree `/home/monopeaks/z-attack-2b4fad9`). Stamp `z_core 0.1.0 · 2026-10-19 · 2b4fad9`. Probe: `/home/monopeaks/z-attack-2b4fad9-evidence/harnesses/b1-probe` with `CARGO_TARGET_DIR=/home/monopeaks/z-attack-2b4fad9-evidence/target-b1`. Data dir: `/home/monopeaks/z-attack-2b4fad9-evidence/scratch/b1/data` via `set_data_dir` (also `XDG_DATA_HOME=…/scratch/b1/xdg`, `HOME=…/scratch/b1/home`). Fixture: copy of `نصوص التجربة/ألماني 1.txt` at `fixtures/docs/ألماني 1.txt` (sha256 `4a01beb4fb80546b91a9743b5b33064ef12beb96ad18348edda3d16fba7c9862`). Real vault `~/.local/share/zprivacy` was not opened or written.

Public API used: `import_document`, `scan`, `list_findings`, `answer_finding(Protect)`, `payload_to_take_out`, `set_question` / `question`, `build_payload`, `ask_model` (fake provider), `chat_to_take_out`. Product source under `z-attack-2b4fad9` was not modified.

Searches: UTF-8 and UTF-16 LE/BE (and reversed) over disk files, payload, question, chat copy, and a hand-built PDF of the payload.

---

## Direct Mode / G2 / G2b — still gone

Rule 62 remains deleted, not greyed.

- `z_core/src/api.rs:2525` `send(handle: PayloadHandle, …)` and `:2547` `ask_model(handle: PayloadHandle, …)`. Comment at `:2612`: there is no second door that takes a `String`.
- `z_core/src/gateway.rs:84` `Request.payload` is a `PayloadHandle` only.
- `z_core/src/providers/mod.rs:225` `ask` takes a handle.
- Dart: `send({required PayloadHandle handle, …})`, `askModel({required PayloadHandle handle, …})` in `apps/flutter_app/lib/src/rust/third_party/z_core/api.dart`.
- Glass: `send_sheet.dart:915–926` — the «The original text» chip is gone (comment only, explaining the deletion). Tests `only_the_protected_version_is_sent_test.dart` and `the_model_that_answers_test.dart` assert `findsNothing` for that chip and grep the app for `askModelDirectly` / `sendOriginal`.
- Remaining mentions of those names are gate strings, test negatives, or comments. No live signature accepts original document text for send/ask.

Log: `logs/B1-direct-mode.txt`.

---

## Defects

### B1-1 · Address Protect leaves the PO box on the same line

- **ID:** B1-1
- **attack:** Import ألماني 1.txt with pack `de`. Scan. Answer Protect on every suggestion, including the address whose span is `04179 Leipzig`. Take the text out through `payload_to_take_out` (Copy Protected / Save as PDF / pull) and through `chat_to_take_out` after a send.
- **files:** `z_core/src/ops/mod.rs` (`payload_to_take_out`, `chat_to_take_out`); scanner address rule (LanguagePack postcode+town); findings dump `scratch/b1/run/findings-before-answer.txt` id=19 span `57..70` text=`04179 Leipzig`.
- **should:** Protect on that address line should take the postal identity with it, or the review should have asked about `Postfach 4410` as its own value. After a finished review the leaving text should not still name the box.
- **actual:** Zero open suggestions (`suggested=0`). Payload line 2 is still `Kundenservice · Postfach 4410 · <ADDR token>`. The suggestion’s span was only the postcode+town. The box number was never a finding. The same leftover stands in `chat_to_take_out` (twice: earlier request and echoed answer) and in a product-reader round-trip of a simple PDF of that payload.
- **commands:** `CARGO_TARGET_DIR=…/target-b1 cargo build --release` then `XDG_DATA_HOME=…/scratch/b1/xdg HOME=…/scratch/b1/home …/target-b1/release/b1-probe`; `python3 search_bytes.py scratch/b1/run/payload-take-out.txt --needles-file needles.txt`.
- **evidence:** `logs/B1-payload-take-out.txt` line 2; `logs/B1-leftovers-payload.txt` `Postfach 4410 raw=true in_the_clear=true`; `logs/B1-findings-before.txt` id=19; `logs/B1-chat-to-take-out.txt`; `logs/B1-payload-search.txt`; `logs/B1-pdf-readback.txt` `contains Postfach 4410: true`.
- **grade:** SERIOUS
- **deterministic:** yes

### B1-2 · Bank name never offered, still leaves

- **ID:** B1-2
- **attack:** Same journey; search the leaving text (copy / payload / chat / PDF read-back) for original values from the letter after every suggestion is answered.
- **files:** scanner on `Bankverbindung:` (cuts the IBAN, ignores the bank name); `logs/B1-findings-before.txt` / `logs/B1-findings-after.txt` — no finding whose text is `Sparkasse Leipzig`.
- **should:** A bank identity on a `Bankverbindung:` line is the same class of thing as the GmbH on the letterhead (which *was* offered and protected). Either it is offered, or the review must not claim every identified value has been answered.
- **actual:** After zero open suggestions, `Sparkasse Leipzig` still stands in `payload_to_take_out`, in `chat_to_take_out`, and in the PDF read-back, next to a tokenised IBAN and BIC. The scanner already knows the `Bankverbindung:` line (IBAN and BIC are tokens) and does not treat the bank’s name.
- **commands:** same probe; leftover report; byte search of payload and chat.
- **evidence:** `logs/B1-payload-take-out.txt` last line `Bankverbindung: Sparkasse Leipzig, IBAN __Z_…__, BIC __Z_…__`; `logs/B1-leftovers-payload.txt` / `logs/B1-leftovers-chat.txt` `Sparkasse Leipzig raw=true in_the_clear=true`; findings lists have Company=`Stadtwerke Lindenau GmbH` and Iban/Bic, never Sparkasse.
- **grade:** SERIOUS
- **deterministic:** yes

### B1-4 · Invoice amount and letterhead city leave after a finished review

- **ID:** B1-4
- **attack:** Same take-out; UTF-8 search of original needles in the leaving text.
- **files:** payload / chat / PDF read-back; scanner comments treating payroll/amount figures as not personal data.
- **should:** Under the product’s own contract, amounts are not personal data and a city on a date line is context. They are still original values from this letter, and they do leave.
- **actual:** `184,60 €`, `Leipzig, 14. Oktober 2026`, and the three dates remain in copy, payload, chat, and PDF read-back. This matches the written limit (protect identified values, not all context) more than it matches a leak of a protected value.
- **commands:** leftover report on `payload_to_take_out` and `chat_to_take_out`.
- **evidence:** `logs/B1-leftovers-payload.txt` `184,60 raw=true`; `scratch/b1/run/payload-take-out-clear.txt` still contains `Leipzig, 14. Oktober 2026` and `184,60 €`.
- **grade:** NOTE
- **deterministic:** yes

---

## What held

### Direct Mode

Gone from contract, gateway, providers, Dart, and glass. Send/ask take `PayloadHandle` only. See above.

### خ2 / B1-3 · IBAN-as-Person jam — fixed on this commit

Previously (84832a0): after Protect-all, `set_question("Was schuldet Markus Feldmann Frau Katrin Sommer? IBAN DE89 3704 0044 0532 0130 00")` minted a Person token whose value was the four letters `IBAN`, then `build_payload` refused `a protected value still stands 5 time(s) where at most 2 was expected`. Copy, PDF, pull and send closed.

On `2b4fad9`:

- `question()` / `set_question` marks: Markus, Feldmann, Katrin, Sommer as Person; the number as Iban; **no mark on `IBAN`**.
- Token values: no token whose value is `"IBAN"`. Safe question: `Was schuldet <PERSON> <PERSON> Frau <PERSON> <PERSON>? IBAN <IBAN>`.
- `build_payload` **succeeded** (`logs/B1-build-iban-ok.txt`). `payload_to_take_out` and `ask_model` stayed open. Exact previous error **did not occur**.
- Second half: hand-`protect` of the word `IBAN` (`Applied { places: 2 }`) still built (`scratch/b1/run/protect-iban-word.txt`, `payload-after-hand-iban.txt`). The exit audit no longer counts `IBAN` inside `__Z_…_IBAN_…__` tokens.

Product test `z_core/tests/the_label_is_not_a_value.rs` documents this as the attacker’s B1-3. Independent retest on the German letter confirms the fix.

### Copy / pull (`payload_to_take_out`)

Protected (tokens, values from `reveal`): Markus, Feldmann, Katrin, Sommer, Stadtwerke Lindenau GmbH, Gartenstraße 17 / 04155 Leipzig, 04179 Leipzig, 7731-0458, RE-2026-118734, IBAN, BIC, phone, `k.sommer@stadtwerke-lindenau.example`. Control strings (`Kundenservice`, `Zweite Mahnung`) remain, so the search is not blind. `protected_count=17`, `open_suggestions=0`.

### Fourth door (`chat_to_take_out`) — present

Present at this commit (`api.rs:2590`, Dart `chatToTakeOut`, glass `session_state.dart:1098`). G36 lists four exits: `ask_model`, `chat_to_take_out`, `payload_to_take_out`, `send`.

Tested: after Protect-all, `set_question` without the word IBAN, `build_payload`, `ask_model` (fake echo), `chat_to_take_out`. Before a turn: `NothingToSend`. After a turn: transcript of protected request + echo. Names / IBAN / email / phone are tokens. Same B1-1 / B1-2 leftovers (`Postfach 4410`, `Sparkasse Leipzig`) leave on this door too — not a new class of leak, an extra exit for the same leftovers.

### PDF

Product writer is Dart `apps/flutter_app/lib/core/protected_pdf.dart`, fed by `payload_to_take_out`. **Not executed** on this commit: running `flutter test` would write the immutable worktree’s `.dart_tool` / build cache. Code inspection:

- `pw.Document(compress: true)` with no title/author/producer/creation date (`protected_pdf.dart:333–335`). Comment: `pdf` writes `/Info` only when one of them is given.
- Filename is the session name (`Session N-protected-YYYY-MM-DD.pdf`), never inside the file (`saveProtectedPdf` `sessionName`).

Supplementary: a hand-built uncompressed PDF of the payload (product *reader*, not the z-pdf writer) imported via `import_document` kind Pdf. Read-back still contains `Postfach 4410`, `Sparkasse Leipzig`, `184,60`; not Markus / DE89. Log: `logs/B1-pdf-readback.txt`. Compressed CID z-pdf bytes would not UTF-8-match those needles; the body text is the payload.

### In-app chat (`ask_model` / `set_question`)

Question text is scanned before it is a workspace line. Document names in the question became the document’s own tokens. `ask_model` completed on the fake provider after the IBAN-jam fix. `chat_to_take_out` is the copy of that history.

### Disk (scratch data dir)

Files the core wrote: `vault.zv` (magic `ZVLT`), `settings.zcfg`, `sessions/1.zs` (50 bytes) and `sessions/2.zs` (10882 bytes, opaque), `writing.lock` (0 bytes).

UTF-8 and UTF-16 LE/BE (and reversed) over `scratch/b1/data`: **NO HITS** for the letter’s originals, the vault passphrase, or `sk-probe-not-a-real-provider-key-0001` (`logs/B1-disk-search.txt`).

`settings.zcfg` after a saved journey:

```
ZCFG1
schema_version=1
first_run_completed=true
ui_language=de
default_privacy_pack=de
…
```

No client name, no token, no key, no path. Provider key from `connect_provider` while the vault is open is sealed inside `vault.zv`. `RevealedValue` Debug prints `[REDACTED]` (field `.value` is still returned to the owner on `reveal`).

### Network / GUI

- One client: `ureq`, declared in `z_core/Cargo.toml`, named only in `z_core/src/providers/http.rs` (`ureq::` hits only there).
- Socket opens in `post_json` from `providers::ask` (send / ask_model) and `ping`. `https` or literal loopback IP; `localhost` as a name is refused. `max_redirects(0)`. User-Agent `z-privacy`.
- No analytics/telemetry/sentry in product `lib/` or `z_core`. `apps/flutter_app/lib` does not import `package:http` / `package:dio`.
- First-run (`first_run.dart`): No account / no ads / no analytics / no Z Privacy server; only the protected version is sent.
- **GUI launch: Not Tested.** Building or starting the Flutter binary would write the immutable worktree’s target/`.dart_tool`, and a default-HOME launch would touch the real vault. First-run TCP was not measured with `ss`/`lsof`. Code inspection only.

---

## Coverage checklist

- [x] Fixture copied from `نصوص التجربة/ألماني 1.txt` (sha256 match with `de1-original.txt`)
- [x] Copy door = `payload_to_take_out` (UTF-8 / UTF-16 search)
- [x] PDF: writer inspected (no `/Info`); product writer not executed; reader round-trip of payload PDF
- [x] Pull / `payload_to_take_out`
- [x] `send` / `ask_model` take a handle (G2 / G2b); Direct Mode gone
- [x] In-app question scanned; IBAN question retested; `ask_model` completed
- [x] Fourth door `chat_to_take_out` present and tested
- [x] Disk: `vault.zv`, `settings.zcfg`, `sessions/*.zs`, `writing.lock` — no plaintext original
- [x] Temp data dir via `set_data_dir`; live `~/.local/share/zprivacy` not opened
- [x] Network: ureq only, only on send/ping (code); GUI/TCP Not Tested
- [x] No product source written
