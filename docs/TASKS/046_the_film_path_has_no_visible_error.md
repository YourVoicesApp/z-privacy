# 046 · The film's path, in English, with no visible error

**Status: ORDERED** · 7 Oct 2026 · lead → programmer · branch `fix/the-film-path` from `main` (`fad220f`) · **one commit per item, measured before the next; the German and Swedish numbers must not move a digit.**

## Where it comes from

The owner's decision for Friday's three-minute film: **two English documents of the same client.** Clean the first by hand, drop in the second, and the screen itself shows the idea — «كل جلسة تحتاج وقتاً أقل من الجلسة السابقة». Web Summit's PITCH is three minutes + three minutes of questions, so the film is also the pitch.

The two documents are written and invented: `~/Documents/film/EN-1_engagement_and_invoice.txt` (an engagement letter and invoice, 7 people) and `EN-2_payroll_query.txt` (a payroll query to the same client, 7 people, 2 of them new). They become fixtures `z_core/tests/fixtures/` as part of item B, with a guard, like DE-1.

## What the lead measured on `fad220f`, before writing this

A rig against `z_core::api`, English session, the two files:

| | EN-1 cold | EN-2 cold |
|---|---|---|
| findings | 11, all automatic | 11, all automatic |
| **persons** | **1** — and it is `Eleanor Whitfield, Finance Director`, the job title inside the token | 1, the same |
| candidates (Names panel) | **0** | **0** |
| not found | Priya Raghunathan · Dermot Hale · Mairead Quinlan · Callum Stride · Rowan Pellbrook · «Dear Ms Whitfield» · (EN-2 also Owen Brackley · Sian Doherty) | |

Then the owner's own demo: a profile for the client, nine hand protections on EN-1 at `Scope::Profile`, then EN-2 in the same profile:

```
EN-1 cleaned by hand            9 acts  (8 Applied + 1 Snapped: «Hale» inside «Dermot Hale» — correct)
EN-2, same client, second doc   8 people protected by themselves
                                12 of 14 findings automatic, not one person asked
                                0 acts
```

**9 → 0 is the film.** And three defects stand in the picture:

## A · The session's language must reach the rules — the one place where «German only» is still true

`z_core/src/ops/mod.rs:1695`:

```rust
fn active_sets(s: &Session, vault: &VaultStore) -> Vec<String> {
    let from_profile = s.profile_id.as_deref().map(|id| vault.languages_of(id)).unwrap_or_default();
    if from_profile.is_empty() { vec![s.pack_id.clone()] } else { from_profile }
}
```

The profile's list **replaces** the session's language, and `create_profile` (`ops/vault.rs:816`) is born `languages: vec![default_pack_id()]` — this device's German. So: make a profile for the client, choose English in the bar, and the English label rows never run. That is why the measurement above lost `Account number`, `Client number`, `VAT number` and turned three automatic phones into three questions the moment a profile was in play: only the shape rules survived, because the label rows being asked were German ones.

**Build:** the session's language is **always** active, and the profile's languages are **added** to it — the comment two lines above `scan` already says a document may be German and English at once. And a new profile starts with the language of the session that created it, falling back to the device's. Red first: a profile session in `en` finds `Client number: 440821`.

## B · An English pack — the cues, and not one name of data

`installed_packs()` is `[de, sv]`, so `packs::scan` and `packs::discover` return nothing for `en`: no salutation rule, no pair rule, no discovery, and **the names the person taught never reach the engine** (they arrive as `names` and are dropped with the missing pack — only vault *values* survive, through `vault_pass`). An empty Names panel in English is this, not a dictionary gap.

**Build** `z_core/src/scanner/packs/en.rs`, `locale: "en-GB"`, **`names: ""`** — an empty dictionary on purpose, so a bare given name still opens nothing and the 11-to-1 guard keeps its meaning:
- salutation: `Dear Mr/Mrs/Ms/Miss/Dr/Prof X` → Person **Auto** (the honorific list already exists in `sets/en.rs`);
- the closing: `Yours sincerely,` / `Kind regards,` / `Best regards,` followed by a line that is a name → Person **Auto** for the signature, and the pack's `copulas` empty as German's are;
- the pair rule and discovery exactly as the pack contract defines them, so a taught half makes a pair and an unknown surname beside a taught given name becomes a **candidate**.

**Acceptance on EN-1/EN-2:** persons found ≥ 6 of 7, candidates ≥ 4, **false protections 0**, no caption or job title becomes a person; DE-1 stays 7/7 and 0 false; SV-1, SV-16, DE-2, DE-3, DE-4 unchanged to the digit.

## C · A name ends where the name ends

`Contact person: Eleanor Whitfield, Finance Director` is one Person finding, job title inside. `Validator::Name` must stop at a comma and at the end of the line. **Guard what this must not touch:** the German reversed pair «Nachname, Vorname» and the Swedish «X, role» rule both read across a comma on purpose — name them in the test so the next person cannot undo one with the other.

## D · A refusal sentence is read by a person

`protect` with `Scope::Profile` and no profile refuses with, verbatim:

```
this conversation is not in a profile, so there is no profile to remember it                      for — choose «always», or open a profile first
```

Nineteen spaces inside the sentence — a wrapped Rust literal. Sweep every `reason:` in the core for a run of two or more spaces, fix them, and add a gate that fails on one. It is the kind of thing a jury sees before it hears anything.

## E · The client is a profile, and the words are the same everywhere

Creating a client and putting this document in it must be two clicks from the document screen (the demo needs it for `Scope::Profile` to exist at all). And one vocabulary, in the dialog, the card, the panel and the explain sheet: **Once · This conversation · This client · Everywhere** — today the core's names (`Profile`, `Always`) reach the screen in places.

## Done means

- One commit per item, red first, each measured before the next; `cargo test`, `flutter test` the gates' way, gates, clippy, counts before and after.
- `docs/THE_NUMBERS.md` gains **§5 English**: the cold table above, the hand count on EN-1, and the automatic count on EN-2 — before and after this task.
- EN-1 and EN-2 in `z_core/tests/fixtures/` with a guard that holds their numbers, as DE-1 has.
- Report per item, then stop for the lead's measurement.

## Not in this task

- An English name dictionary (its own task, with a licence file, after the film).
- 038-G, 038-B (SCB), 038-C, 043, 045 — all still queued.
- Any change to the German or Swedish packs.

---

## G · The home is the conversation (ADDED 7 Oct, the owner's first fix — before B)

**The owner, 7 October:** «دعنا نبدأ الإصلاح الأول، بدون نشر أو تجربة. الخطوة الأولى: إنشاء الخزنة ثم الانتقال إلى شاشة شات — هل هذه موجودة؟»

**Measured answer: no.** `shell.dart` puts the vault in front of the home and then shows `HomeScreen` — a composer with «Write or paste your text here…», «Open and scan», «Add a document», «Open Z Vault», «Profiles», «Settings». The model is not a screen: it is the send sheet, opened from the workspace's AI button, which exists **only once a document is open**, and the answer lands in a third screen (`answer.dart`). From the home there is no door to a model at all.

**Build — 043's heart without 043's restructure. Nothing moves in the workspace.**

1. The home's own text box becomes the conversation's line. No new widget, no new screen: the composer it already has is the input.
2. **The AI door comes down to the home.** A person who has just made a vault can ask a model without first opening a document. Same sheet, same catalogue, same modes.
3. **The answer appears under the question, in the same screen**, instead of `answer.dart` as a separate destination. That alone is what makes it read as a conversation. `answer.dart`'s reveal/copy behaviour and its clipboard warning move with it unchanged — the warning is not optional.
4. **The gate stays, and says why.** Type → protect in place → see what will leave → send. Send remains blocked while any suggestion is unanswered, and the button carries the reason. A chat that can send before the review is answered breaks the product's one promise.

**Done means**

- Red first on «from the home, with no document open, a question can be asked and its answer appears in the same screen».
- The document path's numbers do not move: DE-1 · DE-2 · DE-3 · DE-4 · DE-6 · SV-1 · SV-16 unchanged to the digit, and the English rows of §5 unchanged.
- No model name in Dart (the existing test); strings in en.
- `flutter test` the gates' way, gates, clippy, counts before/after. **No publish, no owner test** — the owner asked for the fix only.

**Order from here:** G · D · then B if the evening allows; C and E after. The panel-truth defect F found (a book imported «everywhere» with a client open protects but shows 0 rows) comes with G, because the owner may press that button on camera.
