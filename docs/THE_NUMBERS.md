# The numbers

Every number this project claims about itself, in one place, each with the
command that produces it. A number that cannot be produced by a command in
this repository is not a claim; it is a memory, and memories drift.

**Build measured:** `z_core 0.1.0 · 2026-10-05 · 08b04aa` (the stamp every
probe prints first). **Date:** 5 October 2026, evening. **Measured by:** the
lead, on a clean worktree of `main`, with a throwaway rig that calls the public
API exactly as the app does and prints **numbers only** — the rig's output
format is reproduced by task 038's probe so that these tables can be re-run
from the repository alone.

Three rules this page keeps:

1. **Numbers, never values.** No name, no account, no address from any
   document appears here. Where a shape helped a judgement, it is written as a
   shape (`999999-9999`), never as the value.
2. **Ground truth is written down before the measurement**, from the letters we
   wrote ourselves. For the owner's own documents and the public books, ground
   truth is what a person counts by hand, and is said to be that.
3. **A found value counts once per kind and state**, exactly as `ScanReport`
   and `list_findings` report it. `auto` = protected without asking;
   `suggested` = offered, in the clear until answered.

---

## 1 · The corpus

| id | language | what it is | pages | words | lives | licence |
|---|---|---|---|---|---|---|
| DE-1 | German | a business letter we wrote: 7 people, IBAN, BIC, phones, e-mails, ID card, plate, tax numbers | 1 | 227 | `z_core/tests/fixtures/Brief_Weber.txt` | ours, every value invented |
| DE-6 | German | a payslip we wrote: a four-row yearly table of «Nachname, Vorname», social-security and tax numbers, IBAN, BIC, a clerk with her direct line | 1 | 182 | `z_core/tests/fixtures/Lohnabrechnung_Weber.txt` | ours, every value invented |
| DE-2 | German | a contract we wrote | 1 | 447 | `z_core/tests/fixtures/Vertrag_Nordstern.txt` | ours, invented |
| DE-3 | German | a public tax guide, «Steuern von A bis Z» | 146 | 29 593 | the owner's machine, `~/Documents/steuern-von-a-z.pdf` (`ZPRIVACY_SECOND_GOLDEN`) | public, not redistributed |
| DE-4 | German | an Austrian ICD-10 edition: code tables, one team page | 734 | 200 202 | the owner's machine, `~/Downloads/tysk1.pdf` (`ZPRIVACY_THIRD_GOLDEN`) | public, not redistributed |
| SV-1 | Swedish | a business letter we wrote, the Swedish twin of DE-1: 7 people, personnummer, org.nr, IBAN, BIC, bankgiro, 4 phones, 2 e-mails, 4 addresses, plate, VAT number | 1 | 208 | `z_core/tests/fixtures/Brev_Lindqvist.txt` | ours, every value invented |
| SV-2…15 | Swedish | the owner's own company papers: annual report, AGM minutes, registration certificate (2 versions), balance sheet, income statement, account analysis, two tax forms, a Bolagsverket filing, a register extract, a receipt, an invoice, a payment reminder | 1–7 each | 76–4 717 each | the owner's machine only | private, never redistributed, **never printed** |
| AR-1 | Arabic | a business letter we wrote, the Arabic twin of DE-1: 7 people with honorifics, commercial register, IBAN SA, BIC, 4 phones (one in Arabic-Indic digits), 2 e-mails, national ID, 2 VAT numbers, 4 addresses, plate, birth date | 1 | 230 | `z_core/tests/fixtures/Risala_Alharbi.txt` | ours, every value invented |
| AR-2 | Arabic | «كليلة ودمنة», a public-domain classic as a PDF from a free-books site | 221 | 38 567 | the owner's machine, `~/Downloads/` | public domain, not redistributed |

The three German PDFs and the Arabic book are **skipped, never passed**, by
`scripts/gates.sh` when they are not on the machine (`----` in its output).

---

## 2 · German — the baseline the phases were accepted on

Pack `de` (300 given names from Berlin 2023 · 601 family names from Wikidata ·
10 CC0 family names; provenance in `z_core/assets/licenses/`).

| document | auto | suggested | normal | by layer (rules / pack) | persons found / present | name candidates | FP (auto) |
|---|---|---|---|---|---|---|---|
| DE-1 letter | **20** | **8** | 162 | 4 / 18 | **7 / 7** (all auto) | 2 | 0 |
| DE-2 contract | **9** | **1** | 426 | 3 / 6 | 1 / 1 | 0 | **1** — the line under the closing («Abteilung …», a department) is protected as a person: the signature rule takes whatever follows the closing |
| DE-3 tax guide | **2** | **4** | 29 579 | 1 / 1 | 0 / 0 | 0 | 0 |
| DE-4 ICD-10 | **18** | **1** | 200 165 | 2 / 18 | 16 auto, all on the team page (the page's own count is not taken by hand here) | **5** (536 places) | 0 — the test asserts the code tables and chapter letters stay clear |

### 2a · After 038-H — the name bank, tier 1 (6 Oct 2026)

Pack `de` now carries **5,712 given names** (every spelling in three or four of
the Berlin, Bonn, Dortmund and Köln newborn registers) and **3,246 surnames**
(Wikidata's German citizens with ten bearers or more, plus Schmidt). Tier 2 —
the 3,774 spellings two cities carry — was measured and **left out**; tier 3 is
written beside the bank and never loaded. Nothing in the detection path
changed: the rules are the rules of Phase 2.

| document | auto | suggested | normal | persons found / present | name candidates | false protections | false suggestions |
|---|---|---|---|---|---|---|---|
| DE-1 letter | 20 → **21** | 8 → **8** | 162 → 160 | 7 / 7 → **7 / 7** | 2 → **1** | 0 → **0** | 0 → **0** |
| DE-2 contract | 9 → **9** | 1 → **1** | 426 | 1 / 1 → 1 / 1 | 0 → **0** | 1 → **1** (the old department line) | 0 → **0** |
| DE-3 tax guide | 2 → **2** | 4 → **4** | 29 579 | 0 / 0 | 0 → **2** («Euro», «Rechtsgrundlage») | 0 → **0** | 0 → **0** |
| DE-4 ICD-10 | 18 → **18** | 1 → **2** | 200 165 → 200 163 | 15 → **16** distinct | 5 → **19** (12 of the 14 new ones are the team page's own surnames) | 0 → **0** | 0 → **0** |
| DE-6 payslip | 6 → **6** | 9 → **9** | 136 | 2 / 5 → **2 / 5** | 2 → **1** | 0 → **0** | 0 → **0** |
| SV-1 (control) | 10 → **10** | 5 → **5** | 171 | 2+2 → **2+2** | 2 → **2** | 0 | 0 |

What moved, and why:

* **DE-1 gains an auto.** «Markus Weber» is written twice; the signature rule
  protected both places and only one of them carried a finding. The bank's pair
  rule now names the second place as well, and a post-scan pass settles its
  state to Protected — before that pass it was offered and could not be
  answered, because the place was already protected.
* **DE-4 gains a suggestion.** «Gregor Keller» is on the team page and was in
  the clear until the bank carried both halves of him.
* **DE-1 and DE-6 each lose a candidate.** «Demir» and «Reinhardt» are in the
  bank now, and the comma rule only *discovers* a surname it does not know. A
  surname that is also a given name — «Demir», «Yilmaz» — is invisible to
  discovery until «known» there means «known as a surname», which is a rule and
  not this task.
* **Tier 2 was refused.** It found no person any golden was missing, added 25
  more candidates across DE-3 and DE-4, and turned «Vorfinanzierung, da …» into
  a name to look at, because two cities once gave a child the name «Da».
* **Three function words were added to the pack** — `per`, `mal`, `anders` —
  measured: without them «Per Post versandt» offers «Per Post» as a person, and
  «per Post» is in every second German business letter.

DE-6 (`Lohnabrechnung_Weber.txt`, written for this task) is the one golden the
bank does **not** help: its four people are written «Nachname, Vorname» in a
table, and that form is a discovery rule for *unknown* surnames only. Knowing
more names cannot find them; a rule that reads the reversed pair can, and that
is 038-A/E/G's ground.

DE-1 by kind: Person 7 · Phone 3 · Email 2 · TaxId 2 · Iban 1 · Bic 1 ·
CustomerNo 1 · IdCard 1 · Birthdate 1 · Vehicle 1 (all auto); Address 4 ·
Company 2 · Contract 2 (suggested). **What would leave after every question is
answered carries none of the seven people, the birth date, the ID card, the
plate, the customer number or the tax numbers** — `the_german_letter.rs`
asserts each one by value.

DE-4 is the Phase 2 number the owner accepted: **734 pages → 5 decisions**
(5 candidates, of which 4 useful), instead of reading 734 pages.

FP across the 880 public pages (DE-3 + DE-4): **0 at auto**; 4 + 1 suggestions,
all of the shape a person would want asked (addresses, a phone, a company).
**One false protection on our own contract fixture (DE-2)**, found by this
measurement and not by any test: the signature rule protects the line under
«Mit freundlichen Grüßen» whatever it is, and there it is a department. It is
the shape of error a person would accept (a line hidden, nothing leaked), and
it is counted here because a number that leaves it out is not the number.

**Reproduce:** `cargo test -p z_core --test the_german_letter --test
the_second_golden --test the_third_golden --test the_name_dictionary --test
find_once_teach_once --test a_language_is_data` — 23 tests, all green on this
build. `cargo run -p z_core --example check_document -- <file>` prints the
reader's numbers; `review_names` prints the decisions a person would be asked.

Timing on this machine (debug build of the rig in release): DE-4 is read in
130 ms and scanned in 75 ms; DE-3 in 30 + 10 ms.

---

## 3 · Swedish — what the second pack does, and does not, know

Pack `sv` (Phase 3's proof that a language is data: 82 lines, ~300 names from
Wikidata CC0, salutations `Herr/Fru/Fröken`, titles, company forms `AB/HB/KB`,
roles, closings; **no Swedish identifier rules**).

### 3.1 · The letter we wrote (SV-1), ground truth known

| present in the letter | found | state |
|---|---|---|
| 7 people (8 mentions) | **4** | 2 auto · 2 suggested; 3 not seen |
| 2 companies | 2 | suggested |
| 1 personnummer `999999-9999` | 1 | auto — as **TaxId**, by the label-bound general rule, not as a Swedish kind |
| 1 org.nr `999999-9999` | 1 | auto — as TaxId, same rule |
| 1 IBAN | 1 | auto |
| 1 BIC (8 letters) | **0** | — |
| 1 bankgiro `9999-9999` | **0** | — |
| 4 phones | 3 | 2 auto · 1 suggested (the `08-` landline) |
| 2 e-mails | 2 | auto |
| 4 addresses | **0** | — (the German address rule is the German pack's) |
| 1 plate `AAA 999` | **0** | — |
| 1 VAT number `SE…01` | **0** | — |
| customer number (3 mentions) | 1 | auto |
| invoice number (3 mentions) | 0 | — |

Totals: **auto 10 · suggested 5 · normal 171**; layers 4 rules / 8 pack; 2
name candidates. Of the 7 people, the two reached by the pack's rules were a
closing-line signature and a given+family pair the dictionary knew on both
sides; the two suggested had one side known; the three unseen have no Swedish
cue the pack holds (no salutation — modern Swedish letters do not use one — and
a family name outside 300).

### 3.2 · The owner's own papers (SV-2…15), numbers only

14 PDFs; **11 read, 3 refused** — the annual report (page 3 decodes to 71%,
its fonts map ten codes to nothing, as noted on 3 October) and the two
registration certificates (encrypted PDFs; the password gate is right).

| across the 11 readable papers | count |
|---|---|
| pages · words | 29 · 21 428 |
| persons auto / suggested / candidates | **0 / 0 / 0** |
| persons present, counted by hand | ≥ 1 (the AGM minutes name one person in three roles, 7 role mentions; a Bolagsverket filing carries one personnummer) |
| companies suggested | 13 (11 of them the counterparties in the account analysis — right) |
| phone suggested | 26 — 20 amounts or form fields of the shapes `999 99.999` and `999 999.999`, 5 of a reference shape `9999-999 999`, 1 date; **false suggestions, zero false protections** |
| the company's own org.nr `999999-9999` | 36 occurrences across the set, **never recognised** (no label the rule knows) |
| e-mail / IBAN / phone auto | 3 / 1 / 4 — all in the one English-language payment reminder, by the general rules |

What this says, plainly: **the Swedish pack as merged is an architecture
proof, not a Swedish product.** Nothing in it recognises a personnummer, an
org.nr, a bankgiro or a Swedish address; the role words it carries
(`ordförande`, `justerare`…) produced no candidate on minutes that use them
seven times. The German letter's 7/7 is not a Swedish number.

**Reproduce:** the SV-1 row from the fixture with task 038's probe (`measure sv
z_core/tests/fixtures/Brev_Lindqvist.txt`); the SV-2…15 rows only on the
owner's machine, and only as counts.

---

## 4 · Arabic — the baseline before any Arabic pack exists

There is no `ar` pack on this build. The measurement is made with pack `de`,
which on Arabic text means: **the general rules alone** (e-mail, IBAN, BIC,
phone), and nothing that reads Arabic.

### 4.1 · The letter we wrote (AR-1), ground truth known

| present in the letter | found | state |
|---|---|---|
| 7 people (8 mentions), each after an honorific or kinship cue | **0** | — |
| 2 companies (`شركة … المحدودة`, `… ذ.م.م`) | **0** | — |
| 1 commercial register number (10 digits) | 0 | — |
| 1 national ID (10 digits) | 0 | — |
| 2 VAT numbers (15 digits) | 0 | — |
| 1 IBAN SA | 1 | auto |
| 1 BIC | 1 | auto |
| 4 phones | 3 | 1 auto (`+966`) · 2 suggested (`012 …`, `05…`); **the one written in Arabic-Indic digits: not seen** |
| 2 e-mails | 2 | auto |
| 4 addresses, 1 plate, 1 birth date, customer number (3 mentions) | 0 | — |

Totals: **auto 5 · suggested 2 · normal 213**; 0 candidates. Under pack `sv`
the same letter gives 4 / 2 (the BIC goes), which is the language-independence
of the general rules measured the other way round.

### 4.2 · A public Arabic book (AR-2): does the core damage Arabic text?

221 pages read in 38 ms, scanned in 24 ms; **auto 1** (the publisher's e-mail
address, a true find) · **suggested 0** · 38 566 normal words. **0 false
protections on 221 Arabic pages.**

But the census of what the reader hands the scanner says what the Arabic pack
will first have to face:

| of 333 417 characters | count |
|---|---|
| Arabic letters (U+0600 block) | 82 975 |
| **Arabic presentation forms** (U+FB50–FDFF, FE70–FEFF) | **205 434** |
| ASCII digits · Arabic-Indic digits | 1 031 · 470 |

and a probe for the book's own title word: **0 raw · 0 after NFKC · 180 after
NFKC and reversing the string**. The PDF's fonts emit glyph-shaped characters
in visual (right-to-left-reversed) order, and the reader passes them through
as they are. **On this build no Arabic rule can match a word in an Arabic
PDF**, however good the rule; plain-text input (`.txt`, pasted text) is in
logical order and unaffected — AR-1 is `.txt`, which is why its e-mails and
IBAN were found.

### 4.3 · The owner's demo: «our own lists work» — a list of the book's characters

The owner's proposal (5 Oct, night): write the names of the book's characters
into Z and put the book in; if they are protected, the user-taught layer is
shown to work in Arabic with no dictionary at all. Measured with a fresh vault
holding five characters as Person values, policy «always»:

| text given to the scanner | taught | Person auto | note |
|---|---|---|---|
| AR-1, the invented letter (`.txt`) + its 7 people taught | 7 | **7** | the vault layer finds every taught name in Arabic running text; auto rises 5 → 12 |
| AR-2 as this build reads the PDF | 5 | **0** | presentation forms in visual order defeat every list |
| AR-2 folded to NFKC (poppler's text, logical order, diacritics kept) | 5 | **461** | = 180 + 209 + 4 + 1 + 67, each name's own count |
| the same with the diacritics (harakat) removed | 5 | **562** | 101 more: the occurrences that carry a vowel mark inside the name |

So the layer the Arabic pack rests on — names taught once, protected
everywhere — **works on Arabic today**, and what stands between it and the
real book is the reader, in two parts: fold the presentation forms (NFKC) and
hand the text over in logical order; then let a taught value match through
the vowel marks. A value matches as a substring, which in Arabic is what one
wants (`وكليلة`, `لدمنة`: the clitic stays, the name goes) and is also the
risk a short name carries inside another word.

A common noun taught as a name is the live lesson of the «suggest» policy: the
word for the lion, a character of the book and an ordinary word, stands 267
times.

**Reproduce:** `measure de z_core/tests/fixtures/Risala_Alharbi.txt` for the
letter; the book only on a machine that has it.

---

## 5 · What may be said, and what may not

May be said, with the command behind it:

- Seven invented people in a German letter: **7 of 7 protected without a
  question**, and nothing of the writer's own left in the clear after the
  questions are answered.
- **0 false protections on 880 public German pages** and **0 on 221 public
  Arabic pages** (and one on our own contract fixture, named above).
- A 734-page document costs the reader **5 decisions**, not 734 pages.
- The general rules (e-mail, IBAN, BIC, phone) hold in German, Swedish and
  Arabic text alike, under any pack.
- Adding Swedish needed **no change to the core** (Phase 3).

May **not** be said yet:

- Anything about Swedish coverage: 4 of 7 invented people, **0 of ≥1 real**,
  no personnummer/org.nr/bankgiro kind.
- Anything about Arabic beyond the general rules: 0 of 7 people, 0 of 2
  companies, no Arabic-Indic digits, and no Arabic PDF readable by a rule
  until the reader folds presentation forms and restores logical order.

---

## 6 · The measured debts, in the owner's order (5 Oct 2026, night)

None of these is fixed ad hoc. All wait for Phase 4 (the Multi-Model Gateway)
to be delivered, so that one person at a time changes the gates and the
detection path. In the owner's words: «نسجلها كديون مقاسة».

| paper | debt | the number that measures it today | the number that closes it |
|---|---|---|---|
| 038 | the probe in git: `measure <pack> <file>`, goldens four to six | rows §3–§4 reproducible only by the lead's rig | every row one command |
| 038-A | the signature rule protects the line under the closing whatever it is | DE-2: 1 false protection («Abteilung …») | 0, with the one person still 1 |
| 038-B | Swedish production gaps: personnummer · organisationsnummer · bankgiro · roles · addresses | SV-1: 4 of 7 people, BIC/bankgiro/plate/VAT/addresses 0; the owner's papers: 0 persons, 36 unrecognised org.nr, 26 false phone suggestions | SV-1 at DE-1's level; the papers' persons found; the org.nr a kind of its own |
| 038-C | Arabic PDF normalisation **in ingestion, before any pack**: presentation forms · RTL/reordering · Arabic-Indic digits — normalisation is for comparison, never for changing the document | AR-2: 205 434 presentation-form characters, title word 0 raw; five taught names 0 | title word 180 raw; five names 461, then 562 through the vowel marks — **these numbers are the acceptance contract** |
| then | the Arabic pack — **only after 038 + 038-C, the quality/ingestion step** | AR-1 under general rules: 0 of 7 people, 0 of 2 companies | its own paper |

**What the measurement settled** (the owner): «محرك Z والقوائم الشخصية قادران أصلًا على
التعامل مع العربية؛ العطل في طبقة إدخال PDF» — the fix goes where the fault is,
not where the language is.

**The reason the Arabic reader comes before the Arabic pack** (the owner):
«لا نبني الحزمة العربية قبل إصلاح طبقة القراءة. وإلا سنقيس فشلًا في اللغة بينما
المشكلة في أن النص نفسه وصل إلى Z مشوهًا.»

**And the reason the ugly rows stay on this page** (the owner): «لا نحاول إخفاء
النتائج غير الجميلة… فهي تثبت أننا نقيس ونكتشف حدود النظام بدل ادعاء أن المنتج
يعرف كل شيء. وبعد إصلاحها يصبح لدينا قبل/بعد حقيقي.»
