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
- Harmless by design: someone who types «Lindq» after *Lindqvist* was shown loses the completion, but typing the name out and pressing Enter finds the same 12 places.
- «Third character» counts letters as the eye sees them, so Arabic «لين» counts three.

Guard: «Lin» in a document holding Lindqvist ×12 and Lindberg ×2 → faint *Lindqvist*; Tab → the bar reads «Lindqvist»; Enter → the 12-place result line. «Li» → nothing faint. «Lin» shows *Lindqvist*, then «d» → faint *Lindberg* (Lindqvist refused); then «b» → nothing more fits that was not shown, so the faint text is gone and the bar reads «Lindb».

## Beside it: highlighted words become suggestions (owner, 14 Oct)

A word the person coloured before the document entered Z (Word highlight; PDF Highlight annotation) arrives as a **suggestion**, never as protected outright: the colour may not be the session owner's, and people highlight for other reasons. It is an option that exists, not the main road.

- **Measure first:** the reader today drops colour entirely (no `highlight`, `shd` or annotation handling in `z_core/src/documents`). Two real files from the owner (a Word file with highlighted names, a PDF highlighted with the Highlight tool) → what each reader can see, before anything is built.
- Out of reach, said plainly: a printed page marked with a pen and photographed. Z does not read images.

## Waits on

- **The comparison study** (sent 14 Oct): how ten projects plus Acrobat's «Find text to redact» and Word's search match, count, light, navigate, act, and store. It may add to the shape, not to the rulings.
- The owner's two highlighted files.

## Guards (pinned red first)

- **The count guard:** a word in 12 places with 9 protected, 2 suggested and 1 clear → the bar reports exactly 12 / 9 / 2 / 1.
- **The act guards:** Protect → 12 protected, 0 suggested; Un-protect here → 11; Un-protect in this conversation → 0, other conversations untouched.
- **The walk guard:** Go to → both columns at the first place, the same offset; Next → the second; the count is shown on the button.
- **The no-history guard:** after a search, no file the app writes contains the typed word except the document itself.
