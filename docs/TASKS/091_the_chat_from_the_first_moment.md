# 091 — The chat from the first moment: rules 71–75

**Rules:** 71–75 in `~/محرر النصوص.md`, section «٥ب» (owner, 18 October, «نعم» with two additions, 74 and 75). Read them first.
**Base:** lead line `lead/the-day-of-the-attack` at `8510d82` (560 · 0 · 0, rust 779, dart 390), installed and pushed.
**Builder:** e2 — glass, one branch `fix/the-chat-from-the-first-moment` from `8510d82`. No push.

## What the owner saw on 8510d82 and 34ed785

- He opened the app with no document: no place to write to the AI. The box he wanted («What should the AI do with this?») appears only once a document is in. He wants to chat with no document at all.
- He ended a chat and started a new one: the old document stayed on the surface. A new chat must start from zero.
- He wanted to remove a document and bring another.
- Settings opened on the AI room; he wants Sessions first. And the settings overlay should go away on a press anywhere outside it.

## The five, in build order

**71. A new chat starts from zero.** When a chat ends — «End the chat», the session deleted from the room, or a new session opened — the whole surface empties: no document in the first part, no request, no thread in the third. Today «End the chat» closes the panel and leaves the columns standing (B5 of 090, on my ruling, now reversed by the owner). The kept copies in the session's list (54-ج/ز) are untouched by this; only the surface empties. The same person who wants the same document brings it in again by its door (rule 63).

**72. The chat box is there from the first moment, in the first part, with no document.** One box, always: it is today's request box `_TheQuestion` («What should the AI do with this?»), drawn whether or not a document is in. What is typed there is what enters: a short question or a whole pasted letter. It travels the middle column protected and goes to the chat like any question — with a document above it, it is the addition under the document (64, `--- Request ---`); with no document, it is the whole of what leaves (ed's `build_the_question_alone` already carries a question alone; measure that a question with no document leaves by it and that «Choose who answers» then opens the chat on its answer). So a chat with no document is the ordinary path, not a special one.
  - **72-أ. One box, not two.** The top strip's «Write or paste your text here… · Open and scan» is deleted (rule 35), «+» stays for files. A letter pasted in the one box is protected, leaves, and becomes a z-pdf by the same road: measure that a pasted multi-line text in the box is scanned and protected like a typed document was through «Open and scan», and that its z-pdf export still works. If something the top strip did cannot be done from the box (say so, with the line), that is a finding for me, not a reason to keep two boxes.

**73. «Remove the document» in the first part; «+» brings another.** Removing empties the first column and does not take the document out (54-و: no exit, no bubble, no question); its kept copy stays in the session's list (54-ز) and can be reopened from there. «+» with a document standing replaces it after removing it the same way. The request box keeps what was typed unless the chat ends (71).

**74. Settings opens on Sessions.** `SettingsRoom.sessions` is the room the overlay opens on, not `ai`. Nothing else in the rooms moves.

**75. The settings overlay closes on a press anywhere outside it.** A dismiss-anywhere barrier under the 480-wide overlay (`shell.dart` Stack). The house knows the trap: «a full-screen catcher swallows the next press» — the press that closes the overlay must not also land on what is under it, and must not swallow the next press on the gear or on «Unlock». Measure both.

## Measurement

`scripts/gates.sh` green in your tree from a plain `flutter build linux --debug` (G7-build repairs the library itself). Widget tests, one per rule: 71 end-the-chat empties three parts and the session's kept list is unchanged; 72 a question with no document leaves alone and opens the chat on its answer; 72-أ a pasted letter in the one box is protected and exports; 73 remove then «+» replaces, the kept copy stays; 74 the overlay's first room; 75 a press outside closes it and the next press lands. Report the branch head, the three numbers, and whatever the paper got wrong about the tree.

## Not this round

Nothing else: no Windows, no German, no site. The debts of 090 stay debts.
