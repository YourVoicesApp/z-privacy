# 079 · z-pdf: the document that knows its way back

**The owner, 13 Oct 2026, from work — the ruling that opens the circle:**
a hard line between *pdf* and *z-pdf*. Every document the app exports MUST
carry the z-pdf mark — trusted, named, unmistakable to its owner as THE
protected copy, never confused with an ordinary file. And the app gains the
door it never had (measured 13 Oct: zero `is_token` in the import path,
restore lives on the answer path only): **opening a protected document and
translating it back.**

The circle's order in the queue: this circle now, then back to the
selection circle (076, one click takes one word).

## The mark — pdf vs z-pdf

1. Every exported protected PDF carries the mark TWICE, for two readers:
   **a visible badge for the human** (beside the existing stamp line: the
   document says plainly it is a Z-protected copy) and **a machine-readable
   marker for the app** (so detection never depends on a filename). Design
   seat shapes the badge; core seat owns the marker's grammar and its guard.
2. The mark is a CLAIM, not the proof: detection of a returning document
   rests on the tokens themselves (`is_token` — the four-char-tail promise
   from 046/U was written for this day), so **a third party's own letter
   carrying one of our tokens opens the door too** (the owner's lawyer
   example: six tokens went out in our export; the lawyer's own office
   paper returns carrying ONE — and one token is enough for itself).

## The door

3. **Explicit**: the + menu on the first screen gains «z-pdf» — the mode is
   RESTORE, never protection.
4. **Automatic**: any ordinarily-opened file in which our tokens are found
   raises the banner «هذا ملفٌّ محميٌّ من Z — أتريد ترجمته؟» — the person
   who forgot the explicit door is not lost.
5. **Forbidden, absolutely**: a returning document is never re-protected
   and never re-scanned as fresh content — a token is not tokenized over
   (no onion layers). Guarded, not hoped.

## The translation law — the conversation's own law

6. The token's namespace names its session; the session is matched against
   the vault (deterministic naming from the session key — measured today:
   names return for ever). The allowed set = the union of that session's
   turns' allowed names.
7. A resolvable token translates in place; everything else in the document
   stays exactly as it came. An unresolvable token is NAMED in the
   unresolved list, one by one — never silently dropped. (How many resolve
   is the owner's pending semantic ruling on Conversation-scope values —
   the door itself is independent of that ruling; Always/Profile values
   return from the vault today, measured 3→2→the-one-that-was-kept.)
8. **A locked vault is a standing door**: no translation before the
   passphrase. On a stranger's machine the z-pdf is worth nothing — the key
   to its meaning lives in ONE place: its owner's vault. Never in the file,
   never in a sidecar, never on a server.

## Seats and order

Core (programmer, after the sealed-name pillar): the marker grammar +
`is_token` detection at import + session matching + restore-from-document
API, with reopen guards and the no-reprotect guard. Glass (design seat,
when it reopens): the + menu entry, the banner, the badge, the restore
screen reusing the answer path's pieces (`Piece` law as-is). The lead
measures, merges, and holds the Divergence Ledger — this circle touches
scanner/restore, so every landed commit here gets a ledger entry for the
library's V1-G0.
