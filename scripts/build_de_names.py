#!/usr/bin/env python3
"""Build the German name bank — `z_core/assets/de_names_v2.csv`.

    python3 scripts/build_de_names.py --fetch          # read the sources, write the CSV
    python3 scripts/build_de_names.py --check          # check the CSV on disk, offline
    python3 scripts/build_de_names.py --rebuild-check  # rebuild into a temp dir, compare bytes
    python3 scripts/build_de_names.py --swedish        # the Swedish pack's names (unchanged)

Everything here happens at **development** time. The product reads the
generated CSV out of its own binary (`include_str!`), so a scan needs no file
and no network — a scan on an aeroplane finds what a scan in an office finds.

# Where the names come from

Given names: four German cities that publish their newborn registers as open
data, downloaded by the lead on 6 October 2026 and kept in
`~/work-now/names/de/` (override with `ZPRIVACY_NAME_SOURCES`). Each folder
carries a `SOURCE.txt` with the link, the publisher and the licence, and those
facts are copied into `z_core/assets/licenses/german_names_sources.md`, which
is the file to read before this one is changed.

    berlin      2012–2023   154,909 rows   CC BY 3.0 DE      comma
    bonn        2017–2024    31,324 rows   CC0               semicolon, 2018 in cp1252
    dortmund    2021–2025    17,643 rows   DL-DE-Zero 2.0    semicolon, its own column order
    koeln       2019–2023    33,782 rows   DL-DE-Zero 2.0    semicolon, two shapes

Family names: Wikidata (CC0), every family name borne by people it records as
German citizens, with the number of bearers — 49,363 of them. Plus the ten CC0
surnames of V1, because Wikidata has no German-labelled family-name item for
**Schmidt** with German-citizen holders, and the second commonest surname in
the country is not a hole to ship.

# Tiers, by presence rather than by size

A name in one city's register is a name that city gave to a child. A name in
four is a name the language uses. So the bank is written in tiers and the pack
loads the ones that have been measured:

    given   tier 1  in 3 or 4 cities
            tier 2  in 2 cities
            tier 3  in 1 city only — written, never loaded in 038-H
    family  tier 1  at least FAMILY_TIER1 bearers in Wikidata
            tier 3  the rest — written, never loaded

Which tiers the pack actually loads is `z_core/src/scanner/packs/de_names.rs`,
and each one was measured on every German golden before it was let in. **The
rules do not change here**: a dictionary hit is a signal, never a verdict.
"""

from __future__ import annotations

import argparse
import csv
import filecmp
import io
import json
import os
import pathlib
import re
import sys
import tempfile
import unicodedata
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "z_core" / "assets" / "de_names_v2.csv"
# Tier 3 is written and never loaded, so it is written **beside** the bank
# rather than inside it: the shipped file is compiled into the binary with
# `include_str!`, and 60,548 rows nobody reads would be 14 MB of download in
# every copy of the product. Measured: the bank the pack may load is 3.3 MB,
# the whole of it is 17.1 MB.
OUT_TIER3 = ROOT / "z_core" / "assets" / "de_names_v2_tier3.csv"
OUT_SV = ROOT / "z_core" / "assets" / "sv_names_v1.csv"
SOURCES = pathlib.Path(os.environ.get("ZPRIVACY_NAME_SOURCES", "~/work-now/names/de")).expanduser()

FIELDS = [
    "name", "type", "gender", "count", "rank", "scope", "year", "source",
    "license", "source_url", "notes", "cities", "tier",
]

# Measured on the goldens before it was chosen; see the task report. 3,298 names.
FAMILY_TIER1 = 10

CITIES = ("berlin", "bonn", "dortmund", "koeln")
LICENCES = {
    "berlin": ("CC BY 3.0 DE", "https://github.com/berlin/haeufige-vornamen-berlin",
               "Berlin — haeufige Vornamen 2012–2023",
               "BerlinOnline GmbH, auf Basis von Daten des LABO"),
    "bonn": ("CC0 1.0", "https://opendata.bonn.de/dataset/vornamen-von-neugeborenen-im-jahr-2024",
             "Bonn — Vornamen von Neugeborenen 2017–2024", "Bundesstadt Bonn"),
    "dortmund": ("DL-DE-Zero 2.0", "https://open-data.dortmund.de/explore/dataset/vornamen-geburten-in-dortmund-gesamt/",
                 "Dortmund — Vornamen der Geburten seit 2021", "Stadt Dortmund"),
    "koeln": ("DL-DE-Zero 2.0", "https://offenedaten-koeln.de/dataset/vornamen-2019-2022",
              "Koeln — Vornamen 2019–2023", "Stadt Koeln"),
}

SURNAMES_URL = (
    "https://raw.githubusercontent.com/sigpwned/popular-names-by-country-dataset"
    "/master/common-surnames-by-country.csv"
)
SURNAMES_REPO = "https://github.com/sigpwned/popular-names-by-country-dataset"
WIKIDATA_ENGINE = "https://qlever.dev/api/wikidata"
WIKIDATA_PAGE = "https://www.wikidata.org"
WIKIDATA_CACHE = SOURCES / "wikidata" / "family.json"
COUNTRIES = {"de": ("Q183", "German"), "sv": ("Q34", "Swedish")}
WIKIDATA_QUERY = """
PREFIX wdt: <http://www.wikidata.org/prop/direct/>
PREFIX wd: <http://www.wikidata.org/entity/>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT ?nameLabel (COUNT(?person) AS ?people) WHERE {
  ?person wdt:P31 wd:Q5 ;
          wdt:P27 wd:{country} ;
          wdt:P{part} ?name .
  ?name rdfs:label ?nameLabel .
  FILTER(LANG(?nameLabel) = "de")
}
GROUP BY ?nameLabel
ORDER BY DESC(?people)
LIMIT {limit}
"""

# A name the rules can match on one word: a capital, then letters, a hyphen or
# an apostrophe, and at least two characters — a single letter is an initial,
# and the core refuses to treat one as a name anyway.
NAME_SHAPE = re.compile(r"[A-ZÄÖÜ][A-Za-zÄÖÜäöüß'’-]+$")


def nfc(text: str) -> str:
    return unicodedata.normalize("NFC", text).strip()


def read_rows(path: pathlib.Path, delimiter: str) -> list[dict]:
    """One file, whatever it was exported as.

    Two encodings and a byte-order mark: Bonn's 2018 file is cp1252 — measured,
    it is the only one — and Dortmund's and Köln's exports begin with a BOM.
    """
    raw = path.read_bytes()
    try:
        text = raw.decode("utf-8-sig")
    except UnicodeDecodeError:
        text = raw.decode("cp1252")
    return list(csv.DictReader(io.StringIO(text), delimiter=delimiter))


def city_names(city: str) -> dict[str, tuple[int, dict[str, int]]]:
    """Every spelling one city's registers carry, with its count and genders."""
    folder = SOURCES / city
    counts: dict[str, int] = {}
    genders: dict[str, dict[str, int]] = {}

    def take(name: str, count: int, gender: str) -> None:
        name = nfc(name)
        if not name:
            return
        counts[name] = counts.get(name, 0) + count
        gender = gender.strip().lower()
        # Dortmund writes the word, the others the letter.
        gender = {"mannlich": "m", "männlich": "m", "weiblich": "w"}.get(gender, gender)
        if gender in ("m", "w"):
            genders.setdefault(name, {})
            genders[name][gender] = genders[name].get(gender, 0) + count

    files = sorted(folder.rglob("*.csv")) + sorted(folder.rglob("*.CSV"))
    for path in files:
        delimiter = "," if city == "berlin" else ";"
        for row in read_rows(path, delimiter):
            lower = {(k or "").strip().lower().lstrip("﻿"): v for k, v in row.items()}
            name = lower.get("vorname") or ""
            try:
                count = int((lower.get("anzahl") or "0").strip() or 0)
            except ValueError:
                continue
            take(name, count, lower.get("geschlecht") or "")
    return {name: (count, genders.get(name, {})) for name, count in counts.items()}


def given_names() -> list[dict]:
    """The four cities, merged — and how many of them carry each spelling."""
    per_city = {city: city_names(city) for city in CITIES}
    everywhere: dict[str, dict] = {}
    for city, names in per_city.items():
        for name, (count, genders) in names.items():
            row = everywhere.setdefault(name, {"count": 0, "genders": {}, "cities": set()})
            row["count"] += count
            row["cities"].add(city)
            for gender, n in genders.items():
                row["genders"][gender] = row["genders"].get(gender, 0) + n

    out: list[dict] = []
    for name, found in everywhere.items():
        if len(name) < 2 or not NAME_SHAPE.match(name):
            continue
        cities = len(found["cities"])
        tier = 1 if cities >= 3 else (2 if cities == 2 else 3)
        seen = found["genders"]
        total = sum(seen.values()) or 1
        # A name given to both is written as both: «Noah» and «Luca» are, and a
        # dictionary that picks one would be saying something the data does not.
        gender = "".join(g for g in ("m", "w") if seen.get(g, 0) / total >= 0.20) or "u"
        where = ", ".join(sorted(found["cities"]))
        out.append({
            "name": name, "type": "given", "gender": gender,
            "count": found["count"], "rank": 0,
            "scope": f"{cities} of 4 cities ({where})",
            "year": "2012-2025",
            "source": "Berlin, Bonn, Dortmund and Koeln newborn registers",
            "license": "CC BY 3.0 DE; CC0 1.0; DL-DE-Zero 2.0",
            "source_url": LICENCES["berlin"][1],
            "notes": "count is births in those cities in those years, not Germany",
            "cities": cities, "tier": tier,
        })
    # Most used first, and the name itself breaks a tie, so the file is the same
    # file every time it is built.
    out.sort(key=lambda r: (-r["count"], r["name"]))
    for rank, row in enumerate(out, start=1):
        row["rank"] = rank
    return out


def wikidata(part: str, lang: str = "de", limit: int = 60000) -> list[tuple[str, int]]:
    """Names and how many people Wikidata records carrying them."""
    country, _ = COUNTRIES[lang]
    query = (WIKIDATA_QUERY.replace("{country}", country)
             .replace("{part}", part).replace("{limit}", str(limit)))
    request = urllib.request.Request(
        WIKIDATA_ENGINE, data=query.encode("utf-8"),
        headers={
            "Content-Type": "application/sparql-query",
            "Accept": "application/sparql-results+json",
            # A real agent string, because a public service is owed one.
            "User-Agent": "ZPrivacy-build/0.1 (local, one-off; a German name list for on-device PII detection)",
        },
    )
    with urllib.request.urlopen(request, timeout=240) as answer:  # noqa: S310 — a known https URL
        payload = json.load(answer)
    return [(b["nameLabel"]["value"], int(b["people"]["value"])) for b in payload["results"]["bindings"]]


def family_names() -> list[dict]:
    """Every German family name Wikidata knows, tiered by how many bear it.

    Cached in the sources folder: one answer of 49,363 rows is enough, and a
    rebuild that re-asks a public endpoint for the same thing is a rebuild that
    cannot be checked byte for byte.
    """
    if WIKIDATA_CACHE.is_file():
        rows = [(name, count) for name, count in json.loads(WIKIDATA_CACHE.read_text(encoding="utf-8"))]
    else:
        rows = wikidata("734")
        WIKIDATA_CACHE.parent.mkdir(parents=True, exist_ok=True)
        WIKIDATA_CACHE.write_text(json.dumps(rows, ensure_ascii=False), encoding="utf-8")

    out: list[dict] = []
    for name, count in rows:
        name = nfc(name)
        if len(name) < 2 or not NAME_SHAPE.match(name):
            continue
        out.append({
            "name": name, "type": "family", "gender": "u",
            "count": count, "rank": 0,
            "scope": "Wikidata, German citizens",
            "year": 2026,
            "source": "Wikidata — family names of people with German citizenship",
            "license": "CC0 1.0", "source_url": WIKIDATA_PAGE,
            "notes": "count is people recorded in Wikidata, not the population",
            "cities": "", "tier": 1 if count >= FAMILY_TIER1 else 3,
        })

    # The hole: no German-labelled family-name item for «Schmidt» has
    # German-citizen holders in Wikidata, and it is the second commonest
    # surname in the country. The CC0 ten of V1 fill it, and say so themselves.
    have = {row["name"].lower() for row in out}
    for row in csv.DictReader(io.StringIO(urlopen_text(SURNAMES_URL))):
        if (row.get("Country") or "").strip() != "DE":
            continue
        name = nfc(row.get("Romanized Name") or "")
        if not name or name.lower() in have or not NAME_SHAPE.match(name):
            continue
        out.append({
            "name": name, "type": "family", "gender": "u",
            "count": int(row.get("Count") or 0), "rank": 0,
            "scope": "Germany", "year": "",
            "source": "sigpwned/popular-names-by-country-dataset — Germany subset",
            "license": "CC0 1.0", "source_url": SURNAMES_REPO,
            "notes": "one of the ten commonest German surnames; Wikidata has no item for it",
            "cities": "", "tier": 1,
        })

    out.sort(key=lambda r: (-r["count"], r["name"]))
    for rank, row in enumerate(out, start=1):
        row["rank"] = rank
    return out


def urlopen_text(url: str) -> str:
    with urllib.request.urlopen(url, timeout=120) as answer:  # noqa: S310 — a known https URL
        return answer.read().decode("utf-8-sig")


def write(rows: list[dict], out: pathlib.Path = OUT, kind: str = "bank") -> None:
    """Write one file. `kind` is what is in it, never where it is going.

    The header used to be chosen by comparing the path with `OUT`, which is
    true of the repository and false of a temp directory — so the rebuild check
    wrote a **Swedish** header into a German bank and then said, correctly, that
    the two files differed. A file says what it holds; it does not ask where it
    was put.
    """
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8", newline="\n") as handle:
        if kind in ("bank", "tier3"):
            if kind == "tier3":
                handle.write("# (tier 3 only — written for the next task, never compiled in)\n")
            handle.write(
                "# German Name Bank — generated by scripts/build_de_names.py\n"
                "# A signal for Person detection, never a verdict: a dictionary hit\n"
                "# can offer a name the rules would have walked past, and can never\n"
                "# protect one by itself.\n"
                "# Tiers: given 1 = in 3 or 4 city registers, 2 = in 2, 3 = in 1;\n"
                f"# family 1 = at least {FAMILY_TIER1} bearers in Wikidata, 3 = fewer.\n"
                "# Sources and the attribution each licence requires:\n"
                "# z_core/assets/licenses/german_names_sources.md\n"
            )
        else:
            handle.write(
                "# Swedish Name Dictionary V1 — generated by scripts/build_de_names.py\n"
                "# A signal for Person detection, never a verdict: see item B of the\n"
                "# owner's paper, and z_core/assets/licenses/swedish_names_sources.md\n"
                f"# Source: {WIKIDATA_PAGE} (CC0 1.0).\n"
            )
        writer = csv.DictWriter(handle, fieldnames=FIELDS, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in FIELDS})
    where = out.relative_to(ROOT) if out.is_relative_to(ROOT) else out
    print(f"wrote {where} — {len(rows)} names")


def build() -> list[dict]:
    return given_names() + family_names()


def swedish_rows() -> list[dict]:
    """150 given and 150 family names — a proof, not a dictionary."""
    out = []
    for part, kind in (("735", "given"), ("734", "family")):
        for rank, (name, count) in enumerate(wikidata(part, "sv", 150), start=1):
            if not NAME_SHAPE.match(nfc(name)):
                continue
            out.append({
                "name": nfc(name), "type": kind, "gender": "u", "count": count, "rank": rank,
                "scope": "Wikidata, Swedish citizens", "year": 2026,
                "source": f"Wikidata — {kind} names of people with Swedish citizenship",
                "license": "CC0 1.0", "source_url": WIKIDATA_PAGE,
                "notes": "count is people recorded in Wikidata, not the population",
                "cities": "", "tier": 1,
            })
    return out


def rows_on_disk() -> list[dict]:
    body = "\n".join(line for line in OUT.read_text(encoding="utf-8").splitlines() if not line.startswith("#"))
    return list(csv.DictReader(io.StringIO(body)))


def check() -> int:
    """Offline: the file has the shape the product expects, and nothing else."""
    if not OUT.is_file():
        print(f"FAIL  {OUT.relative_to(ROOT)} is not there")
        return 1
    rows = rows_on_disk()
    problems: list[str] = []
    if list(rows[0].keys()) != FIELDS:
        problems.append(f"the fields are {list(rows[0].keys())}")
    given = [r for r in rows if r["type"] == "given"]
    family = [r for r in rows if r["type"] == "family"]
    if not given or not family:
        problems.append("a bank with only one kind of name in it")
    for kind, group in (("given", given), ("family", family)):
        counts = [int(r["count"]) for r in group]
        if counts != sorted(counts, reverse=True):
            problems.append(f"the {kind} names are not in order of use")
    for row in rows:
        name = row["name"]
        # The apostrophe of «O’Connor» and «N’Diaye» is the typographic one as
        # often as the ASCII one, and both are in these registers.
        if len(name) < 2 or not name[0].isupper() or not all(c.isalpha() or c in "-' ’" for c in name):
            problems.append(f"«{name}» is not shaped like a name")
        if not row["license"] or not row["source_url"]:
            problems.append(f"«{name}» does not say where it came from")
        if row["tier"] not in ("1", "2"):
            problems.append(f"«{name}» is tier {row['tier']}, and the bank ships tiers 1 and 2")
        if row["type"] == "given":
            cities, tier = int(row["cities"]), int(row["tier"])
            wanted = 1 if cities >= 3 else (2 if cities == 2 else 3)
            if tier != wanted:
                problems.append(f"«{name}» is in {cities} cities and tier {tier}")
    if problems:
        for problem in problems[:20]:
            print(f"FAIL  {problem}")
        return 1
    tiers = {t: sum(1 for r in rows if r["tier"] == t) for t in ("1", "2")}
    print(
        f"PASS  {len(rows)} names — {len(given)} given, {len(family)} family; "
        f"tier 1 {tiers['1']}, tier 2 {tiers['2']}"
    )
    return 0


def rebuild_check() -> int:
    """Rebuild from the sources into a temp dir and compare the bytes.

    Skipped, not failed, where the sources are not on the machine — the same
    rule the goldens follow for the owner's own PDFs.
    """
    if not SOURCES.is_dir() or not (SOURCES / "berlin").is_dir():
        print(f"----  no name sources at {SOURCES} (set ZPRIVACY_NAME_SOURCES); the shape check still ran")
        return 0
    with tempfile.TemporaryDirectory() as tmp:
        rows = build()
        fresh = pathlib.Path(tmp) / "de_names_v2.csv"
        write([r for r in rows if r["tier"] != 3], fresh, "bank")
        if not filecmp.cmp(fresh, OUT, shallow=False):
            print("FAIL  the bank in the repository is not what this script writes")
            return 1
    print("PASS  the bank is byte for byte what the sources and this script make")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fetch", action="store_true", help="read the sources and write the CSV")
    parser.add_argument("--check", action="store_true", help="check the CSV on disk, offline")
    parser.add_argument("--rebuild-check", action="store_true", help="rebuild into a temp dir and diff")
    parser.add_argument("--swedish", action="store_true", help="build the Swedish pack's names")
    args = parser.parse_args()
    if args.swedish:
        write(swedish_rows(), OUT_SV, "swedish")
        return 0
    if args.fetch:
        rows = build()
        write([r for r in rows if r["tier"] != 3], OUT, "bank")
        write([r for r in rows if r["tier"] == 3], OUT_TIER3, "tier3")
        return check()
    if args.rebuild_check:
        return check() or rebuild_check()
    if args.check:
        return check()
    parser.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())
