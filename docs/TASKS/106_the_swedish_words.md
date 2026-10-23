# 106 — The Swedish words: the one list speaks Swedish

**Owner, 23 October («نعم أطلق الترجمة السويدية لـ ed الآن»):** the Swedish slot stops carrying English words (56-أ). Builder: **ed**. Branch `feat/the-swedish-words` off **24c74db** (paper 104's tip — the translation must stand on 104's corrected sentences, not on the ones the review graded false). Arabic explicitly waits until after publishing — it is a base, not a translation (the script-family doctrine), and nothing in this paper touches it.

## 1 · The work

Every sentence in the one list (691 at `check_the_one_list.py`'s last count) gets its Swedish in `app_sv.arb`, through the same gen-l10n door as German. No meaning moves: the English sentence is the claim, the Swedish says the same thing to a Swede — where German already made a choice (formality, a technical term, the «du/Sie» register's Swedish cousin «du», which is standard Swedish software register), the Swedish follows the same choice. Names of things the product coined (vault, session, z-pdf, block) translate the way the German did, consistently, once — a glossary first, then the sentences.

## 2 · The guards move where they must

- Where a pinned sentence exists in three languages (the refusal sentences, the one-list pins, G66's family), the Swedish pin is written with the translation — a guard that still pins the English word in the sv slot after this round is the round failing.
- `check_the_one_list.py` and the language gates green; the English suite untouched (no English sentence moves in this paper — a Swedish round that edits app_en.arb is out of scope and comes back as a question).
- README's 56-أ line (just rewritten in 104) moves to the new truth — worded as what is measured: the Swedish words exist and the gates check their shape.

## 3 · The named debt: the owner's eye

The translation lands machine-first by ed's hand; **the owner is the only native reviewer and his review is a post-publish round of its own**. Until that review closes, nothing on the site or in README may say Swedish is «complete» or «reviewed» — the honest sentence is that the interface carries Swedish and its review is listed. The owner's review round gets its own paper when he takes it.

## Not in this round

Arabic (after publishing, as a base-first project aimed at Doha); the Swedish detection pack (it already exists and is not this paper); any English or German sentence; the site's language pages.

## Measurement

Full gates green on ed's base; the count of sv sentences equals the count of en sentences by the one-list census; report to the lead. The lead merges after 104 and 105 are both in, measures, and the owner's word pushes. Publishing tomorrow does not wait for this paper: if 106 is green before the final packaging it rides the release; if not, it is the first post-publish merge — the owner's call on the day.
