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
