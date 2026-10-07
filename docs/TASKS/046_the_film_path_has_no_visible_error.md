# 046 · The film's path, in English, with no visible error

**Status: ORDERED** · 7 Oct 2026 · lead → programmer · branch `fix/the-film-path` from `main` (`fad220f`) · **one commit per item, measured before the next; the German and Swedish numbers must not move a digit.**

## Where it comes from

The owner's decision for Friday's three-minute film: **two English documents of the same client.** Clean the first by hand, drop in the second, and the screen itself shows the idea — «كل جلسة تحتاج وقتاً أقل من الجلسة السابقة». Web Summit's PITCH is three minutes + three minutes of questions, so the film is also the pitch.

The two documents are written and invented: `~/Documents/film/EN-1_engagement_and_invoice.txt` (an engagement letter and invoice, 7 people) and `EN-2_payroll_query.txt` (a payroll query to the same client, 7 people, 2 of them new). They become fixtures `z_core/tests/fixtures/` as part of item B, with a guard, like DE-1.

## What the lead measured on `fad220f`, before writing this

A rig against `z_core::api`, English session, the two files:

| | EN-1 cold | EN-2 cold |
|---|---|---|
| findings | 11, all automatic | 11, all automatic |
| **persons** | **1** — and it is `Eleanor Whitfield, Finance Director`, the job title inside the token | 1, the same |
| candidates (Names panel) | **0** | **0** |
| not found | Priya Raghunathan · Dermot Hale · Mairead Quinlan · Callum Stride · Rowan Pellbrook · «Dear Ms Whitfield» · (EN-2 also Owen Brackley · Sian Doherty) | |

Then the owner's own demo: a profile for the client, nine hand protections on EN-1 at `Scope::Profile`, then EN-2 in the same profile:

```
EN-1 cleaned by hand            9 acts  (8 Applied + 1 Snapped: «Hale» inside «Dermot Hale» — correct)
EN-2, same client, second doc   8 people protected by themselves
                                12 of 14 findings automatic, not one person asked
                                0 acts
```

**9 → 0 is the film.** And three defects stand in the picture:

## A · The session's language must reach the rules — the one place where «German only» is still true

`z_core/src/ops/mod.rs:1695`:

```rust
fn active_sets(s: &Session, vault: &VaultStore) -> Vec<String> {
    let from_profile = s.profile_id.as_deref().map(|id| vault.languages_of(id)).unwrap_or_default();
    if from_profile.is_empty() { vec![s.pack_id.clone()] } else { from_profile }
}
```

The profile's list **replaces** the session's language, and `create_profile` (`ops/vault.rs:816`) is born `languages: vec![default_pack_id()]` — this device's German. So: make a profile for the client, choose English in the bar, and the English label rows never run. That is why the measurement above lost `Account number`, `Client number`, `VAT number` and turned three automatic phones into three questions the moment a profile was in play: only the shape rules survived, because the label rows being asked were German ones.

**Build:** the session's language is **always** active, and the profile's languages are **added** to it — the comment two lines above `scan` already says a document may be German and English at once. And a new profile starts with the language of the session that created it, falling back to the device's. Red first: a profile session in `en` finds `Client number: 440821`.

## B · An English pack — the cues, and not one name of data

`installed_packs()` is `[de, sv]`, so `packs::scan` and `packs::discover` return nothing for `en`: no salutation rule, no pair rule, no discovery, and **the names the person taught never reach the engine** (they arrive as `names` and are dropped with the missing pack — only vault *values* survive, through `vault_pass`). An empty Names panel in English is this, not a dictionary gap.

**Build** `z_core/src/scanner/packs/en.rs`, `locale: "en-GB"`, **`names: ""`** — an empty dictionary on purpose, so a bare given name still opens nothing and the 11-to-1 guard keeps its meaning:
- salutation: `Dear Mr/Mrs/Ms/Miss/Dr/Prof X` → Person **Auto** (the honorific list already exists in `sets/en.rs`);
- the closing: `Yours sincerely,` / `Kind regards,` / `Best regards,` followed by a line that is a name → Person **Auto** for the signature, and the pack's `copulas` empty as German's are;
- the pair rule and discovery exactly as the pack contract defines them, so a taught half makes a pair and an unknown surname beside a taught given name becomes a **candidate**.

**Acceptance on EN-1/EN-2:** persons found ≥ 6 of 7, candidates ≥ 4, **false protections 0**, no caption or job title becomes a person; DE-1 stays 7/7 and 0 false; SV-1, SV-16, DE-2, DE-3, DE-4 unchanged to the digit.

## C · A name ends where the name ends

`Contact person: Eleanor Whitfield, Finance Director` is one Person finding, job title inside. `Validator::Name` must stop at a comma and at the end of the line. **Guard what this must not touch:** the German reversed pair «Nachname, Vorname» and the Swedish «X, role» rule both read across a comma on purpose — name them in the test so the next person cannot undo one with the other.

## D · A refusal sentence is read by a person

`protect` with `Scope::Profile` and no profile refuses with, verbatim:

```
this conversation is not in a profile, so there is no profile to remember it                      for — choose «always», or open a profile first
```

Nineteen spaces inside the sentence — a wrapped Rust literal. Sweep every `reason:` in the core for a run of two or more spaces, fix them, and add a gate that fails on one. It is the kind of thing a jury sees before it hears anything.

## E · The client is a profile, and the words are the same everywhere

Creating a client and putting this document in it must be two clicks from the document screen (the demo needs it for `Scope::Profile` to exist at all). And one vocabulary, in the dialog, the card, the panel and the explain sheet: **Once · This conversation · This client · Everywhere** — today the core's names (`Profile`, `Always`) reach the screen in places.

## Done means

- One commit per item, red first, each measured before the next; `cargo test`, `flutter test` the gates' way, gates, clippy, counts before and after.
- `docs/THE_NUMBERS.md` gains **§5 English**: the cold table above, the hand count on EN-1, and the automatic count on EN-2 — before and after this task.
- EN-1 and EN-2 in `z_core/tests/fixtures/` with a guard that holds their numbers, as DE-1 has.
- Report per item, then stop for the lead's measurement.

## Not in this task

- An English name dictionary (its own task, with a licence file, after the film).
- 038-G, 038-B (SCB), 038-C, 043, 045 — all still queued.
- Any change to the German or Swedish packs.

---

## G · The home is the conversation (ADDED 7 Oct, the owner's first fix — before B)

**The owner, 7 October:** «دعنا نبدأ الإصلاح الأول، بدون نشر أو تجربة. الخطوة الأولى: إنشاء الخزنة ثم الانتقال إلى شاشة شات — هل هذه موجودة؟»

**Measured answer: no.** `shell.dart` puts the vault in front of the home and then shows `HomeScreen` — a composer with «Write or paste your text here…», «Open and scan», «Add a document», «Open Z Vault», «Profiles», «Settings». The model is not a screen: it is the send sheet, opened from the workspace's AI button, which exists **only once a document is open**, and the answer lands in a third screen (`answer.dart`). From the home there is no door to a model at all.

**Build — 043's heart without 043's restructure. Nothing moves in the workspace.**

1. The home's own text box becomes the conversation's line. No new widget, no new screen: the composer it already has is the input.
2. **The AI door comes down to the home.** A person who has just made a vault can ask a model without first opening a document. Same sheet, same catalogue, same modes.
3. **The answer appears under the question, in the same screen**, instead of `answer.dart` as a separate destination. That alone is what makes it read as a conversation. `answer.dart`'s reveal/copy behaviour and its clipboard warning move with it unchanged — the warning is not optional.
4. **The gate stays, and says why.** Type → protect in place → see what will leave → send. Send remains blocked while any suggestion is unanswered, and the button carries the reason. A chat that can send before the review is answered breaks the product's one promise.

**Done means**

- Red first on «from the home, with no document open, a question can be asked and its answer appears in the same screen».
- The document path's numbers do not move: DE-1 · DE-2 · DE-3 · DE-4 · DE-6 · SV-1 · SV-16 unchanged to the digit, and the English rows of §5 unchanged.
- No model name in Dart (the existing test); strings in en.
- `flutter test` the gates' way, gates, clippy, counts before/after. **No publish, no owner test** — the owner asked for the fix only.

**Order from here:** G · D · then B if the evening allows; C and E after. The panel-truth defect F found (a book imported «everywhere» with a client open protects but shows 0 rows) comes with G, because the owner may press that button on camera.

---

## I · A list is filled the way a document is read (the owner's plan, 7 Oct evening)

**His words, in three parts.** (1) «عند الضغط على إضافة تضيف خيار قوائم، وعند الضغط عليه ندخل إلى ملف الخزنة لإنشاء قائمة. مبدئياً لا نحذف خيار اللغة. الفرق الوحيد المضاف: في خيار قوائم نجعل المستخدم يضيف اسم القائمة، وفي خيار لغة نضع نحن اسم القائمة.» (2) «خيار قائمة المفترض أن يظهر لك القوائم المخزّنة سابقاً، وإضافة قائمة جديدة.» (3) «نضيف ملف أو نص للقائمة ثم نذهب للخطوات التالية كما نفعل الآن — نجعل الخيارات نفسها وكل شيء نفسه — وإضافة مفردات جديدة للقائمة كما هو الآن.»

**What his rule uncovers, and why it is cheap:** who names the list is the same line as **which layer it feeds**. A list the person names is a book of **values** — people and companies in the vault, matched in any language with no pack (`vault_pass`). A list we name is a **dictionary** of words for that language's rules, which is how the engine discovers a name nobody taught it. Both live behind the one passphrase, both have a switch, both can be imported. That is the architecture already agreed on 7 October; this task only puts a door on it.

**And «the same steps as now» is nearly free, because the pipeline already does it:** pressing Protect with a scope *is* writing into the vault. Feeding a list is therefore the ordinary pipeline — import text or a file, scan, the same cards, the same options — with the list as the destination instead of the document.

### What to build

1. **Add → Lists.** The **+** on the chat screen gains «Lists» beside «a document» and «text». It opens a chooser: **the lists already stored** (name · how many names · on/off), and **«A new list»** where the person types its name. The language lists stay, named by us, in the same chooser and marked as what they are.
2. **A user-named list is allowed.** `clean_list_name` refuses every name that is not a language — «a list is a language, one for each». It must accept a person's own name for a list while keeping the language names reserved and still refusing an empty or whitespace name. A named list's rows are values; a language list's rows are dictionary words; the core decides that by the list's kind, never by guessing from the row.
3. **Fill a list through the ordinary pipeline.** With a list chosen, «add a file» and «add text» feed **the list**: the same scan, the same cards, the same scope options, and confirming a card writes the value into that list rather than replacing it in a document. Adding one name by hand stays exactly as it is.
4. **A list-filling session has no model door, and says so.** This is the lead's addition and it is not optional: the raw file a person feeds a list — a staff register, a patient roster — is the most sensitive document they own, and it is not a thing they ever meant to send. So in a list-filling session the AI door is **absent**, Send does not exist, and the document is dropped when the list is saved. A build where a staff register can be sent to a model by one wrong press is a build that will eventually do it.

### Done means

- Red first on each of: a stored list is listed · a person-named list is created and refused when empty · a file feeds a list and its names land in that list and not in the document · **a list-filling session offers no model door**.
- The document path's numbers do not move: DE-1 · DE-2 · DE-3 · DE-4 · DE-6 · SV-1 · SV-16 and the English rows unchanged to the digit.
- The vault model's version rises if the list kind is stored, with a migration that reads every older vault.
- Gates, clippy, counts before and after. **No publish, no owner test.**

### Not in this task

- Two lists at once in one session. One session has one list today, and a value saved «everywhere» is the escape hatch. The owner knows and it is his later decision.
- The subscription bundle, the sealed export, the Arabic direction (045), the SCB bank (038-B).

---

## O · Save the protected text as a PDF (ADDED 7 Oct, the owner's word; built by the designer seat)

**The owner, 7 October:** «زرُّ النسخ نحافظ عليه كما هو، ونضيف إليه خيار نسخة PDF ليقوم التطبيق بحفظ النص في الجهاز كملف PDF.»

So «Copy Protected» in `send_sheet.dart` is untouched, and a second act stands
beside it: **Save as PDF**, writing the protected text to a file on this
machine. Neither act sends anything.

**Built, with the numbers measured on `202cd88`:**

- `apps/flutter_app/lib/core/protected_pdf.dart` — the writer. Dart, because
  G15 allows the filesystem in `z_core/src` only on the vault's own marked
  lines; the core gives the text and the numbers, Dart writes the file.
- `pdf 3.13.1` (Apache-2.0), pure Dart — **not** its sibling `printing`, which
  is the half with the native plugin. G5a reads for network packages and this
  is none; nor is anything it brings.
- **DejaVu Sans embedded**, 759,720 bytes of asset. Without an embedded font a
  PDF promises Helvetica and gets whatever the reader has: ä ö ü, å ä ö and ß
  come out as the wrong letter or as nothing, and the file lies about its own
  text. Only a subset of it reaches each PDF. Chosen over a smaller face
  because it also carries Arabic, so this is not a decision to take twice.
- **One footer line**, and only what a reader can check: the build stamp
  (`coreVersion()`, verbatim), how many places were replaced and how many
  values by kind, and a **sha256 of the protected text** — the same string Copy
  Protected copies, so the claim is checkable with `sha256sum` and nothing of
  ours. No logo, no serial, no seal.
- **No `/Info` dictionary at all**: no title, no author, no creation timestamp.
  This file exists to be handed to a model or a person, and a document's name
  is not protected text — «Müller-Scheidung» in `/Title` would leave the device
  inside the very file made to stop that. The name stays on the local file
  name, where the owner asked for it and where it does not travel.
- `~/Documents/zprivacy/<document>-protected-<date>.pdf`, **said in full on the
  screen** after the write, and never an overwrite: a second save becomes `-2`.

**The test, and why it is not a byte search.** A PDF with an embedded TrueType
font writes its text as glyph indices in a CID font, so `grep` finds «Markus
Weber» nowhere in the file even when the page shows it, compressed or not.
`a_pdf_keeps_the_promise_test.dart` keeps that demonstration — an original
written in the clear, uncompressed, invisible to the byte search — because the
next person will reach for that search and must see it fail. The real guard
reads the file back through **our own PDF reader** (`z_core::documents::pdf`,
which decodes `Identity-H` through the font's `/ToUnicode` map) and asserts no
original value comes out, with a control proving the same reader **does** find a
planted one. Seven tests, and **five breaks on purpose**:

| broken | what happened |
|---|---|
| the original written instead of the payload | red — «Markus Weber» is readable in the PDF |
| the digest dropped from the footer | red — the sha256 is not in the file |
| an empty body | red — the control fired first: «our reader cannot read our own PDF» |
| the disk's own catch deleted | **stayed green.** The catch-all below it also says «could not», so the test asserted «a failure is reported» while claiming to assert «the disk's failure is reported by name». Strengthened to assert the folder is named — then red. |
| the body no longer a spanning widget | red — 120 lines came out as one page |

The fourth is the one worth keeping: a guard green for a reason broader than its
own subject, found only by breaking it. It is the third of this family this week.

**Confirmed outside our own code**, on a real one-page letter: `pdftotext`
(poppler) extracts the tokens whole, every umlaut and Nordic letter
(ä ö ü ß Ä Ö Ü å ä ö Å Ä Ö æ ø é è ñ ç) and **none of the seven originals**; and
`sha256sum` over the protected text answers the digit the footer states,
`df7530952c84…ede7fc8`. The page was rendered and looked at, not inferred.

**One defect of the feature, found by its own test and fixed in the same
commit:** `pasteAnswer` refuses with «Copy the safe text first» unless a payload
is bound, so a person who saved the PDF, took it to a model and came back was
told to do the thing they had just done. The act is taking the text out, not the
clipboard, so a save that happened binds it too.

**What it cost in bundle size**, release, measured against `202cd88`:

| | before | after | added |
|---|---|---|---|
| bundle | 37,161,720 | 39,655,958 | **+2,494,238** |
| `lib/libapp.so` (Dart AOT) | 6,292,368 | 8,029,072 | +1,736,704 |
| `data/flutter_assets` | 3,114,056 | 3,871,590 | +757,534 |

The font is 0.72 MiB of that and the Dart code 1.66 MiB: `pdf`'s widget layer
reaches `image` unconditionally, so tree-shaking keeps it. Measured in the
shipped `libapp.so`: `image` survives (155 references), while `barcode`, `qr`,
`svg`, `xml`, `posix` and `ffi` are all shaken out — so the two packages in the
tree that call libc are **not in the binary**. Writing the content stream by
hand against `package:pdf/pdf.dart` alone would win most of the 1.66 MiB back
and cost text layout and font subsetting. **A megabyte is the owner's to
accept, not ours to spend quietly** — it is his call, and a separate task.

## What is NOT delivered, measured rather than assumed

**Arabic is not supported, and it fails in the worse of the two ways.** The
font carries the glyphs, but `pdf` runs its shaping and its bidi pass only when
the text direction is `rtl`, and the writer sets none. Rendered and looked at:
«السيد» draws as «ديسلا» — the line is laid out left to right and comes out
**mirrored**. That matters more than «Arabic comes out as nothing» would: a
page that is visibly empty gets fixed, and a page that is quietly backwards
does not. The direction belongs per paragraph with the Latin tokens isolated
inside each RTL run — the same problem 043's S9 board drew — and it is its own
item.

**The catch-all in `saveProtectedPdf` has no test that reaches it.** The tested
failure is the disk's, which the branch above it answers; the catch-all exists
so that a throw from `buildProtectedPdf` cannot leave the button on «Saving…»
for the rest of the session. Named rather than claimed.

**`~/Documents` is hard-coded**, not read from `XDG_DOCUMENTS_DIR`. On a German
desktop a person's own documents folder may be `~/Dokumente`. What is created
here is **our** folder and we create it, so nothing depends on theirs existing,
and the full path is on the screen — but if the lead wants the XDG name, it is
a line, and a shell-out to `xdg-user-dir`.

**`rememberCopiedPayload` now understates what it does** — the act is taking
the text out, and two doors do it. The rename touches four test files and was
left alone to keep this one item one item.

**Also not in this item:** the question Copy is to ask («for a person, or for
an AI?»), Print as a sealed envelope, and a logo or a seal in the footer.
