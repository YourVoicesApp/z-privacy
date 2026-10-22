# What Z Privacy claims, what each claim does not cover, and how to check it

The owner, 19 October 2026: «نجعل ملف مراجعة في git نحدد فيه نقاط الادّعاءات
التي ندّعيها في التطبيق» — a file in git naming the claims the product makes,
so that an outside reader can attack each one through its own proof.

**How to read a section.** Four lines, always the same four:

- **We say** — the sentence the app or the site actually shows, quoted, with
  the key it is stored under (`apps/flutter_app/lib/l10n/app_en.arb`) or the
  page it is on. Not a paraphrase of what we mean.
- **The limit** — what the claim does *not* cover. It is a line of its own, in
  the same type size as the claim, because a limit in a footnote is a limit
  nobody read.
- **The proof** — a test file, a gate number or a source line **that exists in
  this tree at this commit**. A proof that begins with **unproven —** is a
  claim we have not measured; it stays in this file with that word on it,
  because a claim removed from a list is a claim hidden rather than dropped.
- **Measure it yourself** — the command a stranger runs, from the root of this
  repository, with nothing installed that the repository does not name.

`scripts/check_claims.py` (gate **G56**) reads this file on every gate run: it
refuses a section that is missing one of the four lines, refuses a path, gate,
test or sentence key that does not exist, and prints how many claims are proven
and how many are not. So this file cannot quietly rot, and it cannot quietly
grow a claim with no proof.

**What this file is not.** It is not a security audit; nobody independent has
audited this code (C-16). It is the list of things we say, with our own
measurements beside them, offered so that somebody else can try to break them.

---

## C-01 · Only the protected version is sent to AI through Z Privacy

**We say:** «Only the protected version is sent to AI through Z Privacy.» (key `onlyTheProtectedVersionIsSent`, the first screen; rule 62, after which the «original text» choice was deleted rather than greyed)
**The limit:** the protected text itself travels, and with it the request's own envelope — the provider's address, the time, the model's name and the size of what was sent. Z Privacy hides the values inside the text; it does not hide that you asked, or whom you asked. And a person may copy restored text themselves (C-02): nothing stops a hand.
**The proof:** `z_core/tests/wire_capture.rs` records the request byte for byte on a local server and asserts the body's `content` **is** the safe payload character for character, with no original or vault value anywhere in body, headers or URL; the contract has no door that takes text (gate `G2`, every `send*`/`ask*` signature names `PayloadHandle`); `z_core/src/gateway.rs` carries a `PayloadHandle` and never a string.
**Measure it yourself:** `cargo test -p z_core --features fake_provider,test_clock,measuring --test wire_capture -- --nocapture`

## C-02 · Your original stays on this device unless you copy restored content yourself

**We say:** «Your original data stays on this device unless you explicitly copy restored content.» (key `originalDataStaysHere`) — and the press that does it asks first: «Copy restored text?» … «This will place the real protected values on your system clipboard.» (keys `copyRestoredTextQuestion`, `thisWillPlaceTheRealValues`)
**The limit:** the clipboard is the operating system's, and any program on the machine may read it after you have put something there. We empty it before an exit press and we ask before restoring into it; we cannot take it back afterwards.
**The proof:** every manual exit ends at one door, `payload_to_take_out` in `z_core/src/ops/mod.rs`, which runs the audit and the waiting-word law before handing text out (gates `G28`, `G31`); on the glass the press empties the clipboard first — `emptyTheClipboardFirst` in `apps/flutter_app/lib/screens/shell.dart` — and `apps/flutter_app/test/copy_report_test.dart` fails if it does not.
**Measure it yourself:** `cd apps/flutter_app && flutter test test/copy_report_test.dart`

## C-03 · No account, no analytics, and no Z Privacy server

**We say:** «No account.» «No analytics.» (keys `noAccount`, `noAnalytics`) — and of the three ways to ask a model: «The first needs no account at all.» (key `aiWhat`)
**The limit:** the app does talk to the provider **you** choose, with the key you gave it, and that provider has its own terms and its own logs. «No analytics» is about us, not about them. A local model (llama.cpp, Ollama, LM Studio) is the one path where nothing leaves the machine at all.
**The proof:** one HTTP client, declared in one crate and named in one folder (gate `G1`); the interface cannot reach the network at all — no network package and no socket class in `apps/flutter_app/lib` (gate `G5`); the outgoing text has a single reader behind the gateway (gate `G16`); there is no Z Privacy account, server or endpoint in the tree — `z_core/src/providers/` holds the list and every base address comes from the person's own login.
**Measure it yourself:** `bash scripts/gates.sh 2>&1 | grep -E "G1[a-d]?|G5[ab]?|G16"`

## C-04 · Nothing goes out before you connect a provider

**We say:** «No analytics.» (key `noAnalytics`) and «The first needs no account at all.» (key `aiWhat`) together say that a first run is silent.
**The limit:** this is about Z Privacy's own code. The desktop toolkit, the operating system and the graphics stack may do what they do; we have not measured them.
**The proof:** unproven — the gates prove there is only one send path and that the glass cannot open a socket (`G1`, `G5`, `G16`), and the independent attacker measured a silent first run with `tcpdump` on 17 October, but **that measurement was taken on a desk and is not reproducible from this tree**: nothing here runs the app and watches the interface. Until a test does that, this claim rests on a reading of the code and one outside measurement.
**Measure it yourself:** `grep -rn "crate::providers::ask\|gateway::send" z_core/src --include=*.rs | grep -v "^z_core/src/providers/"`

## C-05 · Protection is permanent: a protected word keeps its token for ever

**We say:** «Every document and every message protected in it can never be unprotected again — not by you, and not by Z Privacy. The key was the only thing that could.» (key `everyDocumentCanNeverBeUnprotected`, the Sessions room; rules 49–51, 58, 59 and 089)
**The limit:** permanent means *we* cannot undo it — the vault keeps the block and the key for the conversation is gone. It does not mean the model you already sent the protected text to has forgotten it, and it does not mean a copy you made yourself is protected.
**The proof:** `z_core/tests/a_block_is_never_deleted.rs` and `z_core/tests/a_block_crosses_a_profile_and_forget_exempts_it.rs` measure that «Forget» writes an exemption and never erases a block, and that a block crosses a client profile; one function writes every exemption, which gate `G40` reads from the source.
**Measure it yourself:** `cargo test -p z_core --features fake_provider,test_clock,measuring --test a_block_is_never_deleted --test a_block_crosses_a_profile_and_forget_exempts_it`

## C-06 · The vault is one encrypted file, and the passphrase is never stored

**We say:** «One passphrase, kept on this device. Everything Z learns while you work — your names, your lists, your decisions — is kept in it.» (key `onePassphrase`) and the site's own sentence «even the vault file on disk contains no readable name» (`site/en/index.html`)
**The limit:** the encryption is only as strong as the passphrase a person chooses, and an unlocked vault is readable by anything running as that user on that machine. We protect a file at rest, not a machine already taken. **And the folder that holds it is narrowed on Unix only:** `z_core/src/secure_file.rs` sets the data directory to 0700, and refuses to write at all when the person has taken a permission off it; the half of that file that is compiled off Unix creates the folder and asks nothing, so on Windows the vault's folder is whatever that machine's own permissions make it. Measured from the other end on 21 October: the Dart contract walk handed the core the machine's shared temp folder, Linux refused it — nobody can narrow a folder they do not own — and Windows accepted it and wrote a vault there.
**The proof:** `z_core/tests/the_vault_file_says_nothing.rs` searches the written file for the names it was taught and finds none; `z_core/tests/zcfg_leak.rs` does the same for the one file that is **not** encrypted; the core writes two kinds of file and no third, which gate `G15` counts from the source; and no function in the whole contract returns a key or a passphrase (gate `G8`).
**Measure it yourself:** `cargo test -p z_core --features fake_provider,test_clock,measuring --test the_vault_file_says_nothing --test zcfg_leak`

## C-07 · Two copies of Z Privacy never lose a write

**We say:** «Another copy of Z Privacy changed this vault. Close that window, or lock and unlock here to take in its work.» (key `troubleVaultChangedElsewhere`)
**The limit:** one machine and one data directory. Two machines sharing a folder over a network file system are **not** measured, and the lock we take (`LockFileEx` on Windows, `flock` on Linux) is not a promise across such a share.
**The proof:** `z_core/tests/two_copies_never_lose_a_write.rs` runs two processes against one vault — a ready-file handshake, forty trials — and asserts no write is lost silently; the lock is taken for the whole of a core call in `z_core/src/session.rs`, which gate `G43` reads, and the Windows job asks for this test by name (gate `G53`).
**Measure it yourself:** `cargo test -p z_core --features fake_provider,test_clock,measuring --test two_copies_never_lose_a_write -- --nocapture`

## C-08 · Z Privacy keeps no document but the one in front of you

**We say:** «Every document and every message protected in it can never be unprotected again…» (key `everyDocumentCanNeverBeUnprotected`) — and the Sessions room lists what a session is holding, which is the one document in the preview that has not left it (rules 54, 55, 089 rule 9)
**The limit:** what has **left** is not kept — so a document you sent is gone from here and lives wherever you sent it. And the one kept copy is kept: it is in the session's own file, sealed under the session's key, until the document leaves or the session is deleted.
**The proof:** `z_core/tests/the_preview_keeps_what_it_holds.rs` and `z_core/tests/the_session_is_born_at_the_first_document.rs` measure what is kept and when; `z_core/src/ops/conversation.rs`'s `the_preview_has_left` takes the copy out at every door that takes text out, which gate `G36` reads as a census of four doors.
**Measure it yourself:** `cargo test -p z_core --features fake_provider,test_clock,measuring --test the_preview_keeps_what_it_holds --test the_session_is_born_at_the_first_document`

## C-09 · Sessions are isolated: the same name takes a different token in each

**We say:** «Each session has its own encryption. The same name in two sessions takes two different tokens, and in one session it takes the same one wherever it appears» (key `eachSessionHasItsOwnEncryption`)
**The limit:** the *kinds* leak on purpose — a token says `PERSON` or `IBAN`, because a model that cannot tell a person from an account cannot answer. And this is about linking across sessions, not about a provider: one provider sees everything you send it.
**The proof:** `z_core/tests/a_token_does_not_cross_a_session.rs` measures that a token minted in one session comes back unknown in another and is never restored; `z_core/tests/a_session_carries_its_own_key.rs` measures the key; every token carries a namespace drawn from the operating system every time, with no weaker interim stage — `os_hex4` in `z_core/src/tokens.rs`, which asks `getrandom` and whose fallback mixes the clock rather than panicking. The library's own vectors (C1–C7) live in a different repository (`ZPrivacy-lib`, sealed), so from **this** tree the app side is what is measured.
**Measure it yourself:** `cargo test -p z_core --features fake_provider,test_clock,measuring --test a_token_does_not_cross_a_session --test a_session_carries_its_own_key`

## C-10 · The reader's limits are named numbers, not «too large»

**We say:** the sentences the reader refuses with name the number, e.g. «{size} MiB is past the {limit} MiB limit for one document» (`z_core/src/documents/mod.rs`)
**The limit:** every number is named and every one of them is this reader's. The general limits: a file of 25 MiB, 4 MiB of text after decompression, 8 MiB for one entry inside a zip, 512 entries, 2000 pages, and a swell of at most 200× (measured worst case in the owner's own documents: 95.7×). And the PDF's own two ceilings, which are the ones a bomb meets first: a document may unpack to `max(16 MiB, 32× the file)` (`PDF_UNPACKED_FLOOR`, `PDF_UNPACKED_SWELL` — the pair the owner's 39.50 MiB tax PDF argued for) and no single stream past 8 MiB (`PDF_STREAM_BYTES`). A document inside those numbers is read; one outside them is refused by name rather than read half-way.
**The proof:** the numbers are one `limits` module in `z_core/src/documents/mod.rs`; `z_core/tests/a_cut_stream_is_never_a_read_document.rs` measures that a stream cut by a limit is never imported as a whole document; the zip and PDF readers hold their own refusals in `z_core/src/documents/zip.rs` and `z_core/src/documents/pdf.rs`.
**Measure it yourself:** `cargo test -p z_core --features fake_provider,test_clock,measuring --test a_cut_stream_is_never_a_read_document && cargo test -p z_core --features fake_provider,test_clock,measuring --lib documents`

## C-11 · The scanner is rules, packs and your vault — no model, and review is explicit

**We say:** «A privacy pack is a detection engine, not the language of the interface — and more than one pack can run in a single scan, so this is a starting point» (key `languageAndRulesWhat`) and «A suggestion that has not been answered is never quietly treated as safe, and there is no «send anyway» — not here, not in a hidden flag.» (key `answerEverySuggestionWhat`)
**The limit:** a rules engine finds what its rules describe. What it misses is listed in «What we do not claim» below, by name, including the three defects the independent attacker measured on 17 October that are still open.
**The proof:** `z_core/tests/nothing_leaves_while_a_word_waits.rs` measures that every door refuses while a suggestion is unanswered; the refusal is built in one function, which gate `G28` reads, and the four doors are a census, which gate `G36` reads; there is no model in the tree — `z_core/src/scanner/` is rules, packs and the vault's own values. **And the three faults the outside model graded serious on 19 October are closed and measured** (095): a name is read as a person reads it, so a zero-width character or an NFD umlaut no longer hides one (`z_core/tests/a_name_is_read_as_a_person_reads_it.rs`); the post-office box and the bank's own name on a German footer are findings (`z_core/tests/the_box_and_the_bank_are_findings_too.rs`); and the English letter's six fields — the given name beside a protected surname, the National Insurance number, a payment card by its checksum and its issuer prefix, the date of birth, the employee number and the United Kingdom address — leave nothing in the clear after a finished review (`z_core/tests/the_english_letter_after_the_review.rs`).
**Measure it yourself:** `cargo test -p z_core --features fake_provider,test_clock,measuring --test nothing_leaves_while_a_word_waits`

## C-12 · A z-pdf comes back into its names, and a token no key can restore stays literal

**We say:** the door back is a row in Settings, and what it writes is «Z-pdf : Zprivacy-svara» on its own answer page (`z_core/src/tokens.rs`, `ANSWER_PAGE_WORD`)
**The limit:** the names come back only where **this** vault holds the key — a z-pdf read on another machine, or after the session was deleted, keeps its tokens as text and says so. A document that comes back is never scanned and never protected again, which also means it is never a bench you can edit.
**The proof:** `z_core/tests/the_door_back.rs` and `z_core/tests/the_answer_page_finds_its_way_back.rs` measure the round trip and the refusal; `z_core/tests/a_z_pdf_reads_back_its_lines.rs` measures that our own writer's lines are read back as lines; `z_core/tests/a_returning_document_is_not_protected_again.rs` measures 079 rule 5.
**Measure it yourself:** `cargo test -p z_core --features fake_provider,test_clock,measuring --test the_door_back --test the_answer_page_finds_its_way_back --test a_returning_document_is_not_protected_again`

## C-13 · The chat carries only protected exchanges, and the core builds its history itself

**We say:** «The chat is on your clipboard, protected — bring the answer back with «Add an answer».» (key `theChatIsOnYourClipboard`; rules 65–69, and 55-و)
**The limit:** every later question carries the earlier turns **with it** to the model, in the protected form they left in — so a long chat sends more, not less. The document itself is sent once; the history is not a second copy of it.
**The proof:** `z_core/tests/the_chat_remembers.rs` measures that a second question carries the first turn as it left, that a follow-up leaves without the document, and that what a person copies out is what the model was shown; `z_core/tests/the_lock_gives_the_session_back.rs` measures that a lock does not end a chat; `z_core/tests/a_session_is_born_at_the_first_question.rs` measures the chat that has no document at all; gate `G46` holds the history to one builder, with no door on either contract surface taking one.
**Measure it yourself:** `cargo test -p z_core --features fake_provider,test_clock,measuring --test the_chat_remembers --test the_lock_gives_the_session_back --test a_session_is_born_at_the_first_question`

## C-14 · A release says nothing about the machine that built it

**We say:** the build's own stamp, printed in the window and written into `BUILD-INFO.txt`: «core stamp … product commit … the two files that are the product» (`scripts/package_linux.sh`, `scripts/package_windows.sh`)
**The limit:** this is about paths and symbols, not about anonymity of the publisher: the archive names the commit it was built from on purpose, so that a person can tell one build from another. And it is measured on the archive this tree builds — a rebuild by somebody else is their archive, not ours. **Measured against this claim and not yet true of every Windows build in the world:** the Windows session found a registry path from the runner's own home inside an installed `z_bridge.dll` on 20 October. That file was not this job's output — it carried no `BUILD-INFO.txt` and no hash — but it named two holes that were real until 098: the job's remap spelled the cargo home as a typed path instead of reading `CARGO_HOME`, and nothing searched the built library **in the job**, so an MSIX (which the packaging script never sees) was never searched at all. Three files in the Windows release are **not** searched, by name and on purpose: Microsoft's C++ runtime, which we copy and did not compile. **And the plainest limit of all, measured on the real run (39508181140):** until 098 item 4 the Windows packaging never ran at all — the job staged inside its own checkout and `scripts/package_windows.sh` refused the dirty tree, so no stamp, no zip and no `.sha256` was ever written on that platform and the installer people downloaded was never searched by the script this claim names. The staging now lives in the runner's own temp. The same run found the third hole in a notice's own text: the crate list that `scripts/package_linux.sh` and the Windows job generate carried `(D:\a\…)` straight from `cargo tree`, because the Linux stripper matched a leading `/` only and the rule had never been applied to its second case; both generators now strip any trailing parenthesis. **And as of 21 October that packaging still has not run once:** the next run (39548354872, head `17109b5`) stopped earlier than the last one — the step that copies Microsoft's C++ runtime typed the toolset's folder name, the runner image had moved to MSVC 14.51, and the copy threw with every step after it skipped — so no zip, no `.sha256`, no installer and no MSIX of this job's making has ever existed. The fix is in the job, not in this file; what this claim is measured by is a run, and the run is the owner's hand. **And on the third attempt (39586867441, head `268b964`) the measurement arrived for the first time:** the stamp is real on Windows — `BUILD-INFO.txt` says «z_core 0.1.0 · 2026-10-21 · 268b964», from a clean tree, with the two product hashes matching the files — and the four needles are zero in all 36 files we compile and in the text notices, the only hits being Microsoft's own pdb path inside the three runtime libraries this claim excludes by name. What still has never existed is the zip, its `.sha256`, the installer and the MSIX: that run died at the archive, handed a path in the spelling bash uses and Windows cannot read, which 098 item 6 converts at the one seam it crosses (gate `G68`). **And on the fourth run this claim has been measured on (39719891044, head `a70cfe9`, 22 October) three of those four existed at once for the first time:** the zip and its `.sha256` are in the run's own artefact, the folder beside them, and the installer was built and hashed with the two lines the download page needs printed into the summary — and the Dart suite read 414 · 0 on Windows in the same run. What has still never existed is the **MSIX**. `msix:create` looked for the publisher's certificate in a store the throw-away one is deliberately not in, asked the console whether to install it, and died on its own unanswered prompt; and the same call had been rebuilding the application **after** the needle search, so the package it would have written held a folder nobody had searched. Item 7 turns both off at the call and then compares the six files inside the package with the staged copies — because a third fact came out of the tool's own source while that was written: `msix` 3.16.8 carries three C++ runtime libraries of its own (14.40.33810.0) and copies them over the folder it packs, so the MSIX would have shipped a runtime older than the 14.51 toolset that compiled what it holds. The zip's three and the MSIX's three were never the same files, and nothing had ever compared them. **And the archive that run did upload held a package nobody could install:** the Windows session read `dist/` from it and `Get-AuthenticodeSignature` answers `NotSigned` for the `.msix` — the tool packs *before* it signs and died at the certificate question in between, so the unsigned package and the `.cer` beside it travelled under an artefact name that reads like a release. A step before the uploads now asks every `.msix` in `dist/` for its signature and deletes an unsigned one, out loud and with its certificate, so what is handed over either installs or is absent; it asks the file rather than whether the step above went red, and it is `NotSigned` that is refused and not «not `Valid`», because the certificate is made in this job and its root is deliberately never installed — a correctly signed package reads back untrusted here. **And the same measurement priced the rebuild:** `z_bridge.dll` inside that MSIX differs from the staged one by **23 bytes**, the PE timestamp, so «same sources, same bytes» was never true and the hash comparison is what the claim rests on. **And no package of this job's making has been installed anywhere yet:** that measurement is the owner's machine, and this claim does not make it.
**The proof:** `scripts/package_linux.sh` and `scripts/package_windows.sh` remap every compiler path, strip what they can, and then **refuse to write** if any file still holds `/home/`, `D:\a\`, `C:\Users\runneradmin` or `\.cargo\registry`; the Windows job searches `zprivacy.exe`, `z_bridge.dll` and `data/app.so` for those same four and fails out loud before anything is packaged; `z_core/tests/the_stamp_names_this_commit.rs` measures that the stamp names the commit being built; gates `G53`, `G60`, `G61` and `G69` hold the Windows job to the same shape as the Linux one, to its own two halves, and to packaging the very folder it searched.
**Measure it yourself:** `bash scripts/package_linux.sh && ! grep -rlI "/home/" dist/ && echo "no path from this machine in the archive"`

## C-15 · Every sentence this product shows is checked against the tree it ships in

**We say:** this is the promise behind every other claim in this file: the app's words are gathered in one list and checked, not written per screen (`apps/flutter_app/lib/core/sentences.dart`, `apps/flutter_app/lib/l10n/app_en.arb`)
**The limit:** **the migration is finished, and the gap that is left is this gate's reach rather than the list's contents.** At this commit the one list holds 686 sentences across 28 files and `scripts/check_the_one_list.py` counts **0 sentences still owed in 0 files** — every file the glass draws from is now in the checker's `MIGRATED` set, where holding **one** sentence of its own is a failure, and not in a debt table that only forbade holding more than before. The last of them went in on the owner's word: the z-pdf footer, the «protected copy» mark and the answer page's top line are read in the language of the **session the file left** and never through the interface's holder — what travels is worded for whoever reads the document — and the page marker in the Original column joined the list under the key it already had. **What is not proven:** the census tells a sentence from a key by its shape, and a shape can be blind. It looked for a word of three letters or more, and a sentence made only of short words — «Go to it» — was invisible to it; on the lead's ruling it now reads a sentence in a **space between two runs of letters** as well, which sees that one, while a key and an id, having no space, stay out. Measured when it was widened: it newly admits **nothing**, in the app or in the guards, so the hole was real and had already been paid by hand. What it still cannot see is a **single** word shorter than three letters with no space — this list's own `roomAi`, «AI», a room's name on the glass — and that cannot be closed without admitting every two-letter language code, so it is named in `scripts/check_no_typed_sentence.py` and here rather than quietly rounded away. The definition answers for itself in `the_test_itself`, which reds if it is ever narrowed back. The core writes sentences of its own, in English, and the glass quotes a few of them by name; those are the core's and are deliberately not in this list.
**The proof:** unproven — gates `G41`, `G50`/`G51`, `G55`, `G65` and `G66` measure the sentences that **are** in the list (none outside it in any file the glass draws from, every language present, no invisible character, no guard typing one, and the sentences a claim here leans on pinned by their English) and `z_core/tests/truthfulness.rs` measures that what a report says matches what was measured; but a census with a named blind spot cannot prove a claim about **every** sentence, and this file does not say it does.
**Measure it yourself:** `python3 scripts/check_the_one_list.py`

## C-16 · The measurement is public and anyone can run it

**We say:** the gates are in the repository and the numbers are in `docs/MEASURED_ON_LINUX.txt`, written by the hand that merges, and compared against every run.
**The limit:** no security firm has audited this code. An **outside model** attacked the claims and the tree on 19 October 2026 and graded each one — 0 blockers, 3 serious, 16 notes, its report in the papers repository — and that is a review, not an audit: it is one reader, on one day, with no access to a running installation. And the numbers are Linux numbers until the Windows job's own report is written into `docs/` from a run.
**The proof:** `scripts/gates.sh` runs every gate from a plain debug build and prints «N checks, M failed, K skipped»; `docs/MEASURED_ON_LINUX.txt` holds the last numbers and the stamp gate refuses a tree whose test count has moved away from them; `.github/workflows/windows-core.yml` is the second platform's own report.
**Measure it yourself:** `bash scripts/gates.sh; tail -2 docs/MEASURED_ON_LINUX.txt`

---

## What we do not claim

- **Anonymity from the provider.** Address, time, model, size and the protected text itself travel. A provider knows that you asked and what the shape of it was. Z Privacy removes the values; it does not remove you.
- **Anonymisation.** This is **pseudonymisation**: a token stands for a value and the mapping lives in your vault. A protected text plus knowledge of the world can still narrow down who it is about — a single-patient clinic letter is still about that patient with every name removed.
- **Detection of everything.** The scanner is rules and lists, not a model. The three faults the outside model graded serious on 19 October 2026 (خ3, خ4, خ5) are **closed** — the proof is in C-11 — and what remains open is named here rather than left for a reader to find:
  - **A typographic ligature is still missed.** «ﬁscher» reads as «fischer» only under NFKC, and NFKC is forbidden in this product because it adds a space to the Arabic mark forms and would cut words in two. Measured in `a_ligature_is_still_missed_and_that_is_written_down`.
  - **A date of birth written out in words is still missed.** «12 April 1985» under its own label is not taken: a month-name list is language data and 095 added none. Measured in `a_date_of_birth_written_out_in_words_is_still_missed`.
  - **An amount and the city on a date line are context, not identities** — the review's own ن14, and a written decision rather than a gap.
  - **A card from a network whose prefix is not in the published table is not taken.** The rule asks the checksum **and** the issuer prefix, because one long number in ten passes Luhn by chance — the Arabic letter in this tree holds one that does and is an account number.
- **That review is optional.** Everything the scanner is unsure of is a suggestion, and no door opens while one is unanswered. We do not claim the scanner's first pass is complete — we claim nothing leaves while a word waits.
- **An independent audit.** None by a security firm. One outside model's review exists (19 October 2026); its three serious findings are **closed**, with the proof in C-11, and what it left open is the list above. A review by one reader on one day is not an audit, and we do not present it as one.
- **Every platform.** Linux is measured; Windows is built and measured by the workflow, and its numbers are the ones a run writes into `docs/`. macOS, iOS and Android are not built.
- **That a long chat sends less.** Every later question carries the earlier turns, protected. A chat is cheaper in names, not in bytes.
- **Protection of what you copy yourself.** «Copy Restored» puts real values on the clipboard, after asking. After that it is the operating system's clipboard and other programs may read it.
