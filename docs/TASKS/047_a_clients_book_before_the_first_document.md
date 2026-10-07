# 047 · A client book, protected before the first document opens

**Status: WRITTEN, NOT ORDERED** · 7 Oct 2026 · lead · **after the film.** The owner's idea, 7 October: «قائمة العملاء — يقوم المستخدم بإدخال قائمة بأسماء العملاء في شركته، وبهذا يحدد قبل العمل مباشرة الأسماء التي تحتاج تشفير. ويمكن توسعة القائمة يدوياً أو من ملفات، وقائمة الأصدقاء، وهكذا تصبح عملية البحث أسهل بكثير.»

## What the lead measured first (on `fad220f`) — the idea is four fifths built

| the part | where it is today |
|---|---|
| import a file of names | `import_user_names(csv, profile_id, list)` — CSV whose first line names its columns, `name` and `type` required, `source`/`licence` kept; the whole file read before anything is written, so a refused file leaves the vault untouched; a triple count back and a sentence per refused row |
| a name that is a **person or a company** | goes to the **vault as a value** under the open profile (`ops/vault.rs`, the `OWN_NAMES` entity) — and `vault_pass` matches vault values **in every language, pack or no pack**, which is exactly why the owner's 9→0 English demo works |
| a name that is a **given or family word** | goes to the **dictionary** layer instead: a signal the pack's rules read, never a protection by itself |
| the client as a grouping | **the profile.** `Scope::Profile` is already «every appearance here, and kept in the vault under the profile this conversation is in — so it is found by itself in that client's next document, and in no other client's» |
| a list that can be switched off | `user_lists()` · `set_user_list_enabled` · `move_user_list` · `forget_user_list`, with the switch read in one place (`taught_names_for`) |

## The fifth part — what is actually missing

1. **The import does not carry «always».** `import_user_names` takes no `always`, so an imported person lands as a **suggestion**, not a protection. The owner's sentence is «يحدد قبل العمل الأسماء التي تحتاج تشفير» — protected on arrival. Build: the import takes the same `always` the single `add_user_name` already takes, and the screen asks it once per file, in words: «protect these from the first document» / «offer them to me and I decide».
2. **A list has no name of its own.** `clean_list_name` refuses everything but a language: «a list is a language, one for each» (041-I, and it is right — a dictionary list belongs to a language). So «my clients» is **not** a language list; it is a **profile**, and the screens must say that in the owner's words instead of leaving him to guess: the client screen shows the client's own book, its count, and «Import a list» inside it.
3. **A list must be measurable, or it is a promise.** After an import the document must say what the list did: «your book protected 23 places here». And the cost must be measured, not assumed: a client called «Nord», «Lindgren» or «Al» will blacken ordinary words. The guards that exist are the Latin word boundary (041-P), the case-blind matcher (041-R) and the 11-false-to-1-true rule; what this task adds is a **minimum length** and a refusal list for a value shorter than it, said at import time with the row that caused it.

## Acceptance — the number that decides is the false one

On DE-1, DE-2, DE-3, DE-4, DE-6, SV-1, SV-16 and EN-1/EN-2/EN-3, import a book of 200 invented client names (ours, in the repository) into a profile and measure:

| | before | after |
|---|---|---|
| places the book protected | | |
| **false protections** | 0 | **must stay 0** |
| new suggestions | | a handful, each named |
| the German and Swedish golden rows | | **unchanged to the digit** |

A book that costs one false protection anywhere does not enter until the length rule or the boundary that let it through is fixed — the same entry rule 038-H's tiers obeyed.

## Not in this task

- A friends book is **not** a second feature: it is another profile. Say so on the screen; build nothing.
- Searching the book (`search_vault` exists) and editing it row by row (the vault room exists).
- Any change to the dictionary lists of 041-I.
