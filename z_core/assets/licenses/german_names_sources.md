# The German name bank — where every name came from

`z_core/assets/de_names_v2.csv` holds **12,732 names**: 9,486 given names and
3,246 surnames, in tiers. It is compiled into the binary (`include_str!`), so a
scan reads no file and reaches no network. Tier 3 — a spelling one single city
register ever used — is written beside it as `de_names_v2_tier3.csv` and is
compiled into nothing.

The file is built by `scripts/build_de_names.py --fetch`, which is a
development step and never runs in the product. Which tiers a build believes is
`LOADED_TIERS` in `z_core/src/scanner/packs/de_names.rs`; today it is tier 1,
and `docs/THE_NUMBERS.md` §2 has the measurement that let it in.

Every source below allows redistribution. Three of the four require
attribution, and the required wording is quoted here and carried in the CSV's
own header. **A list with no licence does not enter this file**: the lists that
were refused, and why, are in the lead's register (`~/work-now/names/REGISTER.md`).

---

## 1 · Given names — Berlin, häufige Vornamen 2012–2023

* **What was taken**: every spelling in the registers of the twelve Berlin
  districts for twelve years, with the count summed across districts, years and
  name positions. 154,909 rows read.
* **Data type**: first names of children born in Berlin, published after
  cleaning and anonymisation. No person, no birth, no address.
* **Publisher**: BerlinOnline Stadtportal GmbH & Co. KG, on data of the
  Landesamt für Bürger- und Ordnungsangelegenheiten (LABO).
* **Licence**: CC BY 3.0 DE — <https://creativecommons.org/licenses/by/3.0/de/>
* **Attribution required** (the repository's own wording, quoted):
  > BerlinOnline GmbH, auf Basis von Daten des Berliner Landesamtes für
  > Bürger- und Ordnungsangelegenheiten (LABO)
* **Repository**: <https://github.com/berlin/haeufige-vornamen-berlin>
* **Dataset page**:
  <https://daten.berlin.de/datensaetze/liste-der-h-ufigen-vornamen-2023>

## 2 · Given names — Bonn, Vornamen von Neugeborenen 2017–2024

* **What was taken**: every spelling in the city's yearly files, 31,324 rows,
  counts summed across years and name positions.
* **Publisher**: Bundesstadt Bonn — Offene Daten Bonn.
* **Licence**: CC0 1.0 (`cc-zero`), as stated on each dataset page. No
  attribution is required; it is given anyway.
* **Dataset pages**:
  <https://opendata.bonn.de/dataset/vornamen-von-neugeborenen-im-jahr-2024>
  (one page per year, 2017–2024)
* **Note for whoever rebuilds this**: the 2018 file is encoded cp1252, not
  UTF-8. The builder reads it as such; nothing else in the four cities is.

## 3 · Given names — Dortmund, Vornamen der Geburten seit 2021

* **What was taken**: every spelling in the city's export, 17,643 rows,
  2021–2025.
* **Publisher**: Stadt Dortmund — Open Data Dortmund.
* **Licence**: Datenlizenz Deutschland – Zero – Version 2.0 —
  <https://www.govdata.de/dl-de/zero-2-0>. No attribution is required; it is
  given anyway.
* **Dataset page**:
  <https://open-data.dortmund.de/explore/dataset/vornamen-geburten-in-dortmund-gesamt/>
* **Note**: this city writes the gender as `mannlich`/`weiblich` rather than
  `m`/`w`, and its own column order.

## 4 · Given names — Köln, Vornamen 2019–2023

* **What was taken**: every spelling in the two published files, 33,782 rows.
* **Publisher**: Stadt Köln — Offene Daten Köln.
* **Licence**: Datenlizenz Deutschland – Zero – Version 2.0 —
  <https://www.govdata.de/dl-de/zero-2-0>. No attribution is required; it is
  given anyway.
* **Dataset pages**: <https://offenedaten-koeln.de/dataset/vornamen-2019-2022>
  and <https://offenedaten-koeln.de/dataset/vornamen-2023>
* **Note**: the two files have two different column orders.

## 5 · Surnames — Wikidata, people with German citizenship

* **What was taken**: every family name borne by a person Wikidata records as a
  German citizen, with the number of such people as the count — 49,363
  spellings, of which the 3,246 with ten bearers or more are loaded.
* **Publisher**: Wikidata — <https://www.wikidata.org>
* **Licence**: CC0 1.0. No attribution is required; it is given anyway.
* **How it was asked**: a SPARQL query through QLever
  (<https://qlever.dev/api/wikidata>), because Wikidata's own endpoint times
  out on this question at 60 seconds — measured, including split by first
  letter. The query is in `scripts/build_de_names.py`.
* **What this count is not**: it is people recorded in Wikidata, not the
  population of Germany. A surname's rank here is a rank among the notable.

## 6 · Surnames — the ten of V1 (`popular-names-by-country-dataset`)

* **What was taken**: the German subset, and of it only the names Wikidata does
  not have at all. In practice that is **Schmidt** — no family-name item
  labelled «Schmidt» in German has German-citizen holders in Wikidata, and it
  is the second commonest surname in the country.
* **Publisher**: sigpwned —
  <https://github.com/sigpwned/popular-names-by-country-dataset>
* **Licence**: CC0 1.0.

---

## What the bank is, and is not

A dictionary hit is a **signal**, never a verdict. A name in this file can make
the scanner offer a word it would otherwise have walked past; it can never make
the scanner protect one by itself. That rule is item B of the owner's paper, it
is tested in `z_core/tests/the_name_dictionary.rs`, and 038-H did not touch it:
what changed in that task is only what the dictionary knows.
