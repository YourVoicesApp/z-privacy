# Swedish Name Dictionary V1 — where the names came from

`z_core/assets/sv_names_v1.csv` holds 300 names: 150 given names and 150
surnames. It is compiled into the binary, so a scan reads no file and reaches
no network.

It is **not** a Swedish dictionary. It is the proof Phase 3 was asked for: that
a second language is data, and that adding one needs no change to the core. 300
names are enough to show the rules work in another language, and the owner's
rule from Phase 1 stands — the little that is precise beats the much that is
noisy.

## Source — Wikidata

* **What was taken**: the 150 most borne given names (`P735`) and the 150 most
  borne family names (`P734`) of people Wikidata records with citizenship of
  **Sweden** (`P27` = `Q34`), keeping only single-word labels shaped like a
  name, with the Swedish-language label as the spelling.
* **Data type**: structured data from Wikidata's main namespace.
* **Version**: the live endpoint as queried on 2026-10-05, through QLever
  (<https://qlever.dev/api/wikidata>), which serves the same data. The query is
  in `scripts/build_de_names.py` — the same function that builds the German
  lists, with one country code changed. That is the whole of what «a language
  is data» means at the source.
* **Licence**: **CC0 1.0** — Wikidata's own statement, read from its API:
  «All structured data from the main and property namespace is available under
  the Creative Commons CC0 License»
  (<https://www.wikidata.org/wiki/Wikidata:Copyright>).
* **Attribution**: none required by CC0. Given anyway: Wikidata contributors,
  <https://www.wikidata.org>.
* **What the count is and is not**: the number of people *Wikidata records*,
  which counts the notable and not the population. It orders the list; it is
  not a frequency claim about Sweden, and the `scope` column of every row says
  `Wikidata, Swedish citizens`.

## What the rest of the pack is

`z_core/src/scanner/packs/sv.rs` is a locale, four word lists and this name
list. Its `extra` is empty: the three rules German needs that nothing else can
use — a national vehicle plate, a local number written after the German word
for telephone, a German street line — have no Swedish counterpart here, and
inventing one would be inventing a rule nobody measured.

`z_core/src/scanner/sets/sv.rs` holds eleven label rows, in the same shape as
the German and English sets. A Swedish personal number has a check digit; the
row says what the label means, and the arithmetic, if it is ever added, is a
`Validator` in Rust — never a row. That rule is written at the head of the
`sets` folder and it is older than this pack.
