# Claims review of Z Privacy at e7a8f8f — GPT-5 Codex, 2026-10-23

Reviewed the detached tree at `e7a8f8f48bb9da8fe2b9d07ffb661fd226785b9d`; no repository files were changed.

## Summary

8 confirmed · 3 exaggerated · 2 false · 3 not measured

## C-01 · Only the protected version is sent to AI through Z Privacy — CONFIRMED

Command run: `cargo test -p z_core --features fake_provider,test_clock,measuring --test wire_capture -- --nocapture`

Last lines: `test the_server_receives_the_safe_payload_and_nothing_else ... ok`; `test result: ok. 1 passed; 0 failed`.

What the proof asserts: `z_core/tests/wire_capture.rs` sends a synthetic protected payload to a local capture server and compares the request body byte-for-byte with the safe payload. It also checks that original/vault values are absent from the body, headers and URL; this is the gateway/provider path covered by the test, not a claim about provider-side telemetry.

Counterexample tried: the proof was inspected for a raw-text gateway and for headers/URL; the API signatures and `z_core/src/gateway.rs` use `PayloadHandle`, not a plaintext string. No counterexample in the tested path.

Limit line: complete for the stated gateway path; it explicitly leaves provider address/time/model/size and user copying outside the claim.

Verdict reason: the named test measures the sentence at the local send boundary, with the documented envelope limits.

## C-02 · Your original stays on this device unless you copy restored content yourself — NOT MEASURED

Command run: `cd apps/flutter_app && flutter test test/copy_report_test.dart`

Last lines: `LateInitializationError: Local 'dir' has not been initialized`; failing locations were `copy_report_test.dart: (setUpAll)` and `tearDownAll`; the test never reached its widget assertion.

What the proof asserts: if the native bridge exists, `copy_report_test.dart` uses one synthetic German document, checks that the button clears the clipboard first, and checks that the copied report equals the core report without selected original values. It is narrower than every exit path and does not run in this checkout because the required bridge file is absent.

Counterexample tried: the prescribed command itself was the break attempt; it fails before the test body, so no runtime copy result can be claimed from this tree.

Limit line: missing: the bridge/build prerequisite and coverage of all manual exits are not stated on the limit line.

Verdict reason: the proof source exists, but the stranger command does not measure it at this commit.

## C-03 · No account, no analytics, and no Z Privacy server — CONFIRMED

Command run: `bash scripts/gates.sh 2>&1 | grep -E "G1[a-d]?|G5[ab]?|G16"`

Last lines: the filtered invocation was started, but it entered the repository's long Flutter suite and had not reached its final filtered output when I stopped the duplicate run. The same commit's completed C-16 invocation of `bash scripts/gates.sh` produced: `636 checks, 0 failed, 0 skipped`; its matching lines were `G1a`/`G1b`/`G1c`/`G1d` PASS, `G5a`/`G5b` PASS, and `G16 wire_text() ... read only in providers (2 place(s))` PASS.

What the proof asserts: the gates check source shape: one Rust HTTP client, no Flutter network surface, and the protected wire text has one provider-side reader. The provider code contains named provider adapters and user-supplied base URLs, not a Z account/backend; this is a code-structure proof, not a tcpdump measurement of first-run behavior.

Counterexample tried: searched provider and Flutter surfaces for alternate clients, analytics calls, account endpoints and hidden network code; no second path was found. The exact filtered command itself was not allowed to finish a second full suite, so the completed full-gate run is the execution evidence used here; provider traffic remains explicitly inside the claim's limit.

Limit line: complete for Z-owned account/analytics/backend code; it correctly leaves chosen-provider terms/logs outside.

Verdict reason: the requested gate passed and its checks match the sentence within its stated limit.

## C-04 · Nothing goes out before you connect a provider — NOT MEASURED

Command run: `grep -rn "crate::providers::ask\|gateway::send" z_core/src --include=*.rs | grep -v "^z_core/src/providers/"`

Last lines: `z_core/src/gateway.rs:117: let outcome = crate::providers::ask(`; `z_core/src/ops/mod.rs:882: let raw = crate::providers::ask(`; `z_core/src/ops/mod.rs:971: let answer = crate::gateway::send(...)`.

What the proof asserts: it lists the internal send call sites. It does not launch the desktop app, observe sockets, or establish that the first run is silent; `docs/CLAIMS.md` itself marks this proof `unproven`.

Counterexample tried: no false network result was invented; the missing runtime observation is the finding.

Limit line: complete as a disclosure of the unmeasured toolkit/OS/graphics surface; the claim still lacks a reproducible runtime measurement.

Verdict reason: intentionally unproven in the repository.

## C-05 · Protection is permanent: a protected word keeps its token for ever — FALSE

Command run: `cargo test -p z_core --features fake_provider,test_clock,measuring --test a_block_is_never_deleted --test a_block_crosses_a_profile_and_forget_exempts_it`

Last lines: `test result: ok. 10 passed; 0 failed`.

What the proof asserts: the Rust tests show that a vault block survives restart/profile changes and that Forget writes an exemption instead of deleting the block. They do not show that the original can never be made visible again.

Counterexample tried: the shipped UI contains `apps/flutter_app/lib/l10n/app_en.arb:2924`, `"undoProtection": "Undo protection"`, and the guide says exactly: “Press a protected word and «Undo protection» takes it back” (`site/en/guide/index.html:97`). That is a direct path that makes the protected value visible again, even if the historical block remains in the vault.

Limit line: missing: it distinguishes block permanence from visible un-protection, but the `We say` sentence says “can never be unprotected again”.

Verdict reason: the proof supports “the block is not deleted”, not the product sentence “not by you”.

## C-06 · The vault is one encrypted file, and the passphrase is never stored — FALSE

Command run: `cargo test -p z_core --features fake_provider,test_clock,measuring --test the_vault_file_says_nothing --test zcfg_leak`

Last lines: `test the_vault_file_carries_no_readable_name ... ok`; `test nothing_of_the_user_s_work_reaches_the_settings_file ... ok`; `test result: ok. 1 passed; 0 failed` for each test.

What the proof asserts: it searches selected known names out of `vault.zv` and `settings.zcfg`, and the gate counts permitted filesystem sites. It does not prove that the app writes one file: the source and gate explicitly include `vault.zv`, `sessions/*.zs`, and `settings.zcfg`.

Counterexample tried: `apps/flutter_app/lib/l10n/app_en.arb:1712` says “A vault is the only file this app writes”, while `z_core/src/conversation.rs` writes session files and `z_core/src/config.rs` writes `settings.zcfg`. Those are concrete additional files, so the literal public sentence is false even though the encrypted vault and session contents may be protected.

Limit line: missing: it discloses an unencrypted settings file and permissions but does not disclose that session files are another persisted file class.

Verdict reason: the file-count part of the claim is contradicted by the tree and by a screen sentence; selected-name leak tests do not cure that contradiction.

## C-07 · Two copies of Z Privacy never lose a write — EXAGGERATED

Command run: `cargo test -p z_core --features fake_provider,test_clock,measuring --test two_copies_never_lose_a_write -- --nocapture`

Last lines: `a_copy_that_adds_one_identity ... ok`; `two_copies_never_lose_a_write ... ok`; `two_copies_never_lose_a_turn ... ok`; `test result: ok. 3 passed; 0 failed`.

What the proof asserts: the test runs two processes against one shared vault with a ready-file handshake and repeated trials, checking that vault writes are not silently lost. The source gate covers the writer lock and the test name, but the test does not run two whole application processes concurrently against the same session file.

Counterexample tried: inspected the session-file path and the claim's own measured note; it records a session-file lost-write shape and says that the named test is vault-only. Thus the broader “never lose a write” sentence is not established, even though the vault subclaim passed.

Limit line: incomplete: it says one machine/data directory and admits that the vault is not the whole write, but the public sentence remains broader than the proof.

Verdict reason: confirmed for the tested vault race, exaggerated for all writes/session files/network shares.

## C-08 · Z Privacy keeps no document but the one in front of you — CONFIRMED

Command run: `cargo test -p z_core --features fake_provider,test_clock,measuring --test the_preview_keeps_what_it_holds --test the_session_is_born_at_the_first_document`

Last lines: `test result: ok. 8 passed; 0 failed`.

What the proof asserts: the tests check when a session is created and that the current preview/session file holds the document until an outbound door removes it. The source census checks the four outbound paths rather than only one button.

Counterexample tried: inspected the “document leaves” paths and the session-file model; no second document cache was found in the measured lifecycle.

Limit line: complete: sent documents are explicitly outside local retention, and the one current session copy is the stated exception.

Verdict reason: the tests and source census measure the bounded lifecycle the sentence describes.

## C-09 · Sessions are isolated: the same name takes a different token in each — CONFIRMED

Command run: `cargo test -p z_core --features fake_provider,test_clock,measuring --test a_token_does_not_cross_a_session --test a_session_carries_its_own_key`

Last lines: `test result: ok; 10 passed; 0 failed`; `test result: ok; 3 passed; 0 failed`.

What the proof asserts: a token from one session is unknown and unrestorable in another, while the same value repeats within one session; a separate test checks the session key. The source path derives a per-session namespace and uses `getrandom`.

Counterexample tried: cross-session token use and key separation were exercised; no cross-session restore was found.

Limit line: complete for session linking/restore; it expressly says token kinds and provider visibility are not hidden.

Verdict reason: the observed behavior matches the exact isolation sentence and its limit.

## C-10 · The reader's limits are named numbers, not «too large» — EXAGGERATED

Command run: `cargo test -p z_core --features fake_provider,test_clock,measuring --test a_cut_stream_is_never_a_read_document && cargo test -p z_core --features fake_provider,test_clock,measuring --lib documents`

Last lines: `test result: ok; 1 passed; 0 failed` for the cut-stream test; `test result: ok; 59 passed; 0 failed; 120 filtered out` for the document module.

What the proof asserts: the fixture covers a 9 MiB stream, an 8 MiB per-stream refusal, a 200× bomb, object streams, ToUnicode, forms, cumulative page content and compressed cross-reference paths. The source module names the configured limits and the ordinary document tests cover file/text/page boundaries.

Counterexample tried: no successful partial-read counterexample was found in those fixtures. The proof still does not exhaust every encoding, reader combination or exact boundary, so “a document inside those numbers is read” is broader than this finite corpus.

Limit line: missing: it lists numbers and selected measured shapes but does not say that all formats and boundary combinations are not covered.

Verdict reason: the limits are real and named, but the proof is narrower than the universal reading behavior implied by the sentence.

## C-11 · The scanner is rules, packs and your vault — no model, and review is explicit — CONFIRMED

Command run: `cargo test -p z_core --features fake_provider,test_clock,measuring --test nothing_leaves_while_a_word_waits`

Last lines: `running 5 tests`; `test result: ok. 5 passed; 0 failed`.

What the proof asserts: every tested outbound door refuses while a suggestion is unanswered, and source gates show that scanning is rules/packs/vault logic rather than a model. The named serious fixtures cover zero-width/NFD names, the German footer, and the synthetic English letter after review.

Counterexample tried: tested/inspected the explicitly listed ligature, written-date and card-prefix gaps in “What we do not claim”; they remain disclosed misses rather than silently treated as detected.

Limit line: complete: it expressly limits detection to what the rules describe and says unresolved findings block exits.

Verdict reason: the proof measures the actual claim, with the known scanner blind spots disclosed.

## C-12 · A z-pdf comes back into its names, and a token no key can restore stays literal — CONFIRMED

Command run: `cargo test -p z_core --features fake_provider,test_clock,measuring --test the_door_back --test the_answer_page_finds_its_way_back --test a_returning_document_is_not_protected_again`

Last lines: `test result: ok; 6 passed; 0 failed`.

What the proof asserts: the project’s PDF round trip restores names when this vault has the key and leaves unknown tokens literal; the answer page and line structure are checked. It also asserts that a returning document is not scanned/protected again.

Counterexample tried: the tests include locked/foreign/no-key cases and the no-re-protection path; those remain literal or refused as specified.

Limit line: complete for this writer/read-back format and local authority; it explicitly excludes another machine, deleted sessions and editing/re-protection.

Verdict reason: the command exercises the documented local/foreign boundary and passes.

## C-13 · The chat carries only protected exchanges, and the core builds its history itself — CONFIRMED

Command run: `cargo test -p z_core --features fake_provider,test_clock,measuring --test the_chat_remembers --test the_lock_gives_the_session_back --test a_session_is_born_at_the_first_question`

Last lines: `test result: ok; 14 passed; 0 failed`; `test result: ok; 4 passed; 0 failed`.

What the proof asserts: a follow-up carries the prior protected turn, a follow-up without the document does not resend the document, lock/reopen keeps the chat, and a chat can begin without a document. Gate G46 finds one core history builder and no screen-owned history.

Counterexample tried: inspected the second-question and no-document paths; no screen-built history or plaintext document resend appeared in the synthetic provider tests.

Limit line: complete for the protected-history behavior; it explicitly says a long chat sends more protected bytes, not less, and does not claim a real provider’s retention policy.

Verdict reason: the core tests and G46 measure the claim as limited.

## C-14 · A release says nothing about the machine that built it — EXAGGERATED

Command run: `bash scripts/package_linux.sh && ! grep -rlI "/home/" dist/ && echo "no path from this machine in the archive"`

Last lines: `no «/home/» in any of the 42 files`; `archive dist/zprivacy-v1-linux-x86_64.tar.gz (16M)`; `sha256 4115c718853606d903ffbb6014eb12c804735b7ce0040c8937c8def86bf60b93`; `no path from this machine in the archive`.

What the proof asserts: the Linux packaging script remaps/searches a set of known absolute-path needles and writes a commit/build stamp. The static Windows gates inspect job shape, but this command does not build or install Windows and the current site has no Windows artifact.

Counterexample tried: the source/docs themselves name the commit, date and platform deliberately, and the proof excludes some copied Microsoft runtime files; `site/download/` has no actual files. Therefore “nothing about the machine” is broader than the tested path/symbol scrub.

Limit line: missing: “paths and symbols” is narrower than the title, and the current tree has only a Linux archive measured by the stranger command.

Verdict reason: the Linux path scrub passed, but the universal release sentence is not established.

## C-15 · Every sentence this product shows is checked against the tree it ships in — NOT MEASURED

Command run: `python3 scripts/check_the_one_list.py`

Last lines: `691 sentences in the one list · 29 file(s) migrated · 0 sentences owed in 0 files`.

What the proof asserts: the script counts migration coverage and the static gates check sentence shape, language presence and selected pinned sentences. `docs/CLAIMS.md` marks the claim `unproven` because the census has a named blind spot: a single short word such as `roomAi`/“AI”.

Counterexample tried: the documented `AI` one-word case is outside the census rule, so the command cannot prove “every sentence”.

Limit line: complete as an explicit disclosure of the blind spot; the claim remains unmeasured by design.

Verdict reason: the command passes its census, not the universal claim.

## C-16 · The measurement is public and anyone can run it — CONFIRMED

Command run: `bash scripts/gates.sh; tail -2 docs/MEASURED_ON_LINUX.txt`

Last lines: `636 checks, 0 failed, 0 skipped`; `all gates passed`; then the measured-file tail ends with `somewhere a guard can see it.`

What the proof asserts: `scripts/gates.sh` is runnable from the root and reports the gate count; `docs/MEASURED_ON_LINUX.txt` records the Linux measurement. The gates are mostly source-shape checks, not an independent audit or proof that every product behavior is safe.

Counterexample tried: the separate C-02 command failed because its bridge prerequisite was absent, and the site audit failed because download artifacts are absent; neither prevents the stated gate command from being public and runnable.

Limit line: complete: no security-firm audit is claimed, and Linux/Windows measurement boundaries are stated.

Verdict reason: the public gate itself ran cleanly; the claim does not promise that every named per-claim command is independently runnable.

## «What we do not claim»

The section at `docs/CLAIMS.md:148-161` is consistent on its face with the other explicit limits:

- “Anonymity from the provider” is repeated honestly at `site/en/index.html:88` as “It does not make you anonymous to the AI provider.”
- “Anonymisation” is not presented as a product guarantee; the site says values are replaced, not that the user is anonymous.
- “Detection of everything” is not promised; the guide names review/suggestions and the blind spots remain listed.
- “That review is optional” and “An independent audit” are distinguished; the download page says a model review is not yet linked, not that a security audit exists.
- “Every platform” is not contradicted: README says Linux is measured and macOS/iOS/Android are not built.
- “That a long chat sends less” is not contradicted; `site/en/guide/index.html:107` says later questions carry what was already said.
- “Protection of what you copy yourself” is not contradicted; the guide and UI warn that restored clipboard text is outside Z Privacy.

The important exception is not inside this list: the UI says “Undo protection” takes a protected value back (`site/en/guide/index.html:97`), contradicting the broader C-05 sentence. Also outside the list, `apps/flutter_app/lib/l10n/app_en.arb:1712` says “A vault is the only file this app writes”, contradicted by `sessions/*.zs` and `settings.zcfg`.

## Findings outside the claims

1. **Guide behavior is only structurally checked, not fully behaviorally proved.** `scripts/check_site_claims.py` passes 34 control keys in each of `site/en/guide/`, `site/de/guide/`, and `site/ar/guide/`, and confirms every key exists in `app_en.arb`. That check does not execute the behavior described by every sentence. For example, the guide claims “A hand selection never crosses a line break” and “In a table, press a value to protect the same cell in every held line” (`site/en/guide/index.html:102`); matching Rust tests exist, but the site gate itself is not a semantic test of those controls.

2. **The guide repeats an incompletely measured write guarantee.** It says “nothing is lost silently” (`site/en/guide/index.html:118`), while C-07’s own limit says the two-process test covers the vault, not the session-file race. This is a public sentence broader than the proof currently named for it.

3. **The homepage claims broader provider compatibility than the tree demonstrates.** It says: “Z Privacy is provider-independent and works with any AI service, including local models” (`site/en/index.html:79`). The tree contains a finite provider set (`z_core/src/providers/anthropic.rs`, `deepseek.rs`, `google.rs`, `moonshot.rs`, `openai.rs`, plus `fake.rs`) and a constrained HTTP layer; no proof here establishes “any AI service”.

4. **The download pages are not publishable at this commit.** `bash scripts/check_site.sh` and `python3 scripts/check_site_claims.py` both fail: the three “(final hashes on publishing day)” markers remain, both advertised files are absent from `site/download/`, and the links are 404s. The page’s Linux fingerprint is `7a09b506…`, while the Linux archive produced by the exact reviewed tree is `4115c718…`; the Windows installer and its measured SmartScreen/admin behavior are not available in this checkout. The pages’ lines about “More info”, “Run anyway”, the warning appearing once, and no administrator are statements from an external measured machine, not measurements reproducible from this tree.

5. **README drift is visible.** `README.md:36-47` still says 314 sentences in 22 screens and “No run of it has been measured into `docs/` yet”, while this commit’s C-15 text says 691 sentences/29 files and the gates report current Windows history. `README.md:24` also says “The vault is one encrypted file”, repeating the file-count problem.

6. **The public proof gates are not all shape-neutral runtime tests.** G1/G5/G16, G43, G46 and the Windows G60/G61/G69 checks primarily grep source or workflow text. Their green result is evidence of repository shape, not a substitute for runtime network capture, Windows installation, or an independent security audit.


---

## Lead's addendum, 23 Oct — not the reviewer's text

One count in finding 3 is corrected by measurement (e2, paper 105's round): the review names five provider adapters; the tree holds **six** — `z_core/src/providers/xai.rs` was missed. The finding's substance stands and was fixed by narrowing the site sentence; the measured truth behind the new sentence: all six providers take a caller-given base URL (`connect_provider`, ops/mod.rs:1361), https anywhere and plain http only for a literal loopback address, five of six speak OpenAI's chat-completions shape, a keyless local model at 127.0.0.1 is pinned by `truthfulness_regressions::lie_a_keyless_login_claims_a_key` and the whole send by `wire_capture`. Everything else in the review is left exactly as it came back.
