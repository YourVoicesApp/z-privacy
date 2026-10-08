# 056 · A client table teaches only its names, and says nothing about the rest

The owner asked to try the lists **as a table with rows and columns** — which is
what a real client book is: one row per client, and columns for the number, the
phone, the contract.

## Measured

`import_user_names` reads the header and takes `name` and `type` (both required)
and `source`/`licence` if present. **Every other column is ignored, and the
report does not mention it.**

With a client table built from the film's own people —
`name,type,personnummer,phone,email`:

```
import → Ok(added: 8, already_known: 0, refused: 0)
search_vault("970707-0000")  → 0 rows      ← the number was never learned
search_vault("Nadia")        → 1 row       ← the name was
```

And with the columns that matter most, the ones no shape rule knows —
`name,type,kundnummer,avtal` — against a receivables page holding those numbers
and no name at all:

| | the client's own numbers leaving in the clear |
|---|---|
| before the import | **3 of 3** |
| `import → Ok(added: 2, refused: 0)` | |
| after the import | **3 of 3** |

**Nothing changed, and the report said everything succeeded.**

## Why this is the important one

- It is the owner's stated case from the first day: *a bank builds its client
  list once, on one device, not on every device.*
- The name is the easy half — shapes and packs often find a person anyway. The
  **hard half is exactly what the table drops**: a customer number, a contract
  id, an internal account. 051 already recorded one of these escaping in a real
  letter (`Rechnung Nr. 2026-04471`), and a client table is precisely how a
  person would have taught it.
- And it fails **upward**: `refused: 0` reads as «my table is in». A person who
  imports a client book and is told nothing was refused has been told something
  untrue about their own protection.

This is 054's defect in a second place: there the **list name** was accepted and
thrown away in silence; here three **columns** are. One rule covers both —
**nothing is discarded quietly.**

## Do

1. **A column of values joins the book.** Beyond `name`/`type`, a header may
   name a kind — `kundnummer`, `personnummer`, `telefon`, `e-post`, `avtal`,
   `konto` — and each cell is learned as a value of that kind **for the person
   on that row**, under the scope the import was given. One row is one client,
   which is what a client book is.
2. **A column nobody can place is named, not dropped.** The report gains the
   columns it did not use, and the sheet says: *«three columns were not used:
   kundnummer, avtal, konto — name the kind for each, or they stay out.»*
   A person must be able to see the difference between «imported» and
   «imported the names».
3. **`NameImport` counts values too**, so `added: 2` can never again mean
   «two names and six numbers ignored».
4. **Guards, and the first must bite today:**
   - import `name,type,kundnummer,avtal` and the receivables page comes out with
     **0 of 3** numbers in the clear;
   - a header column that names no kind appears in the report by name;
   - a row whose number cell is empty is not a refusal — a client without a
     contract is still a client.

## And the question it raises for the owner

A table teaches values **per person**. That makes the row the unit, and the row
is a client. So the natural home for an imported table is **the client's book**
(`Scope::Profile`), not «everywhere» — twenty clients of one bank are not facts
about the world. The import asks how far a list reaches; with a table, the
honest default is the client. **His word on that.**
