# 083 · Selection is protection — the protection model, redrawn

**Opened by the owner, 13 Oct 2026 night; the review and the exits ruled 14 Oct.** «هل تعلم صديقي نحن نعقد العملية على أنفسنا كثيراً… أي تحديد هو تشفير… الخيارات هي في فك التشفير.»

This paper replaces the protection dialog, the client profiles and the «everywhere» scope with one plain model. It closes the open contract item **C3** on the app side (`docs/CONFORMANCE_LEDGER.md`). Product experience, not contract: the library is not asked to follow any of it except C3.

## Today (c9987fd)

- **A hand selection opens a dialog** («Protect this», `widgets/protect_dialog.dart:86`) with scopes and kinds before anything is protected.
- **A suggestion carries five answers** (`widgets/review.dart:526-549`): Protect · Not sensitive · Not sensitive in profile · Not sensitive everywhere · Always. Core: `FindingAnswer { protect, always, notSensitive, skip }`, `Scope { once, conversation, … }`, `Policy { always, suggest, … }`.
- **The review has two modes already**: a list and a walk one-at-a-time (`bench.walking`, `review.dart:51`, `:87-95`). Bulk: «Protect all N» and «Leave all N in the clear» with a confirmation (`:351-403`).
- **The three exits do not share one law.** A send refuses with `OpenSuggestions` (`z_core/src/ops/mod.rs:440`, `:486`); Copy Protected and Save as PDF go through `build_payload`, which does not check — **an unanswered suggestion leaves in the clear.** This is C3, open.
- The vault holds values with a kind, a profile and a scope; it can hold identifiers (email, IBAN, phone, national ID).

## The owner's rulings

### 1. Selecting is protecting
1. **Any selection protects, with no dialog and no question.** Select, and it is protected. The selection rules of 076 decide what was selected.
2. The protection dialog is deleted, not hidden.

### 2. Options live only on un-protection
3. **Un-protecting offers two choices: «here»** (this one place) **or «in this conversation»** (every appearance in this conversation). **No «everywhere».**

### 3. Suggestions are a review — two forms (14 Oct)
4. **In the text:** pressing **Review** moves both columns to the first waiting word, lit, with its two buttons beside it; **Review becomes Next**, with the count left on it («Next 3/7»).
5. **Answering moves on by itself** to the next waiting word; **Next** is for leaving a word for later without an answer.
6. **The list:** every waiting word, with **«Protect all»** and **«Skip all»** at its foot. Auto-protected and hand-decided words are seen in the text, not in the list.
7. **Two buttons per suggested word, no more: «Protect» and «Leave it».** One answer holds for **the same word in every place in this conversation** — twelve «Lindqvist» need one answer, not twelve stops.
8. **Deleted:** Not sensitive in profile · Not sensitive everywhere · Always.
9. **«Skip all» keeps its confirmation** («Leave 7 words in the clear? Yes / Cancel»): it is the one door that uncovers words in a batch (owner, 14 Oct).
10. When no word waits, the Next button is gone and the exits open.

### 4. The three exits, one law — closes C3
11. **Send, Copy Protected and Save as PDF: no text leaves while a word waits for the person's answer.** `build_payload` gets the same check the send has, so the law sits in the core, not in three buttons.
12. **The refusal is a guide, not a wall:** an exit pressed while words wait opens the review at the first waiting word. The clipboard is emptied first, as every exit press does (081).
13. A paragraph is not left until its words' fate is decided — the review is how that is lived; the exit law is how it is guaranteed.

### 5. Going to a word is one function
14. **Moving to a word is a word-search system:** one function moves both columns to a span and lights it. Review uses it first; a later Find (Ctrl+F) uses the same one (`~/محرر النصوص.md` rule 40). Both columns land together (W8/073 alignment).

### 6. Sessions replace client profiles
15. **No client profiles.** A conversation's values belong to its session.
16. **Conversation values are kept in the vault, tied to their session.**
17. **No name memory across sessions.** A name protected in one session is not recognised by another because of that.

### 7. The vault is one mass of word blocks
18. **The vault holds word blocks**: no kind label, no link between blocks, no belonging. Shown sorted alphabetically or by length.
19. **Identifiers are never stored** — email, IBAN, phone, national ID. The rules find them again every time.
20. **No real names in the vault as records**: a block is a word, not a person.
21. **The existing harvest is kept, not wiped** — it becomes the app's material, Arabic names above all — but **loses its belonging** (the profile it came from, e.g. «Mongo Shell», is dropped). The Arabic names bank (077) is drawn from it: given and family names only.

## Order of building

| item | what | closes | seat |
|---|---|---|---|
| **083a** | the exit law in the core (`build_payload` checks open suggestions) + exits open the review at the first waiting word | **C3** | core + Dart |
| **083b** | the review: Review→Next with count, auto-advance, two buttons, conversation scope, list with Protect all / Skip all (confirmation kept), one go-to-word function | 3, 5 | Dart |
| **083c** | selection = protection: the dialog deleted | 1 | Dart |
| **083d** | un-protection: here / in this conversation | 2 | core + Dart |
| **083e** | sessions replace profiles; vault as word blocks; identifiers out; harvest kept without belonging | 6, 7 | core (migration) |

083a first: it is the one item where a value can leave in the clear today. 083e is a vault migration and gets its own measurement paper before code (what the vault holds today, by count, never by value).

## Guards (each pinned red against today's tree first)

- **The C3 guard:** a document with one waiting suggestion → Send, Copy Protected, Save as PDF each put out nothing, the clipboard reads empty, the review opens on that word. Answer it → each exit works. Ledger line C3 moves to *conforms*.
- **The one-answer guard:** a suggested word in 12 places → one «Leave it» → 0 waiting, 12 left as written; one «Protect» → one token in 12 places.
- **The walk guard:** Review → the lit word is the first waiting one in reading order, both columns at the same offset; answer → the next; the count falls; the last answer removes the button.
- **The skip-all guard:** Skip all → the confirmation; Cancel changes nothing; Yes leaves all in the clear and opens the exits.
- **The selection guard (083c):** a selection protects with no dialog on screen.
- **The un-protection guard (083d):** «here» uncovers one place; «in this conversation» every place in this conversation and no other.
- **The vault guard (083e):** after migration no block has a kind or a profile, and no stored block matches an identifier rule.

## Waits on

- The owner's screenshots of the options he could not read a reason for (14 Oct): what they show joins the delete list of rule 8 before 083b is built.
- `~/محرر النصوص.md` rules 11–13 and 37–42 are this paper in the editor's words.
