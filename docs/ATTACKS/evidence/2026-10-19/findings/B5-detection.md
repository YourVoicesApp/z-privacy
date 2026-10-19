# B5 — detection quality on 2b4fad9

**Commit:** `2b4fad93cc26b282e6fa9773ad2275544dcc7ee8`  
**Stamp:** `z_core 0.1.0 · 2026-10-19 · 2b4fad9`  
**Probe:** `harnesses/probes` bins `b5` · `b5_escapes`  
**Logs:** `logs/b567/b5-scan.txt` · `logs/b567/b5-escapes.txt`  
**CARGO_TARGET_DIR:** `/home/monopeaks/z-attack-2b4fad9-evidence/target-b567`  
**Data:** `scratch/b567/tmp-data-b5` and `tmp-data-escapes` (not the real vault)

Not a crash: a value that remains after every suggestion is answered will leave if sent. The contract does not promise anonymity from context.

Golden five: `/home/monopeaks/ZPrivacy-lib/parity-corpus/fixtures` (read-only, frozen at `d882c5f`). Experiment texts: `fixtures/docs/experiment/`. API of `z_core` was unchanged; only data-dir paths and the two خ5 expected strings (`Postfach 4410`, `Sparkasse Leipzig`) were added to the harness.

Counts below match `84832a0` to the digit on every document that was compared the same way.

---

## Golden five (after answering every suggestion)

| document | pack | auto | asked | tokens | hidden | missed |
|---|---|---:|---:|---:|---:|---:|
| Vertrag_Nordstern.txt | de | 11 | 1 | 14 | 10 | 0 |
| Brief_Weber.txt | de | 29 | 8 | 38 | 32 | 0 |
| Lohnabrechnung_Weber.txt | de | 34 | 5 | 39 | 32 | 1 |
| Brev_Lindqvist.txt | sv | 14 | 6 | 23 | 19 | 12 |
| Risala_Alharbi.txt | de | 5 | 2 | 7 | 7 | 14 |
| Risala_Alharbi.txt | ar | 5 | 2 | 7 | 4 | 2 |

Risala under `de` and `ar` still 5 auto · 2 waiting.

**Lohnabrechnung miss:** `Lindenstraße 8`.  
**Brev_Lindqvist misses:** Tobias Reinholdsson, Sofia Brandt, Yusuf Demir, Bankgiro `5555-5555`, plate `ABC 123`, three addresses, Moms `SE556123456701`.  
**Risala misses:** all seven Arabic names, customer no, CR, id `1012345678`, two tax ids, DOB, plate.

Vertrag false Auto: signature still takes `Abteilung` and `Vertragswesen` as Person.

---

## Experiment texts (after answering every suggestion)

| document | pack | auto | asked | hidden | missed | still in payload |
|---|---|---:|---:|---:|---:|---|
| ألماني 1 | de | 12 | 5 | 12 | 2 | Postfach 4410; Sparkasse Leipzig |
| ألماني 2 | de | 15 | 3 | 11 | 2 | Versichertennummer A123456780; Rosenweg 3 |
| ألماني 3 | de | 11 | 1 | 6 | 0 | — |
| إنجليزي 1 | en | 7 | 3 | 9 | 4 | Daniel Okafor; HVS-55120; 22 Clifton Road |
| إنجليزي 2 | en | 9 | 1 | 8 | 6 | James; 12/04/1985; NGE-20417; QQ 12 34 56 C; 4111 1111 1111 1111; 7 Elm Terrace |
| سويدي 1 | sv | 6 | 6 | 11 | 2 | bankgiro 5050-1055; Storgatan 12 |
| سويدي 2 | sv | 5 | 11 | 12 | 1 | Kungsgatan 44 |
| عربي 1 | de | 2 | 1 | 3 | 4 | all names; الشركة |
| عربي 2 | de | 1 | 1 | 2 | 5 | all names; 1023456789 |

ألماني 1: the previous table listed 12 hidden / 0 missed because Postfach and Sparkasse were not in the expected list. They are now, and both **MISS**. IBAN/BIC/names/email still hide. Address ASK was `04179 Leipzig` and `Gartenstraße 17`, not the PO box. `Bankverbindung: Sparkasse Leipzig` is not a finding.

إنجليزي 1: ASK still `Hale Design Ltd`, not `Thornton & Hale Design Ltd`. Daniel Okafor never appears.

إنجليزي 2: the only ASK is the company. After Protect, payload still contains `James`, DOB, employee no, NI, PAN, home address. `Mr Whitaker` Auto on the surname only. `James Whitaker` as a pair is not taken; `Whitaker` is.

---

## Escape paths (`b5_escapes`, pack only)

| path | result |
|---|---|
| `Thomas\nMüller` | ASK both words |
| `Yn-\nnerman` untaught | nothing |
| `Sven\nNelander` untaught | nothing |
| ZWSP in Markus after Herr | **nothing** |
| ZWJ Markus+Weber | nothing |
| ZWNJ Thomas+Müller | nothing |
| NFD Müller after Herr | Thomas Auto; **Müller missed** |
| NFC Müller after Herr | both Auto |
| ligature `ﬁscher` | Thomas Auto; ﬁscher missed |
| fullwidth Ｔｈｏｍａｓ after Herr | Auto |
| ALL CAPS pair | ASK |
| ALL CAPS after Herr | Auto |
| `CRISTINA LEIFLAND` untaught sv | nothing |
| `Müller.` | ASK (bare strips period) |
| `Müller,person` no space | nothing |
| `Müller/Vertrieb` | ASK `Müller/Vertrieb` |
| `Müller—Vertrieb` | ASK whole token |
| `(Thomas Müller)` | ASK |
| `Ms.Thornton` glued | nothing (`Ms Thornton` Auto) |
| PAN 4111… / 5500… | **nothing** |
| `National Insurance number: QQ 12 34 56 C` | **nothing** (`en-34` is Auto / `Validator::Number`) |
| `Date of birth: 12/04/1985` | nothing |
| `Employee number: NGE-20417` | nothing |
| `bankgiro 5050-1055` | nothing |
| Moms SE556… | nothing |
| Arabic 10-digit id | nothing |
| Saudi mobile 0501234567 under ar | ASK |
| `Yn-\nnerman` after Always teach | AUTO the broken value |
| `LEIFLAND` after teach Leifland | AUTO |

`languages.rs` still comments that general rules cover «card». There is still no card Kind and no Luhn rule. `is_numberish` still requires every character to be a digit or `- / . ( ) +`, so `QQ 12 34 56 C` is dropped after the `en-34` label matches.

---

## Defects (unchanged vs 84832a0)

### B5-1 · خطير — zero-width blinds the salutation
`Sehr geehrter Herr Mar<ZWSP>kus Weber,` → no finding. ZWJ/ZWNJ likewise. `name_shaped` stops at the first non-letter.

### B5-2 · خطير — NFD
NFC Müller after Herr: Auto. NFD (`u` + combining diaeresis): Thomas Auto, Müller missed. Combining mark fails `char::is_alphabetic`.

### B5-3 · خطير — payment card leaves after the person answered
إنجليزي 2 + isolated `Please charge 4111…`. Comment says card. No detector. PAN stays in the payload.

### B5-4 · خطير — NI row exists, validator rejects the value
`en-34` «national insurance number» Auto / `Validator::Number`. `QQ 12 34 56 C` is not numberish. No finding, no question.

### B5-5 · خطير — half a name: James remains, Whitaker is protected
`Mr Whitaker` Auto on the surname. No `Name:` row in en takes the pair. `James` stays three times.

### B5-6 · خطير — English DOB and employee number have no row
`Date of birth: 12/04/1985` · `Employee number: NGE-20417`. German has `Geburtsdatum:` / `Personal-Nr.:`. en does not.

### B5-7 · ملاحظة — shape escapes
Hyphen-wrap, glued punctuation, ligature. Taught vault values still catch the wrap and ALL CAPS.

### B5-8 · ملاحظة — Swedish lexicon narrower than Brev_Lindqvist
Tobias / Sofia / Yusuf, Bankgiro, Moms, plate, addresses.

### B5-9 · ملاحظة — Arabic has no pack (rule 56)
Names, national id, tax, plate: zero findings. IBAN/BIC/email/+phone still run.

### B5-10 · ملاحظة — false Auto and a company cut at &
`Abteilung` · `Vertragswesen` · `Herr Kollege Albrecht` · `Hale Design Ltd`.

### B5-11 · خطير — Postfach / Sparkasse after review (خ5)
ألماني 1, every ASK Protected. Payload still has `Postfach 4410` and `Sparkasse Leipzig`. Not a finding. Address ASK took the street and the postcode city, not the PO box on the letterhead.

---

**Grades here:** مانع 0 · خطير 7 · ملاحظة 4

(B5-11 is the same خ5 as on 84832a0; it is listed here because this run added those two strings to the expected list.)
