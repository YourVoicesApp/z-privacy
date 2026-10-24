# 110 — The question before is enough: a later question carries one exchange, not the session

**Source:** the owner, 24 October 2026, before publishing: «نوقف إرسال الجلسة أو سياق الجلسة… فقط السؤال السابق مع الإجابة بدون الوثيقة… يكفي لأن الإجابة تُبنى بالتتابع. نعم صديقي فقط السؤال السابق، أجده ممتاز». Builder: **ed**. Branch off `c0326af` (or off your 109 branch if that is simpler, said in the report). You own `docs/CLAIMS.md` this round. This **amends rule 67** (17 Oct) on what a later question carries. Say so where rule 67 is written, with both dates.

## Why

Today every later question carries **every** earlier turn of the chat (C-13's limit line: «a long chat sends more, not less»). So what one chat sends grows with the square of its length. The tenth question carries nine exchanges, and the whole chat sends about forty-five exchanges' worth where ten were asked. The person pays a provider for every word of it. The owner's point is that an answer is built in sequence, so the exchange just before is the context that matters.

## The ruling

- A later question carries **the one exchange before it**: the previous question and its answer, in the protected form they left in. Nothing older.
- **Never the document.** The document is sent once, with the question that first carried it, as today. Check what `Turn.question` holds for that first turn. If the document rides inside it, the carried previous question is the request part alone. Measure it and name it.
- Every older turn stays stored in the sealed session file exactly as now. Nothing is deleted. It is simply not sent.

## The one builder

G46 holds the history to one function, and point 3 of that gate is a law: «what leaves on the clipboard is what the model was shown». Keep the single builder. **The default is that the copied-out chat follows the same rule**, since it is the same text going to a model by another door. If you measure a reason the copy must differ, stop and report it. Do not split the builder on your own.

## Pins

- **Red first:** three questions in one chat (fake provider, test clock). The third question's payload holds the second exchange and **not** the first. Red on `c0326af`, green after.
- No document in a follow-up, as `the_chat_remembers.rs` already measures. It must stay green.
- A first question still carries its document. A chat with no document (`a_session_is_born_at_the_first_question.rs`) still works.
- The copied chat equals what the model was shown (G46 point 3 stays green).
- Older turns are still in the session file after the third question, read back after a lock (`the_lock_gives_the_session_back.rs` stays green).

## Claims

C-13's limit line becomes the new truth: a later question carries only the exchange before it, protected, and never the document, so a long chat no longer sends more with every question. Its proof names the new pin. Paper 108 §6 (e2) writes the site sentence from your line, so send the lead the final C-13 wording as soon as it is fixed.

## Measurement

`bash scripts/gates.sh` green with rust/dart counts, the red-first pin named, and a short answer on what `Turn.question` holds for a document-carrying first turn. The lead merges and measures.
