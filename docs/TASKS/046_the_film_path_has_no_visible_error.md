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
- **A RULE, not a choice (the lead adopted it, 7 Oct): a file Z Privacy writes
  carries no document metadata.** No `/Info` dictionary at all — no title, no
  author, no creation timestamp. This file exists to be handed to a model or a
  person, and a document's name is not protected text: «Müller-Scheidung» in
  `/Title` would leave the device inside the very file made to stop that
  leaving. The name stays on the local file name, where the owner asked for it
  and where it does not travel. **Do not add a title for tidiness.** If a
  future format needs one, it needs a decision first, in writing, here.
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

**Right-to-left writing was refused for an hour, and is now written.** See
**046/R** below; the refusal is gone.

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


---

## R · The PDF writes Arabic the way it is read (7 Oct, after O)

**The owner:** «وأفرح إذا حسمنا مشكلة اللغة العربية». The lead measured his
machine first and corrected his own diagnosis: **22 Arabic-capable fonts
installed**, `Noto Sans Arabic` matching `:lang=ar`. His machine was never the
fault. `protected_pdf.dart` and its tests only.

**What was wrong.** `pdf` runs neither its shaping nor its bidi pass unless the
text direction is `rtl`, and the writer set none, so «السيد» drew as «ديسلا» —
a page that still looks typeset to anyone who cannot read the script.

**What is built.**

- **Direction per paragraph, from the paragraph's own first strong letter**
  (UAX #9, P2/P3) — not one setting for the file, because a client's letter is
  German and Arabic in the same document and one setting gets one of them
  wrong.
- **A `__Z_…__` token does not vote** — see the rule below, which came out of
  this and is bigger than it.
- **A neutral line — blank, or only figures — takes the direction around it**
  and never starts a run of its own. Counted as left-to-right it cut an Arabic
  passage into three and the blank lines vanished from the page. *Found by
  rendering a letter and looking at it, not by a test.*
- **Every right-to-left line carries U+200F.** The bidi library decides the
  base direction for itself, by the same first-strong rule, and it counts the
  token's Latin letters. So a line beginning with a protected name was
  **ordered** left to right by the library while being **aligned** right by us,
  and the token sat at the wrong end. U+200F is strong, zero width and carries
  no glyph. The isolates U+2067/U+2069 say it better and were tried first:
  DejaVu has no glyph for them and they drew as two `.notdef` boxes.
- **Each block is wrapped in a `Partition`.** A `MultiPage` hands its children
  a loose width and `RichText` then takes the width of its longest line, so
  `textAlign: right` aligned inside *that* box. Measured: one Arabic block sat
  flush left at x=44 while the block above it, which happened to contain a
  wrapping line and so had been given the full width, sat at x=553 — two
  passages in one document aligned two different ways by accident of line
  length. A `Partition` constrains tightly **and** hands `canSpan` and
  `hasMoreWidgets` to its child, so paging survives. A `Column` with `stretch`
  gives the same width and does not: it threw `PdfTooBigPageException` on the
  120-line guard.

**The guard, and why it is not the one that was asked for.** An order assertion
over the extracted Latin runs cannot work here, and that is measured, not
argued: our reader walks the **content stream**, and `pdf` writes words into it
in logical order whatever the direction, so the IBAN and the amount come back
at *identical* indices from a right page and a mirrored one. What does separate
them is the glyphs — a shaped, bidi-ordered page is written in Arabic
**presentation forms** (U+FB50..U+FEFF), an unshaped one in **base letters**
(U+0620..U+064A). Measured: 20 presentation / 0 base with the direction set,
0 / 20 without. Both are asserted. Beside them: the Latin islands must come back
verbatim and in their own order (a token swept into the reversal restores as
nothing), a Latin-only page must carry no presentation form and keep its word
order, and a long Arabic document must page with a footer on each page.

**The acceptance was a rendered page, looked at.** A client's letter — Arabic
with a German line in it, tokens where the names were, an IBAN, `1,250.00`, and
a line deliberately *beginning* with a token. Measured at 150 dpi with
`pdftotext -bbox-layout`, content box x 44..551: every Arabic line ends at
551..553 and the German line begins at 44.0. By eye: the salutation is right
aligned with «السيد» rightmost and the token an island inside it; the body wraps
over two lines and reads right to left; the account line keeps the IBAN token
and `1,250.00` forward; the token-first line now carries its token at the right
end. Before the mark, that one line put its token at the left — which is what
the rendering caught and no test did.

**Breaks on purpose, five, each red:** the direction dropped (nothing shaped);
one direction for the whole file (the mixed document's Arabic line unshaped);
the token allowed to vote; a neutral line counted as left-to-right (the passage
split); the mark on only the first line of a block.

### A PRODUCT RULE, adopted by the lead 7 Oct out of this item

> **A `__Z_…__` token must not vote on direction — its letters are Latin and
> *we* put them in the person's line; protection may not change how a document
> reads.**

It belongs beside «the left column is the document byte for byte», and it
generalises past the PDF: **no act of protection may alter layout, direction,
pagination or reading order anywhere.** A token is our word standing in the
person's sentence, and a word of ours may not move their words about.

**Not in this item:** the document column's direction and the selection clitic
rule (both 045), shaping in the app's own screens, and the footer and `/Info`
rules, which stand.

**A debt, recorded not fixed:** `scripts/gates.sh` writes its flutter output to
`/tmp/gd.$$`, a path two concurrent runs in two worktrees can confuse — each
run reads back its own `$$` so no verdict is ever wrong, but the leftovers are
read by people, and one was nearly reported as another worktree's count. A
private temp directory per run, removed at the end. For whoever next touches
that script.

**One thing to know, and it is not fixable here — now folded into 038-C.** A
reader that uses glyph positions, every viewer and poppler, gets this file
right. **Our own reader does not**: it walks the content stream, so it returns
the words in logical order with each word's letters in visual order, which is
neither one thing nor the other. It touches neither the protection nor the
page; it means an Arabic PDF handed to a model that extracts text the way we do
would read oddly.

That is `z_core/src/documents/pdf.rs`, and it is **the same defect
`038C_arabic_arrives_as_it_is_read.md` measured from the reading side on 5
October** — 7 of 7 people found in an Arabic letter given as text against 0 of
461 in the same book given as a PDF, while poppler read that file into
180 / 209 / 67. Our writer and our reader disagree about the same file, and the
reader is the one that is wrong. Written into 038-C rather than started again:
see its last two sections, which also carry the pair of rules this item and
that one produced together.

---

**One thing to know, and it is not fixable here.** A reader that uses glyph
positions — every viewer, and poppler — gets this file right. **Our own reader
does not**: it walks the content stream, so it returns the words in logical
order with each word's letters in visual order, which is neither one thing nor
the other. It does not touch the protection and it does not touch the page; it
means that an Arabic PDF handed to a model that extracts text the way we do
would read oddly. The reader is `z_core/src/documents/pdf.rs`, which is not
this item's file.

---

---

## P · A key is set up in Settings, not in the middle of sending (WRITTEN, NOT ORDERED)

**The owner, 7 Oct, offered as cosmetic:** «نقل إعدادات الموديلات إلى قسم الإعدادات بدلاً من جعلها شاشة في وسط السياق.»

**It is not cosmetic, and that is the argument for doing it:** a **configuration** act does not belong inside a **work** act. Today `send_sheet.dart` carries the provider, the model, the mode **and the connect form with the key**, so «I want to send this document» can turn into «type an API key» in the middle of a sentence. Two different kinds of decision, one screen.

**The split:**
- **Settings** gets the providers: which are connected, the key, the base address, the «keep for this run only" choice, and «Connect» / «Forget». Set up once, where setting up belongs.
- **The send moment keeps the choice**: which provider and model, among what is connected, with the rest greyed as 041-A/3 built it — choosing a model is part of the act; typing a key is not.
- **With nothing connected**, the sheet shows **one line that leads to Settings**, never the form itself: «No provider is connected — open Settings». A door, not a desk.
- 041-A/2's order stays: provider · model · mode first, then the text, then the doors.

**And a reason of the hour:** on Friday the owner shares his screen. A key form that can open by accident in front of someone is a risk with no upside; a Settings screen he never visits during a demo is not.

**Done means:** no key field anywhere outside Settings (a test asserts it) · the catalogue still lists every provider with the unconnected greyed · `usage.model_id` still changes on the next send · no model name in Dart · gates, clippy, counts before and after.
