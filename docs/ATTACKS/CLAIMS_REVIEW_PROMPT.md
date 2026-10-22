# The prompt the owner hands an outside model with `docs/CLAIMS.md`

Written by the lead, 20 October 2026, for paper 094's last step. The owner pastes the text between the rules into a fresh session of an outside model (not one that built this code) together with the repository link and the commit sha, and brings the answer back as a paper under `docs/ATTACKS/`. Nothing is fixed during the review.

---

You are reviewing the claims a software product makes about itself. The product is Z Privacy, a desktop app that replaces sensitive values in a text with tokens on the user's device before the text is sent to an AI model, and restores them locally afterwards. The repository is `<link>`, branch `lead/the-day-of-the-attack`, commit `<sha>`. Clone that commit; do not review a later one.

Read `docs/CLAIMS.md` first. It has sixteen claims, each in four lines: what the product says, the limit the authors themselves put on it, the proof they name (a test, a gate, a source line), and a command they say a stranger can run. Then a section «What we do not claim». Two claims are marked «unproven» on purpose.

Your job is to grade every claim, C-01 to C-16, with one of three words and the reason:

- **confirmed** — you ran the command or read the proof, it exists at this commit, it measures what the claim says, and you could not construct a counterexample.
- **exaggerated** — the claim is true of less than it says: the proof covers a narrower case, a limit is missing from the limit line, or the sentence the product shows promises more than the test measures.
- **false** — you found a counterexample, or the proof does not exist, or it measures something else.

For each claim, do these things and show your work:

1. Run the «Measure it yourself» command from the repository root (Rust: `cargo test -p z_core --features fake_provider,test_clock,measuring …`; Dart: from `apps/flutter_app` after `flutter build linux --debug`; the whole set: `bash scripts/gates.sh`). Paste the last lines of the output. If a command does not run, that is a finding, not your problem to fix.
2. Open the proof it names. Say in two sentences what the test actually asserts, in your own words, and whether that is the claim or something narrower.
3. Try to break it. The ways that matter here: a text where the sentence the product shows would be false; an input the test never gives (another encoding, another language, a document with two of a thing, a second process, a locked vault, a session deleted mid-way); a path through the code the gate does not count. Where you need to run the app, run it against `z_core/tests/fixtures/` and a vault you create with a test passphrase; never a real document of yours.
4. Read the limit line against the proof. A limit the authors did not write but should have is a finding of its own.

Then read «What we do not claim» and answer two questions: is anything in it actually claimed elsewhere, on the first screen, in the settings rooms, or on the website `z-privacy.com` — including `site/<lang>/guide/`, the usage guide, which quotes thirty-four of the product’s own control sentences and is the page that carries the most of them? And is there something the product obviously implies that is in neither list?

Rules of this review:

- **The guide pages are part of this review** (`site/en/guide/`, `site/de/guide/`, `site/ar/guide/`). Every sentence on them is a claim about how the product behaves. Each control they name is keyed to `apps/flutter_app/lib/l10n/app_en.arb` in a comment block at the top of the page: check that the control exists, that it does what the page says it does, and that the page promises nothing `docs/CLAIMS.md` does not.
- **The three download pages are part of this review** (`site/en/download/`, `site/de/download/`, `site/ar/download/`): they print two fingerprints, a command to check them with and a paragraph about what Windows will say. A sentence there is read by somebody about to run an unsigned installer, so «is this measured?» and «does it promise more than it can?» are asked of every line of them.
- Do not fix anything, do not open a pull request, do not push. A red is the report.
- Grade by what is in the tree at this commit, not by what the commit message or the documentation says the authors intended.
- A claim that holds only with a feature flag, a test build or a developer setting is **exaggerated** unless the limit line says so.
- A claim whose proof is a gate: open `scripts/gates.sh`, find that gate, and say what it greps for. A gate that matches a name is not a gate on a shape; say so when you see it.
- Quote sentences from the product and the site exactly, with the file and the key.
- Where you are not sure, say «not measured» rather than guessing either way.

Write the result as one Markdown file in this shape:

```
# Claims review of Z Privacy at <sha> — <model name>, <date>

## Summary
<n> confirmed · <n> exaggerated · <n> false · <n> not measured

## C-01 · <title> — CONFIRMED | EXAGGERATED | FALSE | NOT MEASURED
Command run: … (last lines)
What the proof asserts: …
Counterexample tried: … (result)
Limit line: complete | missing: …
Verdict reason: …

… (C-02 … C-16)

## «What we do not claim»
…

## Findings outside the claims
…
```

Be exact and be short. One counterexample with its input and its output is worth more than a paragraph of doubt.

---

**For the owner:** fill `<link>` and `<sha>` with the merge commit that carries `docs/CLAIMS.md`, hand the model the repository link so it clones rather than reads a pasted file, and bring the file back as `docs/ATTACKS/CLAIMS_REVIEW_<date>.md`. Everything «exaggerated» or «false» becomes a paper before the report is published; everything «confirmed» is what the report says.
