# German Name Dictionary V1 — where the names came from

`z_core/assets/de_names_v1.csv` holds 310 names: 300 given names and 10
surnames. It is compiled into the binary (`include_str!`), so a scan reads no
file and reaches no network. The file is built by
`scripts/build_de_names.py --fetch`, which is a development step and never runs
in the product.

Both sources require attribution, and both requirements are met here and in the
header of the CSV itself.

## 1 · Given names — Berlin Open Data, häufige Vornamen 2023

* **What was taken**: the 300 most used first names in the twelve districts of
  Berlin for 2023, with the count summed across districts and across name
  positions (first name, second name, …). The gender is recorded as `m`, `w`, or
  `mw` where the data gives a name to both.
* **Data type**: names of children born in Berlin in 2023, published after
  cleaning and anonymisation.
* **Year**: 2023.
* **Licence**: CC BY 3.0 DE —
  <https://creativecommons.org/licenses/by/3.0/de/>
* **Attribution required** (the repository's own wording, quoted):
  > BerlinOnline GmbH, auf Basis von Daten des Berliner Landesamtes für
  > Bürger- und Ordnungsangelegenheiten (LABO)
* **And the repository URL must be given in the source statement**, which that
  licence section states in as many words:
  <https://github.com/berlin/haeufige-vornamen-berlin>
* **Dataset page**:
  <https://daten.berlin.de/datensaetze/liste-der-h-ufigen-vornamen-2023>
* **What the count is not**: it is the count inside Berlin 2023 only. It is not
  presented as Germany, and the `scope` column of every row says so.
* The repository's *code* is MIT (BerlinOnline GmbH, 2019–2025). No code was
  taken from it; only data.

## 2 · Surnames — popular-names-by-country-dataset, Germany subset

* **What was taken**: the ten rows of `common-surnames-by-country.csv` whose
  `Country` is `DE`, in the dataset's own rank order — Müller, Schmidt,
  Schneider, Fischer, Meyer, Weber, Wagner, Schulz, Becker, Hoffmann.
* **Licence**: CC0 1.0 Universal — no attribution is required, and it is given
  anyway, because a product whose argument is «you can check this» owes the
  reader the ability to.
* **Source**:
  <https://github.com/sigpwned/popular-names-by-country-dataset>

## 3 · Surnames, V2 — Wikidata, family names of people recorded as German

Added 5 October 2026, for Phase 1. The ten names of source 2 were the
bottleneck: measured on the owner's three files, they matched 1 of the 7
surnames in the German letter and 0 of the 15 in the Austrian document.

* **What was taken**: the 600 most borne family names, ranked by how many
  people Wikidata records with that family name (`P734`) **and** citizenship of
  Germany (`P27` = `Q183`), keeping only single-word labels shaped like a name.
  The German label of the family-name item is the name as written.
* **Data type**: structured data from Wikidata's main namespace.
* **Version**: the live endpoint as queried on 2026-10-05; the query is in
  `scripts/build_de_names.py` and gives the same list from the same data.
* **Licence**: **CC0 1.0** — Wikidata's own statement, read from its API and
  not assumed: «All structured data from the main and property namespace is
  available under the Creative Commons CC0 License»
  (<https://www.wikidata.org/wiki/Wikidata:Copyright>).
* **Attribution**: none required by CC0. Given anyway: Wikidata contributors,
  <https://www.wikidata.org>.
* **Engine**: the query is answered by QLever
  (<https://qlever.dev/api/wikidata>), which serves the same Wikidata data.
  Wikidata's own endpoint refuses this aggregation — it times out at 60 seconds,
  measured repeatedly, including split by first letter. The engine changes
  nothing about the data or its licence.
* **What the count is and is not**: it is the number of *people Wikidata
  records*, which is a count of the notable, not of the population. It orders
  the list; it is not a frequency claim about Germany, and the `scope` column of
  every row says `Wikidata, German citizens`.
* **A hole this source has, measured**: no family-name item labelled `Schmidt`
  in German has German-citizen holders in Wikidata, so the second commonest
  surname in Germany is **absent** from its ranked output. The ten names of
  source 2 are therefore kept as rows beside it — a union of the two covers
  what either misses, and each row says which source it came from.
* **Known limit, named rather than hidden**: the criterion is citizenship of
  Germany, so Austrian and Swiss surnames are not in it. On the owner's
  Austrian document this shows plainly: 12 of its 15 surnames are absent at any
  list size. The fix is the same query with `Q40` or `Q39`, and it is a decision
  for a later phase, not something to slip in here.

## Sources considered and not used, and why

Recorded because «no vague licence» is a rule, and because the next person to
widen this list should not have to measure the same things again.

* **German Wikipedia's lists of surnames** and **Wiktionary** — CC BY-SA. A
  share-alike licence on a compilation that would ship inside a product
  licensed Apache-2.0 is a conflict, not a formality. Not used.
* **`philipperemy/name-dataset`** and anything else derived from the 2019
  Facebook scrape — a leaked dataset. Not used, on the owner's rule and on its
  own merits.
* **Forebears.io**, **Geogen** — the best frequency data for German surnames,
  and proprietary. Not used.
* **German open government data** — publishes *given* names from birth
  registers (source 1 above) and deliberately does not publish surname
  frequencies. There is no official list to take.

## What the dictionary is allowed to do

A signal, never a verdict. A match can make the scanner **offer** a name it
would otherwise have walked past; it can never make it protect one. The rule
that uses it — `dictionary_names` in `z_core/src/scanner/packs/de.rs` — requires
both halves of a name, yields to a salutation or a title, and returns
`Confidence::Suggest` and nothing else. `z_core/tests/the_name_dictionary.rs`
holds that to account.

## Replacing this file

The owner's own `de_names_v1.csv` drops in unchanged: the same eleven columns,
read by the same loader. Run `python3 scripts/build_de_names.py --check` on it
first — it needs no network and says whether the file has the shape the product
expects.
