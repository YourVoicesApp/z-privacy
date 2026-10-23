# 105 — The site says what is measured: two sentences from the outside review

**Source:** `docs/ATTACKS/CLAIMS_REVIEW_2026-10-23.md`, findings 2 and 3 outside the claims. Builder: **e2** (site is the second seat's). Branch off `e7a8f8f`; **do not touch `docs/CLAIMS.md`** — that file is paper 104's (ed), and the two branches must not collide. If a fix here wants a CLAIMS.md line, write it in your report and the lead carries it.

## 1 · «works with any AI service» (finding 3)

`site/en/index.html:79`: «Z Privacy is provider-independent and works with any AI service, including local models.» The tree ships a finite provider set (`anthropic.rs`, `deepseek.rs`, `google.rs`, `moonshot.rs`, `openai.rs`) plus user-supplied base URLs. «Any AI service» is not measured and cannot be. The sentence narrows to what the tree shows — the named providers, and any service reachable through a compatible API at a base URL you give it, including local models — worded for a reader, not a lawyer, in all three languages identically (the 12-identical-sentences doctrine of the download pages applies: one fact, three tongues, same promise). Check first what the base-URL door actually accepts (which provider adapters take a custom base URL, and is a local model one of them in a measured test) — the new sentence may claim exactly that and nothing more.

## 2 · «nothing is lost silently» (finding 2)

`site/en/guide/index.html:118` says the vault-changed-elsewhere sentence means «nothing is lost silently». C-07's own limit is one machine, one data directory, and the session file's guard measured in one process (paper 102). The guide line gains the same boundary in a reader's words — on this machine, between copies of Z on it — or is reworded to describe the refusal sentence without the universal promise. German and Arabic move with it.

## Rules

No new claims, no new controls, nothing removed but overreach. The guide's key-comment blocks stay true to `app_en.arb`. `check_site_claims.py` and `check_site.sh` green at the end — except the download pages' placeholder red, which is lawful until publishing day and must still be red when you finish (if your run turns it green, something swapped artefacts that must not exist yet).

## Measurement

e2: site gates in tree mode green (placeholder state reported, not failed), the three languages carry the same two corrected facts, and the report names the measured truth of the base-URL door. The lead merges and measures; the owner's word pushes.
