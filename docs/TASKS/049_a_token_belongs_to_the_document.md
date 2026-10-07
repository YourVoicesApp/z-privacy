# 049 · A token belongs to the document, not to the conversation

**Status: BUILT · 046/U items 1 and 2** · 7 Oct 2026 · programmer, at the lead's order.

The owner: «ما نحتاجه فعلاً هو إعادة فكّ تشفير الوثيقة في حال ابتعدتُ لعدة أيام وكان هناك وثائق أخرى في هذه المدة.»

He goes away for some days, works on other documents, comes back to the same file, and pastes the answer the model gave him. Until this, that did not work — **and it failed in silence.**

---

## 1 · What was measured, before anything was built

The lead's measurement, on the same document in the same client, the value protected at `Scope::Profile` so the vault keeps it:

```text
day one      __Z_5CDD_PERSON_BEBC__  ·  __Z_5CDD_IBAN_5B32__
             the answer restores                                   ✓

days later   __Z_A6F5_PERSON_8E13__  ·  __Z_A6F5_IBAN_C84F__      ← different names
             the old answer restores to
                 «I checked __Z_5CDD_IBAN_5B32__: the balance is 42 500.»
             and no error is raised                                ✗
```

Two faults, and the second is the worse one. The name was minted **per session**, so even a value the vault keeps got a new one next time: the vault stores the value, never the token's name. And `restore` accepted an answer full of names it could not resolve and handed each one back as **text** — one line reading «not ours: it stays word for word». A person reads `__Z_5CDD_IBAN_5B32__` in the middle of a sentence about their own account and cannot tell whether the app failed or the model wrote that.

## 2 · Item 1 first, because it stops a lie today

`Piece` — `Words` · `Restored` · `Unresolved` — three states and not two bools, because two bools have a fourth corner that means nothing. An unresolved token **stays word for word**, because the model really did write it and dropping it would be a second lie; what changed is that it is a piece of its own, drawn struck through in amber, and `AnswerSnapshot.unknown_tokens` names every one of them from the **same walk** that builds the pieces.

On screen, **above** the answer: «This answer carries 2 tokens this conversation does not know — they were made in another conversation», the names under it, and the honest rule beside them. Above, because a warning under the text is read after the damage.

`is_token` decides by **shape alone**, and strictly: a loose test turns «tokens look like `__Z_` and end in `__`» into two warnings about a perfectly good answer, and a guard that cries wolf is switched off within a week.

## 3 · Item 2 · the name comes from the value and the document

**The argument that chose the shape:** stability across days and linkability across requests are the same property. A name derived from the value and the client alone would be the same name in every request that mentions it — and a provider holding a year of an accountant's requests could read off which documents share a hidden person. That is the *shape of his client book*, assembled out of requests we sent ourselves. Not a name, but exactly the class of thing this product exists to withhold.

So the name is a keyed function of **(the client, the document's own content, the value)**:

| | |
|---|---|
| key | `Purpose::TokenName` off the vault master key — keyed BLAKE2b, already in the tree |
| namespace | `MAC(key, "namespace", profile ‖ document)`, 4 hex — which document, in which client |
| tail | `MAC(key, "value", nfc(value))`, **8** hex |
| stored | **nothing** |

Each input is length-prefixed, because a separator alone lets a profile id ending in that separator forge another profile's names.

**The tail is eight and not four.** Four is 65 536 names, and fifty values in one document collide about twice in a hundred — which for a *derived* name is not a retry but a lost promise, since any retry would depend on the order the values happened to be protected in and that order is not the same next time. Eight is 4.3 billion: fifty values collide about once in a million documents, and that one falls back to a random name, where item 1 reports it rather than restoring the wrong thing.

What falls out, each one a test:

- the same file, the same client, the same value → **the same token for ever**, with nothing stored;
- a file **moved or renamed** still restores, because the path was never part of it;
- **the content is the text the reader extracted**, not the file's bytes — the better of the two, since a PDF re-saved with new metadata or the same letter exported twice by Word reads as the same document and keeps its names. It is also the only one available: the core holds the text and drops the bytes;
- an **edited** file gives new names — honest, because it is a different document, and item 1 makes that case say so instead of passing the old tokens through as prose. **Item 1 is what lets item 2 be strict;**
- two clients never share a name for the same spelling — a property the per-session prefix was providing by accident, and losing it while making names stable would have been a real leak between them;
- a **locked vault** has no key, so the names are random again. Said out loud rather than discovered: restoring across days works for what the vault keeps, and with the vault shut it keeps nothing.

## 4 · The cost, named because a later round will meet it

**When one conversation spans two documents — «compare this payroll with last month's» — the same person carries two different names and a model cannot tell they are one.**

Nothing is lost today: `Context.workspace` goes out empty, so no request ever carries two documents. But whoever builds multi-document context has to decide this deliberately rather than discover it, and the decision is the same trade-off as above seen from the other side: linking two documents for the model's benefit is linking them for the provider's.

The sentence is also written next to the derivation in `Naming::derive`, where it cannot be missed by someone changing it.

## 5 · What item 1 caught in item 2, inside a minute

When the derived tail became eight characters, `is_token` still demanded exactly four. Every derived token it met was therefore «not a token» and went straight back into the plain text — **the silent pass-through item 1 exists to kill, returned by the hand that was supposed to be building on it.**

`an_answer_from_another_conversation_is_reported_and_not_passed_through` went red immediately. The range is now four to eight, and four has to be accepted for ever: an answer written before item 2 carries four-character tails, and that answer is exactly the one a person pastes days later.

## 6 · The recorded fault, and its correction

`today_the_same_value_gets_a_new_token_the_next_day` was written to assert `assert_ne!` — the fault itself, pinned on purpose, because a property nobody wrote down is a property nobody can prove changed. Item 2 turned that line red, which is the only way a recorded fault earns its place. It now reads `the_same_value_now_keeps_its_token_the_next_day`, and both halves of the history stay in the comment above it.

## Not in this paper

- A serial, a seal, a PIN: **044**. The record they need is 046/S, parked.
- The documents room, print, and e-mail: **046/S** and **046/T**, both held by the lead.
- Multi-document context, for the reason in §4.
