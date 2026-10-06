# 038-H · The German name bank, in tiers, each tier measured before it enters

**Status: ORDERED** · 6 Oct 2026 · lead → `mono-privacy-88` · branch `feat/german-name-bank` from `main` (`0121616` local = `f98c5b8` + 041-E) · **the first task since Phase 1 that changes pack data; nothing else in the detection path moves.**

## The owner's words (6 Oct)

«نتابع باللغة الألمانية فقط؛ نريد أن نبني أولاً قاموس أسماء اللغة الألمانية بقدر ممتاز ثم نذهب إلى لغة أخرى. الهدف إثبات أنه في حال كان لدينا فريق يمكننا جعل التطبيق أكثر فاعلية.» And the register rule: «كل قائمة نحصل عليها نجعل لها اسماً ونضع قائمة بالمواقع التي حصلنا منها.» And from Phase 1, still standing: a dictionary hit is a signal, never a verdict; no «capitalised word = person»; the 11-false-to-1-true guard; ordinary-word collisions stay tested.

## What the lead downloaded and measured (6 Oct, `~/work-now/names/de/`, register `~/work-now/names/REGISTER.md`)

| list | years | rows | licence | file shape |
|---|---|---|---|---|
| `berlin/repo/data/<year>/<district>.csv` | 2012–2023 | 154,909 | CC BY 3.0 DE | `vorname,anzahl,geschlecht[,position]` (comma) |
| `bonn/bonn-<year>.csv` | 2017–2024 | 31,324 | CC0 | `anzahl;vorname;geschlecht;position` (2018 is cp1252) |
| `dortmund/dortmund-gesamt-seit-2021.csv` | 2021–2025 | 17,643 | DL-DE-Zero 2.0 | `jahr;stellung;geschlecht;vorname;rang;anzahl;kommune` |
| `koeln/koeln-vornamen-2019-2022.csv` · `koeln-vornamen-2023.csv` | 2019–2023 | 33,782 | DL-DE-Zero 2.0 | `jahr;vorname;anzahl;geschlecht;position` / `anzahl;vorname;geschlecht;position` |

Across the four: **27,459 distinct given-name spellings** — 3,400 in all four cities, 2,518 in three, 4,025 in two, 17,516 in one only. Every given name our goldens missed stands in three or four cities (Tobias · Amira · Yusuf · Markus · Katharina · Sophie · Lars · Sara · Christian · Johan · Joachim; Jerry and Phil in three). Each folder has a `SOURCE.txt`; copy its facts into `z_core/assets/licenses/german_names_sources.md`, one section per list, with the attribution text each licence asks for (Berlin: «BerlinOnline GmbH, auf Basis von Daten des LABO»).

Family names: Wikidata (CC0) the way `scripts/build_de_names.py` already does it, **without the 601 cap**: every family name of people with German citizenship, carrying the count of bearers as the rank.

## What to build

1. **`scripts/build_de_names.py` reads the four cities** (their three shapes and two encodings) plus Wikidata, and writes `z_core/assets/de_names_v2.csv` with the Phase 1 columns (`name · type · gender · count · rank · scope · year · source · license · source_url · notes`) **plus `cities`** (how many of the four carry the name) **and `tier`**. Deterministic: the same inputs give the same bytes; a gate rebuilds into a temp dir and compares, as the brand gate does.
2. **Tiers, by presence not by size:** tier 1 = given names in ≥ 3 cities (≈ 5,918); tier 2 = in 2 cities (4,025); tier 3 = in 1 city (17,516) — **tier 3 is written to the file but never loaded** in this task. Family names: tier 1 = bearers ≥ N (measure N so the list is a few thousand), the rest written, not loaded.
3. **The rules do not change.** Given + family pair → Suggest; salutation/title → Auto; bare given name → nothing; «Nachname, Vorname» → as Phase 2 built it; function words and stop words still open no name. What changes is only *what the dictionary knows*. The 11-to-1 guard and the ordinary-word collision test stay and grow: add the collisions the new tiers bring (measure: which tier-1 given names are also German words — `Ernst`, `Fritz`, `August`, `Mark`, `Rose`, `Christian`, `Stefan`… — and write them into the collision test so a bare one never becomes a person).
4. **Measure per tier, before loading each:** with tier 1 loaded, then tier 1+2 — the table below on every German golden (DE-1 letter, DE-2 contract, DE-3 tax guide, DE-4 ICD-10, DE-6 payslip — `Lohnabrechnung_Weber.txt` is on the paper branch, take it) and on the Swedish goldens as a control (they must not move at all).

| golden | auto | suggested | persons found / present | candidates | false protections | false suggestions |
|---|---|---|---|---|---|---|

   **Entry rule:** a tier enters only if it raises no false protection anywhere and raises persons found on DE-6 (the three table rows) without more than a handful of new false suggestions on DE-3/DE-4. If tier 2 fails that, it stays out and the report says why.
5. `docs/THE_NUMBERS.md` §2 gets the before/after rows; the register's rows get «في الحزمة».

## Done means

- `de_names_v2.csv` built by the script, gate-compared, with the licences file; the pack loads tiers 1 (and 2 if it passed) and says in `provenance` where the names came from.
- Golden tests updated **only where a number improved**, each change named; DE-1 stays 7/7 auto and 0 false; DE-3/DE-4 stay 0 false protections; the 11-to-1 guard and the collision test green and longer.
- Report: rows loaded per tier, the per-tier table, the collisions added, the family-name threshold chosen and why, and the sizes (the CSV in the binary).

## Not in this task

- Swedish or Arabic names (next, in this order).
- Any rule change (038-A/E/G are their own).
- Tier 3.
