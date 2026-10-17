# 090 — The app is a chat: one screen, three parts, and a conversation that continues

**Rules:** 63–70 and 61-أ in `~/محرر النصوص.md` (owner, 17 October, «نعم»). Read them first; they are the law, this paper is the build.
**Base:** lead line `lead/the-day-of-the-attack` at `84832a0` (514 · 0 · 0, rust 755, dart 388).
**Builders:** ed — core (part A). e2 — glass (part B). Nobody pushes.

## What the owner saw

He sent «إنجليزي 1» to Grok with a request under it. The answer came back correct, «Peter» left as a token and came home a name. Then he wanted to ask a second question on the same letter and found two things:

1. There is no place to write it. The third region shows `AnswerPanel` («The answer · One answer in this session») and nothing more; the request box under the Original column says «Each question is asked on its own: the model does not see the earlier ones.» That sentence is true: `askModelProtected` sends `history: const []` (`session_state.dart:988`), and nothing anywhere fills `Context.history` (`gateway.rs:72`).
2. The answer opened on «Restored», readable text first, codes behind a toggle.

His ruling turns this around and names the principle: **inside the app there are no documents. The app is a chat.** A document lives at two doors only, the way in (what the user brings) and the way out (z-pdf). The moment text is pulled in it is chat; the moment a pdf is asked for, the chat is a document.

## The product after this round

One screen, three parts, always the same screen:

```
┌─ top bar: [+ Add a document] [write or paste…]  PACK  VAULT  AI  ⧉  ⚙ ─────────────┐
│ ORIGINAL — LOCAL ONLY   │ SAFE — AI WILL RECEIVE      │ THE CHAT                     │
│ (as today)              │ document                    │ you (as it left)  ▸ coded    │
│                         │ --- Request ---             │ Grok (as written) ▸ coded    │
│ request box (as today)  │ request                     │        [Show the text] → bubble│
│                         │ [Choose who answers]        │ you  ▸ coded                 │
│                         │                             │ Grok ▸ coded  [Show the text]│
│                         │                             │ ┌──────────────────┐ [➤ Grok]│
│                         │                             │ └──────────────────┘         │
│                         │                             │ [Copy the chat] [Add an answer] [End the chat] │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

- **The first screen (`HomeScreen`) is gone.** The shell shows the workspace always, empty or not. «Add a document» and the writing field move to the top of the workspace. z-pdf moves to Settings. Sessions already live in Settings → Sessions (`home.dart:6` says Home had none on purpose), so nothing moves there. `FirstRunScreen` and `VaultScreen` stay as they are.
- **The middle column is unchanged** (rule 64): document, `--- Request ---` (built in `payload.rs:190`), request. The owner said «64 ظهرت في تجربة اليوم».
- **The third part is the chat** (rule 65). It replaces `AnswerPanel`. It opens the moment the first answer arrives and stays open until the chat ends. Each turn shows the question as it left and the answer as the model wrote it — **coded** (rule 66) — and every answer carries one button «Show the text» that opens the restored text in a bubble. The bubble keeps today's «Copy Restored» (with its confirmation and clipboard-emptying, 081) and nothing else.
- **A compose box** at the bottom of the chat with a send arrow and the answerer's name beside it («➤ Grok»). The first question goes through «Choose who answers» as today; the chosen door is the chat's door from then on. Every later question is typed in the compose box and sent with the arrow: protected the same way the first was, and **carrying the previous turns protected** (rule 67). The user never re-adds the document: the first turn, which holds the protected document, travels as history. The model has no memory of its own, so history is the only way the chat continues; what travels in it is only what already left once.
- **«Add an answer»** pastes an answer brought from outside (the user copied the chat, asked a model on the web, came back). It is ingested exactly like an answer that came through a key: stored as written, shown coded, «Show the text» restores it.
- **«Copy the chat»** copies the whole chat as it left — protected text only — through a core door that returns a handle, never Dart-assembled text.
- **«End the chat»** ends it explicitly (rule 68). Closing the app ends it too. Ended turns stay readable in Settings → Sessions under the document (rule 69: «sent · answered»); a new question after the end starts a new chat with empty history.
- **Deleted:** `screens/home.dart`, `screens/answer.dart`, `widgets/the_journey.dart` (its three stages become the «sent · answered» line in the Sessions room), the sentence «Each question is asked on its own…» (`workspace.dart:2341`), and the «Documents» back arrow (`workspace.dart:595`), because there is no screen to go back to. Deleted means deleted (rule 35), not hidden.

## Part A — core (ed), branch `fix/the-chat-remembers` from `84832a0`

Four doors, in the order e2 will need them. Report the commit that fixes the contract first, so e2 can branch on it.

**A1. History comes from the stored turns, never from Dart.**
`ask_model(handle, provider, model, workspace, history)` loses its `history` parameter. Core fills `Context.history` itself from the open session's turns of the *current chat* (A3), in the protected form they are stored in (`ops/mod.rs:2746`: question as `question_safe`, answer as written). One line per turn side, the way `instructions()` already flattens them (`gateway.rs:151`). The first turn's question line is the payload **as it left** (document + `--- Request ---` + request), because that is what the model saw. Measure: a test that asks twice in one session and reads the second request's `Context.history` from the fake provider: it holds the first payload as it left and the first answer as written, nothing restored, nothing more.

**A2. A follow-up question is a question-only payload.**
Today the payload is always document + request (`payload.rs:190`). A second question in the same chat carries the new question alone. Add a scope to `payload_to_take_out` (or a sibling that returns a `PayloadHandle`) for «the question only», produced by the existing `set_question` protection. No text crosses the contract: Dart calls `set_question(text)` as today, then asks for the handle, then `ask_model(handle, …)`. G2b must stay green without an exception.

**A3. A chat has a beginning and an end.**
A session gets a chat counter (an epoch). `end_the_chat(session)` increments it; a fresh process start counts as an end (rule 68: closing the app ends the chat), so the epoch is not persisted as «open» — simplest is: persist the counter, and bump it on session open. `conversation_turns` keeps returning every turn (the Sessions room shows them all); each `TurnRow` names its chat number so the glass can draw the boundary. History (A1) takes only the current epoch's turns.

**A4. The chat leaves through a handle.**
`chat_to_take_out(session) -> PayloadHandle` (name as you see fit, under the `(send|ask)*`/handle discipline): every turn of the current chat, question as it left and answer as written, joined with a plain divider. It is the fourth door in the census at `ops/conversation.rs:575`; G36 names four doors after this. «Add an answer» needs no new door: `pasteAnswer` (`session_state.dart:1139`) already ingests via `ingest_answer`; confirm it records the turn with `TurnVia` for a pasted answer and the current epoch.

**A5. Gates.** G2b holds. G36 census = four. New: a gate that reads `ops/mod.rs` and refuses any `ask_model` body that does not call the history builder; and the A1 test is a named check. `cargo test`, `clippy`, `scripts/gates.sh` green in your tree before you report, with the three numbers.

## Part B — glass (e2), branch `fix/one-screen-three-parts` from `84832a0`, rebase onto ed's contract commit when he names it

**B1. One screen.** `shell.dart:610` `_body()`: the `HomeScreen` branch goes; `WorkspaceScreen` is shown whenever not first-run and not vault. `_bench == null` becomes the empty workspace: top bar with «Add a document» (today's `home.dart:573` entry → `_begin`) and the writing field («Write or paste your text here…» `home.dart:539`; «Open and scan» → `_begin` with typed text), columns empty beneath with one quiet sentence each. `onHome` and the «Documents» arrow are deleted; Alt+Left (`workspace.dart:333`) goes with it. Settings keeps its overlay.

**B2. z-pdf in Settings.** The «z-pdf — read a protected document back» entry (`home.dart:578` → `shell._readBack`) becomes a row in Settings, in the Vault & security room or its own small room — pick the one that reads simplest, and send the press up through the existing `OpenKept` pattern (`settings.dart:88`). `TheReading` dialog stays as it is.

**B3. The chat panel.** New `widgets/the_chat.dart` replacing `AnswerPanel` in the panel switch (`workspace.dart:448–468`); `OpenPanel.answer` becomes `OpenPanel.chat`. It draws every turn of the current chat from `conversationTurns` (the rows that carry the current chat number), coded: the question as it left, the answer as written. Under every answer: «Show the text» → a bubble with the restored segments (the `TurnRow.answer` segments) and today's «Copy Restored» with its confirmation. Keep the existing `_PanelArrow`. The chat opens when the first answer arrives (where `panel = OpenPanel.answer` is set today: `session_state.dart:992, 1115, 1139, 1206`).

**B4. The compose box.** Bottom of the chat: a text field, a send arrow, the answerer's name beside it (the `ProviderId` chosen in the sheet for the first question, kept on the bench for the chat). Send = `setQuestion(text)` → question-only handle (A2) → `askModel` (A1 signature, no history argument). The first question still goes through «Choose who answers» (`_SafeFooter` → `theWayToTheDoors`); after an answer exists, the sheet is not opened again unless the user presses «Choose who answers» in the middle column to change the door.

**B5. Three buttons** under the chat: «Copy the chat» (A4 handle → `WhatMayLeave` → clipboard, with 081's emptying first), «Add an answer» (today's `pasteAnswer`, moved here), «End the chat» (A3; the panel closes, the columns stay).

**B6. Deletions.** `screens/home.dart`, `screens/answer.dart`, `widgets/the_journey.dart`, the «Each question is asked on its own…» sentence, and «One request at a time — a new question replaces the request, and the answers are kept.» rewritten to one line that is true after this round. The Sessions room (`settings.dart:692`, `_KeptDocument` :1137) shows under each kept document «sent · answered» from its turns (rule 69). Grep for every reader of what you delete before you delete it (a variant answers for every reader).

**B7. Measurement.** `flutter analyze`, `flutter test`, `scripts/gates.sh` green in your tree. A widget test that sends a question, receives a fake answer, sees the chat panel with one coded answer and no restored name on the glass, presses «Show the text» and sees the name in the bubble only. A second test that types a second question and sees two turns. Report the three numbers.

## What this round does not do

No German, no site, no Store. Rule 61 is suspended for this round only (61-أ). When the answer is on the glass in this shape, the owner wants the journey on the site («هذا هو تطبيقنا وهذا إعلاننا لألمانيا», 70-أ) — a later paper.

## Reporting

Each of you reports the branch head, the three numbers, and anything the paper got wrong about the tree. The lead measures in a clean tree, merges by hand, writes `docs/MEASURED_ON_LINUX.txt`, installs. Nobody pushes.
