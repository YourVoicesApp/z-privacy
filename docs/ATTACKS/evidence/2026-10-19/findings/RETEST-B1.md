# RETEST B1 — commit 2b4fad9

**Commit:** `2b4fad93cc26b282e6fa9773ad2275544dcc7ee8`  
**Stamp:** `z_core 0.1.0 · 2026-10-19 · 2b4fad9`  
**Probe:** `/home/monopeaks/z-attack-2b4fad9-evidence/harnesses/b1-probe`  
**Data:** `/home/monopeaks/z-attack-2b4fad9-evidence/scratch/b1/data` (`set_data_dir`; `XDG_DATA_HOME`/`HOME` remapped to scratch)  
**Fixture:** `fixtures/docs/ألماني 1.txt` sha256 `4a01beb4fb80546b91a9743b5b33064ef12beb96ad18348edda3d16fba7c9862`  
**Not touched:** `~/.local/share/zprivacy`, `~/mono-privacy`, product tree under `z-attack-2b4fad9`

Logs: `logs/B1-run.txt`, `logs/B1-direct-mode.txt`, `logs/B1-disk-search.txt`, `logs/B1-payload-take-out.txt`, `logs/B1-question-iban-*.txt`, `logs/B1-build-iban-ok.txt`, `logs/B1-chat-to-take-out.txt`, `logs/B1-pdf-readback.txt`.

The four-word vocab (STILL FIXED / REGRESSED / PARTIALLY FIXED / NOT REPRODUCIBLE) is used where it fits. B1-1 and B1-2 were never fixed; they still reproduce, so they are recorded as **STILL OPEN** rather than forced into that list.

---

## Direct Mode

**STILL FIXED**

1. **What I did:** Grep `ask_model_directly`, `Body::Direct`, `sendOriginal`, `askModelDirectly`, `askModelWithTheOriginal`, `chooseOriginal`, and `The original text` over `z_core`, `gateway.rs`, Flutter `lib/`, tests, and `gates.sh`. Read every public `send` / `ask*` signature. Did not launch a GUI.
2. **What should happen:** If first-run promises «only the protected version is sent», no door sends the original.
3. **What happened:** No live door remains. `send(PayloadHandle)` and `ask_model(PayloadHandle, …)` on Rust and Dart. `Request.payload: PayloadHandle`. Chip «The original text» exists only as a deletion comment and as `findsNothing` in tests. Remaining name hits are G62 gate strings and test negatives.

---

## خ2 / B1-3 · IBAN becomes a Person, then jams every exit

**STILL FIXED**

1. **What I did:** German letter, pack `de`, Protect on every suggestion. `set_question("Was schuldet Markus Feldmann Frau Katrin Sommer? IBAN DE89 3704 0044 0532 0130 00")`. Inspect `question()` marks and token values. `build_payload`. Also hand-`protect` the four letters `IBAN` on a second bench and `build_payload` again.
2. **What should happen:** Names and the IBAN *number* leave as the document’s tokens. The label «IBAN» is not a person. Exits stay open. The previous refusal `a protected value still stands 5 time(s) where at most 2 was expected` must not return.
3. **What happened:** Marks = four Person + one Iban; no mark on `IBAN`. Token values: Markus, Feldmann, Katrin, Sommer, `DE89 3704 0044 0532 0130 00` — **no token value `"IBAN"`**. Safe text keeps the label in the clear: `…? IBAN __Z_94D9_IBAN_AB9C5536__`. `build_payload` succeeded. `payload_to_take_out` and `ask_model` stayed open. Hand-protect of the word: `Applied { places: 2 }`, build still succeeded (audit no longer counts `IBAN` inside `__Z_…_IBAN_…__`). Exact previous error **did not occur**.

---

## B1-1 · Postfach 4410 leftover after finished review

**STILL OPEN** (original still reproduces; not STILL FIXED, not REGRESSED, not PARTIALLY FIXED, not NOT REPRODUCIBLE)

1. **What I did:** Protect every suggestion including address id=19 `04179 Leipzig`. `payload_to_take_out`. Byte-search. Same leftover checked on `chat_to_take_out` and PDF reader round-trip.
2. **What should happen:** The PO box on that line is taken with the address, or is its own finding.
3. **What happened:** Unchanged from 84832a0. Line still reads `Kundenservice · Postfach 4410 · <ADDR token>`. Never a finding. Also leaves on the new fourth door.

---

## B1-2 · Sparkasse Leipzig leftover after finished review

**STILL OPEN** (original still reproduces)

1. **What I did:** Same finished review. Search payload / chat / PDF read-back. Inspect findings for a bank-name offer.
2. **What should happen:** The bank on `Bankverbindung:` is offered like the GmbH, or review does not claim every identified value was answered.
3. **What happened:** Unchanged. `Sparkasse Leipzig` stands next to tokenised IBAN and BIC. No finding. Also leaves on `chat_to_take_out`.

---

## Also measured (not in the four-item list)

| Item | Status |
|---|---|
| Disk (`vault.zv`, `settings.zcfg`, `sessions/*.zs`, `writing.lock`) | Holds — no UTF-8/UTF-16 hits for originals, passphrase, or probe key |
| `chat_to_take_out` (fourth door) | Present; copy is tokenised; carries B1-1/B1-2 leftovers |
| Product z-pdf writer | Not Tested (would write immutable Flutter build cache); source has no `/Info` |
| GUI / first-run TCP | Not Tested (would risk real vault / worktree writes) |
| B1-4 amount / date-line city | Still leaves (`184,60 €`, `Leipzig, 14. Oktober 2026`) — NOTE, as before |
