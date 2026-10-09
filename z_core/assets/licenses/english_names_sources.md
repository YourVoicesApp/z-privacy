# English Name Dictionary V1 — where the names came from

`z_core/assets/en_names_v1.csv` holds 299 names: 149 given names and 150
surnames. It is compiled into the binary, so a scan reads no file and reaches
no network.

It is **not** an English dictionary. It is the same proof the Swedish list is —
that a language is data, and that adding one needs no change to the core — and
the owner's rule from Phase 1 stands: the little that is precise beats the much
that is noisy.

## Source — Wikidata

* **What was taken**: the 150 most borne given names (`P735`) and the 150 most
  borne family names (`P734`) of people Wikidata records with citizenship of
  the **United Kingdom** (`P27` = `Q145`), keeping only single-word labels
  shaped like a name, with the **English-language** label as the spelling. One
  given name was dropped by that shape filter, which is why the file holds 149
  and not 150.
* **Why the United Kingdom stands for English.** `P27` is citizenship, and
  English is a language, not a country. One country had to be named or the list
  would be a mixture nobody could reproduce, and the UK is the one whose
  documents this pack was measured on — the film's EN-1 to EN-3: Manchester,
  Leeds, HMRC, a P45, a GB VAT number, an NWBK IBAN. **The file does not claim
  to be «English names»**: the `scope` column of every row says `Wikidata,
  British citizens`, which is whose names they are. An American, Irish or
  Indian-English document meets the same rules and a list that does not know
  its names — and that is the ordinary case this product is built for, where
  the person teaches a name once.
* **Version**: the live endpoint as queried on 2026-10-09, through QLever
  (<https://qlever.dev/api/wikidata>), which serves the same data. The query is
  in `scripts/build_de_names.py` — the same function that builds the German and
  Swedish lists, with one country code changed and the label language made a
  parameter.
* **Licence**: **CC0 1.0** — Wikidata's own statement: «All structured data
  from the main and property namespace is available under the Creative Commons
  CC0 License» (<https://www.wikidata.org/wiki/Wikidata:Copyright>).
* **Attribution**: none required by CC0. Given anyway: Wikidata contributors,
  <https://www.wikidata.org>.
* **What the count is and is not**: the number of people *Wikidata records*,
  which counts the notable and not the population. It orders the list; it is
  not a frequency claim about Britain.

## A correction this build makes to the Swedish note

The query filtered `LANG(?nameLabel) = "de"` for **every** country, including
the Swedish build of 5 October. So `sv_names_v1.csv` holds Swedish citizens'
names *with their German-language labels*, while
`licenses/swedish_names_sources.md` says «the Swedish-language label as the
spelling». For names the two labels are the same string almost always, which is
why nothing showed — but the note claims something the code did not do.

The label language is a parameter now, and the English build passes `en`. The
German and Swedish files are left byte for byte as they are: re-querying them
is a change to shipped data, which is the lead's call and not a side effect of
adding a third language. **The Swedish note should be corrected or the file
rebuilt** — named here rather than quietly fixed, because a line of provenance
that is not true is the kind of defect this project treats as a defect.

## What the rest of the pack is

`z_core/src/scanner/packs/en.rs` is a locale, four word lists and this name
list. Its `extra` is empty, as Swedish's is.

Two things in it are English and have no Swedish counterpart, and both are
written where they are used:

* `-son` is a surname ending in both languages — the owner's own observation,
  measured here at **25 of the 150** British surnames. But English builds
  ordinary nouns with it too, and one of them is «Person», the first word of
  the line the film's letter introduces its contact with. Those nouns are set
  aside by name in the pack's `STOP_WORDS`, and that list is the price of the
  ending.
* The honorific carries a name and the greeting does not: «Dear» opens an
  English letter and says nothing about what follows it. `Mr`, `Mrs` and `Ms`
  are the salutations; `Dear` is a stop word.

`z_core/src/scanner/sets/en.rs` holds the English label rows and is older than
this pack — it shipped on 29 September, while discovery for English did not
exist until today. That gap is why the pack row for `en` reported an empty
locale and zero names.
