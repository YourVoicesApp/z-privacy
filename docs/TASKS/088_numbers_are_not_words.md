# 088 · Numbers are not words

**Opened by 085 ruling 2, the owner, 14 Oct 2026:** «ما ينطبق على الكلمات لا ينطبق على الأرقام، لأنه في السويد مثلاً نظام الموبايل يُكتب بعدة طرق — نعود إليها عندما نضع قوانين الأرقام.» This is that paper.

## Measured, 14 Oct, on the lead line `b5778d1`

Fourteen short German letters, one number in each, invented or public test values only (a Luhn-valid test personnummer, the Visa test card, Faruk AB's public org number, a published example IBAN), run through `check_document` — the product's own scan, **in a German session**, which is what that instrument opens.

| the number, as written | with a label | protected | waiting |
|---|---|---|---|
| `070-123 45 67` | Telefon: | 1 | 0 |
| `0701234567` | Telefon: | 1 | 0 |
| `+46 70 123 45 67` | Telefon: | 1 | 0 |
| `070 123 45 67` | Telefon: | 1 | 0 |
| `+46701234567` | Telefon: | 1 | 0 |
| `+49 30 1234567` | Telefon: | 1 | 0 |
| `030/1234567` | Telefon: | 1 | 0 |
| `030 123 45 67` | Telefon: | 1 | 0 |
| `811218-9876` (personnummer) | Personnummer: | 1 | 0 |
| `SE45 5000 0000 0583 9825 7466` (IBAN) | IBAN: | 1 | 0 |
| `#4711` | Kundennummer: | 1 | 0 |
| `559473-3494` (org. number) | Org.nr: | **0** | **0** |
| **`4111 1111 1111 1111` (card)** | Karte: | **0** | **0** |
| `070-123 45 67` in a sentence | — none — | 0 | **1** |

What the numbers say:

- **All eight phone forms are caught when a label stands before them** — the Swedish ways the owner named, and the German ones. The phone rule already reads a number across its spaces, dashes, slash and `+`.
- **A phone number with no label waits** for the person instead of being protected. That is the conservative choice, and under 083a it now holds the exits until it is answered.
- **The org number is not caught in a German session.** It is in the Swedish set (`z_core/src/scanner/sets/sv.rs:26`, `org.nr` → TaxId, Auto), so a Swedish session catches it. Per-language by design; recorded so nobody calls it a defect.
- **A payment card number is caught nowhere.** There is no card rule in the general rules (Luhn is used only for the Swedish national identity, `general_rules.rs:337-433`), and **there is no card kind in the contract**: the nineteen canonical words (C5) hold no `CARD`. A card number written in a letter leaves Z in the clear. With the third stage of the road — the till — this stops being a gap and becomes the first thing a merchant will test.

**Limit of the measure, said plainly:** `check_document` reports counts, not spans. «1 protected» says one value was taken, not that the whole number and nothing more was taken. The span — whether the token covers `+46 70 123 45 67` exactly, and whether anything after it is swallowed (the IBAN defect in the ledger) — is measured by a builder's guard, not by this table.

## The rules the lead proposes, for the owner's word

**1 · A number is one value across the separators people write.** A run of digits, with the separators people put between groups — space, `-`, `/`, `.`, a leading `+`, parentheses round an area code — is **one** value. This is 085 ruling 2 made into a rule: the phone rule already behaves so; the rule makes it the law for every number, found by the scanner or selected by hand.

**2 · One click on any part of a number takes the whole number.** Today a click takes a space-bounded word (076), so a click on `45` in `070-123 45 67` takes `45`. Under rule 1 it takes the number. *For the owner's word — it changes 076 for numbers only.*

**3 · A mark before a number leaves it, like any edge mark.** `#4711` is protected as `4711`, and the `#` stays in front of the token. It is the debt 085's edge-set merge named and pinned: today the `#` stays only when the scanner did not find the value. One rule closes it: the mark is notation, not the number. *The `#` before a token reveals only that a reference stood there.*

**4 · Card numbers become a rule and a kind.** A run of 13–19 digits in the groups cards are written in, passing Luhn, is protected — and the contract gains a canonical word **`CARD`**. A new kind word is a contract change (C5): it goes into contract v0.1, sealed by the lead with a measurement on both sides, as the change rule demands. Until then a card has no honest kind to wear — `ACCOUNT` would be a lie.

**5 · Addresses — the owner's open question, carried here from 085.** When the app finds «Hotellgatan 3» on its own:
- **(a)** the street is words, protected by the word rules, and `3` by the number rules — two tokens; or
- **(b)** the address is one value, a place, and one token.

The lead's reading: **(b).** An address is read as a place, not as a word and a number; and a house number alone, protected apart from its street, tells a reader nothing worth hiding while the street beside it in the clear tells everything. *The owner decides.*

**6 · Showing the last digits — not now.** Acrobat can leave the last digits of a card visible (the comparison, `docs/reference/Z_SEARCH.md`). In Z a token replaces the whole value and returns the whole value; a token that shows part of what it hides is a second kind of token. The lead's reading: not in this version. *The owner decides.*

## Guards (pinned red first)

- **One value across the separators:** each of the eight phone forms is one token covering exactly the number — the span compared, not the count.
- **A click takes the number:** a click on any digit group of `070-123 45 67` takes all of it (after the owner's word on rule 2).
- **The mark leaves:** `#4711` protected as `4711`, whether the scanner found it or the hand selected it.
- **The card:** `4111 1111 1111 1111` protected as `CARD`; a 16-digit run that fails Luhn is not.
- **Nothing swallowed:** after every number, the next word stands in the clear.
