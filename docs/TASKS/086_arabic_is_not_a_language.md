# 086 · Arabic is not a language, it is settings — a second reading and writing base

**Opened by the owner, 14 Oct 2026, as the first step of the road to Doha.**

> «الخطوة الأولى هي إصلاح القراءة العربي. يجب أن يُبنى على قاعدة كتابة وقراءة مختلفة أو معاكسة. العربية ليست لغة، هي إعدادات.»

This separates two things the lead had folded into one:

| | what it is | when |
|---|---|---|
| **a language pack** | rules that know this word is a name | **last**, by the owner's ruling of the same morning |
| **the reading and writing base** | which way a line is read, and how the characters arrive | **first**, this paper |

A pack is knowledge. A base is **settings**: it governs reading, writing, selection, pages and export alike, and it serves every script that is written the other way — Arabic, Persian, Urdu and the rest of the family ([[project_zprivacy_arabic_script_family]]).

## Measured, and why this is first

- An Arabic book as the PDF reader hands it over: **0 of the taught characters found**.
- The same text folded to logical order: **461**. Through the harakat: **562**.
- Five taught characters matched **462** places in the book through the §4.3 path, and the Arabic clitics rule is the reason the word-edge rule has an Arabic half at all (`z_core/src/text.rs:286-320`, `:370-377`).

So the defect is not that Z lacks Arabic knowledge. **It is that an Arabic document arrives in a shape nothing can be found in** — presentation forms, and the line's order reversed. Every rule we sealed today (076 edges, 083 protection, 084 search) rests on a word's place in the text; on an Arabic PDF today those places are wrong before any rule runs.

## What the core knows already

- The word's edges have an Arabic half: `ARABIC_CLITICS` (`و ب ل ف ك`) and the presentation-form range `U+FE70–FEFF` are named at `text.rs:295`, `:319`.
- The harakat are kept inside a name, never torn off (`text.rs:335-345`), which today's edge-set widening (085) preserved on purpose.
- The PDF reader refuses a page it cannot read faithfully rather than half-reading it (`documents/pdf.rs:89`, `:129`) — «a name we cannot see is a name we cannot protect». **It has no fold and no ordering step**: a search for `FE70`, `presentation` or `fold` in `pdf.rs` finds nothing.
- The glass already asks for the ambient direction in two places (`document_text.dart:884`, `line_gutter.dart:198`) and hard-codes `ltr` in one (`document_text.dart:1128`).

## What the base must settle (to be measured before building)

1. **Reading.** A document arrives folded to its logical order and in ordinary letters, not presentation forms — so that a span, a count and an occurrence mean the same thing in both directions.
2. **Writing.** What Z puts out — the Safe column, a copy, a Z sheet, a z-pdf — reads back the same way it was read. A round trip proves it: read, protect, export, read again, and the same places are found.
3. **Where the base comes from.** A session's base, like its language (080): chosen when the session is born, else the app's. Not guessed per paragraph.
4. **Selection in the other direction.** 076's rules are about the word and the space, so they hold; what moves is which side «the word before» is on (`acts.dart` «Also the word before»), and where a lit word sits on the glass.
5. **The two columns.** Which side holds the original when the text is read the other way, and the W8/073 alignment must survive.
6. **The Z sheet (082).** 3 cm at the top and 2 cm at the bottom do not change. The letterhead and the stamp do not move with the script.
7. **The search bar (084).** The completion counts three letters as the eye sees them, which is already the rule (`~/محرر النصوص.md` 46ب).

## Order

1. **The measurement**, before any code: the owner's own Arabic PDF and the book through the reader — what arrives, in what order, in which characters, per page. Shown as screenshots, both columns. Plus one Arabic file written by hand (a chat text) as the control, since a typed line has no presentation forms.
2. **Reading** (the core, `documents/`): fold and order, with the reader's fail-closed behaviour untouched. The old task name `fix/arabic-arrives-as-it-is-read` (039) belongs here.
3. **Writing and the round trip.**
4. **The glass:** the base as a session setting, the lit word, the columns, «the word before».
5. A language pack is **not** part of this and waits as ruled.

## Guards (pinned red first)

- **The round-trip guard:** an Arabic document read → N places found; protected and exported → read again → the same N, the same spans.
- **The presentation guard:** a PDF page of presentation forms arrives as ordinary letters; a page the reader cannot read faithfully is still refused.
- **The harakat guard** (already standing, 085): a mark on the last letter of a name is not an edge.
- **The direction guard:** a session born on the other base lights the word the eye reads first, in both columns at one offset.

## Why it is first, in the owner's order

Doha is Arabic. A pack can wait because a person can select by hand; **a document that arrives in the wrong order cannot be selected at all.**
