# 120 — French and Spanish: the numbers that matter, and names by their shape

**Source:** the owner's rulings of 2 November 2026, given one by one. The Z lead holds the owner's delegation to 31 December 2026; the owner reviews. Builder: **ed**. Branch `feat/french-and-spanish-packs` off the Z lead tip `01bb6b6`, in a tree of your own (`git -C ~/z/mono-privacy worktree add ~/z/build-ed-120 -b feat/french-and-spanish-packs 01bb6b6`), with **its own `CARGO_TARGET_DIR`** — a shared one runs another tree's tests.

## What the owner said

> «بالحزم لا نحتاج اسماء فرنسية واسبانية. ما نحتاجه فقط اي شيء يخص الأرقام، ونجعل خزنة الأسماء لتحديث مستقبلي. فقط أشكال الأرقام المهمة، ونكتب ذلك صراحة في الويب.»
> «ويمكننا أيضًا إضافة قاعدة بسيطة: الكلمة التي تبدأ بحرف كبير ترشَّح على أنها اسم.» — and: **Suggested**, so that an accepted one is kept in Z's vault.

## What is built

Two packs, `fr` and `es`, in `z_core/src/scanner/packs/`, on the shape of `de`/`sv`, active the way the others are.

### 1 · Numbers (each with its check where one exists; a failed check is not a find)

| Pack | Kind | Shape |
|---|---|---|
| fr | `SocialInsuranceNo` | **NIR**: 13 digits + 2-digit key (97 − n mod 97), spaces allowed; Corsica 2A/2B |
| fr | `TaxId` | **SIREN** 9 digits and **SIRET** 14 digits, Luhn (La Poste SIRET exception named) |
| fr | `TaxId` | **VAT** `FR` + 2-character key + SIREN, the key checked against the SIREN |
| fr | `TaxId` | **numéro fiscal** (SPI): 13 digits starting 0–3 — no public check, so **Suggested** unless a label («numéro fiscal», «SPI») stands beside it |
| fr | `Phone` | `+33` or `0` then 9 digits, in the usual groupings |
| es | `IdCard` | **DNI**: 8 digits + check letter (mod 23) |
| es | `IdCard` | **NIE**: X/Y/Z + 7 digits + check letter |
| es | `TaxId` | **CIF/NIF** of a company: letter + 7 digits + control digit or letter |
| es | `TaxId` | **VAT** `ES` + the NIF/CIF/NIE, checked as above |
| es | `SocialInsuranceNo` | **Seguridad Social**: 12 digits, (first 10 mod 97) = last 2 |
| es | `Phone` | `+34` then 9 digits starting 6, 7, 8 or 9 |

- **No postal code** (five digits in both countries; it would protect every ordinary number).
- **IBAN and BIC are untouched**: the general rules already cover every country.
- Auto or Suggested follows the packs' existing discipline: a value whose check passes and whose shape cannot be an ordinary number → Auto; anything weaker → Suggested. Name every choice in the pack's head comment.

### 2 · Names by their shape — Suggested only

- French and Spanish write a person's name with a capital and write months, days and nationalities in lower case, so the shared engine (`people.rs`: two capitalised words, a title before a name, never a lone capitalised word) fits both. **Give each pack only what that engine asks of a language**: the function words that open a sentence and are no name (Le, La, Les, Ce, Cette, Un, Une, Il, Elle, Nous… · El, La, Los, Las, Este, Esta, Un, Una, Yo, Nosotros…), and the titles (Monsieur, Madame, Mademoiselle, M., Mme, Mlle, Maître, Me, Docteur, Dr · Señor, Señora, Señorita, Sr., Sra., Srta., Don, Doña, D., Dña., Doctor, Dra.).
- **Every name these packs find is Suggested, never Auto** — there is no name library behind them. A name the person accepts goes into Z's vault as every accepted name does today; nothing new is built for that, prove it with a test.
- **No name list.** A names vault for French and Spanish is a later update.

## What is not in this paper

- Any sentence of the interface or the site (paper 121, e2, at the same time).
- A French or Spanish names library.

## Acceptance

Tests, each named as a sentence, on **invented fixtures only** (a French and a Spanish letter you write, with invented people and numbers made valid by their checks — never the owner's documents, never the owner's vault):

1. Every row of the table found with a valid check; the same value with one digit changed **not** found.
2. A five-digit postal code is not found; an IBAN is found by the general rule as before.
3. «Madame Dupont», «Juan García», «Sra. López» → Suggested persons; «Le», «Lundi» at a sentence start, «janvier», «français» → nothing.
4. Nothing from the names rule is ever Auto in these packs.
5. An accepted French name is in the vault and is found Auto in the next document, by the existing library path.
6. The en/de/sv/ar suites are unchanged in their counts.

All gates green with `scripts/gates.sh`. A named commit on your branch; nothing pushed. Report the SHA, the counts on your two fixtures (auto · waiting), and every check you could not find a public rule for.
