# Comparison evidence — three axes only

Work copy `/home/monopeaks/mono-privacy-comparison-20261013-022102` · branch `comparison/local-cycle`.
Product HEAD `d882c5f` · bundle stamp `z_core 0.1.0 · 2026-10-13 · 61fa27b`.
Isolated sandbox only. Dummy values. Origin vault, backup, GitHub, and ZPrivacy-lib were not written.

Axes (the only ones scored):

1. How protection areas are found
2. Kind of protection and restore
3. Chat and PDF

Evidence tags: **tested** · **confirmed-from-code** · **documented** · **unknown**.
Absence from a README is not proof a feature does not exist.

---

## Z Privacy — button names vs the three comparison scopes

The engine has **four** scopes (`z_core/src/api.rs`). The comparison asked for **three** user-facing behaviours. Mapping from this build, without changing app code:

| Comparison axis | Engine `Scope` | Button / label the person actually sees | What the press does in this build |
|---|---|---|---|
| 1. Current-document protection | `Once` | Hand dialog **Just here** — “This one place. The same words elsewhere are left alone.” Token tag **Just here**. | Protects that span only. Session-local. **confirmed-from-code** `protect_dialog.dart`, `tokens.dart` |
| 2. Permanent protection for documents | `Always` | Hand dialog **Remember everywhere** — “Kept in the vault for every client, and found by itself from now on.” Token tag **Remembered everywhere**. Review-row / bubble **Always**. | Vault `learn_value`. Later documents (any client) can find it. **confirmed-from-code** `ops/mod.rs` |
| 3. Protection everywhere including chat | `Conversation` plus vault-Always | Hand dialog **This conversation** — “Every appearance here, under one token. Gone when this conversation is.” Token tag **This conversation**. Review-row / bubble **Protect**. | Session key covers this document **and** this session’s chat send/restore. Always-learned values also apply to later chat. **confirmed-from-code** |

Fourth engine scope, not one of the three comparison axes:

| Extra | Engine | Button | This sandbox |
|---|---|---|---|
| Remember for one client | `Profile` | **Remember for &lt;client&gt;** | Disabled: 0 profiles. AT-SPI: “0 profiles”. **tested** (UI state) + **confirmed-from-code** |

Naming mismatch (fact, not a defect score):

- Review **Protect** writes `Scope::Conversation` (“This conversation”), not “Just here”.
- Review **Always** also writes `Scope::Conversation` on the session **and** `learn_value` into the vault before the session lock (`ops/mod.rs` ~2682–2752). The token tag on that session row stays “This conversation”; the vault copy is what later documents/chats can find.
- Hand-protect is the path that can choose **Just here** / **This conversation** / **Remember for** / **Remember everywhere**.
- Auto-protect of `Confidence::Auto` (IBAN checksum, phone, email, salutation/title, …) writes `Scope::Conversation`, not vault-Always (`ops/mod.rs` ~2446–2462).

Finding classes the scanner actually uses (**confirmed-from-code** `scanner/mod.rs`, `general_rules.rs`, `people.rs`):

| Class | How found | Default act |
|---|---|---|
| Auto | Structured values that “cannot reasonably be anything else” (IBAN+checksum, BIC, email, phone, …). Salutations/titles Auto. | Protected as This conversation without a press |
| Needed a decision | Dictionary names: two known names in a row, **never Auto** (`people.rs` “Never Auto”). | Offered; **Protect** / **Always** / **Not sensitive** / **Skip** |
| Manually specified | Person selects a span and presses Protect in the hand dialog | Kind + one of the four scopes |
| Left clear | Not selected, skipped, or marked Not sensitive | Stays in the payload. **Not a protection failure unless the person chose to protect it.** |

Alice Jensen / Alicia Jensen were **not** in this German cycle. They remain a fixture for the mock only. This build does not join two spellings without an explicit user decision. **confirmed-from-code**; **not tested** on this run.

---

## Z — completed textual experiment (chat restore)

Source: `z_core/tests/fixtures/Brief_Weber.txt` (German letter). Session title on screen: **الاختبار الأول** (`sessions/1.zs`, namespace `1F52`). Vault after the work: **1 identity, 19 values**, 0 profiles, 0 AI providers connected.

What happened, as displayed in the isolated UI:

1. The person **manually protected** German segments (hand selection, not an auto-only pass).
2. A summary came back containing **seven** `__Z_…__` tokens.
3. Z restored those seven tokens to values matching the original letter.

Limits of this evidence:

- **tested** as a **textual** result from displayed Copy Protected / Paste AI answer / Restored output.
- Capture `GET /requests` is still `[]` — **Send to Local AI** did not hit `127.0.0.1:8081`. This is not a wire-capture PASS.
- This is **not** proof of PDF restore, and **not** proof of automatic detection.

Whole-span restore: original line is `Meine E-Mail-Adresse lautet m.weber@beispiel-firma.de`. The protected PDF (same session) shows `Meine E-Mail-Adresse __Z_1F52_EMAIL_C055081E__`. Restoring that token brings back **`lautet` together with the email**. Restore returns the entire selected span, not the address alone. **tested** (displayed text + PDF extract of the same token).

---

## Z — protected PDF (separate from the seven-token chat)

Path (sandbox HOME only):

`tests/cycle/sandbox/home/Documents/zprivacy/text-protected-2026-10-13.pdf`

16172 bytes · PDF 1.5 · 1 page · sha256 `1776f077f0a798a14afd5932f44d050c7c7b84a840c8e20ff2509b4c846c2aa4`.

Footer (product, **tested** extract): `z_core 0.1.0 · 2026-10-13 · 61fa27b · 33 places replaced, 28 values (Address ×1, BIC ×1, Customer number ×1, E-mail ×2, IBAN ×1, Person ×15, Personnel number ×1, Phone ×3, Something else ×3) · sha256 of the protected text 4cc99e955ed0acd69cc5878e011edd90de2e04950c02430b9aad9e7077d3c01c`.

Writer: Dart `protected_pdf.dart` — local file, no network, no `/Info` dictionary. **confirmed-from-code**.

Origin `~/Documents/zprivacy/` still holds only the older Faruk/invoice PDFs (9 Oct). Origin vault size 742 mtime 1791828743 unchanged. Isolation held. **tested**.

### Values in the German letter — finding class (PDF extract + scanner rules)

Classes below mix **tested** (what the PDF shows) with **confirmed-from-code** (how this scanner treats that kind). The person did manual protects; Auto vs hand on each row was not logged from the review banner, so Auto/decision is inferred from rules where the PDF token exists, and **unknown** where the UI choice was not captured.

| Original span | Token kind | Finding class | Notes |
|---|---|---|---|
| Katharina Lindemann | PERSON ×2 | needed a decision (dictionary, never Auto) | Protected |
| Tobias Reinhardt | PERSON ×2 | needed a decision | Protected |
| Amira Haddad | PERSON | needed a decision (Frau Dr. title Auto on the name after it) | Protected; title `Dr.` stays clear by rule |
| Markus Weber (twice) | PERSON ×2, reused | needed a decision / signature | Same tokens in body and sign-off |
| Yusuf Demir | PERSON ×2 | needed a decision | Protected |
| IBAN DE89 3704 0044 0532 0130 00 | IBAN | Auto (checksum) | Protected |
| BIC COBADEFFXXX | BIC | Auto | Protected |
| +49 89 1234 5678, 0171 9876543, 089 1234 5699 | PHONE ×3 | Auto | Protected |
| `lautet m.weber@beispiel-firma.de` | EMAIL | Auto email **plus** manual span (`lautet` included) | Whole span |
| jonas.petersen@kanzlei-petersen.de | EMAIL | Auto | Protected |
| Kundennummer 7733-9120 | CUSTNO | Auto / pack | Reused twice, one token |
| Personalausweisnummer L01X00T47 | EMPNO | Auto / pack | Protected |
| Bahnhofstraße | ADDR | Auto / pack | House number `27` left clear |
| USt-IdNr. DE123456789 | CUSTOM | manually specified | Something else ×3 includes this |
| `vielen Dank` | CUSTOM + PERSON | manually specified | Split across two tokens |
| Lindenstraße | PERSON | manually specified or name-shaped | Street tokenised as Person |
| `Mein Fahrzeug` | PERSON ×2 | manually specified | Not a person in the source |
| `Lieferung` | PERSON (reused) | manually specified | Same token in two places |
| `vor Ort` | CUSTOM + PERSON | manually specified | |

Leftover **clear** in the PDF (**tested** extract). Recorded; **not** a protection failure unless the person chose to protect them:

| Left clear | Why it is listed |
|---|---|
| Rechnung Nr. `2026-04471` | Invoice id stayed readable |
| Dates `14. September 2026`, `3. März 2025`, `22. September`, `10. Oktober 2026`, `27.11.1979`, `18. August 2026`, `14:30` | Dates not tokenised |
| Amount `1.284,50 Euro` | Amount not tokenised |
| `Lindemann & Partner GmbH` | Company line clear |
| `Jonas Petersen` | Name beside a tokenised email |
| Steuernummer `143/815/08154` | Tax number clear |
| `Sophie Brandt` | Name clear |
| Plate `A-MW 2041` | Kennzeichen clear |
| `Weber Elektrotechnik GmbH` | Company clear |
| Cities `München`, `Augsburg`, `Düsseldorf` | Clear |
| House numbers `27`, `8`, `112` | Clear next to some tokenised streets |
| `Berliner Allee 112` | Street+number clear |

Chat seven-token restore and this 28-value PDF are **two artefacts of one session**, not one proof.

PDF reopen + second session in the same vault: **not done yet**. Next UI step is in `MANUAL_UI.md`.

---

## Z — mock (tools only, this folder)

Default `POST /v1/chat/completions` reply now:

- Echoes **every** `__Z_…__` token in the last user message, unchanged, even if names/IBANs remain in the clear.
- Never copies original values into the reply (replaced with `<LEFT_CLEAR>`).
- Records leftover clear on the request as `leftover_clear`. That list is **not** a capture FAIL.

Alice / Alicia are **not** joined by the mock.

---

## Rizzo (rizzo-pii)

Identity: [Rizzo-AI-Academy/rizzo-pii](https://github.com/Rizzo-AI-Academy/rizzo-pii). Version cited: app **Rizzo PII 2.0.0** (release `v2.0.0`, 8 Aug) · model **rizzo-pii-0.3B v1.5.0**. Default HTTP `http://127.0.0.1:5005` (GitHub cycle expected `:5006/analyze`). **Not started in this sandbox. Not tested here.**

| Axis | What the public docs and README state | Tag |
|---|---|---|
| 1. Finding | Neural token-classifier (mmBERT / ModernBERT, 22 BIO tags) **paired with** a regex+checksum net (IBAN mod-97, CF, PIVA, Luhn). A disabled tag is still detected and left in the clear. Residual/short values warned via `X-PII-Residual` / `X-PII-Skipped`. | **documented** (README, release 2.0.0). Code in that repo not confirmed in this copy. |
| 2. Protection / restore | Reversible placeholders `[FULLNAME_1]`, `[IBAN_1]`, `[CF_1]` + local dictionary on disk. Identical values share one placeholder. Switch `--no-mapping` / `PII_MAPPING=0` builds **no** restore map. Per-tag exclude. No Z-style Just here / This conversation / Remember everywhere. | **documented**. Restore **documented**, **not tested** here. |
| 3. Chat + PDF | Copy anonymized text into ChatGPT/Claude/Gemini, restore locally from the answer (chat is paste, not an in-app provider send). `POST /pdf` returns a redacted PDF (content-stream replace, not a black box); metadata/XMP/annotations/form fields/bookmarks scrubbed. `POST /analyze` for text/PDF/md/txt. Preview `POST /pdf/preview`. | **documented**. **not tested** here. |

GitHub cycle `/analyze` on `:5006`: **SKIPPED** (nothing listening).

---

## Secret Guard

GitHub `tests/cycle` (branch `tests/cycle`, commit `b42cf0e`) expected a compatible **`POST http://localhost:5007/analyze`** in “gateway mode”. No local checkout, no running process, no confirmed repository.

`chintanshah35/secretguard` is a **CI source-code secret scanner** (`npx secretguard .`). It is a different product: it does not claim chat restore or a protected PDF. It is **not** identified as the cycle’s Secret Guard.

| Axis | Record | Tag |
|---|---|---|
| 1. Finding | Unknown for the cycle target | **unknown** |
| 2. Protection / restore | Unknown | **unknown** |
| 3. Chat + PDF | Unknown. Cycle assumed `/analyze` only | **unknown** |

Probe `:5007/analyze`: **SKIPPED**. README silence is not used as “no feature”.

---

## Ten-project table

No canonical list of ten names exists in origin `~/mono-privacy`, the GitHub `tests/cycle` README (it names **three**: Z, Rizzo, Secret Guard), or this work copy. Rows 4–10 are public products in the **same niche** (find PII, replace or mask, optionally restore, optionally PDF/chat). This is a disclosed working set for the three axes, not a ranking and not a claim of Z’s superiority.

| # | Project | Version / evidence date | 1. Finding | 2. Protection / restore | 3. Chat + PDF | Tag |
|---|---|---|---|---|---|---|
| 1 | **Z Privacy** | `d882c5f` / stamp `61fa27b` · 2026-10-13 | Rules + language pack. Auto vs Suggest vs hand span. Dictionary names never Auto. | Four engine scopes; review Protect = This conversation; Always = conversation + vault. Restore of returned tokens, whole selected span (`lautet`+email). | In-app Local AI `POST /v1/chat/completions`; Copy Protected; Save as PDF (local, no metadata). | finding **confirmed-from-code**; chat restore **tested** (UI text); PDF export **tested**; PDF reopen **not tested** |
| 2 | **rizzo-pii** | 2.0.0 / model 0.3B v1.5.0 | NER + regex/checksum, 22+1 tags, per-tag off | Reversible `[TAG_n]` + on-disk dict; optional no-mapping | Paste-to-LLM restore tab; `POST /pdf` true redaction | **documented** · **not tested** |
| 3 | **Secret Guard** (cycle `:5007`) | unidentified | unknown | unknown | unknown (`/analyze` assumed) | **unknown** |
| 4 | **Microsoft Presidio** (now data-privacy-stack/presidio) | public main, 2026-10 | NER + regex + checksum + custom recognizers; text/images/structured | Anonymizer operators (replace, mask, hash, encrypt, …). Encrypt can be reversed with the key; default replace is not a session vault | SDK/HTTP, not an LLM chat app. Image redactor for PDF-like pages is a separate module | **documented** · **not tested** |
| 5 | **OpenAI Privacy Filter** | openai/privacy-filter · Apr 2026 · 1.5B/50M | On-device token classifier, 8 categories | Mask / redact spans. Official card describes detection and masking, not a restore vault | Model only; chat/PDF would be an integrator. Browser demos exist | **documented** (openai.com + model card) · **not tested** |
| 6 | **Protect AI LLM Guard** | protectai/llm-guard Anonymize + Deanonymize | Presidio + extra patterns | Vault of `[REDACTED_TYPE_n]`; Deanonymize restores | Library around a prompt, not a PDF product | **documented** · **not tested** |
| 7 | **PasteGuard** (sgasser/llm-shield) | public README | Multilingual PII + secrets | Mask mode placeholders + restore; Route mode sends sensitive turns to local LLM | Browser ChatGPT/Claude/Gemini + API proxy + coding agents. PDF **unknown** (absence from README not treated as no) | **documented** · **not tested** |
| 8 | **Private Guard** (michalirving/private-guard) | public README | 30+ regex + on-device NER + optional MLP | `[PERSON_1]` etc., restore in the response even if brackets stripped | Chrome/Edge on web chat. PDF **unknown** | **documented** · **not tested** |
| 9 | **PrivAiTe** (crp4222/PrivAiTe) | public README | Presidio + OpenAI privacy-filter, local | Scrub then restore in the reply, including tool-call JSON | OpenAI-compatible proxy for agents. PDF **unknown** | **documented** · **not tested** |
| 10 | **A5 PII Anonymizer** | v0.0.1 | Local ONNX NER | `NAME_1` / `PHONE_NUMBER_2`; Pro JSON mapping for re-id | Desktop files including **PDF** in/out. In-app chat **unknown** | **documented** · **not tested** |

Similarities that actually appear in the sources:

- Z, rizzo-pii, LLM Guard, PasteGuard, Private Guard, PrivAiTe all describe **placeholder out, restore locally**.
- Z and rizzo-pii both ship a **person-facing document UI** plus a **protected PDF**. Presidio and Privacy Filter are **engines**.
- Z’s restore is **session-scoped tokens** (`__Z_<ns>_<KIND>_<tail>__`) with an optional **vault**. rizzo-pii’s mapping is a **local dictionary** that can be switched off. Those are different durability models.
- Z asks the person on dictionary names; rizzo-pii and Privacy Filter **tag then replace** (with optional per-tag off in rizzo).
- Leftover clear text is normal in Z when the person did not choose the span. rizzo-pii warns residuals. Treating leftover clear as an automatic fail would mis-score both.

Differences that actually appear:

- Z is a Linux desktop FFI app with a vault and four scopes. rizzo-pii is a local HTTP/Tauri app with `/analyze` + `/pdf`.
- Z’s chat path is an in-app OpenAI-compatible send. rizzo-pii’s documented chat path is copy/paste.
- Z PDF is a newly typeset page of the protected **text** plus a checkable footer. rizzo-pii `POST /pdf` on a PDF input claims **in-place content-stream** redaction of the original layout.
- Secret Guard in the cycle harness is still an empty slot.

---

## Out of scope

No full product audit. No app-code change. No ZPrivacy-lib. No origin/backup/GitHub write. No redteam harness pointed at origin.
