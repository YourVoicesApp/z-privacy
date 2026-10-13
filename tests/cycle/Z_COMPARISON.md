# Comparison evidence — three axes only

Work copy `/home/monopeaks/mono-privacy-comparison-20261013-022102` · branch `comparison/local-cycle`.
Product HEAD `d882c5f` · bundle stamp `z_core 0.1.0 · 2026-10-13 · 61fa27b`.
Isolated sandbox only. Dummy values. Origin vault, backup, GitHub, and ZPrivacy-lib were not written.

Axes (the only ones scored):

1. How protection areas are found
2. Kind of protection and restore
3. Chat and PDF

Inside axis 2, three facts stay separate. A button that names one does not
answer the others.

| Fact | What it is | What it is not |
|---|---|---|
| **Word-protection scope** | Where protection is **re-applied** when that **word** appears again, according to the person's choice. | Not where the document is saved. Not which key restores a token. |
| **Document save location** | Inside the app (session file) or outside it (exported PDF), owner's choice. Copies kept **in sessions** are the **protected** copies, because session files live **outside the vault**. | Not a Protect / Always / Just here choice. |
| **Session restore key** | The **matching session's** encryption restores protected segments (`__Z_<ns>_…__`). Record per token with that session's key. | Not predicted from a scope button. |

Evidence tags: **tested** · **confirmed-from-code** · **documented** · **unknown**.
Absence from a README is not proof a feature does not exist.

---

## Z — the three facts, from this build

### 1. Word-protection scope (the word)

The engine has **four** scopes (`z_core/src/api.rs`). The comparison asked for **three** user-facing behaviours. Mapping from this build, without changing app code. These buttons say **where the word is protected again**. They do not say where the document is saved, and they do not say whether a later restore will succeed.

| Comparison behaviour (the word) | Engine `Scope` | Button / label the person actually sees | Where the word is protected again |
|---|---|---|---|
| Current document | `Once` | Hand dialog **Just here** — “This one place. The same words elsewhere are left alone.” Token tag **Just here**. | This one place. **confirmed-from-code** `protect_dialog.dart`, `tokens.dart` |
| Permanent for later documents | `Always` | Hand dialog **Remember everywhere** — “Kept in the vault for every client, and found by itself from now on.” Token tag **Remembered everywhere**. Review-row / bubble **Always**. | Vault `learn_value`. Later documents (any client) can find that word again. **confirmed-from-code** `ops/mod.rs` |
| This conversation, including its chat | `Conversation` | Hand dialog **This conversation** — “Every appearance here, under one token. Gone when this conversation is.” Token tag **This conversation**. Review-row / bubble **Protect**. | Every appearance in this conversation. **confirmed-from-code** |

Fourth engine scope, not one of the three comparison axes:

| Extra | Engine | Button | This sandbox |
|---|---|---|---|
| Remember for one client | `Profile` | **Remember for &lt;client&gt;** | Disabled: 0 profiles. AT-SPI: “0 profiles”. **tested** (UI state) + **confirmed-from-code** |

Naming mismatch (fact, not a defect score), still about **the word**:

- Review **Protect** writes `Scope::Conversation` (“This conversation”), not “Just here”.
- Review **Always** also writes `Scope::Conversation` on the session **and** `learn_value` into the vault before the session lock (`ops/mod.rs` ~2682–2752). The token tag on that session row stays “This conversation”; the vault copy is what later documents can find **as a word**.
- Hand-protect is the path that can choose **Just here** / **This conversation** / **Remember for** / **Remember everywhere**.
- Auto-protect of `Confidence::Auto` (IBAN checksum, phone, email, salutation/title, …) writes `Scope::Conversation`, not vault-Always (`ops/mod.rs` ~2446–2462).

### 2. Document save location (the document)

The owner chooses **inside the app** or **outside it**. Product decision: the copy a session keeps is the **protected** copy, not the clear original, because the session file lives **outside the vault**.

| Place | Path in this sandbox | What is kept | Tag |
|---|---|---|---|
| Vault body | `xdg-data/zprivacy/vault.zv` | Session **number, handle, sealed 32-byte key**, document **hash** for matching. Not the conversation text. | **confirmed-from-code** `vault/model.rs` Conversation; `conversation.rs` header |
| Session file (inside the app, outside the vault) | `xdg-data/zprivacy/sessions/1.zs` | Turns: question **in the form that travelled** (tokens), answer as it arrived, allowed **token names**. Sealed under the session key. Values are not in this file. | **confirmed-from-code** `conversation.rs` (`FOLDER = "sessions"`, format v2); `ops/conversation.rs` `turns()` |
| Exported PDF (outside the app) | sandbox `Documents/zprivacy/text-protected-2026-10-13.pdf` | Newly typeset **protected** page + footer. Owner's file on disk. | **tested** extract + **confirmed-from-code** `protected_pdf.dart`, `data_dir.rs` |

Why the session is not inside `vault.zv`: that body is re-sealed whole on every change; a conversation inside it would rewrite every byte the person owns on every save (`conversation.rs`, `vault/model.rs`). Settings panel when the vault is shut: “the conversations themselves were never in it.” **confirmed-from-code** `settings.dart`.

A live bench still holds the **original** text in memory (`session.rs` `original_str`). That is the working copy, not the saved session file.

### 3. Session restore key

Restore of `__Z_<ns>_<KIND>_<tail>__` is a **key / namespace** question.

- `restore()` puts a token back only if it is in **this session’s TokenStore** and in that turn’s **allowed** list (`tokens.rs`). Another session’s namespace stays `Piece::Unresolved`.
- The session key is the 32 bytes the vault keeps for that row. Namespace `1F52` is derived from **الاختبار الأول**’s key (`tokens.rs` `Naming::of_session`).
- After restart the live TokenStore is empty until a document is on the bench. Import **clears** protections then scans (`ops/mod.rs` `import_document`). Scan can **re-apply a word** the vault already knows (word-protection scope). That is a new protection, not restore of an old `1F52` token.
- Do not assume Conversation tokens fail reopen. Do not assume Always tokens succeed reopen. Record what the matching key did.

---

## Z Privacy — finding classes (axis 1)

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

---

## Z — PDF reopen after isolated restart (in progress)

This is a **document-save + session-key** test. It is not a word-scope test. Protect / Always / Just here are not used to predict the cells below.

Isolated window was closed (SIGTERM of the previous copy) and started again with `tests/cycle/run_app_isolated.sh`. Isolation held: origin vault size 742 mtime 1791828743 unchanged. New process `195385`, `HOME` = sandbox home, stamp `z_core 0.1.0 · 2026-10-13 · 61fa27b`. Vault already unlocked on restart; session **الاختبار الأول** (`sessions/1.zs`, namespace `1F52`) is “the one you are in”. **tested** (AT-SPI + `/proc`).

The file on disk is the **outside** protected copy. Import of that same PDF is the remaining UI act. A GTK **Open File** chooser is standing; the path bar is in **flutter_assets**. The PDF sits in the **bundle** folder of this copy (same bytes as the sandbox Documents file). AT-SPI can click GTK chrome; **Open** has not completed import from this side. Restore after reopen is therefore **not yet observed**.

How restore is scored when that import happens (**confirmed-from-code**, not a predicted outcome):

- Score **with the matching session’s key**. Session 1 column = `1.zs` / namespace `1F52`. Session 2 column = a new session in the same vault, no key transfer.
- `restore()` puts a token back only if it is in **this session’s TokenStore** and in that turn’s **allowed** list (`tokens.rs`). Another session’s namespace stays `Piece::Unresolved`.
- Session file `1.zs` stores questions, raw answers, and allowed **token names**. It does not store the value map. Values live in the live bench store. The vault holds 19 Always-learned **words**.
- Importing a PDF **clears** the bench’s protections then scans the extracted text (`ops/mod.rs` `import_document`). The extracted original of this file **is** the tokenised page.
- If leftover **clear** words are scanned and the vault re-protects them, that is **word-scope re-apply**, recorded aside from this table. It is not restore of a `1F52` token.

Per-token restore after reopen — **not observed yet**. The table is keyed by token name, not by Just here / This conversation / Remember everywhere.

| Token | Kind | Occ. | Session 1 restore (own key) | Session 2 restore (no key transfer) |
|---|---|---|---|---|
| `__Z_1F52_PERSON_F28DE7CF__` | PERSON | 1 | not observed | not observed |
| `__Z_1F52_PERSON_CCF923CA__` | PERSON | 1 | not observed | not observed |
| `__Z_1F52_CUSTOM_294A05EC__` | CUSTOM | 1 | not observed | not observed |
| `__Z_1F52_PERSON_9FB561CF__` | PERSON | 1 | not observed | not observed |
| `__Z_1F52_CUSTNO_43545CAF__` | CUSTNO | 2 | not observed | not observed |
| `__Z_1F52_PERSON_5C45B1F7__` | PERSON | 1 | not observed | not observed |
| `__Z_1F52_PERSON_846FE819__` | PERSON | 1 | not observed | not observed |
| `__Z_1F52_ADDR_6A08B785__` | ADDR | 1 | not observed | not observed |
| `__Z_1F52_PERSON_144984F1__` | PERSON | 1 | not observed | not observed |
| `__Z_1F52_IBAN_1FB36806__` | IBAN | 1 | not observed | not observed |
| `__Z_1F52_BIC_D4ADB467__` | BIC | 1 | not observed | not observed |
| `__Z_1F52_PHONE_49FD3F28__` | PHONE | 1 | not observed | not observed |
| `__Z_1F52_PHONE_3E5AEABC__` | PHONE | 1 | not observed | not observed |
| `__Z_1F52_EMAIL_C055081E__` | EMAIL | 1 | not observed | not observed |
| `__Z_1F52_EMAIL_F203A99F__` | EMAIL | 1 | not observed | not observed |
| `__Z_1F52_PERSON_CFDB41D2__` | PERSON | 2 | not observed | not observed |
| `__Z_1F52_PERSON_13502662__` | PERSON | 2 | not observed | not observed |
| `__Z_1F52_EMPNO_759300B3__` | EMPNO | 1 | not observed | not observed |
| `__Z_1F52_PERSON_29E91933__` | PERSON | 2 | not observed | not observed |
| `__Z_1F52_PERSON_65D30635__` | PERSON | 1 | not observed | not observed |
| `__Z_1F52_PERSON_5FBDC692__` | PERSON | 1 | not observed | not observed |
| `__Z_1F52_PERSON_8D324019__` | PERSON | 2 | not observed | not observed |
| `__Z_1F52_CUSTOM_90C5687C__` | CUSTOM | 1 | not observed | not observed |
| `__Z_1F52_PERSON_1294B6B9__` | PERSON | 1 | not observed | not observed |
| `__Z_1F52_PHONE_369A10B2__` | PHONE | 1 | not observed | not observed |
| `__Z_1F52_PERSON_E1B5E125__` | PERSON | 1 | not observed | not observed |
| `__Z_1F52_PERSON_FE95AB35__` | PERSON | 1 | not observed | not observed |
| `__Z_1F52_CUSTOM_453ADFE7__` | CUSTOM | 1 | not observed | not observed |

Leftover clear from the PDF extract stays leftover. That is **not** a restore fail.

Next UI step is in `MANUAL_UI.md`.

---

## Z — mock (tools only, this folder)

Default `POST /v1/chat/completions` reply now:

- Echoes **every** `__Z_…__` token in the last user message, unchanged, even if names/IBANs remain in the clear.
- Never copies original values into the reply (replaced with `<LEFT_CLEAR>`).
- Records leftover clear on the request as `leftover_clear`. That list is **not** a capture FAIL.

Alice / Alicia are **not** joined by the mock.

---

## Canonical ten-project list

This is the original list. **No project is replaced.** Rows that were previously LLM Guard, PasteGuard, Private Guard, PrivAiTe, or A5 are withdrawn. Absence of `/analyze` is not evidence that a product lacks its function. Projects that were not started here are scored from public docs/code only, tagged **documented** / **confirmed-from-code** / **unknown**, never **tested**.

---

## 1. OpenAI privacy-filter

Identity: [openai/privacy-filter](https://github.com/openai/privacy-filter) · [openai.com announcement 22 Apr 2026](https://openai.com/index/introducing-openai-privacy-filter/) · weights Hugging Face `openai/privacy-filter`. Apache 2.0. 1.5B total / 50M active. **Not run here.**

| Axis | Record | Tag |
|---|---|---|
| 1. Finding | Bidirectional token classifier, 8 categories: `account_number`, `private_address`, `private_email`, `private_person`, `private_phone`, `private_url`, `private_date`, `secret`. BIOES + constrained Viterbi. CLI `opf`. | **documented** (README + model card) |
| 2. Protection / restore | Mask / redact spans. Official card describes detection and masking. No session vault or placeholder restore is described. | **documented** for mask/redact; restore vault **unknown** (silence is not “no”) |
| 3. Chat + PDF | Model/CLI/library. Chat or PDF would be an integrator. Browser demo exists. | **documented** as a model; in-app chat/PDF **unknown** |

**not tested**.

---

## 2. packyme/privacy-filter

Identity: [packyme/privacy-filter](https://github.com/packyme/privacy-filter). Pure Go, no NER. HTTP `:8088/redact`, gRPC `:8089`. **Not run here.**

| Axis | Record | Tag |
|---|---|---|
| 1. Finding | Two layers: regex PII (email, phone, national ID, Luhn card, IP) and gitleaks + entropy secrets. README states it does **not** recognise person / place / organisation names. | **documented** |
| 2. Protection / restore | Typed irreversible placeholders (`[邮箱]`, `[电话]`, `[身份证]`, `[银行卡]`, `[IP]`, `[密钥]`). README: no un-redaction. | **documented** irreversible |
| 3. Chat + PDF | Library / HTTP / gRPC in front of an LLM gateway. PDF **unknown**. No `/analyze` in this README; the product door is `POST /redact`. | **documented** for gateway text; PDF **unknown** |

**not tested**.

---

## 3. Masquerade (postralai/masquerade)

Identity: [postralai/masquerade](https://github.com/postralai/masquerade). MCP privacy firewall for PDFs. **Not run here.**

| Axis | Record | Tag |
|---|---|---|
| 1. Finding | PDF → text, then Tinfoil isolated Llama 3.3 70B to identify names, emails, dates, entities. | **documented** |
| 2. Protection / restore | Builds a redacted PDF. Preview, then the person uploads the redacted file. Restore of originals is not described. | **documented** redaction; restore **unknown** |
| 3. Chat + PDF | Claude Desktop MCP: paste a **file path**, not the original PDF. Query is a later **manual** upload of the redacted PDF to Claude. | **documented** |

**not tested**.

---

## 4. Presidio (mentioned links)

Attempted URLs on 2026-10-13:

| URL | HTTP | Final |
|---|---|---|
| https://github.com/microsoft/presidio | 200 | https://github.com/data-privacy-stack/presidio |
| https://microsoft.github.io/presidio/ | 200 | same host (page text: “This page has moved” → data-privacy-stack.github.io/presidio) |
| https://data-privacy-stack.github.io/presidio/ | 200 | https://presidio.dataprivacystack.org/ |
| https://github.com/data-privacy-stack/presidio | 200 | itself |
| https://microsoft.github.io/presidio/analyzer/ | 200 | same host |

Hard failure (timeout/404) **did not continue** on those URLs. The old Microsoft GitHub path redirects. The old `microsoft.github.io/presidio` URL still answers 200 with a **move notice**, not the full docs. Current docs: https://presidio.dataprivacystack.org/ and repo [data-privacy-stack/presidio](https://github.com/data-privacy-stack/presidio).

| Axis | Record | Tag |
|---|---|---|
| 1. Finding | Analyzer: NER + regex + checksum + custom recognizers; text, images, structured. | **documented** |
| 2. Protection / restore | Anonymizer operators replace / mask / hash / encrypt. Encrypt can be reversed with the operator key. Default replace is not a Z-style session vault. | **documented** |
| 3. Chat + PDF | SDK / HTTP / Docker / Kubernetes. Not an LLM chat app. Image-redactor covers standard images and DICOM; PDF-page redaction is that module, not a chat restore. Analyzer HTTP historically used `/analyze`; absence of that path in a **different** product is not a score against Presidio. | **documented** · **not tested** |

---

## 5. BentoPDF

Identity: [alam00000/bentopdf](https://github.com/alam00000/bentopdf) · [bentopdf.com](https://bentopdf.com). Client-side PDF toolkit. **Not run here.**

| Axis | Record | Tag |
|---|---|---|
| 1. Finding | No PII NER/scanner is described. Redact Content is a person-driven PDF edit. | **documented** as a toolkit; auto-finding **unknown** |
| 2. Protection / restore | **Redact Content** permanently removes content. **Sanitize PDF** / **Remove Metadata**. No LLM placeholder restore is described. | **documented** redact/sanitize; restore vault **unknown** |
| 3. Chat + PDF | PDF in the browser, no server upload. No in-app LLM send. | **documented** PDF; chat **unknown** |

**not tested**.

---

## 6. OpenMed

Identity: [maziyarpanahi/openmed](https://github.com/maziyarpanahi/openmed). Local clinical NER + PII de-identify. Python/Swift/Android/browser. REST `POST /analyze`, `POST /pii/extract`, `POST /pii/deidentify`. **Not run here.** `/analyze` here is clinical NER, not “the product is missing if it has no /analyze”.

| Axis | Record | Tag |
|---|---|---|
| 1. Finding | `extract_pii` / clinical NER. HIPAA Safe Harbor-aligned categories, multilingual routes, optional OpenAI Privacy Filter family and Nemotron fine-tune. | **documented** |
| 2. Protection / restore | `deidentify` methods mask, replace (Faker synthetic), hash, shift_dates. That replace is synthetic, not a session map back to the original. | **documented** de-identify; original-value restore **unknown** |
| 3. Chat + PDF | REST service, MCP, batch. PDF as a first-class protected-and-restore document is **unknown** in this README (a third-party wrapper exists; it is not this project). | **documented** text/REST; PDF **unknown** |

**not tested**.

---

## 7. rizzo-pii

Identity: [Rizzo-AI-Academy/rizzo-pii](https://github.com/Rizzo-AI-Academy/rizzo-pii). App **Rizzo PII 2.0.0** · model **rizzo-pii-0.3B v1.5.0**. Default HTTP `http://127.0.0.1:5005`. GitHub cycle expected `:5006/analyze`. **Not started in this sandbox. Not tested here.**

| Axis | Record | Tag |
|---|---|---|
| 1. Finding | Neural token-classifier (mmBERT / ModernBERT, 22 BIO tags) paired with a regex+checksum net (IBAN mod-97, CF, PIVA, Luhn). A disabled tag is still detected and left in the clear. Residuals warned via `X-PII-Residual` / `X-PII-Skipped`. | **documented** |
| 2. Protection / restore | Reversible `[FULLNAME_1]`, `[IBAN_1]`, `[CF_1]` + local dictionary on disk. Identical values share one placeholder. `--no-mapping` / `PII_MAPPING=0` builds **no** restore map. Per-tag exclude. No Z-style Just here / This conversation / Remember everywhere. | **documented**. Restore **documented**, **not tested** |
| 3. Chat + PDF | Copy anonymized text into ChatGPT/Claude/Gemini, restore locally (paste, not an in-app provider send). `POST /pdf` content-stream replace; metadata/XMP/annotations/forms/bookmarks scrubbed. `POST /analyze` for text/PDF/md/txt. Preview `POST /pdf/preview`. Having `/analyze` is this product’s HTTP door, not a requirement for the others. | **documented**. **not tested** |

GitHub cycle `/analyze` on `:5006`: **SKIPPED** (nothing listening).

---

## 8. Censgate Redact

Identity: [censgate/redact](https://github.com/censgate/redact). README v0.12.4-era; crates `redact-core` **0.12.5**. CLI `redact analyze`, gateway `POST /v1/redact` on `127.0.0.1:8080`, REST `POST /api/v1/analyze`. 61 compiled entity types; optional ONNX NER. **Not run here.** `/analyze` is one door (CLI/REST); the gateway door is `/v1/redact`.

| Axis | Record | Tag |
|---|---|---|
| 1. Finding | Deterministic pattern engine (NER off unless added). 61 types via `list-entities`. Secrets in CI, Postgres location scan, prompt redaction. | **documented** |
| 2. Protection / restore | `redact anonymize --strategy mask`. Gateway redacts prompts on the way to a provider and can emit an evidence pack. A session restore vault that puts original values back into an LLM reply is **unknown** from this README (silence is not “no”). | **documented** redact/mask; chat restore **unknown** |
| 3. Chat + PDF | OpenAI-compatible gateway for prompts. PDF **unknown**. | **documented** gateway; PDF **unknown** |

**not tested**.

---

## 9. Worka PII

Identity: [worka-ai/pii](https://github.com/worka-ai/pii). Rust library (`crates.io/crates/pii`). Regex / validator / dictionary / optional Candle NER. **Not run here.** No HTTP `/analyze` is required for a library.

| Axis | Record | Tag |
|---|---|---|
| 1. Finding | Built-in: Email, Phone, IP, card, IBAN, SSN, tax IDs, passport, bank, crypto, MAC, UUID, VIN, IMEI, URL, domain, hostname. Person / Location / Organization when a NER engine is enabled. | **documented** |
| 2. Protection / restore | Operators redact / mask / replace / hash. README examples keep original spans for an audit log beside the replacement. A durable session restore map is **unknown**. | **documented** operators; session restore **unknown** |
| 3. Chat + PDF | Library for scrubbing text (including prompts). PDF **unknown**. | **documented** as a library; chat app / PDF **unknown** |

**not tested**.

---

## 10. Secret Guard

GitHub `tests/cycle` (branch `tests/cycle`, commit `b42cf0e`) expected **`POST http://localhost:5007/analyze`** in “gateway mode”. No local checkout, no process on `:5007`, no confirmed repository for that cycle target.

[chintanshah35/secretguard](https://github.com/chintanshah35/secretguard) is a **CI source-code secret scanner** (`npx secretguard .`). It masks findings in output, skips PDFs as binary, and does not describe chat restore or a protected-PDF product. It is **not** identified as the cycle’s Secret Guard and is **not** used as a substitute row.

| Axis | Cycle target `:5007` | CI scanner (different product, not a replacement) |
|---|---|---|
| 1. Finding | **unknown** | **documented**: 95 patterns, credentials + some PII (SSN, card, email, phone, public IPv4) |
| 2. Protection / restore | **unknown** | **documented**: masked report; no restore vault |
| 3. Chat + PDF | **unknown**. Cycle assumed `/analyze` only | **documented**: CLI/CI; PDFs skipped as binary |

Probe `:5007/analyze`: **SKIPPED**. README silence is not used as “no feature”.

---

## Ten-project table (original names only)

| # | Project | Version / evidence date | 1. Finding | 2. Protection / restore | 3. Chat + PDF | Tag |
|---|---|---|---|---|---|---|
| 1 | **OpenAI privacy-filter** | openai/privacy-filter · Apr 2026 · 1.5B/50M | Token classifier, 8 categories | Mask / redact. Restore vault unknown | Model/CLI; chat/PDF would be an integrator | **documented** · **not tested** |
| 2 | **packyme/privacy-filter** | public README | Regex PII + gitleaks/entropy; no NER names | Irreversible typed placeholders | Gateway `POST /redact`. PDF unknown | **documented** · **not tested** |
| 3 | **Masquerade** | postralai/masquerade | Tinfoil Llama 3.3 70B on PDF text | Redacted PDF; restore unknown | Claude MCP; manual upload of redacted PDF | **documented** · **not tested** |
| 4 | **Presidio** | data-privacy-stack/presidio after move from microsoft/presidio · 2026-10-13 | NER + regex + checksum + custom | replace/mask/hash/encrypt | SDK/HTTP/images. Not an LLM chat app | **documented** · **not tested**. Old Microsoft URLs redirect or show a move notice; no remaining 404 on the URLs tried |
| 5 | **BentoPDF** | alam00000/bentopdf | Person-driven redact; auto-PII unknown | Redact Content, Sanitize/metadata | Client-side PDF toolkit; chat unknown | **documented** · **not tested** |
| 6 | **OpenMed** | maziyarpanahi/openmed | Clinical NER + `extract_pii` | mask/replace/hash/shift_dates | REST `/analyze` and `/pii/*`; PDF unknown | **documented** · **not tested** |
| 7 | **rizzo-pii** | 2.0.0 / model 0.3B v1.5.0 | NER + regex/checksum, 22+1 tags | Reversible `[TAG_n]` + on-disk dict | Paste-to-LLM; `POST /pdf` | **documented** · **not tested** |
| 8 | **Censgate Redact** | censgate/redact · crates 0.12.5 | 61 types, optional ONNX NER | mask/redact gateway; chat restore unknown | Gateway `/v1/redact`, REST `/api/v1/analyze`. PDF unknown | **documented** · **not tested** |
| 9 | **Worka PII** | worka-ai/pii | Regex/validator/dictionary + optional NER | redact/mask/replace/hash | Rust library. Chat app / PDF unknown | **documented** · **not tested** |
| 10 | **Secret Guard** | cycle `:5007` unidentified | unknown for the cycle target | unknown | unknown | **unknown**. CI `chintanshah35/secretguard` is a different product, not a substitute |

Z Privacy is the product under test, not a replacement row in this list. Its three-axis evidence is the sections above this list.

Similarities that actually appear in the sources:

- Z and rizzo-pii both describe **placeholder out, restore locally**, plus a **person-facing document UI** and a **protected PDF**.
- OpenAI privacy-filter, OpenMed, and Presidio are **engines** (detect then mask/anonymize) that an integrator can put in front of chat.
- packyme/privacy-filter and Censgate sit on the **gateway / prompt** path. Masquerade and BentoPDF sit on the **PDF file** path.
- Z’s **restore key** is the matching session (`__Z_<ns>_<KIND>_<tail>__`). Z’s **word-protection scope** is a separate choice (Just here / This conversation / Remember everywhere) and lives partly in the vault. rizzo-pii’s mapping is a **local dictionary** that can be switched off. Those are different durability models. Z’s session-stored copy is the **protected** form because `sessions/*.zs` sit beside `vault.zv`, not inside it.
- Leftover clear text is normal in Z when the person did not choose the span. rizzo-pii warns residuals. Treating leftover clear as an automatic fail would mis-score both.

Differences that actually appear:

- Z is a Linux desktop FFI app with a vault and four engine scopes. rizzo-pii is a local HTTP/Tauri app. Presidio/OpenAI privacy-filter/Worka/OpenMed are libraries or services. BentoPDF is a PDF editor. Masquerade is an MCP. Censgate is CLI+gateway. Secret Guard’s cycle identity is still empty.
- Z’s chat path is an in-app OpenAI-compatible send. rizzo-pii’s documented chat path is copy/paste. Masquerade’s is a later manual Claude upload.
- Z PDF is a newly typeset page of the protected **text** plus a checkable footer. rizzo-pii `POST /pdf` on a PDF input claims **in-place content-stream** redaction. BentoPDF redacts inside the original file. Masquerade writes a redacted PDF for preview.
- Having `/analyze` (rizzo, Presidio, OpenMed, Censgate REST) or not having it (Z, BentoPDF, packyme `/redact`, Masquerade MCP) is a **door**, not proof the function exists or is missing.

---

## Out of scope

No full product audit. No app-code change. No ZPrivacy-lib. No origin/backup/GitHub write. No redteam harness pointed at origin. No project in the original ten was replaced.
