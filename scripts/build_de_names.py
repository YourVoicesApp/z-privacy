#!/usr/bin/env python3
"""Build `z_core/assets/de_names_v1.csv` — the German Name Dictionary V1.

Two public sources, both fetched at **development** time and never at run
time. The product reads the generated CSV out of the binary (`include_str!`),
so a scan needs no file and no network.

    python3 scripts/build_de_names.py --fetch     # download and write the CSV
    python3 scripts/build_de_names.py --check     # check the CSV on disk, offline

`--check` is what a gate can run: it needs no network and proves the file has
the shape the product expects — 310 rows, eleven fields, the counts in order,
and nothing in it that is not a name.

The owner's own `de_names_v1.csv` replaces this file the day it arrives. It is
read by the same loader, so nothing but the file changes; run `--check` on it.

Given names — Berlin Open Data, häufige Vornamen 2023, aggregated across the
twelve districts and across name positions, exactly as the owner described it:
«the count in V1 is the count inside Berlin 2023 only, and is not presented as
Germany as a whole».

Surnames — the Germany subset of sigpwned/popular-names-by-country-dataset.

See `z_core/assets/licenses/german_names_sources.md` for the attribution each
licence requires. That file is the one to read before this one is changed.
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import pathlib
import re
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "z_core" / "assets" / "de_names_v1.csv"

FIELDS = [
    "name", "type", "gender", "count", "rank", "scope", "year", "source",
    "license", "source_url", "notes",
]

GIVEN_LIMIT = 300
FAMILY_LIMIT = 600
BERLIN_RAW = "https://raw.githubusercontent.com/berlin/haeufige-vornamen-berlin/main/data/2023"
BERLIN_DISTRICTS = [
    "charlottenburg-wilmersdorf", "friedrichshain-kreuzberg", "lichtenberg",
    "marzahn-hellersdorf", "mitte", "neukoelln", "pankow", "reinickendorf",
    "spandau", "steglitz-zehlendorf", "tempelhof-schoeneberg", "treptow-koepenick",
]
BERLIN_PAGE = "https://daten.berlin.de/datensaetze/liste-der-h-ufigen-vornamen-2023"
BERLIN_REPO = "https://github.com/berlin/haeufige-vornamen-berlin"
SURNAMES_URL = (
    "https://raw.githubusercontent.com/sigpwned/popular-names-by-country-dataset"
    "/master/common-surnames-by-country.csv"
)
SURNAMES_REPO = "https://github.com/sigpwned/popular-names-by-country-dataset"

# Wikidata, through an engine that will actually answer: the question is «which
# family names do the people Wikidata records as German citizens carry, and how
# many of them», which Wikidata's own endpoint times out on at 60 seconds —
# measured, including split by first letter. QLever serves the same CC0 data.
WIKIDATA_ENGINE = "https://qlever.dev/api/wikidata"
WIKIDATA_QUERY = """
PREFIX wdt: <http://www.wikidata.org/prop/direct/>
PREFIX wd: <http://www.wikidata.org/entity/>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT ?nameLabel (COUNT(?person) AS ?people) WHERE {
  ?person wdt:P31 wd:Q5 ;
          wdt:P27 wd:Q183 ;
          wdt:P734 ?name .
  ?name rdfs:label ?nameLabel .
  FILTER(LANG(?nameLabel) = "de")
}
GROUP BY ?nameLabel
ORDER BY DESC(?people)
LIMIT 2000
"""
WIKIDATA_PAGE = "https://www.wikidata.org"
# A name the rule can match on one word: a capital, then letters, a hyphen or an
# apostrophe. «von Rumerskirch» and «Jarosch von Schweder» are real names and
# not ones this rule is built to read.
NAME_SHAPE = re.compile(r"[A-ZÄÖÜ][A-Za-zÄÖÜäöüß'\u2019-]+$")


def get(url: str) -> str:
    with urllib.request.urlopen(url, timeout=60) as answer:  # noqa: S310 — a known https URL
        return answer.read().decode("utf-8-sig")


def given_names() -> list[dict]:
    """Every name in Berlin 2023, with its count summed over districts and positions."""
    counts: dict[str, int] = {}
    genders: dict[str, dict[str, int]] = {}
    for district in BERLIN_DISTRICTS:
        text = get(f"{BERLIN_RAW}/{district}.csv")
        for row in csv.DictReader(io.StringIO(text)):
            name = (row.get("vorname") or "").strip()
            if not name:
                continue
            try:
                count = int(row.get("anzahl") or 0)
            except ValueError:
                continue
            counts[name] = counts.get(name, 0) + count
            gender = (row.get("geschlecht") or "").strip().lower()
            if gender in ("m", "w"):
                genders.setdefault(name, {}).setdefault(gender, 0)
                genders[name][gender] += count
    # Most used first, and the name itself breaks a tie so the file is the same
    # file every time it is built.
    ordered = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))[:GIVEN_LIMIT]
    out = []
    for rank, (name, count) in enumerate(ordered, start=1):
        seen = genders.get(name, {})
        total = sum(seen.values()) or 1
        # A name given to both is written as both: «Noah» and «Luca» are, and a
        # dictionary that picks one would be saying something the data does not.
        parts = [g for g in ("m", "w") if seen.get(g, 0) / total >= 0.20]
        out.append({
            "name": name,
            "type": "given",
            "gender": "".join(parts) or "u",
            "count": count,
            "rank": rank,
            "scope": "Berlin 2023",
            "year": 2023,
            "source": "Berlin Open Data — haeufige Vornamen 2023",
            "license": "CC BY 3.0 DE",
            "source_url": BERLIN_PAGE,
            "notes": "count is within Berlin 2023 births only, not Germany",
        })
    return out


def family_names() -> list[dict]:
    rows = list(csv.DictReader(io.StringIO(get(SURNAMES_URL))))
    german = [r for r in rows if (r.get("Country") or "").strip() == "DE"]
    german.sort(key=lambda r: int(r.get("Rank") or 0))
    out = []
    for row in german:
        name = (row.get("Romanized Name") or "").strip()
        if not name:
            continue
        out.append({
            "name": name,
            "type": "family",
            "gender": "u",
            "count": int(row.get("Count") or 0),
            "rank": int(row.get("Rank") or 0),
            "scope": "Germany",
            "license": "CC0 1.0",
            "year": "",
            "source": "sigpwned/popular-names-by-country-dataset — Germany subset",
            "source_url": SURNAMES_REPO,
            "notes": "ten most common surnames in the Germany subset",
        })
    return out


def wikidata_surnames() -> list[dict]:
    """The 600 most borne family names of people Wikidata records as German."""
    request = urllib.request.Request(
        WIKIDATA_ENGINE,
        data=WIKIDATA_QUERY.encode("utf-8"),
        headers={
            "Content-Type": "application/sparql-query",
            "Accept": "application/sparql-results+json",
            # A real agent string, because a public service is owed one.
            "User-Agent": "ZPrivacy-build/0.1 (local, one-off; a German surname list for on-device PII detection)",
        },
    )
    with urllib.request.urlopen(request, timeout=120) as answer:  # noqa: S310
        payload = json.load(answer)
    out: list[dict] = []
    for row in payload["results"]["bindings"]:
        name = row["nameLabel"]["value"].strip()
        if not NAME_SHAPE.match(name):
            continue
        out.append({
            "name": name,
            "type": "family",
            "gender": "u",
            "count": int(row["people"]["value"]),
            "rank": 0,  # filled below, after the shape filter has thinned it
            "scope": "Wikidata, German citizens",
            "year": 2026,
            "source": "Wikidata — family names of people with German citizenship",
            "license": "CC0 1.0",
            "source_url": WIKIDATA_PAGE,
            "notes": "count is people recorded in Wikidata, not the population",
        })
        if len(out) >= FAMILY_LIMIT:
            break
    for rank, row in enumerate(out, start=1):
        row["rank"] = rank
    return out


def family_rows() -> list[dict]:
    """Both surname sources, as a union.

    Wikidata ranks them, and it is missing `Schmidt` — no family-name item with
    that German label has German-citizen holders there, so the second commonest
    surname in Germany is not in its output. The ten CC0 names of V1 are kept
    for exactly that reason, and each row still says where it came from.
    """
    wikidata = wikidata_surnames()
    have = {row["name"].lower() for row in wikidata}
    kept = [row for row in family_names() if row["name"].lower() not in have]
    return wikidata + kept


def write(rows: list[dict]) -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(
            "# German Name Dictionary V1 — generated by scripts/build_de_names.py\n"
            "# A signal for Person detection, never a verdict: see item B of the\n"
            "# owner's paper, and z_core/assets/licenses/german_names_sources.md\n"
            f"# for the attribution each source requires ({BERLIN_REPO},\n"
            f"# {SURNAMES_REPO}).\n"
        )
        writer = csv.DictWriter(handle, fieldnames=FIELDS, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)
    print(f"wrote {OUT.relative_to(ROOT)} — {len(rows)} names")


def check() -> int:
    if not OUT.is_file():
        print(f"FAIL  {OUT.relative_to(ROOT)} is not there")
        return 1
    text = OUT.read_text(encoding="utf-8")
    body = "\n".join(line for line in text.splitlines() if not line.startswith("#"))
    rows = list(csv.DictReader(io.StringIO(body)))
    problems: list[str] = []
    if list(rows[0].keys()) != FIELDS:
        problems.append(f"the fields are {list(rows[0].keys())}")
    given = [r for r in rows if r["type"] == "given"]
    family = [r for r in rows if r["type"] == "family"]
    if len(given) != GIVEN_LIMIT:
        problems.append(f"{len(given)} given names, not {GIVEN_LIMIT}")
    if not FAMILY_LIMIT <= len(family) <= FAMILY_LIMIT + 10:
        problems.append(f"{len(family)} surnames, not {FAMILY_LIMIT} to {FAMILY_LIMIT + 10}")
    family_by_source: dict[str, list[dict]] = {}
    for row in family:
        family_by_source.setdefault(row["source"], []).append(row)
    groups = [("given", given)] + [
        (f"family from {source.split(' — ')[0]}", rows) for source, rows in family_by_source.items()
    ]
    for kind, group in groups:
        counts = [int(r["count"]) for r in group]
        if counts != sorted(counts, reverse=True):
            problems.append(f"the {kind} names are not in order of use")
        for row in group:
            name = row["name"]
            if not name or not name[0].isupper() or not all(c.isalpha() or c in "-' " for c in name):
                problems.append(f"«{name}» is not shaped like a name")
            if not row["license"] or not row["source_url"]:
                problems.append(f"«{name}» does not say where it came from")
    if problems:
        for problem in problems:
            print(f"FAIL  {problem}")
        return 1
    print(f"PASS  {len(rows)} names, {len(given)} given and {len(family)} family, each with its source")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fetch", action="store_true", help="download the sources and write the CSV")
    parser.add_argument("--check", action="store_true", help="check the CSV on disk, offline")
    args = parser.parse_args()
    if args.fetch:
        write(given_names() + family_rows())
        return check()
    if args.check:
        return check()
    parser.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())
