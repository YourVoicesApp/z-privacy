# 081 · A refused copy leaves the old clipboard — the original walks out through a door that said no

**Opened by the owner, 13 Oct 2026, from a field test on 12 Oct.** «You enter the app, take a document, protect it, go to Copy or Save as PDF without naming a session or being inside one — and the surprise is that you get the text unprotected. This alone brings the app down.»

## What the lead measured (d882c5f)

- **The core is clean.** Scratch probe outside the tree: `Brief_Weber.txt`, German pack, no vault, no session → 21 values auto-protected → `build_payload` → **0 of 21 present verbatim in the payload**; `payload.audit` refuses any payload that fails G3.
- **The glass refuses a nameless exit.** Both exits go through `beginThenRead` (`session_state.dart:1659`): vault open + no session + no name → `refused: 'Give it a name first — one word is enough.'`, nothing written. The public package (`c6cab87`) carries this.
- **The hole: a refusal writes nothing — and erases nothing.** The guard `the_name_at_the_exit_test.dart:282` asserts `probe.writes == 0` and **`probe.text == 'SENTINEL'`** — it counts the old clipboard surviving as success. Whatever the person copied before stays there.

## The most likely path of the owner's leak (to be confirmed by his word)

1. The original German text was copied (the same day's chat-language experiment, 080).
2. The document was protected; Copy Protected pressed with no session named.
3. The press refused with one small line; the button looked the same.
4. Paste → **the original text**, still on the clipboard from step 1.

The app did not put the original out; it **let it out**: a quiet no, and a clipboard left holding the last thing. A guard green for the wrong reason — it measures what the app wrote, not what the person will paste.

## The owner's rulings (13 Oct)

1. **No refusal at the exit: a session is born with a sequential name** — «الجلسة 1، الجلسة 2…» — the moment Copy Protected, Save as PDF or a send is pressed with none open. This **replaces** the earlier rule «the name is asked once, at the exit» (064).
2. **Rename lives in the sessions list**, inside the session's rectangle, beside Delete. The core already has it: `conversation_rename(number, name)` — «the number is the identity and does not move».

## The lead's addition (backstop, for any refusal left anywhere)

- **A copy that does not succeed clears the clipboard**, and says so in words: «Nothing was copied — the clipboard is empty.» No old content survives a failed Copy Protected.

## Guards (each pinned red against today's tree first)

- **The paste guard** (replaces the SENTINEL assertion): put the document's original text on the clipboard, press every exit with no session — what a paste would read is the protected payload, or nothing; **never a value the scan protected**.
- **The birth guard:** a nameless exit with the vault open births «Session N» (N = the core's number), renames the bench's tokens, and the text that leaves wears the new session's names.
- **The rename guard:** rename from the sessions list changes the name, not the number; tokens and file unchanged.
- **The filename note (found on the way):** the saved PDF's file name is built from the original document's name (`protected_pdf.dart:392`) — a name in a file name leaves in the clear. Folded in: the saved file is named after the session, not the source document.

## Seat and order

Dart seat (send sheet, `beginThenRead`, sessions list) with no core change (`conversation_begin` and `conversation_rename` exist). **Before 080**, right after the sealed-name pillar: it touches the product's first promise — no original text leaves. Ledger line per landed commit (the library's exit must have the same shape: no refusal that leaves stale state behind).
