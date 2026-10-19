# 094 — What we claim: one file in git, every claim with its limit and its proof, and a gate that refuses a claim without one

**Owner, 19 October:** «نجعل ملف مراجعة في git نحدد فيه نقاط الادّعاءات التي ندّعيها في التطبيق، ونطلب من نموذج خارجي مراجعة الملف، الهجوم على الكود، ثم تثبيت ما هو الصدق وما هو مبالغ فيه.» The one thing before publishing.
**Base:** lead line at `2b4fad9` (594 · 0 · 0, rust 792, dart 405), pushed.
**Builder:** ed. Branch `fix/what-we-claim` from `2b4fad9`. No push. You will not meet e2 (he is in `vault.dart`, `vault_forms.dart`, `why_sheet.dart`, `name_review.dart`, `send_sheet.dart`, `entity_detail.dart` and the ARBs); you touch `docs/`, `scripts/`, `gates.sh`.

## The file

`docs/CLAIMS.md`, English, public. One section per claim, in this fixed shape:

```
## C-07 · Two copies of Z never lose a write
**We say:** «Another copy of Z Privacy changed this vault…» (the app's own sentence, key troubleVaultChangedElsewhere)
**The limit:** one machine, one data directory; two machines sharing a folder over a network file system are not measured.
**The proof:** z_core/tests/two_copies_never_lose_a_write.rs (40 trials, 0 silent losses); the lock is std::fs::File::lock on writing.lock taken in session::with_core; gate G43 reads the shape.
**Measure it yourself:** cargo test -p z_core --features fake_provider,test_clock,measuring two_copies_never_lose_a_write
```

Four lines, always the same four: what we say (quoting the sentence the app or the site actually shows, by its key or its page), the limit (what the claim does **not** cover — the honest half, written first-class, never in a footnote), the proof (test file, gate number, or source line; a thing that exists in this tree at this commit), and the command a stranger runs.

A fifth section at the end, **«What we do not claim»**, in the same voice: no anonymity from the provider (address, time, model and the protected text travel); pseudonymisation, not anonymisation; no machine learning in the scanner, so what it does not catch is listed (the attacker's scanner debts B1-1, B1-2, B1-4, and the 17 Oct list: zero-width, NFD, payment card, English NI, half a name, English birthdate, Postfach, bank name); no independent security audit yet; Linux and Windows only; the chat's history travels with every question, protected.

## The claims, as the lead names them (you attach the proofs; where a proof does not exist, say so in the file and leave the claim there with «unproven» — a claim removed is a claim hidden)

1. **Only the protected version is sent to AI through Z Privacy** (the first screen's sentence; rule 62). Proof: the contract has no text door (G2b: every ask/send takes a handle; G36 names the four doors), the gateway's Request carries a PayloadHandle, the attacker's B1 wire capture.
2. **Your original data stays on this device unless you explicitly copy restored content.** Proof: the exit law (payload_to_take_out audits every door; G31's seats), the clipboard is emptied first (081), «Copy Restored» asks.
3. **No account, no ads, no analytics, no Z Privacy server; no network at first run; the only network calls go to the provider the person chose.** Proof: the attacker's first-run TCP/UDP measurement, the gateway's one send path, providers list.
4. **Protection is permanent:** a word that took a token is a vault block, never deleted; it comes back by name a year later, from any session (rules 49–51, 58, 59). Proof: the vault model tests, G40 (removal-verb shape, 10 doors), delete_entity exempts and never erases.
5. **The vault is one encrypted file**, the passphrase is never stored, the auto-lock lives in the core and every way in checks the clock (`judge_idle`), and a provider key has two homes and no third (sealed in the vault or in memory for this run), never a file in the clear and never returned to the interface. Proof: `vault/mod.rs`, the storage contracts (`check_storage_contracts.sh`, nine), G15 names the files Z writes, the attacker's disk scan (no original, no passphrase, no key found in UTF-8/UTF-16).
6. **Two copies never lose a write** (as above).
7. **Documents are not kept** — only the one in the preview that has not left; a session's documents are encrypted under the session's key; deleting a session destroys the key and nothing can be unprotected again (rules 54, 55; the Sessions room's own sentences). Proof: session file tests, format 6 reader, G22.
8. **Session isolation:** the same name in two sessions takes two different tokens; a token from another session comes back unknown, never restored (the lib's contract C1–C7 and its vectors; the app's `a7` shape). Proof: name the tests on both sides.
9. **Reader limits are named numbers, not «too large»:** a PDF that unpacks past the ceiling is refused by name (CompressionBomb ratio, document ceiling max(16 MiB, 32× file), 8 MiB stream), a cut stream is never imported, ObjStm and XRef bombs are refused before load. Proof: the reader tests, the attacker's B3 bombs re-run, the sentences in the one list.
10. **The scanner is rules + packs (de, en, sv) + your vault, no model;** what it finds is a starting point and review is explicit — no suggestion is ever silently treated as safe and there is no «send anyway» (the Privacy room's sentence). Proof: the open-suggestions law (`OpenSuggestions` refusal at every door), G38 the census of doors.
11. **z-pdf round trip:** a document that left with tokens is read back into its names from the vault, never scanned, never protected, never put on a bench; a token no key can restore stays literal and is named. Proof: the z-pdf tests, the lib's V1-J two-owner proof, `the_way_back`.
12. **The chat carries only protected exchanges;** the core builds the history itself from stored turns, the document never leaves twice unprotected, and a lock does not end a chat (55-و, 67, 68). Proof: `the_chat_so_far`, the three-moment test, `the_lock_gives_the_session_back.rs`.
13. **A release says nothing about its builder:** no path of the build machine, symbols stripped, a stamp naming the commit, two product hashes (Linux and Windows). Proof: `package_linux.sh`, `package_windows.sh`, G53.
14. **Every sentence on the glass is true of the tree it ships in:** the sentence gates (G41 and kin), the one list, no sentence outside it, no invisible character in it (G50, G51, G55).
15. **The measurement is public:** `scripts/gates.sh`, the numbers in `docs/MEASURED_ON_LINUX.txt`, the Windows job's report.

## The gate

`scripts/check_claims.py`, run by `gates.sh` as **G56**: every `## C-NN` section has exactly the four lines; every path named under «The proof» exists in the tree; every gate number named exists in `gates.sh`; every test name named exists in a test file; every key named exists in `app_en.arb`; no section is missing «The limit». A claim marked «unproven» is allowed and counted, and the pass line prints «N claims · M proven · K unproven» so the number is on the record. Pin it red by naming a test that does not exist.

## What the external review gets

The owner hands an outside model the repository link and `docs/CLAIMS.md` with the lead's prompt (written separately, not in this paper): attack each claim through its proof, run the command, look for the counterexample, grade each claim **confirmed / exaggerated / false**, and do not fix anything. The review's findings come back as a paper, like the attacker's.

## Measurement

Linux gates green from a plain debug build; report the head, the three numbers, and what the paper got wrong — especially any claim whose proof is thinner than the lead believes, said plainly in the file.
