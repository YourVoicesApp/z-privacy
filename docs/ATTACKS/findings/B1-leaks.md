# B1 — leaks

Commit `84832a015f74952556f5d512187a8d5f99673d9d` (copy under `/home/monopeaks/z-attack-final/src`). Installed stamp `z_core 0.1.0 · 2026-10-17 · 84832a0`. Temp data dir: `/home/monopeaks/z-attack-final/fixtures/de1-run/data` via `set_data_dir`. Fixture: copy of `~/نصوص التجربة/ألماني 1.txt` at `fixtures/docs/de1-original.txt` (sha256 `4a01beb4fb80546b91a9743b5b33064ef12beb96ad18348edda3d16fba7c9862`). Live vault `~/.local/share/zprivacy/vault.zv` hash unchanged (`1931180a88006ce40704b6f25ce1718e3b3c1e1cf9d8c1ca107a4cf40aea7592`).

Searches: UTF-8 and UTF-16 LE/BE (and reversed) over disk files, payload, question, PDF bytes, PDF read-back.

---

## Direct Mode / G2 / G2b

Rule 62 is deleted in this commit, not greyed.

- `z_core/src/api.rs`: `send(handle: PayloadHandle, …)` and `ask_model(handle: PayloadHandle, …)`. Comment at the contract: there is no second door that takes a `String`.
- `z_core/src/gateway.rs`: `Request.payload` is a `PayloadHandle` only.
- `z_core/src/providers/mod.rs`: `ask` takes a handle; the old `&str` door is deleted.
- Dart: `send({required PayloadHandle handle, …})`, `askModel({required PayloadHandle handle, …})`.
- Glass: `send_sheet.dart` — the «The original text» chip is gone. `only_the_protected_version_is_sent_test.dart` greps the app (bridge included) for `askModelDirectly` / `sendOriginal`.
- Gate G2b in `scripts/gates.sh`: every `send*` / `ask*` public signature must name `PayloadHandle`.

No remaining signature accepts original document text for send/ask.

---

## Defects

### B1-1 · Address Protect leaves the PO box on the same line

What I did: imported ألماني 1.txt with pack `de`, scanned, answered Protect on every suggestion (including the address at span covering `04179 Leipzig`), then took the text out through `payload_to_take_out` (the door Copy Protected, Save as PDF, and pull share).

What should happen: Protect on that address line should take the postal identity with it, or the review should have asked about `Postfach 4410` as its own value. The line that leaves should not still name the box.

What happened: the payload and the z-pdf read-back both still contain `Postfach 4410 · <ADDR token>`. The suggestion’s span was only the postcode+town. The box number was never a finding.

Grade: خطير

### B1-2 · Bank name never offered, still leaves

What I did: same journey; searched the leaving text (copy/PDF/payload) for original values from the letter.

What should happen: a bank identity on a `Bankverbindung:` line is the same class of thing as the GmbH on the letterhead (which *was* offered). Either it is offered, or the review must not claim every identified value has been answered.

What happened: after zero open suggestions, `Sparkasse Leipzig` still stands in the payload, the copy door, and the PDF read-back, next to a tokenised IBAN and BIC. The scanner already knows the `Bankverbindung:` line (it cuts the IBAN out of it) and does not treat the bank’s name.

Grade: خطير

### B1-3 · In-app question turns the word «IBAN» into a person, then jams every exit

What I did: after a clean take-out, set the question `Was schuldet Markus Feldmann Frau Katrin Sommer? IBAN DE89 3704 0044 0532 0130 00` (names already in this document) and built a payload to send/ask.

What should happen: names and the IBAN *number* leave as the same tokens the document already minted. The label «IBAN» is not a person. `build_payload` / `ask_model` / `send` still open.

What happened: `question()` returned the names and the number as tokens, and minted a new person token whose value is the four letters `IBAN`. The next `build_payload` refused: `a protected value still stands 5 time(s) where at most 2 was expected`. The audit counts the substring `IBAN` inside `__Z_…_IBAN_…__` tokens as well as the two labels still in the letter. Copy, PDF, pull and send are then all closed on this document until the person undoes a protection they never asked for.

Grade: خطير

### B1-4 · Invoice amount and letterhead city leave after a finished review

What I did: same take-out and PDF read-back, UTF-8 search of original needles.

What should happen: under the product’s own contract, amounts are not personal data (scanner comment on payroll figures) and a city on a date line is context. They are still original values from this letter, and they do leave.

What happened: `184,60 €`, `Leipzig, 14. Oktober 2026`, and the three dates remain in copy, payload, and PDF. This matches the written limit (protect identified values, not all context) more than it matches a leak of a protected value.

Grade: ملاحظة

---

## What held

### Copy / pull (`payload_to_take_out`)

Same string as the Safe column. After answering review: Markus, Feldmann, Katrin, Sommer, Stadtwerke Lindenau GmbH, Gartenstraße 17, 04155 Leipzig, 04179 Leipzig, 7731-0458, RE-2026-118734, the IBAN, BIC, phone, and `k.sommer@stadtwerke-lindenau.example` are tokens. Control strings (`Kundenservice`, `Zweite Mahnung`) remain, so the search is not blind.

### PDF

Writer: `apps/flutter_app/lib/core/protected_pdf.dart`. Generated `Session 1-protected-2026-10-17.pdf`.

- No `/Info`, `/Title`, `/Author`, `/Creator`, `/Producer`, `/CreationDate`, `/ModDate`.
- Byte search of the compressed CID file finds none of the needles (expected: glyph indices). Product reader (`import_document` kind pdf) reads the same leftovers as the payload, and none of the protected names/IBAN/email/phone.
- Filename is the session name, not the source file. Default `Session N`. Passing the source stem `ألماني 1` as the session name puts that stem in the *filename only*, not in the file.

### In-app chat (`ask_model` / `set_question`)

Question text is scanned (`protect_lines`) before it is a workspace line. Document names in the question became the document’s own tokens. `ingest_answer` stores `question_safe`, not the typed line. `conversation_record(question: String, answer: String, …)` exists on the contract and is not called from `lib/` (only `contract_test.dart`).

`ask_model` itself was not completed on this fixture after B1-3 jammed `build_payload`. `wire_capture` (below) is the wire measurement.

### Disk (temp data dir)

Files the core wrote: `vault.zv` (magic `ZVLT`), `settings.zcfg`, `sessions/1.zs` (opaque), `writing.lock` (0 bytes).

UTF-8 and UTF-16 LE/BE (and reversed) over that folder: **no hits** for the letter’s originals, the vault passphrase, or `sk-probe-not-a-real-provider-key-0001`.

`settings.zcfg` after a saved journey:

```
ZCFG1
schema_version=1
first_run_completed=true
ui_language=de
default_privacy_pack=de
…
```

No client name, no token, no key, no path.

Provider key: `connect_provider` while the vault is open seals it under `Purpose::Provider` inside `vault.zv`. `ProviderRow` returns `connected` / `session_only` and never the secret (G8). Debug of `RevealedValue` prints `[REDACTED]`.

### Network

- One client: `ureq`, declared in `z_core/Cargo.toml`, named only in `z_core/src/providers/http.rs` (G1).
- Socket opens in `post_json` from `providers::ask` (send / ask_model) and `ping` (test connection, body is the word `ping`).
- `https`, or literal loopback IP; `localhost` as a name is refused. `max_redirects(0)`. User-Agent `z-privacy`.
- No analytics/telemetry/sentry in product `lib/` or `z_core`.
- Flutter `pubspec.yaml` has no http/dio. Transitive `http 1.6.0` comes from `file_selector_platform_interface`; `apps/flutter_app/lib` does not import it (G5).

### First-run vs site

First-run (`first_run.dart`): No account / no ads / no analytics / no Z Privacy server. Originals stay unless you explicitly copy restored content. Only the protected version is sent to AI through Z Privacy.

Site `en/index.html`: originals stay unless you explicitly export restored text; vault local; no account / no backend; clipboard is outside once copied; minimises, does not anonymise.

Site `en/privacy/index.html`: names the files that check the promises (`wire_capture.rs`, `the_vault_file_says_nothing.rs`, `zcfg_leak.rs`, `http.rs`). No analytics on the site.

Copy Restored is the named exception on first-run; the site says «export restored». Same door.

### Existing tests (copy, this commit)

```
cargo test -p z_core --features fake_provider,test_clock \
  --test no_leak --test the_vault_file_says_nothing \
  --test zcfg_leak --test wire_capture --test wire_refusals
```

- `no_leak`: 4 passed
- `the_vault_file_says_nothing`: 1 passed (searched `vault.zv` + empty `writing.lock`)
- `zcfg_leak`: 1 passed
- `wire_capture`: 1 passed (loopback records the SafePayload character for character; originals absent from body, headers, URL)
- `wire_refusals`: 9 passed

---

## Coverage checklist

- [x] Fixture copied from `~/نصوص التجربة/ألماني 1.txt` into `z-attack-final/fixtures`
- [x] Copy door = `payload_to_take_out` (UTF-8 / UTF-16 search)
- [x] PDF door: metadata, filename, product read-back
- [x] Pull / `payload_to_take_out`
- [x] `send` / `ask_model` take a handle (G2 / G2b); Direct Mode gone from contract, gateway, providers, glass
- [x] In-app question scanned; `ask_model` jammed after B1-3 (recorded)
- [x] Disk: `vault.zv`, `settings.zcfg`, `sessions/*.zs`, `writing.lock` — no plaintext original
- [x] Temp data dir via `set_data_dir`; live `~/.local/share/zprivacy` not written
- [x] Network: ureq only, only on send/ping; no analytics
- [x] First-run promises vs `site/en/index.html` and `site/en/privacy/`
- [x] Tests: `no_leak`, `the_vault_file_says_nothing`, `zcfg_leak`, `wire_capture`, `wire_refusals`
- [x] No product source written
