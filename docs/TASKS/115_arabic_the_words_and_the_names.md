# 115 — Arabic: the app's words, and the names it knows

**Source:** the owner, 25 October 2026, the day after publishing. Z development stops after this round, and the app is left for real use for one to two weeks. His words: «تكون نصوص التطبيق بالعربية، ولدينا مكتبة من 2600 اسم نضعها داخله عند استخدام العربي، فقط. وهكذا سيكون في كل تطوير للغة. لا يمكننا التوسع المطلق بأي لغة: بعض القواعد الممكنة، بعض الأسماء، وإمكانية قراءة الشاشات بهذه اللغة». Builder: **ed**. Branch off the lead tip (`bfd79e6`). Paper 116 (e2) takes the right-to-left screens and the site in parallel.

## The language doctrine (governs this paper and every language after it)

A language in Z is three bounded things, never unbounded coverage:

1. **the app's sentences in it**, so a person can read the screens in that language;
2. **a bounded name library** that is active when that language is used;
3. **a few feasible rules** for it, and only those that can be measured.

Paper 086 already built the **reading base** (an Arabic document arrives in a shape the rules can find things in). This paper is the language on top of it, and nothing more.

## 1 · The words: `app_ar.arb`

- Every value of the one list in Arabic, exactly as 106 did Swedish: same keys, placeholders untouched, the values that must stay identical across languages (the «Session {number}» seam, product names) **by name**, as 106 listed its eleven.
- Register: one form of address throughout, chosen once and named in the report. The glossary follows the site's existing Arabic pages where they already name a term («الخزنة», «الجلسة» and the rest). The site was written by us and read by the owner, so its words are the nearest thing to a reviewed glossary we have. Guard 2b gains the Arabic column.
- **The same honesty as 106:** the owner is the only native reviewer. Nothing calls the Arabic «complete» or «reviewed» until his review round closes, and `check_the_one_list.py` prints Arabic's written-not-reviewed count beside de and sv.
- `theListIsWrittenIn('ar')` becomes true, so every gate that counts the languages of the interface moves with it. Find each one and say which moved.

## 2 · The names: an Arabic name pack from the owner's library

- **Source:** `~/الأسماء العربية.txt` (34 324 bytes, 2 698 lines). Its own header says **1 292 male + 1 135 female = 2 427**, not 2 600. **Measure the real count** after de-duplication and say it. Never write a number the file does not give. The file is grouped by letter, with header lines, section rules (`════`) and per-group counts like «(الذكور 17 — الإناث 10)». Parse names only, and pin the parse: header and count lines must never become names.
- Compound names (more than one word on a line, e.g. «عبد …») are a single name. Report how many there are.
- **Normalisation, using lessons this house already paid for:** a name with harakat («يُمنى») must match the same name written without them in a document, and the reverse. **Never fold with NFKC on Arabic** (it inserts a space before combining marks; see `nfkc_inserts_a_space_on_arabic_mark_forms`). Use the reading base's own fold from 086/038-C, and say which function. Arabic clitics (و، ف، ب، ل، ال) follow the word-edge rule that 076/§4.3 already has.
- **Active only when Arabic is used**, per the doctrine: the pack loads with the Arabic language choice, the way `de_names` is tied to German. Measure that an English or German session does not use it.
- It is **names only**. A name list is not a rule that something is a person in every context, so the existing «Suggested», never «Auto», discipline for names applies. Say what kind (Auto or Suggested) the pack's hits take, by the same rule `de_names` follows.
- **Provenance in the tree:** the pack's file names its source and date. The owner's library is the owner's work, and the pack carries no third-party licence claim.

## 3 · A few rules, only if measurable

Only what this round can measure on fixtures: for example Arabic-Indic digits (٠١٢٣٤٥٦٧٨٩) inside an IBAN or phone number, if the existing rules miss them today. Measure first. If they already work, write «already works» and add nothing.

## Pins (red first)

- A fixture Arabic letter (`Risala_Alharbi.txt` or a new fixture with names from the library) protects names it did not protect on `bfd79e6`, with the count before and after.
- A name with harakat and the same name without match each other both ways.
- A header/count line of the library never becomes a name.
- English/German sessions are unchanged by the pack: the same findings before and after.
- The one-list gates: ar has every key, placeholders intact, and the written-not-reviewed count is printed.

## Not in this paper

Right-to-left screens and the site are 116 (e2). Persian, Urdu and the rest of the script family wait. The context-words memory and everything else waits for the return after the pause (~8 November).

## Measurement

`bash scripts/gates.sh` green with counts, the real name count, the compound-name count, and the before/after of the fixture. The lead merges, measures and publishes Arabic as a new build after the owner's own look at the screens.
