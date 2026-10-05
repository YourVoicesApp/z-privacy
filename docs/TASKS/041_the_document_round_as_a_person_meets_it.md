# 041 · The document round, as a person meets it

**Status: ORDERED** · 6 Oct 2026 · lead → `mono-privacy-88` · from `main` (`d1ed2ed`) · **four small branches, delivered and measured one at a time, in this order**; no change to the scanner's rules, the packs' data or the gateway's contract.

## Where it comes from

The owner installed the published Linux build (`ac948be`) on a cleaned machine from the web and used it for an evening. The live round worked end to end (a German text went out as tokens, the answer came back, the names were restored on his device). Everything below is what stood between him and that result, in his order, each measured by the lead in the code before it was written here.

## A · `fix/a-door-you-can-see` — the back button and the AI door

1. **Back, one step.** Today the only way home is tapping the mark + «Z Privacy» in the top bar (`workspace.dart`, `_TopBar`, an `InkWell` with no arrow, no tooltip, no button shape). Build: a visible back control at the left of the top bar (arrow + «Documents» or the owner's word), tooltip, keyboard `Alt+Left`; the mark stays tappable.
2. **The AI door.** The provider/model/mode choice lives inside the send sheet, behind «Review what will leave», which is disabled until every suggestion is answered, and the connect form sits under the «Direct API» door at the bottom. Build: an **AI** button in the top bar (the owner's board of 3 Oct) that opens the same sheet at any time; **in the sheet the order becomes: provider · model · mode first, then the text, then the doors**; the connect form for an unconnected provider at the top beside its name; sending stays gated by the open suggestions, and says so.
3. **The model list is the whole catalogue.** `_ModelAndMode` lists `available` models only, so with one provider connected a person sees one provider's models and nothing of the rest. Build: every model from `models()`, grouped by provider, the unconnected ones greyed with «Connect» beside them; switching a model changes `usage.model_id` on the next send (a test on the fake provider proves the switch).

## B · `fix/once-per-name` — the review

4. **One decision per name.** `answer_finding` protects one range (`protect_range(record.start, record.end)`); the hand path already spreads («in 3 places»). Build: Protect / Not sensitive / Always on a suggestion apply to **every suggested finding with the same text** in the document (same kind), in the core, in one call; the card says «in N places»; Skip stays per place. Red first on DE-1 (the writer's name is suggested in more than one place).
5. **The count on the card.** The suggestion card shows the places count (from 4); the Names panel already does for candidates.
6. **«Always» says what it needs.** `require_open_vault()` refuses «Always» when there is no vault; the owner saw nothing happen. Measure where the refusal sentence is drawn; build: the button itself carries the state — enabled with the vault open, otherwise «Always · needs a vault» which opens the vault screen. One sentence beside it explains what Always is: «protect this value in every document from now on».

## C · `fix/a-selection-that-stays` — the selection

7. The owner, twice: «التحديد يظهر متقطعاً ثم يختفي». Measure on `ac948be` with the German letter: drag across a run that contains protected words, release over a protected word and outside one; write what happens. Then: the selection is painted **above** the washes (washes translucent, the 4 Oct open decision — the owner's word in this paper is yes), and releasing a drag over a mark never opens the mark's card and never collapses the selection; a tap without a drag still opens it.

## D · `feat/your-own-names` — languages and names

8. **The language list is a list.** The pack choice (first run, settings, top bar) shows a fixed few; build: a dropdown fed by `packs()`, every pack this build carries, the active one marked; nothing hard-coded.
9. **Add a name, import a list.** There is no plain way to add names: candidates must appear first, and the vault forms are for identities. Build: in the Names panel, **«Add a name»** (text · given/family/person/company · always/suggest) into user knowledge, and **«Import a list»** from a CSV `name,type` (type ∈ given · family · person · company) into the same user layer, with a count back («312 added · 4 already known · 2 refused»); both need the vault and say so the way 6 does. The owner is preparing Swedish and German lists for this; their provenance is his and stays with the file (`source,licence` columns optional, kept if present). **Not into the packs** — pack data changes are 038-B's, with a licence file.

## Done means (per batch)

- Each batch: red first on the behaviour it changes; `flutter test` the gates' way, gates, clippy, counts before/after; every German/Swedish row of `docs/THE_NUMBERS.md` unchanged to the digit (B changes no number: it changes how many clicks a number costs — say the click count on DE-1 before/after).
- Strings in en only (the UI language is a later decision, 038-D); no model name in Dart (the existing test).
- Report per batch, then stop for the lead's measurement before the next.

## Not in this task

- New providers in the catalogue (042, after this): DeepSeek · xAI · Mistral · Google through their official OpenAI-shaped endpoints, each a file.
- A conversation of several turns (needs roles in `Context.history`, the deferred debt) — the AI door of A opens the one-answer sheet.
- 038-A/B/C/D/E (the measured debts) and the Arabic pack.
