# Arabic Given Names V1 — where the names came from

`z_core/assets/ar_names_v1.csv` holds **2,414 given names**: 1,292 from the
male list and 1,135 from the female one, 2,427 lines in all, of which 13 names
stand in both lists — أمل, نور, سلام and the like are given to either, which is
a fact about Arabic names and not a mistake in the file. It is compiled into the
binary, so a scan reads no file and reaches no network.

It is **not** an Arabic name dictionary, and it is not a corpus. It is one
person's list, and this is the whole provenance:

## Source — the owner's own library

* **What was taken**: every name line of `~/الأسماء العربية.txt`, his own
  compilation, handed over on 25 October 2026 for this purpose. The file is a
  reading list: a title, a header that counts itself, rules of `═` and `─`, a
  section per letter and two headings under each — `الذكور:` and `الإناث:`.
  Everything that is not a name line is dropped by name in
  `scripts/build_ar_names.py`, including the 28 bracketed per-letter tallies
  the file writes between sections.
* **Licence**: his own. There is no third party in this file and no query
  against anybody's endpoint: the owner compiled the list and gave it to his own
  product. Nothing in it is attributable to a source that would need naming, and
  nothing in it was copied from one.
* **Harakat**: kept exactly as he typed them. 897 of the names carry a vowel
  mark, and the mark is part of how he wrote it. The matching side folds the
  marks off (`z_core/src/scanner/packs/ar.rs`), so a document finds the name
  whether it writes the marks or not — and **856 of his names exist in the file
  only in a marked form**, which is why that fold is not a nicety. Folded, the
  2,414 names collapse to **2,306 distinct keys**: 108 of them differ from
  another only by a mark.
* **Compound names**: 27 of the rows are two words — «ذو الفقار», «أمّ كُلثوم»,
  «ست الملوك» — and each is **one** name, kept whole, because that is what it
  is. The matching rule reads one word at a time, so these are carried in the
  file and found only when a document writes the whole of one.

## What it does not hold, measured

* **No surnames.** The library is given names, so the Arabic pack's
  `family_suffixes` list is empty and nothing in it claims a family name. An
  Arabic surname is mostly a nisba — «الحربي», «العمري» — and an ending rule for
  those is a measurement nobody has made yet.
* **Six names a reader would expect are not in it**, measured against a list of
  26 common ones: **محمد**, عثمان, يوسف, إبراهيم, عبدالله written as one word,
  and نور. «محمد» is the commonest name in the Arabic-speaking world and the
  file does not have it; it has محمود and محمودة. That is the owner's to fill,
  and filling it is re-running the builder — which is the reason the builder
  exists and the CSV is not edited by hand.
* The owner said the list holds «about 2,600». Its own header says 2,427 and the
  parse agrees with the header to the line. The number in this file is the one
  that ships.

## How a hit is used

A dictionary hit **offers** a name and never protects one: `ar-2` marks it
`Suggested` and waits for the person's word, because a great many Arabic given
names are also ordinary words — «أمل» is hope, «نور» is light, «سلام» is peace.
Measured on AR-1 (`z_core/tests/the_arabic_pack.rs`): the library puts three
such words on the waiting list in one letter — a street named after a prince,
the word for an account holder, and half of the phrase a letter closes with.
What protects by itself is a **form word** in front of a name — «السيد»,
«الدكتورة» — which is the same law the German pack keeps for «Frau».
