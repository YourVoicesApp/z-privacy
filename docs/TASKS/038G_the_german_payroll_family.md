# 038-G · The German payroll family: two kinds, one label, the reversed pair, and a column that names its values

**Status: ORDERED** · 6 Oct 2026 · lead → `mono-privacy-88` · branch `feat/german-payroll` from `main` (local `833a5b9` = 041-E + 038-H) · **rule changes, German pack and general rules; measured on the five German goldens and the Swedish control before and after, as 038-H did.**

## Why

The first real user is a payroll accountant in Germany; his documents are «أي معلومة توجد في حسابات العملاء». The invented golden DE-6 (`z_core/tests/fixtures/Lohnabrechnung_Weber.txt`: a payslip + a payroll-ledger extract with four employees in a table) measured on `08b04aa` and unchanged by 038-H:

| present | found | note |
|---|---|---|
| 5 people (one twice) | 1 auto («Lindemann, Katharina» after `Name:`) · 1 suggested · 2 candidates → 1 after 038-H | the three table rows «Reinhardt, Tobias» etc. are not found; **knowing more names found fewer**, because the reversed pair is a discovery rule for unknown surnames |
| 4 Steuer-ID (11 digits, grouped `86 095 742 719`) | **0** | their fragments became **2 phone suggestions** |
| 4 Sozialversicherungsnummer (`65 140388 L 512`) | **0** | no kind exists |
| 5 birth dates | 1 auto (after the label) | the 4 in the table column became **3 phone suggestions** |
| 5 Personal-Nr. | 0 | label unknown |
| IBAN · BIC · e-mail · phone · 2 addresses | found | |

## What to build (each a commit, measured before the next)

1. **`Kind::SocialInsuranceNo`** (German *Sozialversicherungsnummer / Rentenversicherungsnummer*): `NN DDMMYY L NNN` with or without spaces — two digits (area), a birth date DDMMYY that must exist, one capital letter (the first letter of the birth name), three digits (serial + check); the check digit rule is published (weights 2,1,2,5,7,1,2,1,2,1,2,1 over the digits with the letter as two digits of its alphabet position) — implement it and test it on invented numbers that pass and fail. **Auto**, label or no label, in any pack (it is a general rule; the shape is German but nothing else matches it).
2. **`Kind::TaxId` learns the 11-digit Steuerliche Identifikationsnummer** (grouped `NN NNN NNN NNN` or plain): its check-digit rule (the ISO 7064 Mod 11,10 variant the BZSt documents) and the structure rule (one digit appears twice or thrice, one digit never, first digit not 0). **Auto** when the check passes; the existing `Steuernummer` label rule stays as it is.
3. **The phone rule stops** where a date or a grouped ID stands: `DD.MM.YYYY` is never a phone; a run that the Steuer-ID or SV rules claim is theirs first (order of rules in the scanner: identifiers before phone, or the phone rule yields to a longer claim on the same span). DE-6's 5 phone suggestions → 0; the real phone stays auto.
4. **Label «Personal-Nr.» / «Personalnummer» / «Pers.-Nr.»** → `Kind::CustomerNo` (or a new `EmployeeNo` if the screen's wording needs it — measure which reads better in the explain card) **auto**, pack data not code, like Kundennummer today.
5. **The reversed pair, in both directions:** «Family, Given» where **given is known** (tier 1 or taught) → Person **suggest** whatever the family word is (Phase 2's discovery rule, now first-class); where **both** are known → Person suggest with the higher confidence line; where the pair follows a label (`Name:`) → auto as today. The three table rows of DE-6 become suggestions. Red first on DE-6.
6. **A column names its values:** in a text that came from a table (lines with the same number of runs separated by two or more spaces or tabs, under a header line), a header cell that is a known label (Geburtsdatum · SV-Nummer · Steuer-ID · Personal-Nr. · Name · IBAN …) applies that label's kind to the cells beneath it. Smallest honest version: header words from the pack's label list, columns by character position, measured on DE-6's ledger (4 birth dates → auto, 4 SV → auto by rule 1 anyway, 4 Steuer-ID → auto by rule 2 anyway, 4 Personal-Nr. → auto). Say in the report what else this rule touched on DE-3/DE-4 (tables of codes!) — it must touch nothing there.

## Measure, before and after each commit

The 038-H table (auto · suggested · persons found/present · candidates · false protections · false suggestions) on DE-1, DE-2, DE-3, DE-4, DE-6 and SV-1 as control; plus DE-6 by kind: SV-Nummer found/4, Steuer-ID found/4, birth dates found/5, Personal-Nr. found/5, false phones.

**Acceptance (the owner's family):** DE-6 — people ≥ 4/5 found (auto or suggested), SV 4/4 auto, Steuer-ID 4/4 auto, birth dates 5/5, Personal-Nr. 5/5, **false phones 0**; DE-3 and DE-4 keep 0 false protections and gain no more than a handful of suggestions; DE-1/DE-2/SV-1 unchanged or better, every change named.

## Done means

- Tests for each rule with invented numbers that pass and fail their checks; the goldens updated only where a number improved; `docs/THE_NUMBERS.md` §2 gets DE-6 before/after; counts of tests, gates, clippy before/after.
- Nothing printed of any document; the invented DE-6 is the only payroll text in the repository.

## Not in this task

- Amounts (salaries) — the owner's hand protects them; a «money after a payroll label» kind is his call later.
- Krankenkasse names as companies (pack data, later).
- The Swedish identifiers (038-B) — the same shape of work, after German is excellent.
