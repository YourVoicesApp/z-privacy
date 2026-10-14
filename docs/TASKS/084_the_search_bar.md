# 084 · The search bar — type a name, see its fate, act on it

**Opened by the owner, 14 Oct 2026.** «وجدت ما كان ينقصنا في كل هذه العملية… شريط بحث في الوثيقة.» And: «هذا يحل الإشكال الأكبر.»

Today the person must *find* a name before Z can do anything with it: «Protect all matches» (`apps/flutter_app/lib/widgets/acts.dart:62`) appears only after the word was selected by hand. The only search box in the app is the vault's (`screens/vault.dart:250`). The document has none.

## What already exists in the core (c9987fd)

The owner's reading is right: the finding engine is there.

- `text::occurrences(haystack, needle)` (`z_core/src/text.rs:389`) returns every place of a word: **case-blind and whole-word only** (`stands_alone`). It is already used by the scanner, the vault, and the `matches` count behind «Protect all matches» (`ops/mod.rs:1304`, `:1605`).
- Known gap, written at the function: `ß` is not folded, so «Weiß» does not find «WEISS».
- **Missing:** nothing exposes it to a *typed* query, and nothing returns each place's state.

## The owner's rulings

1. **The bar is in plain sight and blue**, so the eye goes to it first. It is not hidden behind a key or a menu.
2. **Type a name, get numbers:**
   - how many times the word appears in the text;
   - for each place, its state: **protected**, **suggested** (waiting), or **in the clear**.
3. **Four actions on the result:**
   - **Protect**;
   - **Un-protect here** (this one place);
   - **Un-protect in this conversation** (every place);
   - **Go to the word**: both columns move to it and light it (the go-to-word function of 083, rule 14; Next walks the places).
4. **The search bar is the most important piece**; the highlight reading below is a second option beside it.

## Shape — the lead's reading, for the owner's eye on the glass

- **One result line:** «Lindqvist — 12 places: 9 protected · 2 suggested · 1 in the clear», with the four actions beside it.
- **Protect** takes every place that is not protected yet: the clear ones and the suggested ones, which answers those suggestions. One answer per word per conversation, as in 083.
- **Go to** starts at the first place in reading order; the button becomes **Next 1/12**.
- **Search is whole-word and case-blind**, which is what `occurrences` does today. A search for part of a word («Lind») finds nothing; the comparison study (below) decides whether that stays.
- **The bar searches the original column**: a protected name is still found by its name, and its token is shown beside it.
- **What is typed is never stored**: no search history. A list of searched names would be a list of names in plain text.
- Un-protection here / in this conversation is the same act as 083d, so 084 lands after 083d, or carries 083d inside it.

## Completion while typing (owner, 14 Oct)

«تبدأ الاقتراحات اعتباراً من الحرف الثالث… بخط شفاف أسفل الكلمة… ثم تاب ثم إنتر.»

5. **From the third character typed**, a completion appears **in faint text under the typed word**: «Lin» → *Lindqvist*.
6. **Tab** takes the completion into the bar; **Enter** searches the whole word.
7. This is how the whole-word search meets a half-typed name: the search stays whole-word and case-blind, and the completion supplies the whole word.

The lead's reading:
- **Completions come only from the words of the document open now.** They never come from the vault, from other sessions, or from earlier searches. Nothing new is stored, and nothing from elsewhere is shown.
- **The one shown is the word that appears most often with that beginning** (case-blind); a tie goes to the earlier one in reading order.
- **Typing on means the shown word is refused (owner, 14 Oct):** «الاستمرار في كتابة الأحرف يعني أن الخيار الأول مرفوض والبحث عن خيار ثاني. في حال عدم وجود خيار ثاني تختفي الإضافات وتستمر الكتابة.» Each new letter drops every word already shown and offers the next one that fits what is typed now. If none is left, the faint text disappears and the typing goes on. Enter then searches what was typed. This replaces the lead's «second Tab». Tab only takes; it never cycles.
- **A refused word does not come back (owner, 14 Oct):** «استمرار الكتابة يعني أن الخيار الأول لا يستمر في الظهور، يختفي، لا نعود إليه.» This is deliberately unlike a web search box that holds on to its guess while the letters still agree. When the completion vanishes, the app has understood that the shown word was refused, or not noticed. The person then either types on or **erases back to the third letter**, which is simpler than typing on.
- The lead's reading of the erase: erasing back offers the next word that fits and has **not** been refused; a refused word stays refused until the bar is emptied, and an empty bar starts fresh.
- Harmless by design: someone who types «Lindq» after *Lindqvist* was shown loses the completion, but typing the name out and pressing Enter finds the same 12 places.
- «Third character» counts letters as the eye sees them, so Arabic «لين» counts three.

Guard: «Lin» in a document holding Lindqvist ×12 and Lindberg ×2 → faint *Lindqvist*; Tab → the bar reads «Lindqvist»; Enter → the 12-place result line. «Li» → nothing faint. «Lin» shows *Lindqvist*, then «d» → faint *Lindberg* (Lindqvist refused); then «b» → nothing more fits that was not shown, so the faint text is gone and the bar reads «Lindb».

## Colours in the search box, not in the text (owner, 14 Oct)

«الكلمات المشفرة… تظهر بلون أحمر مائي شفاف، والكلمات غير المشفرة تظهر بلون أزرق مائي شفاف» — and then, the owner's correction to the lead's reading: **«الكلمة الحمراء في مستطيل البحث، وفي النص الكلمة تبقى كما هي. لا نغيّر في إعدادات النص.»**

8. **The colours belong to the search box.** In the result, a protected word is shown on a transparent watery red; a word the app found and that is not protected yet is shown on a transparent watery blue.
9. **The document's own marks are unchanged.** The washes and lines it draws today stay exactly as they are (`apps/flutter_app/lib/widgets/document_text.dart:665-722`):
   - wavy amber: suggested;
   - dashed clay: protected by a layer;
   - solid clay: protected by hand;
   - the river wash: the vault.
   084 changes nothing in how the text is drawn.

## Beside it: highlighted words become suggestions (owner, 14 Oct)

A word the person coloured before the document entered Z (Word highlight; PDF Highlight annotation) arrives as a **suggestion**, never as protected outright: the colour may not be the session owner's, and people highlight for other reasons. It is an option that exists, not the main road.

- **Measure first:** the reader today drops colour entirely (no `highlight`, `shd` or annotation handling in `z_core/src/documents`). Two real files from the owner (a Word file with highlighted names, a PDF highlighted with the Highlight tool) → what each reader can see, before anything is built.
- Out of reach, said plainly: a printed page marked with a pen and photographed. Z does not read images.

## The comparison, returned (14 Oct, `docs/reference/Z_SEARCH.md`)

None of the ten projects has a find bar tied to protection. The standard people know is Acrobat's «Find text to redact»: type, see a list with checkboxes, uncheck a place, apply.

The lead's reading of what to take and what to leave:

| what others do | in 084? | why |
|---|---|---|
| count, light all, walk the places (Word, Acrobat) | **yes** | the result line and Next 1/12 |
| exclude one place (Acrobat checkboxes) | **yes, already** | «un-protect here» |
| regex / wildcards / patterns (Acrobat, Word) | **no** | finding patterns is Z's own work, the packs; simpler than simplicity |
| case and part-of-word switches (Word) | **no** | the completion supplies the whole word |
| Replace All (Word, BentoPDF) | **no** | Z never changes how the document reads |
| search across a folder (Acrobat) | **no** | one document, one session |
| query history (Microsoft Search) | **no, forbidden** | rule 47; ZCFG already forbids it (`config.rs:16-18`) |
| mask part of a number (Acrobat) | **to the numbers paper** | tonight |

## Measured by the builder before building, 14 Oct — the shape corrected

**(a) Each place's state is not derivable today.** «Lindqvist» in a document holding «Anna Lindqvist» and «Lindqvist AB» stands in 5 whole-word places — the count exists (`matches`). But after «Anna Lindqvist» is protected by hand, every place reports `protected_as: None`, and `snaps_to` is built from protections alone: a place inside a *suggestion* cannot be told from a place in the clear. So «9 protected · 2 suggested · 1 in the clear» needs **one core function that returns, per place, what covers it**: a protection → protected (and its token); a finding → suggested; nothing → in the clear. The count, the washes and the four acts all read from that one source.

**(b) A place's state is the state of what COVERS it, not the state of the word.** Everything the glass protects today is `Scope.conversation`; `Scope.once` is asked from nowhere. So a single word is never «9 of 12» because of a scope. The mixture comes from **containing values**: «Lindqvist» inside the protected «Anna Lindqvist» is protected, inside the suggested «Lindqvist AB» is suggested, and alone is in the clear. This corrects the lead's reading above, which treated the state as the word's.

**(c) What «Protect» in the bar does with a place inside a wider suggestion — ruled by the lead, 14 Oct.** The lead's reading above said «Protect takes every place not yet protected… which answers those suggestions». Measured, a suggestion can be **wider than the word typed**: the person typed «Lindqvist»; the suggestion is «Lindqvist AB», a company. Answering it protects what he did not type. So:
- **«Protect» protects the places in the clear, with the word the person typed, and does not answer a wider suggestion.**
- The result line says so: «2 places inside words still waiting: Lindqvist AB».
- Why: selection is the person's will (085), and that was not his will; a wide answer is not undone in one press; and **nothing leaks by leaving it** — a suggestion that still waits holds every exit shut under 083a's law, so the part inside it cannot leave in the clear. The review is where it is answered.
- A place inside a wider **protection** needs nothing: it is already protected.

## Waits on

- **The comparison study** (sent 14 Oct): how ten projects plus Acrobat's «Find text to redact» and Word's search match, count, light, navigate, act, and store. It may add to the shape, not to the rulings.
- The owner's two highlighted files.

## Guards (pinned red first)

- **The count guard:** a word in 12 places with 9 protected, 2 suggested and 1 clear → the bar reports exactly 12 / 9 / 2 / 1.
- **The act guards:** Protect → 12 protected, 0 suggested; Un-protect here → 11; Un-protect in this conversation → 0, other conversations untouched.
- **The walk guard:** Go to → both columns at the first place, the same offset; Next → the second; the count is shown on the button.
- **The no-history guard:** after a search, no file the app writes contains the typed word except the document itself.
