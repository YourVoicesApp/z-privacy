# 118 · The 25 questions, their English answers, and the evidence behind each

**Revision 2 — 26 October 2026, after the owner read all 25.** The structure
and most of the content were accepted; the text below is the one that answers
his corrections. **It is not approved yet, and no translation starts until the
English is final.**

**His governing line for every answer here:** «إذا اضطررنا إلى الاختيار بين
إجابة تجذب Google وإجابة تصف الحقيقة بدقة، نختار الحقيقة» — where an answer
that draws Google and an answer that describes the truth exactly pull apart,
the truth wins. Several answers below are now longer, flatter and less
quotable than they were in revision 1. That is the trade, taken on purpose.

**And the rule the file was written under from the start** (the owner, 26
October): every answer that describes a capability of Z Privacy rests on
`docs/CLAIMS.md` or on a documented test, and where the evidence is not
enough the answer is not published until it is verified.

## What he settled, so nobody reopens it

- **Q2 and Q9: no links to provider policies.** They would be a claim about
  somebody else that rots on somebody else's schedule.
- **Q19 keeps five sentences.** An approved exception to the 2–4 limit,
  because the three things the scanner misses are the honest half of it.
- **Q20 stays blocked** until ed measures an Arabic PDF on a fixture — never
  the owner's own book.
- **Q21 says «free» with no hedge.** The company's decision: Z Privacy is
  Faruk AB's investment in trust, and Mono Scribe is the commercial product.
- **Q16 names no recovery key** and describes the published build's actual
  recovery mechanism, which is none.
- **Q24 links to the download page's own paragraph** rather than restating it.

## How to read an entry

- **Answer** — the English text proposed for the page.
- **Evidence** — the claim (`C-NN`), the test file, the gate or the source
  line **that exists in this tree at this commit**. Where an answer is about
  somebody else's product or about the law, the evidence says so.
- **Changed** — what the owner's reading moved, and why, so the final review
  can see the edit rather than re-derive it.
- **NOT PUBLISHABLE YET** — the evidence is thin or stale.

## Three things no answer below does

1. **No answer states what any AI provider does with your data.**
2. **No answer says that using Z Privacy makes anything lawful.**
3. **No answer names a capability that is designed but not built.**

And a fourth the owner added by his corrections: **no answer generalises from
the scope of a test to a property of the whole product.** Where a test
measured one request, one door or one path, the answer says so in those words.

---

## Q1 · Is it safe to paste client documents into ChatGPT?

**Answer.** That depends on your agreement with the service and on what is in the document, and it is a question about them rather than about us. What is certain either way is that the whole document leaves your machine: the names, the account numbers and the addresses travel with the part you actually wanted help with. The useful question is which of those values the model needs for the task you are asking about — for some tasks it does need them — and Z Privacy is built so that you decide that value by value and see the result before anything is sent.

**Evidence.** No capability of ours is claimed until the last clause, which is `C-01` (`z_core/tests/wire_capture.rs`) and `C-11` (review is explicit, `z_core/tests/nothing_leaves_while_a_word_waits.rs`).

**Changed.** «The smaller question — does the model need those values? — is usually no» is gone. It is not true for every task; some values are needed for the answer to be any good. What Z does is help a person decide, which is a smaller and truer claim than assuming every sensitive value can leave without cost.

## Q2 · Do AI services use my conversations or files for training? And do they keep them?

**Answer.** Those are two different questions and each provider answers them separately: training is whether your content is used to improve a model, retention is how long a copy is kept and who may see it. The answers differ by provider, by plan — a consumer account and an API account are often not the same — and they change over time, so the only reliable source is the provider's own current terms. Z Privacy changes neither; what it changes is what is in the text you send.

**Evidence.** `docs/THE_PROVIDERS.md` (the owner's ruling of 7 October: Z does not come between you and the provider and takes no position on their terms); `C-01`'s limit. No claim is made about any named provider.

**Changed.** The condition is withdrawn: **no links**, by the owner's decision. The answer sends the reader to «the provider's own current terms» without naming a URL we would then own.

## Q3 · How can I use AI on documents with personal data without sending the names?

**Answer.** You replace each value with a token before the text leaves, and put the real values back when the answer comes home. In Z Privacy that is the whole path — Import, Scan, Review, Protect, Choose who answers, AI, Restore — and before anything is sent you are shown exactly what will leave. The mapping from token back to value lives in your vault and nowhere else, so only your machine can reverse it. That is not the same as being unlinkable: what is left of a document can still point at a person through its content alone (see «anonymisation or pseudonymisation» and «does Z make me anonymous»).

**Evidence.** `C-01` (`z_core/tests/wire_capture.rs`); `C-06` (`z_core/tests/the_vault_file_says_nothing.rs`); «What we do not claim · Anonymisation» for the last sentence.

**Changed.** «Reversible on your own machine only» was left standing as though it answered the whole worry. It answers who can undo the substitution — not whether the remaining text identifies anybody. The fourth sentence now says that, and points at Q5 and Q18.

## Q4 · What should I consider under GDPR before sending client data to AI?

**Answer.** Three separate things, and none of them substitutes for another. **Data minimisation** (Art. 5(1)(c)) asks whether the model needs a given value at all — that is the question a tool like Z Privacy helps with. **Your legal obligations** — a lawful basis, your records, your processor agreements, transfers — are yours, and no tool changes them. And **what Z Privacy does** is replace values in the text you send, which is pseudonymisation: under the GDPR that does not make data anonymous by itself, and the text may still be personal data depending on what is left in it (Art. 4(5), Recital 26). This is information, not legal advice; your controller or DPO decides.

**Evidence.** GDPR Art. 4(5), Art. 5(1)(c), Recital 26, cited and not interpreted beyond their wording; «What we do not claim · Anonymisation».

**Changed.** «so what you send is still personal data» became «does not make data anonymous by itself, and may still be personal data depending on what is left in it». The first version decided a question the regulation leaves to the facts of each text, which is the opposite of not giving advice.

## Q5 · What is the difference between anonymisation and pseudonymisation?

**Answer.** Pseudonymisation replaces identifying values with stand-ins while a mapping that can reverse it still exists somewhere; the data can remain personal data (Art. 4(5)). Data counts as anonymous only where the person can no longer be identified by means reasonably likely to be used — a standard that takes account of what others might reasonably do, and not only of what you would do — and then the GDPR no longer applies to it (Recital 26). Z Privacy does the first: the mapping is your vault, on your machine. And a text with every name removed can still be about one identifiable person — a single-patient clinic letter is the standard example.

**Evidence.** GDPR Art. 4(5) and Recital 26, in the Recital's own terms; «What we do not claim · Anonymisation», which uses that same example.

**Changed.** «Anonymisation means nobody can get back to the person» was too absolute and is not the legal test. The test is identification by means **reasonably likely to be used**, and the sentence now says that in the Recital's own words. **Revision 3:** «by anyone, not only by you» is gone. It could be read as a test over every imaginable means by every imaginable party, which is the absolute the Recital was written to avoid. The reasonable-likelihood standard governs the whole sentence, other people included, and the clause now sits inside it rather than beside it.

## Q6 · How can an accountant use AI without exposing clients' financial data?

**Answer.** Work on the document inside Z Privacy: the scan and your own taught values mark what they find, you add anything they did not, and the question goes out with tokens in place of those values. What is replaced is what Z Privacy detected or you marked; everything else stays in the text exactly as you approved it, which is why the review step exists and why it is shown to you before anything is sent. Your professional obligations are not changed by this: Z Privacy reduces what you send, it does not make the sending permissible.

**Evidence.** `C-11` (`z_core/tests/nothing_leaves_while_a_word_waits.rs`); `C-01`; «What we do not claim · Detection of everything»; `docs/THE_PROVIDERS.md` for the last sentence.

**Changed.** «The figures and the structure travel unchanged; the identities do not» is deleted, and it was the worst sentence in revision 1. A figure can itself be identifying or sensitive — a single salary, a single transfer — and no scanner is guaranteed to have found every identity. The answer now says what actually happens: what was detected or marked is replaced, the rest stays, and the person sees it first.

## Q7 · How can a lawyer use AI on case files confidentially?

**Answer.** The same path: what Z Privacy detected and what you chose to protect is replaced before anything leaves, the rest of the text goes as you approved it, and the answer is restored on your machine. Z Privacy does not decide whether your professional rules allow an external model to see a matter at all — that judgement is yours and it differs by jurisdiction. What it changes is how much identifying detail is in what you send, and it shows you the exact text before it goes.

**Evidence.** `C-01`; `C-12` (`z_core/tests/the_door_back.rs`); `C-02`; «What we do not claim · Detection of everything».

**Changed.** «Names, file references and addresses are replaced» read as a guarantee about three categories. It is conditional on what the scanner found and what the person marked, and now says so. «Confidentially» stays the question's word and not the answer's.

## Q8 · Can I use AI on medical or HR documents without revealing who they are about?

**Answer.** Mechanically yes — names, identifiers and addresses can be replaced before the text leaves. But these are the two kinds of document where the identity is most often inferable from the content itself, and no replacement fixes that. Health data is a special category under Art. 9 and HR data carries its own obligations; whether to process it with an external model at all is the controller's decision, not a tool's. If you do, pseudonymisation is a measure, not a permission.

**Evidence.** «What we do not claim · Anonymisation»; GDPR Art. 9; `C-01`.

**Changed.** Nothing. The owner read this one as it stands.

**Note.** His earlier amendment holds: this splits later into a medical question and an HR question, because the risks and the regulation differ.

## Q9 · What happens to my data when I upload a PDF to an AI chatbot?

**Answer.** The file leaves your machine and is processed on the provider's servers; what happens next — how long a copy is kept, who may look at it, whether it is used to improve a model — is set by that provider's terms and your plan, and is not visible from the file. The part worth noticing is that a PDF carries every page, including the ones you did not need help with. Z Privacy's answer is to send the text with the values replaced, rather than the file.

**Evidence.** Same discipline as Q2: nothing asserted about any provider. The last sentence is `C-01` and `C-10` (`z_core/src/documents/mod.rs`).

**Changed.** The link condition is withdrawn with Q2's.

## Q10 · Can I use an AI model on my own computer instead of a cloud service?

**Answer.** Yes. Z Privacy speaks to any server that answers an OpenAI-compatible request, including one on your own machine — llama.cpp, Ollama, LM Studio — and a local model needs no key at all. Plain `http` is accepted only for a **literal** loopback IP address, never for a name like «localhost», so a hosts file cannot be what decides that plaintext is safe. On that path Z Privacy's request to the model goes to that address and no further; it says nothing about what other programs on your computer do.

**Evidence.** `C-17` (`z_core/tests/the_bundle_of_six.rs`, `z_core/tests/the_model_gateway.rs`); `truthfulness_regressions.rs::lie_a_keyless_login_claims_a_key`; `is_loopback_url` in `z_core/src/providers/http.rs`, measured by `plain_http_is_refused_unless_the_host_is_a_literal_loopback_address`.

**Changed.** «Nothing leaves the machine» is scoped to Z Privacy's own request. The old sentence was a statement about the whole computer, which no test of ours can make and which a reader could act on.

## Q11 · What does Z Privacy do, in one minute?

**Answer.** You open a document or write a question. Z Privacy scans it with its rules, its language packs and the values you have taught it, and shows you two columns: your original, and what would leave. You protect what should not go — by the scan's own finding, by pressing a word, or by selecting a run of text with your hand — and nothing leaves while a suggestion is unanswered. Then you choose who answers, see the exact text before it is sent, and the answer comes back with your names restored on this machine.

**Evidence.** Each of the three ways is measured in the published build, not planned: the scan's own finding in `z_core/tests/golden_scan.rs` and `z_core/tests/find_once_teach_once.rs`; the press in `apps/flutter_app/test/selecting_protects_and_the_two_un_protections_test.dart` and `apps/flutter_app/test/the_states_change_only_by_a_press_test.dart`; the hand selection in `z_core/tests/a_selection_takes_the_whole_word.rs`, `z_core/tests/a_selection_may_not_cross_a_line.rs` and `apps/flutter_app/test/a_selection_takes_the_whole_word_test.dart`. The waiting law is `C-11`; the restore is `C-12`.

**Changed.** «Automatically, by pressing a word, or by selecting it» now names each method's own test, per his instruction that a method on this page must exist in the published build.

## Q12 · What does the AI actually receive?

**Answer.** Three things are worth separating. **What Z Privacy sends** is one request to the address you configured: the model's name, your protected text, and — inside the app, from the second question on — the exchange before it, in the protected form it left in. That protected text is the document and question as you approved them, so whatever the scan did not find and you did not mark is in it, and the earlier exchange carries whatever it carried. The request also carries the credential you gave for that service. **What the provider can observe anyway**, as with any program that connects to it, is your network address, the time, how large the request was and how often you ask. **And what we measured**, exactly: one request recorded byte for byte against a server on this machine, asserting that the body's content is the protected payload character for character and that no original value and no vault value appears in the body, the headers or the URL. That is a measurement of one request's content, not a proof that no other program or path exists.

**Evidence.** `C-01` (`z_core/tests/wire_capture.rs`) for the last part, in its own words; the body's three fields are built in one place — `model`, `messages`, `stream` in `z_core/src/providers/openai.rs`, with Anthropic's own shape beside it; the headers are `content-type` plus the provider's own authorisation (`authorization: Bearer …`, or `x-api-key` and `anthropic-version` in `z_core/src/providers/anthropic.rs`); `C-13` (`z_core/tests/the_chat_remembers.rs`) for the one added exchange; `C-04` is **unproven** and that is why the last sentence is there.

**Changed.** This is the answer he called the most important, and it was the most overstated. Three faults. (a) «Nothing else from your machine goes» claimed a property of the machine from a test of one request body — `C-04`, the claim that nothing goes out before you connect a provider, is marked **unproven** in our own file for exactly this reason. (b) The old envelope list mixed what is *sent* with what is *observable*: the model's name is a field we fill, your address and the timing are properties of making a connection at all, and «the provider's address» is where the request goes rather than something we tell them. (c) The test's scope is now stated literally instead of being offered as the proof of a general claim. **Revision 3:** «the credential … and nothing else of yours» is deleted — a fourth absolute hiding inside a sentence about a credential. A request carries whatever the protected text carries, including values the scan did not find and the person did not mark, and the earlier exchange carries whatever it carried. The answer says that now, which is what the three-way split was for.

## Q13 · How do the real names come back into the answer?

**Answer.** On your machine, out of your vault. Inside the app the answer is restored as it arrives; if you carried the question to a model yourself, «Add an answer» brings the text back and every token that chat has carried turns back into its name. A protected PDF has its own door: «z-pdf» in Settings reads such a file back into its names and says which session each one came from. A token whose key this vault does not hold stays as text, and the app says so rather than guessing.

**Evidence.** `C-12` (`z_core/tests/the_door_back.rs`, `z_core/tests/the_answer_page_finds_its_way_back.rs`); `C-09`; `C-13`.

**Changed.** Nothing.

## Q14 · Does Z Privacy see or store my documents?

**Answer.** There is no Z Privacy account, no Z Privacy server and no analytics: the source carries one network client and one send path, the interface cannot open a socket at all, and no Z Privacy address appears anywhere in it — so the only address this program is built to speak to is the provider you configured, with the credential you gave it. On your own machine, **in this build and as read from its source code rather than watched on a running installation**, it writes a known set of files and no others: the encrypted vault, one encrypted file per session, a lock beside them, and a settings file that never holds your work — plus the two documents you ask for by name, a protected copy and a restored plain PDF. The document in the preview is kept in its session's own encrypted file until it leaves by one of the doors that take text out, and leaving takes the copy with it. By that same reading of the source: a file being written exists briefly under a second name beside the finished one, in the same folder, and is renamed into place; nothing is written to the system's temporary directory, and no log file is written at all.

**Evidence.** `C-03` (gates `G1`, `G5`, `G16`); the four classes the core writes are counted from the source by gate `G15`/`G15b` — the vault, the session files, the writer's lock, and `config.rs`'s settings file, the one that is not encrypted (`z_core/tests/zcfg_leak.rs`); the two the Dart side writes when a person names them are in `C-06`'s limit, with `apps/flutter_app/test/the_restored_text_is_saved_as_a_plain_pdf_test.dart`; the preview's own copy and its removal at each door are `z_core/tests/the_preview_keeps_what_it_holds.rs` and gate `G36`'s census. **Checked for this answer, because he asked for every save path:** the core carries no `println!`, no `eprintln!` and no logging crate outside its tests, so there is no log file; the only console line in the whole app prints the core's version at startup (`apps/flutter_app/lib/main.dart`). The system temporary directory is touched only inside `#[cfg(test)]` blocks — a write in the product goes to `temp_path()` in `z_core/src/secure_file.rs`, which is the destination's own path with another extension, inside the folder that `secure_dir` has already narrowed, and is then renamed into place. Every line in the core that touches the filesystem at all carries a `G15-ok` comment above it so the exemptions can be counted, which is what gate `G15` counts.

**Changed.** «What you have sent is not kept here at all» was an absolute built on one test about the preview copy. He asked for every save path, so the answer now lists the file classes the gates actually count — including the settings file, which is not encrypted, and the two files a person asks for, one of which holds values in the clear — and the absolute sentence is replaced by what is measured: the preview's copy is taken out at each door. **Revision 3:** the first sentence no longer says «the only address this program speaks to», which is a statement about a running program resting on checks that read a tree — the same gap that keeps `C-04` marked unproven. It now names what those checks actually establish and says «is built to speak to». And the file list, the temporary-file sentence and the no-log sentence are all governed by one stated kind of evidence — **read from the source, not watched on a running installation**. Reading every write path in a tree and running the program with something watching the disk are different measurements, and three sentences here rest on the first. Nothing else in the answer is weakened.

## Q15 · Where are my names kept, and how are they protected?

**Answer.** In one encrypted vault file on your device, one block per protected value, opened by a passphrase that never leaves the machine — a test searches the written file for the names it was taught and finds none. The encryption is only as strong as the passphrase you choose, and an unlocked vault is readable by anything running as you on that machine: we protect a file at rest, not a machine already taken. On Linux the folder is narrowed to you and the core refuses to write if it cannot be; on Windows the folder is whatever that machine's own permissions make it.

**Evidence.** `C-06` (`z_core/tests/the_vault_file_says_nothing.rs`, `z_core/tests/zcfg_leak.rs`, gates `G15` and `G8`); `z_core/src/secure_file.rs` for the 0700 folder and its Unix-only half.

**Changed.** Nothing — he read this as sound in principle.

## Q16 · What happens if I forget my passphrase?

**Answer.** The vault cannot be opened — not by you and not by us. This build has no recovery mechanism of any kind: no reset, no escrow, no second key and no copy held anywhere, and nothing on our side could recover the vault without the passphrase. The app says so before you set one: «There is no way back. Nobody holds a copy of this, and no reset exists — the passphrase never leaves this device and nothing on our side could recover the vault without it.»

**Evidence.** The sentence is the shipped one, key `thereIsNoWayBack` in `apps/flutter_app/lib/l10n/app_en.arb`; `C-06` (the passphrase is never stored) and gate `G8` (no function in the whole contract returns a key or a passphrase).

**Changed.** The second sentence now states the published build's actual recovery mechanism — none, named in four ways — rather than leaving it to be read off a quotation. **And the page names no recovery key.** One is designed and not built; naming it here would turn a design note into a promise, and a privacy product that hints at a way back into a locked vault has undone the claim it exists to make.

## Q17 · Which AI services work with Z Privacy?

**Answer.** Two are supported and have been used against the live service: OpenAI and Anthropic. Four more are in the catalogue — xAI, DeepSeek, Moonshot and Google — and have not been tested with a live connection; a provider with no credential reports itself as unavailable rather than as ready. Five of the six go out through the same `chat/completions` request shape and Anthropic has its own, so a service that answers neither shape is not reached by this build however open the address field is. Every connection is made at an address you can change, and a model on your own computer needs no key at all.

**Evidence.** `C-17` and paper 105 (`z_core/tests/the_bundle_of_six.rs` measures the six by id and that a provider without a credential answers «unavailable»; `z_core/tests/the_model_gateway.rs` makes every request against a server on this machine that records the bytes).

**Changed.** «Two have ever been spoken to… because those are the keys we hold» is gone. Which keys a developer happens to own is not a product fact, and it belongs in the technical documentation if anywhere. The distinction the reader needs is **supported and tested live** against **in the catalogue, not tested with a live connection**, and that is now what the first two sentences say.

## Q18 · Does Z Privacy make me anonymous to the AI provider?

**Answer.** No. You sign up under your own name with your own credential, and the provider is entitled to know who its customer is; your network address, the time and the size of each request are visible to them as they are to any service you connect to. Z Privacy removes values from inside the text — it does not remove you. What it protects is the people in your documents, who agreed to nothing with your provider.

**Evidence.** «What we do not claim · Anonymity from the provider»; `C-01`'s limit; `docs/THE_PROVIDERS.md` (the owner's ruling of 7 October).

**Changed.** The envelope list is split the same way as Q12's: what is visible to a provider because you connected to them, rather than a list of things we hand over. The first word is still «No».

## Q19 · What does Z Privacy detect automatically, and what must I mark myself?

**Answer.** Automatically: what its rules describe. The IBAN and BIC rules are not tied to a language pack, so they do not depend on which language a document is in; the language sets add e-mail addresses, telephone numbers, tax and social-insurance numbers, customer, contract and employee references, dates of birth, people, companies and addresses — and every value you have taught it is matched wherever it appears. All of that depends on two things upstream of any rule: that the text reached the scanner as it reads on the page, and that the value is written in a form the rules describe. Anything it is unsure of becomes a suggestion that waits for your word, and the law «nothing leaves while a suggestion is unanswered» is asked of every door that takes text out of the app: sending to a model, copying the protected text, copying the chat, and saving a protected PDF. Those doors are not a list somebody keeps up to date — they are counted from what the functions do, so a new one is caught by the count rather than remembered. What the scanner still misses is written down rather than left to be found: a typographic ligature, a date of birth written out in words, and a payment card from a network whose prefix is not in the published table.

**Evidence.** `C-11` (`z_core/tests/nothing_leaves_while_a_word_waits.rs`); the doors are a census read from the source by gate `G36`, and gate `G28` asks the waiting law of every door that census finds, so the two cannot disagree about how many doors there are; the kinds come from `z_core/src/scanner/sets/` (`world.rs`: Iban, Bic; `de.rs`, `en.rs`, `sv.rs`); the three misses are «What we do not claim · Detection of everything», each with its own named test.

**Changed.** «There is no send anyway, not in a menu and not in a hidden flag» is gone. It generalised from four measured doors to the whole product. What replaces it is stronger as evidence and weaker as a slogan: the doors are named, and the fact that worth knowing is that they are **counted from the source** rather than listed by hand. Five sentences, by his approval. **Revision 3:** «IBANs and BICs in any language» read as a guarantee over every representation of them, which is not what the rule set is. What is true is narrower and more useful: those two rules are **not tied to a language pack**. And the sentence that follows names the two things every rule depends on before it can fire — the text arriving as it reads, and the value being written in a described form. After the Arabic-PDF finding, the first of those is not a theoretical caveat.

**Note.** The four doors as the census finds them today: the model request, «Copy Protected», «Copy the chat» and «Save as PDF». The count has moved before — rule 62 removed one, rule 65 added another — which is the argument for counting rather than listing.

## Q20 · Which file types and languages does it support?

**Answer.** Files: plain text (`.txt`, `.md`, `.csv`), Word documents (`.docx`) and PDFs. A PDF with no text layer — a photograph of a document — is refused by name rather than guessed at, and so is an encrypted one. Detection has four language packs today — English, German, Swedish and Arabic — beside rule sets that are not bound to a language, and the interface itself speaks those four. Arabic inside a PDF is a case of its own: a file that carries its text in the shapes a layout program drew is refused by name, because the order read would be the drawing’s and the words would come out backwards, and you are pointed to `.docx` or `.txt`; an Arabic PDF with a sound text layer in logical order is not refused for this reason, and in the cases tested it reads as the same text as plain text, though such a file may still be refused for another reason, such as encryption or a missing text layer. Two limits remain there: a file drawn backwards that still carries ordinary letters is not caught by this, and a protected PDF that Z Privacy itself wrote in Arabic can no longer be brought in as a document to protect.

**Evidence.** `_kinds` in `apps/flutter_app/lib/screens/shell.dart`; the named refusals are the `Refusal` enum in `z_core/src/api.rs`; the packs are `z_core/src/scanner/packs/{ar,de,en,sv}.rs` and the sets `z_core/src/scanner/sets/`; the interface languages are the four `app_*.arb` files. The Arabic-PDF clause is paper 119, merged at `50270fd`: the refusal is `Refusal::TextInDisplayForms { percent }` in `z_core/src/api.rs`, its sentence is `refusalTextInDisplayForms` in the four `app_*.arb` files, and the measurement is `z_core/tests/a_text_read_backwards_is_refused.rs` — the five fixtures read logical 19·5 and mixed 8·2 unchanged, no-ToUnicode and scanned refused by their old names, and the visual one refused at 96%. The marker is the share of the text’s Arabic standing in Unicode’s compatibility blocks, threshold 33% over a floor of 8 characters. **The two limits are the paper’s own words**, not a reading of it.

**Changed.** The Arabic-PDF clause is **deleted**, not revised. Revision 2 said «Arabic inside a PDF does not arrive readable yet», and ed's measurement makes that wrong in both directions: an Arabic PDF stored in **reading order reads exactly like the same text as `.txt`**, so the sentence condemned a format that mostly works — while one stored in **visual order imports silently** and is then scanned wrong, which the sentence was far too mild about. A wrong warning on a page whose argument is «check us» is worse than a missing one.

**Changed.** Revision 2's clause said «Arabic inside a PDF does not arrive readable yet», which ed's measurement made wrong in both directions — a reading-order file reads exactly like `.txt`, and a visual-order one imported **silently**. It was deleted rather than revised, and the answer waited. **Revision 4, after 119:** the clause is written from the measurement itself and says four things — why such a file is read backwards, that it is now refused by name with a pointer to `.docx` or `.txt`, that an Arabic PDF with a sound text layer in logical order is **not refused for this reason** — in the cases tested — while it may still be refused for another, and the two limits that remain. **What it does not say** is whether the z-pdf read-back door returns reversed Arabic: paper 119 says «may» and calls it another door and another paper, which is an acknowledged unknown and not a finding. Writing it down would be inventing a measurement.

**Note.** The answer now runs to five sentences, one over the limit, for the same reason Q19 does: the two remaining limits are the honest half of it. The owner's call, as his was there.

**Still true of the page, not of this answer:** the download card carrying these same facts is on branch `fix/the-arabic-limit-after-119` (`7bb7d35`), written the same day from the same measurement, and it must ship in the same deploy as the corrective build — the pages still offer build `4920398`, in which the import is silent.

## Q21 · Is Z Privacy free?

**Answer.** Yes. There is no paid tier, no account and nothing to subscribe to, and the source is under the Apache License 2.0. What can cost money is the model you choose: a credential from OpenAI or Anthropic is billed by them at their prices, and a model running on your own computer costs nothing at all.

**Evidence.** `LICENSE` (Apache-2.0) and the footer of every published page; `C-03` (no account); `C-17` for the keyless local model. There is no price, no billing code and no purchase path anywhere in the tree — an absence, stated as one.

**Later, not in this build — the lead's English finding of 27 October, for the owner.** One word carries two meanings in the English, and it is the third time this round in a third language: **«mark»**. Q6 says «the scan and your own taught values **mark** what they find», and every other «mark» on the page is the person's own hand — «what you marked» in Q12, «what must I mark myself» in Q19's heading. It is exactly what the owner caught in the Arabic Q6 and what the lead then caught in the German. The English is approved text, so it is not touched here; the German and the Arabic already say it his way, which means the three languages disagree until this is settled in all three together.

**Later, not in this build — the owner's editorial note of 27 October.** «a model running on your own computer costs nothing at all» overreaches: it costs electricity and it costs the machine. It becomes, in all three languages, **«needs no fee to an AI provider just to run it locally»**. That is an English, German and Arabic change together, and it is not in the pages built on 27 October.

**Changed.** The hedge is withdrawn on the owner's word: **«free» stands with no qualification.** His reason is a company decision rather than a measurement — Z Privacy is Faruk AB's investment in trust, and Mono Scribe is the commercial product — and it is recorded here so that the sentence has a known author.

## Q22 · Is it open source, and can companies use it?

**Answer.** Yes — Apache License 2.0, with the source repository linked from this site. Use it as you like, in a company or alone, and ask nobody. This project ships a `NOTICE` file, and §4(d) of the licence says what a distributed derivative work must do with the notices such a file contains; the licence and the file are both published here, and they are the text that governs rather than anything said on this page. It is attribution carried forward, not an advertisement you owe us.

**Evidence.** `LICENSE`; `NOTICE`, quoted from its own first two lines; Apache-2.0 §4(d), which lists exactly those three places and says the notices are «for informational purposes only»; the «Source and licence» block on `site/en/index.html`.

**Changed.** Two things. The quoted attribution now matches `NOTICE` as it actually reads, with the company's registered details, instead of the shortened form revision 1 used. And «a product built on this code says so where it lists what it is built on» is replaced by the licence's own three places and the words «not an advertisement you owe us» — his point being that §4(d) preserves attribution and does not impose promotion. **Revision 3:** the legal explanation is shortened again. Listing the three places and quoting the attribution line made a FAQ answer into a reading of the clause, and a reading can be wrong in a way the text it summarises is not. The answer now points at `LICENSE` and `NOTICE` and says plainly that those govern — which is both shorter and the only thing we are in a position to assert.

## Q23 · How can I check Z Privacy's claims myself?

**Answer.** `docs/CLAIMS.md` lists every claim with the same four lines each: the sentence we actually show, what it does **not** cover, the test or gate that proves it, and the command you run yourself. It is worth knowing what those two kinds of proof are: a **test** runs this product's code and measures what it does, while a **gate** reads the source and measures its shape — that there is one network client, that the interface cannot open a socket, that every door obeys a law. A shape check shows that the code satisfies the constraint it checks; it is not a recording of the program running, and no number of them adds up to a network capture, an installation or a security audit — which is why some claims in that file carry the word «unproven» rather than being removed from it.

**Evidence.** `C-16`; `docs/CLAIMS.md`'s own «What a proof is made of» paragraph, from which the second and third sentences are taken; gate `G56` refuses a section missing one of its four lines or naming a path, gate, test or sentence key that does not exist; `C-04` and `C-15` are the two claims carrying «unproven» today.

**Changed.** «`bash scripts/gates.sh` runs the whole set and prints how many checks ran and how many failed» is gone. A count of checks is not evidence of security, and quoting it invites the reader to treat it as one. What replaces it is the distinction that actually matters to somebody auditing us — test against shape check — and the plain statement of what shape checks cannot do. **Revision 3:** «shows the code **cannot be** a certain thing» became «satisfies the constraint it checks». The first claims impossibility; a text check over a tree establishes that the constraint it looked for holds, which is a smaller statement and the true one. One sentence changed, nothing else.

## Q24 · Which operating systems does it run on, and why does Windows warn me?

**Answer.** Linux x86_64 with GTK3, and Windows 10 or 11 on x86_64; macOS, iOS and Android are not built. On Windows the first start shows a blue «Windows protected your PC» page, because nothing has signed this installer: that page means Windows has no basis to treat the file as trusted, not that it has examined it and found it safe or unsafe. The SHA-256 printed on the download page tells you the file you have is the file that fingerprint describes, provided the fingerprint itself comes from a source you trust — it says nothing about who published the file, and if the site serving both were compromised both could change together. It is not a substitute for a signature, and the download page's own paragraph says what the screen looks like and how it is got through.

**Evidence.** `site/en/download/index.html`, which the answer links to rather than restating; `C-14`; «What we do not claim · Every platform».

**Changed.** Both of his mandatory corrections. (1) The warning is about Windows having no basis for trust, not about the file being examined and cleared — revision 1's «not that it found anything wrong inside it» could be read as a clean bill of health. (2) **SHA-256 does not prove who published a file.** It proves the bytes match a published fingerprint, and only as far as that fingerprint's source is trusted; one site serving both means one compromise changes both. Saying so costs us the neatest line on the download page and is the single most important correction in this round. The «More info → Run anyway» steps and the measured hedge beside them now stay where they are measured, on the download page, and this answer links there.

## Q25 · Who makes Z Privacy?

**Answer.** Faruk AB, Aktiebolag (AB), Sweden. Company registration (Org.nr) 559473-3494. Hotellgatan 3, 311 31 Falkenberg, Sweden. Contact and support: zprivacy@mono-peak.com — there is no form and nothing is collected on this site.

**Evidence.** The publisher block printed on every page, field for field: «Faruk AB», «Aktiebolag (AB), Sweden», «Company registration (Org.nr) 559473-3494», «Hotellgatan 3, 311 31 Falkenberg, Sweden», and «Contact and support: zprivacy@mono-peak.com». The site's own guard already holds that block identical in every place it is stated.

**Changed.** The four fields are now the publisher block's own wording in its own order, so the FAQ cannot drift from the Impressum. «Z Privacy is a mono-peak project by Faruk AB» is dropped from the answer: it is the colophon's line, not a fact about the publisher, and repeating it here would be a second place to keep in step.

---

## What changed in revision 2, and what it cost

**Fifteen answers moved. Four of the edits are substantive rather than verbal,
and they are the ones worth a second reading.**

- **Q12** claimed a property of the machine from a test of one request body.
  Our own `C-04` is marked **unproven** for precisely that reason, so the FAQ
  was making a claim the claims file refuses to make. It now separates what is
  sent, what a provider can observe because you connected at all, and what the
  test literally measured.
- **Q14** said «what you have sent is not kept here at all». The file classes
  are now named from the gate that counts them, including the settings file
  that is not encrypted and the restored PDF that holds values in the clear —
  and the temporary-file and log questions are answered rather than assumed.
- **Q6** said «the figures travel unchanged; the identities do not». A figure
  can itself identify somebody, and no scanner is guaranteed to have found
  every identity. That sentence was the most quotable thing in revision 1 and
  the least defensible.
- **Q24** now says that a SHA-256 does not prove who published a file. It
  proves the bytes match a published fingerprint, as far as that fingerprint's
  source is trusted, and one site serving both means one compromise changes
  both.

**What it cost, said plainly:** the answers that used to be sharp are now
qualified, and the page is less quotable for it. Q12, Q14, Q19 and Q24 each
lost a line that would have travelled well. That is the owner's trade and it
is the right one for this product — but it should be made with open eyes
rather than discovered later, so it is written here.

**One answer is still blocked.** Q20's Arabic-PDF clause, waiting on ed's
measurement against a fixture. The second half of that question — refused by
name, or imported as readable-looking text that matches nothing — may be a
defect report rather than a FAQ sentence.

## The consistency test of the promises — what it is, and what it found

His check, from reading all 25: an answer that says **always**, **never**,
**nothing leaves** or anything of that shape claims every case, and a test
that measured one request, one door or one build does not cover every case.
`scripts/check_the_absolutes.py` is that check, run over this file and over
the FAQ pages once they exist.

**It is a register, not a cleverer scan.** It finds the absolute words
mechanically and then refuses any it has not been told about. Each one has to
be written down once with a verdict: the claim, test or gate that covers it as
stated; or **qualified**, meaning the sentence carries its own limit in the
same breath; or **not ours**, meaning the absolute is about the law, about
somebody else's product or about the world, so no test of ours could cover it
and none is claimed. Nothing passes for being obviously fine. The cost is a
line in a table; what it buys is that a *new* absolute cannot enter quietly,
and that softening a sentence reds the check instead of silently leaving the
register claiming it was examined.

**Today: 40 absolutes across 21 of the 25 answers.** 25 carry a named proof,
8 are qualified in their own sentence, 7 are not about Z Privacy at all.

**And it found three things while it was being built**, which is the argument
for building it:

1. **Q14 said «the only address this program speaks to is the provider you
   configured».** That is a statement about a running program resting on
   checks that read a tree — the exact gap that keeps `C-04` marked unproven
   in `docs/CLAIMS.md`. The sentence now names what those checks establish and
   says **«is built to speak to»**. This is the one substantive correction of
   revision 3 that nobody asked for; the register asked for it.
2. **Q16 asserts the same absolute twice** — once in our words and once inside
   the shipped sentence it quotes. Both are registered, because a quotation is
   still something this page says, and a translator working from the English
   will meet both.
3. **The checker's own first matcher was wrong in the way this file is about.**
   It asked whether a registered phrase was anywhere in the answer, so one
   entry could answer for a different absolute — Q21's «nothing to subscribe
   to» covered «costs nothing at all», and the second was then reported as
   having disappeared. A register that can be satisfied by the wrong line is
   not a register. Hits are bound by position now.

**For translation, which is the next place this earns its keep:** eight of the
forty are safe *only* because of the words around them. A translator who
tightens «it says nothing about what other programs on your computer do» or
«only as strong as the passphrase you choose» for readability removes the
limit and leaves the absolute. Running this over the German and Arabic pages
needs its own register per language, and that is a real piece of work rather
than a flag to flip — named here so it is planned rather than discovered.

## The order from here, as he set it

1. These fixes. **Done — this file.**
2. The evidence for each claim, tightened to match the corrected answers.
   **Done in the same pass:** Q11 now names a test per protection method, Q12
   names the three body fields and the headers by source, Q14 names the gate
   that counts the file classes, Q19 names the door census and the gate that
   reads it, Q22 quotes `NOTICE` and Apache-2.0 §4(d) as they actually read,
   Q23 names what a shape check cannot do.
3. **ed's Arabic PDF measurement**, on a fixture.
4. The final English review — **this file is waiting there now.**
5. Then Arabic and German translation.
6. A meaning check across the three languages.
7. Publish.

**No translation before the English is final.** Several of the corrections
above are a single qualifying clause doing the whole work — «by means
reasonably likely to be used», «does not make data anonymous by itself», «as
far as that fingerprint's source is trusted». A translator who tightens any
one of those for readability puts back the overstatement it was written to
remove, so each will need naming when step 5 starts.

*Branch `feat/the-questions-before-the-name`, from `1cc2733`. No page, no
engine change, no app feature. Z Privacy's product code stays paused.*
