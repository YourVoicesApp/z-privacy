# 038-B · Swedish is a product, not a proof

**Status: WAITING — after Phase 4, second of the three measured debts (the owner's order, 5 Oct night).** · lead → the builder the owner names · branch `feat/swedish-identifiers` from `main`.

## Measured (`08b04aa`, `docs/THE_NUMBERS.md` §3)

The `sv` pack was Phase 3's proof that a language is data (82 lines, no core change). As a Swedish product it is not there: on our invented letter 4 of 7 people, and no BIC, bankgiro, plate, VAT number or address; on the owner's eleven readable company papers **0 persons**, the company's org.nr unrecognised 36 times, and 26 false phone *suggestions* on amounts and form fields. The personnummer and org.nr in the letter are caught only because a label stands before them, and then as `TaxId`.

## What to build — the owner's five, in order

1. **personnummer** `YYMMDD-NNNN` / `YYYYMMDDNNNN` (with the `+` for the over-hundreds, the Luhn check digit, and a date that exists): a kind of its own (`Kind::IdCard` or a new `PersonalNumber`, measured against what the screen says), **auto**, label or no label.
2. **organisationsnummer** `NNNNNN-NNNN` (Luhn; the third digit ≥ 2 tells it from a personnummer): its own kind; whether it is protected by itself is the owner's call — it is public at Bolagsverket — so build it as `Suggest` and let him rule.
3. **bankgiro / plusgiro** `NNNN-NNNN`, `NNN-NNNN`, `NNNNNN-N`: `Kind::Account`, auto with a label, suggest without.
4. **roles**: `ordförande`, `justerare`, `protokollförare`, `VD`, `styrelseledamot`, `suppleant`, `revisor`, `firmatecknare` make the following capitalised pair a Person candidate (the minutes use them seven times and produced nothing).
5. **addresses**: `Gatan NN, NNN NN Ort` — the Swedish postcode shape is three-space-two.

And the measured false suggestions: the phone rule stops at a decimal point inside the digits (`999 99.999` is never a phone), and `9999-999 999` is not one either.

## Done means

SV-1 at DE-1's level (7/7 people, the identifiers found); counts on the owner's papers (persons found, org.nr recognised, false suggestions) re-measured and written into §3.2 as before/after; the German rows untouched to the digit.
