# 080 · The conversation speaks one language — the chat and the document read by the same rule

**Opened by the owner, 13 Oct 2026, from a field test.** A German PDF dragged in: 7 findings. The same text copied and pasted into the chat: 0.

## What the lead measured (d882c5f, before writing a line of this paper)

The two doors read the same text with two different languages.

- **The file door** (`_begin`, `apps/flutter_app/lib/screens/shell.dart:277`) asks `languageForNextDocument` (`:58`): the open session's language if it has one, otherwise it asks the person.
- **The chat door** (`_askFromHome`, `shell.dart:219`) never asks and never looks at the session. It reads `config.packId` — the value the first-run screen wrote from the *interface* language (`shell.dart:439`: `language == 'de' ? 'de' : 'en'`). On the owner's home machine `settings.zcfg` holds `pack=en`.

The same German letter (`z_core/tests/fixtures/Brief_Weber.txt`), one scan per pack, the text unchanged (scratch probe outside the tree, `open_session` → `import_text` → `scan`):

| pack | auto | suggested |
|---|---|---|
| de | 21 | 8 |
| en | 6 | 2 |
| sv | 7 | 2 |
| ar | 5 | 2 |

Read with an English eye, only the general rules remain. The owner's German book complaint («ما بنيناه للغة لا يستخدم») and this finding are the same defect: 075d («the language is asked once in a conversation's life») was written at the file door and never applied to its sibling — the trap recorded as *a rule written in place is not applied to its second case*.

## The owner's rulings (13 Oct, his words carried)

1. **«ما ينطبق على الوثائق ينطبق على الشات»** — the chat is not a separate world. One rule for both doors.
2. **The language is chosen when a session is created.** A new session shows the language choice.
3. **The app has a language of its own, set in Settings** («يمكن إضافة خيار لغة التطبيق في الإعدادات»).
4. **A chat or a document whose session has no chosen language takes the app's language.**
5. **Two languages for now: German and English.**

**Sealed by the owner, 13 Oct, after reading the paper:** «موافق على لغة الشاشة الأولى، وهكذا هناك طريقان لاختيار لغة الجلسة: إما إنشاء جلسة جديدة بلغة محددة وهي لغة الجلسة، أو لغة التطبيق.» — two ways only, and the first-run choice *is* the app's language.

## The rule, one sentence

A text — typed, pasted or read from a file — is scanned with **its session's language**; a session that has none takes **the app's language**; there is no third source.

## What is built

- **One function decides the language for both doors.** `_askFromHome` and `_begin` both call it; `config.packId` is read in exactly one place (the fallback). A guard proves it: grep finds no second read of `packId` from the config outside that function.
- **New session → the language is chosen there**, once, with the app's language preselected. Choosing writes it through the core's one door (`switch_pack`), as 075d already does for the first document.
- **Settings gain «App language»** (German / English). It is the fallback for sessions without one, and it is the interface language the first-run screen already chooses — one value, not two: the first-run choice and this setting are the same field, so they cannot disagree.
- **The offer is two languages.** The choice shows German and English only. The Swedish and Arabic packs stay in the core, untouched and measured; they are not offered on the glass in this round. Nothing is deleted.
- **A session that already holds a language keeps it.** Nothing rewrites an existing session.

## Guards (each must bite before it is accepted)

- **The two-door guard** (the seam guard for this item): the same German text in through the chat door and through the file door of one German session gives the same finding count. Pinned first against today's tree, where it must be red (0 vs 7 is the owner's own measurement).
- **The fallback guard**: a session with no language scans with the app's language; change the app's language and a *new* session follows it, an *old* one does not.
- **The single-source guard**: the config's pack is read in one function only.

## Seat and order

Dart seat (shell, the new-session choice, Settings) with one core touch at most (reading the session's language, which `openSessionRow.packId` already carries). **The programmer takes it after the sealed-name pillar closes and before 079's core** — it is small, it is a correctness defect the owner met in the field, and 079's restore path reads the session's language too, so it should read one source. The settings row and the new-session choice are drawn by the design seat when it opens; until then the programmer builds them in the existing style.

Every landed commit → one line in the Divergence Ledger (the library must make the same choice: one language per session, one fallback).
