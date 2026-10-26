# 118 · The 25 questions, their English answers, and the evidence behind each

**This is a review file, not a page.** Paper 118 step 3: the owner and the lead
read it, technically and linguistically, before anything is published. The
evidence column is for that review; it is not necessarily the published text.

**The rule this file is written under** (the owner, 26 October 2026): every
answer that describes a capability of Z Privacy rests on `docs/CLAIMS.md` or on
a documented test. Where the evidence is not enough, the answer is **not
published until it is verified**. Z Privacy is a privacy product, so it may
never overstate what it guarantees.

**And the voice**, which is his too: not «Z Privacy protects your sensitive
information» — a promise from a company — but «What exactly does the AI
provider receive?», a question that can be answered with something a reader can
check. Every answer below is written to be checkable.

## How to read an entry

- **Answer** — the English text proposed for the page, 2–4 sentences, plain,
  no superlatives.
- **Evidence** — the claim (`C-NN`), the test file, the gate or the source line
  **that exists in this tree at this commit**. Where an answer is about
  somebody else's product or about the law, the evidence says so, because a
  sentence about a third party is not a capability of ours and must never be
  dressed as one.
- **NOT PUBLISHABLE YET** — the evidence is thin or stale. The reason is named
  and so is the measurement that would close it.
- **BEFORE PUBLISHING** — publishable, but something must be decided or
  maintained first. These are not evidence gaps; they are scope and upkeep.

## Three things no answer below does

1. **No answer states what any AI provider does with your data.** Training and
   retention are set by each provider's own terms, by plan, and they change.
   We point at their pages; we never paraphrase them as fact
   (`docs/THE_PROVIDERS.md`).
2. **No answer says that using Z Privacy makes anything lawful.** It reduces
   what you send. The controller, and their DPO, decide the rest.
3. **No answer names a capability that is designed but not built.** A FAQ that
   mentions a coming feature has made a promise.

---

## Q1 · Is it safe to paste client documents into ChatGPT?

**Answer.** That depends on your agreement with the service and on what is in the document, and it is a question about them rather than about us. What is certain either way is that the whole document leaves your machine: the names, the account numbers and the addresses travel with the part you actually wanted help with. The smaller question — does the model need those values to answer? — is usually no, and that gap is what Z Privacy was built for.

**Evidence.** No capability of ours is claimed until the last sentence, which is `C-01` (only the protected version is sent; `z_core/tests/wire_capture.rs`). The first two sentences are about the reader's own service and are written as such — «depends on your agreement», not «they keep it».

## Q2 · Do AI services use my conversations or files for training? And do they keep them?

**Answer.** Those are two different questions and each provider answers them separately: training is whether your content is used to improve a model, retention is how long a copy is kept and who may see it. The answers differ by provider, by plan — a consumer account and an API account are often not the same — and they change over time, so the only reliable source is the provider's own current policy. Z Privacy changes neither; what it changes is what is in the text you send.

**Evidence.** `docs/THE_PROVIDERS.md` (the owner's ruling: Z does not come between you and the provider and takes no position on their terms); `C-01`'s limit (the envelope travels). No claim is made about any named provider.

**BEFORE PUBLISHING:** The page must **link** to each provider's own policy page rather than describe it. A link list is a claim about somebody else that rots: it needs a named owner, a re-read date, and a decision on which providers are listed — the six in our catalogue, or only the two we have ever spoken to. Without that decision this answer ships without links, which weakens it but tells no lie.

## Q3 · How can I use AI on documents with personal data without sending the names?

**Answer.** You replace each value with a token before the text leaves, and put the real values back when the answer comes home. In Z Privacy that is the whole path — Import, Scan, Review, Protect, Choose who answers, AI, Restore — and before anything is sent you are shown exactly what will leave. The replacement is reversible on your own machine only: the mapping lives in your vault and nowhere else.

**Evidence.** `C-01` (`z_core/tests/wire_capture.rs` records the request byte for byte and asserts the body is the safe payload, with no original and no vault value in body, headers or URL); `C-06` (the vault, `z_core/tests/the_vault_file_says_nothing.rs`); the path as the app prints it, already on `site/en/index.html`.

## Q4 · What should I consider under GDPR before sending client data to AI?

**Answer.** Three separate things, and none of them substitutes for another. **Data minimisation** (Art. 5(1)(c)) asks whether the model needs a given value at all — that is the question a tool like Z Privacy helps with. **Your legal obligations** — a lawful basis, your records, your processor agreements, transfers — are yours, and no tool changes them. And **what Z Privacy can guarantee** is narrow and stated plainly: it replaces values in the text you send, which is pseudonymisation and not anonymisation, so what you send is still personal data (Art. 4(5), Recital 26). This is information, not legal advice; your controller or DPO decides.

**Evidence.** The GDPR's own text (Art. 4(5), Art. 5(1)(c), Recital 26) — cited, never interpreted beyond its wording; our own «What we do not claim · Anonymisation» in `docs/CLAIMS.md`.

**BEFORE PUBLISHING:** Four sentences, which is the paper's limit, and every clause is load bearing — this is the one answer where a translator who shortens it changes its legal force. The last sentence must survive into German and Arabic unchanged in strength, and the three-way split must stay a split.

## Q5 · What is the difference between anonymisation and pseudonymisation?

**Answer.** Anonymisation means nobody can get back to the person; once that is true the data is no longer personal data at all (Recital 26). Pseudonymisation replaces identifying values with stand-ins while a mapping that can reverse it still exists somewhere — the data stays personal data (Art. 4(5)). Z Privacy does the second: the mapping is your vault, on your machine. And a text with every name removed can still be about one identifiable person — a single-patient clinic letter is the standard example.

**Evidence.** «What we do not claim · Anonymisation» in `docs/CLAIMS.md`, which uses that exact example; `C-06` for where the mapping lives; GDPR Art. 4(5) and Recital 26.

## Q6 · How can an accountant use AI without exposing clients' financial data?

**Answer.** Work on the document inside Z Privacy: the scan and your own taught values mark the names, account numbers and client references, and the question goes out with tokens in their place. The figures and the structure — which is what a model actually needs to check a tax document — travel unchanged; the identities do not. Your professional obligations are not changed by this: Z Privacy reduces what you send, it does not make the sending permissible.

**Evidence.** `C-11` (the scanner is rules, packs and your vault; `z_core/tests/nothing_leaves_while_a_word_waits.rs`); `C-01`; `docs/THE_PROVIDERS.md` for the last sentence.

## Q7 · How can a lawyer use AI on case files confidentially?

**Answer.** The same path: the facts of the matter travel, while names, file references and addresses are replaced before anything leaves, and the answer is restored on your machine. Z Privacy does not decide whether your professional rules allow an external model to see a matter at all — that judgement is yours and it differs by jurisdiction. What it changes is how much identifying detail is in what you send, and it shows you the exact text before it goes.

**Evidence.** `C-01`; `C-12` (the way back, `z_core/tests/the_door_back.rs`); `C-02` (the original stays here unless you copy restored content yourself).

**BEFORE PUBLISHING:** Must not read as a view on professional secrecy in any jurisdiction. The word «confidentially» is in the question, not in the answer, and that asymmetry is deliberate — check it survives translation.

## Q8 · Can I use AI on medical or HR documents without revealing who they are about?

**Answer.** Mechanically yes — names, identifiers and addresses can be replaced before the text leaves. But these are the two kinds of document where the identity is most often inferable from the content itself, and no replacement fixes that. Health data is a special category under Art. 9 and HR data carries its own obligations; whether to process it with an external model at all is the controller's decision, not a tool's. If you do, pseudonymisation is a measure, not a permission.

**Evidence.** «What we do not claim · Anonymisation» (the single-patient clinic letter is our own example of exactly this); GDPR Art. 9; `C-01`.

**Note.** The owner's amendment: this splits later into a medical question and an HR question, because the risks and the regulation differ. One question for this first page.

## Q9 · What happens to my data when I upload a PDF to an AI chatbot?

**Answer.** The file leaves your machine and is processed on the provider's servers; what happens next — how long a copy is kept, who may look at it, whether it is used to improve a model — is set by that provider's terms and your plan, and is not visible from the file. The part worth noticing is that a PDF carries every page, including the ones you did not need help with. Z Privacy's answer is to send the text with the values replaced, rather than the file.

**Evidence.** Same discipline as Q2: nothing is asserted about any provider. The last sentence is `C-01` plus `C-10` (the reader's named limits, `z_core/src/documents/mod.rs`).

**BEFORE PUBLISHING:** Carries Q2's link condition. If Q2 ships without provider links, this one must too — a page that links policies in one answer and not in the next reads as though the second had something to hide.

## Q10 · Can I use an AI model on my own computer instead of a cloud service?

**Answer.** Yes. Z Privacy speaks to any server that answers an OpenAI-compatible request, including one on your own machine — llama.cpp, Ollama, LM Studio — and a local model needs no key at all. Plain `http` is accepted only for a **literal** loopback IP address, never for a name like «localhost», so a hosts file cannot be what decides that plaintext is safe. On that path nothing leaves the machine.

**Evidence.** `C-17` (`z_core/tests/the_bundle_of_six.rs`, `z_core/tests/the_model_gateway.rs`); `z_core/tests/truthfulness_regressions.rs::lie_a_keyless_login_claims_a_key` measures the keyless local login with the vault open; the loopback rule is one function before any socket is opened — `is_loopback_url` in `z_core/src/providers/http.rs`, measured by `plain_http_is_refused_unless_the_host_is_a_literal_loopback_address`; `C-03` for «nothing leaves».

## Q11 · What does Z Privacy do, in one minute?

**Answer.** You open a document or write a question. Z Privacy scans it with its rules, its language packs and the values you have taught it, and shows you two columns: your original, and what would leave. You protect what should not go — automatically, by pressing a word, or by selecting it with your hand — and nothing leaves while a suggestion is unanswered. Then you choose who answers, see the exact text before it is sent, and the answer comes back with your names restored on this machine.

**Evidence.** `C-11`; `C-01`; `C-12`; the path and the two columns as the app prints them (`site/en/index.html`, `site/en/guide/index.html`).

## Q12 · What does the AI actually receive?

**Answer.** The protected text, and the request's own envelope: the provider's address, the time, the model's name and the size of what was sent. Inside the app a second question also carries the exchange before it — the previous question and its answer, in the protected form they left in — and never the document again. Nothing else from your machine goes: a test records the request byte for byte against a local server and asserts the body **is** the safe payload, character for character, with no original and no vault value in the body, the headers or the URL.

**Evidence.** `C-01` (`z_core/tests/wire_capture.rs`) and its limit, which is where the envelope sentence comes from; `C-13` (`z_core/tests/the_chat_remembers.rs`, `a_third_question_carries_only_the_exchange_before_it`).

## Q13 · How do the real names come back into the answer?

**Answer.** On your machine, out of your vault. Inside the app the answer is restored as it arrives; if you carried the question to a model yourself, «Add an answer» brings the text back and every token that chat has carried turns back into its name. A protected PDF has its own door: «z-pdf» in Settings reads such a file back into its names and says which session each one came from. A token whose key this vault does not hold stays as text, and the app says so rather than guessing.

**Evidence.** `C-12` (`z_core/tests/the_door_back.rs`, `z_core/tests/the_answer_page_finds_its_way_back.rs`); `C-09` (the vault is the boundary of who can read back, the session decides how a value is named); `C-13` for the hand-carried answer.

## Q14 · Does Z Privacy see or store my documents?

**Answer.** There is no Z Privacy account, no Z Privacy server and no analytics — the only address this program speaks to is the provider you configured, with the key you gave it. On your own machine Z keeps one document: the one in the preview that has not left its session, sealed in that session's own file. What you have sent is not kept here at all; it lives wherever you sent it.

**Evidence.** `C-03` (one HTTP client, gate `G1`; the interface cannot open a socket, gate `G5`; one reader behind the gateway, gate `G16`; no Z Privacy endpoint in the tree); `C-08` (`z_core/tests/the_preview_keeps_what_it_holds.rs`, `z_core/tests/the_session_is_born_at_the_first_document.rs`).

## Q15 · Where are my names kept, and how are they protected?

**Answer.** In one encrypted vault file on your device, one block per protected value, opened by a passphrase that never leaves the machine — a test searches the written file for the names it was taught and finds none. The encryption is only as strong as the passphrase you choose, and an unlocked vault is readable by anything running as you on that machine: we protect a file at rest, not a machine already taken. On Linux the folder is narrowed to you and the core refuses to write if it cannot be; on Windows the folder is whatever that machine's own permissions make it.

**Evidence.** `C-06` (`z_core/tests/the_vault_file_says_nothing.rs`, `z_core/tests/zcfg_leak.rs` for the one file that is not encrypted, gate `G15`'s census of the four file classes, gate `G8`: no function in the contract returns a key or a passphrase); `z_core/src/secure_file.rs` for the 0700 folder and its Unix-only half.

## Q16 · What happens if I forget my passphrase?

**Answer.** The vault cannot be opened — not by you and not by us. Nobody holds a copy, no reset exists, and nothing on our side could recover it. The app says exactly that before you set one: «There is no way back. Nobody holds a copy of this, and no reset exists — the passphrase never leaves this device and nothing on our side could recover the vault without it.»

**Evidence.** The sentence is the shipped one, key `thereIsNoWayBack` in `apps/flutter_app/lib/l10n/app_en.arb`; `C-06` (the passphrase is never stored) and gate `G8`.

**BEFORE PUBLISHING:** **This answer must not mention a recovery key.** One is designed and it is not built; naming it here turns a design note into a promise on a published page, and a privacy product that promises a way back into a vault has said the most dangerous sentence it owns. If the owner wants the roadmap named, that is a different page with a date on it.

## Q17 · Which AI services work with Z Privacy?

**Answer.** The catalogue is six by name — OpenAI, Anthropic, xAI, DeepSeek, Moonshot and Google — and of those, two have ever been spoken to: OpenAI and Anthropic, because those are the keys we hold. Five of the six go out through the same `chat/completions` request shape and Anthropic has its own, so «any service» is exactly as wide as those two shapes, however open the address field is. Every connection is made at an address you can change, and a model on your own computer needs no key at all.

**Evidence.** `C-17` and paper 105's narrowing of it (`z_core/tests/the_bundle_of_six.rs` measures the six by id and that the four without a credential report themselves unavailable; `z_core/tests/the_model_gateway.rs` makes every request against a local server that records the bytes).

## Q18 · Does Z Privacy make me anonymous to the AI provider?

**Answer.** No. You sign up under your own name with your own key, and the provider is entitled to know who its customer is; the address, the time, the model and the size of your request all travel. Z Privacy removes the values inside the text — it does not remove you. What it protects is the people in your documents, who agreed to nothing with your provider.

**Evidence.** «What we do not claim · Anonymity from the provider», verbatim in substance; `C-01`'s limit; `docs/THE_PROVIDERS.md` (the owner's own ruling of 7 October, which is where the last sentence comes from).

**Note.** The owner left this question unchanged and set its first word: «No».

## Q19 · What does Z Privacy detect automatically, and what must I mark myself?

**Answer.** Automatically: what its rules describe. IBANs and BICs in any language, and per language set e-mail addresses, telephone numbers, tax and social-insurance numbers, customer, contract and employee references, dates of birth, people, companies and addresses — plus every value you have taught it, matched wherever it appears. Anything it is unsure of becomes a suggestion that waits for your word: no door opens while one is unanswered, and there is no «send anyway», not in a menu and not in a hidden flag. What it still misses is written down rather than left to be found — a typographic ligature, a date of birth written out in words, and a payment card from a network whose prefix is not in the published table.

**Evidence.** `C-11` (`z_core/tests/nothing_leaves_while_a_word_waits.rs`; the refusal is one function, gate `G28`; the four doors are a census, gate `G36`); the kinds are read from `z_core/src/scanner/sets/` (`world.rs`: Iban, Bic; `de.rs`, `en.rs`, `sv.rs` for the rest); the three misses are «What we do not claim · Detection of everything», each with its own named test.

**BEFORE PUBLISHING:** Five sentences, which is one over the paper's limit. It is over because the open misses are the honest half of the answer and will not fit beside the list. Either the limit bends here or the misses become a linked line — the owner's call, not mine.

## Q20 · Which file types and languages does it support?

**Answer.** Files: plain text (`.txt`, `.md`, `.csv`), Word documents (`.docx`) and PDFs. A PDF with no text layer — a photograph of a document — is refused by name rather than guessed at, and so is an encrypted one. Detection has four language packs today — English, German, Swedish and Arabic — beside rule sets that are not bound to a language, and the interface itself speaks those four. **Arabic inside a PDF does not arrive readable yet**: for Arabic, use `.txt` or `.docx` until that is fixed.

**Evidence.** `_kinds` in `apps/flutter_app/lib/screens/shell.dart` maps the five extensions onto three readers; the named refusals are the `Refusal` enum in `z_core/src/api.rs` (`ScannedPdfNoTextLayer`, `EncryptedPdf`, `UnsupportedEncoding { page, readable_percent }`, `UnreadableStructure`); the packs are `z_core/src/scanner/packs/{ar,de,en,sv}.rs` and the sets `z_core/src/scanner/sets/`; the interface languages are the four `app_*.arb` files.

**NOT PUBLISHABLE YET:** The last sentence is the owner's and the lead's, and I believe it — but the **number** behind it is stale and the behaviour behind it is unmeasured. The measurement is `docs/THE_NUMBERS.md` §4.3, taken at `08b04aa`: 7 of 7 taught names found in an Arabic letter as `.txt`, **0 of 461** in the same book as a PDF, because presentation forms in visual order defeat every list. At this commit the evidence is by absence — `z_core/src/documents/pdf.rs` contains no step that converts Arabic presentation forms to letters or recovers logical order (zero hits for `FB50`, `FE70`, «presentation», «logical order»), and paper 038-C is still marked WAITING. Two things to do before this clause is published: (a) measure it again at the build the page will describe, and (b) answer the question nobody has — **is such a PDF refused by name, or imported with text that looks fine and matches nothing?** `UnsupportedEncoding` measures readable percent **per page**, and glyph codes may well read as «readable». If the app imports it silently, the FAQ sentence is not «use .txt» but a warning, and it is a product defect the page should not be papering over.

## Q21 · Is Z Privacy free?

**Answer.** Yes. There is no paid tier, no account and nothing to subscribe to, and the source is under the Apache License 2.0. What can cost money is the model you choose: a key from OpenAI or Anthropic is billed by them at their prices, and a model running on your own computer costs nothing at all.

**Evidence.** `LICENSE` (Apache-2.0) and the footer of every site page; `C-03` (no account); `C-17` for the keyless local model. There is no price, no billing code and no purchase path anywhere in the tree — which is the evidence for «no paid tier», and is an absence rather than a test.

**BEFORE PUBLISHING:** «Free» is a word a company can grow out of. If a paid tier is ever intended, this answer is the sentence that will have to be unsaid in public — worth the owner's eye for one minute now.

## Q22 · Is it open source, and can companies use it?

**Answer.** Yes — Apache License 2.0, with the source repository linked from the site. Use it as you like, in a company or alone, and ask nobody; the one condition is the one the licence already carries. A product built on this code says so where it lists what it is built on — «Z Privacy, Copyright 2026 Faruk AB» — as the `NOTICE` file asks and Apache 2.0 §4(d) binds. That means its own notices, its documentation or its About screen; it does not mean advertising.

**Evidence.** `LICENSE`, `NOTICE`, and the «Source and licence» block already published on `site/en/index.html`, from which the last two sentences are taken almost word for word — they were written for exactly this question when it was asked once before.

## Q23 · How can I check Z Privacy's claims myself?

**Answer.** `docs/CLAIMS.md` lists every claim with the same four lines each: the sentence we actually show, what it does **not** cover, the test or gate that proves it, and the command you run yourself. `bash scripts/gates.sh` runs the whole set from a plain debug build and prints how many checks ran and how many failed. A claim we have not measured carries the word «unproven» in that file rather than being quietly removed from it.

**Evidence.** `C-16` (`scripts/gates.sh`, `docs/MEASURED_ON_LINUX.txt` and the stamp gate that refuses a tree whose test count has drifted); `docs/CLAIMS.md` itself, which gate `G56` reads on every run and which refuses a section missing one of its four lines or naming a path, gate, test or sentence key that does not exist.

## Q24 · Which operating systems does it run on, and why does Windows warn me?

**Answer.** Linux x86_64 with GTK3, and Windows 10 or 11 on x86_64; macOS, iOS and Android are not built. On Windows the first start shows a blue «Windows protected your PC» page, because nothing has signed this installer: that page says Windows does not recognise who published the file, not that it found anything wrong inside it. «More info», then «Run anyway» gets through, and nothing asks for an administrator — it installs for you alone, in your own folder. Since no signature says the file is ours, the SHA-256 printed on the download page is what does: run the one line there and compare, character for character.

**Evidence.** `site/en/download/index.html`, which carries all of this already and is the page this answer must not drift from; `C-14` (the build's own stamp and the hashes); «What we do not claim · Every platform».

**BEFORE PUBLISHING:** The download page says the second button «was offered every time on the machine where this was measured», and that hedge is deliberate. The FAQ sentence above drops it for brevity and therefore hardens a measured observation into a general one. Either restore the hedge or link straight to that page's own paragraph — I would link.

## Q25 · Who makes Z Privacy?

**Answer.** Faruk AB, a Swedish limited company (Aktiebolag), company registration number 559473-3494, at Hotellgatan 3, 311 31 Falkenberg, Sweden. Contact is by e-mail — zprivacy@mono-peak.com — and there is no form and nothing collected on this site. Z Privacy is a mono-peak project by Faruk AB.

**Evidence.** The publisher block and the footer on every published page (`site/en/download/index.html`, `site/en/index.html`), which the site's own claim checker already holds.

---

## What this file says when you stand back from it

**One answer is blocked, and it is blocked on a measurement rather than on a
word.** Q20's Arabic-PDF clause is true as far as anyone here knows, and the
number behind it is from `08b04aa`. Publishing a stale number on a page whose
whole argument is «check us» would be the one mistake this page cannot afford.
What closes it is half an hour with an Arabic PDF at the build the page will
describe — and the answer to the second question (refused by name, or imported
and silently useless) may turn a FAQ sentence into a defect report.

**Seven answers carry a condition, and they fall into three kinds.**

- **Upkeep we would be taking on** — Q2 and Q9 want links to provider policy
  pages. A link to somebody else's policy is a claim that rots on their
  schedule, not ours. Either we name an owner and a re-read date, or we ship
  both answers without links and say less.
- **Words that must not harden in translation** — Q4 (the three-way split and
  «not legal advice»), Q7 («confidentially» is the question's word, not the
  answer's), Q24 (the download page hedges «on the machine where this was
  measured»; my shorter sentence drops the hedge, and should link instead).
- **A promise not to say something** — Q16 must not mention the recovery key
  that is designed and not built. This is the single most dangerous sentence on
  the page: a privacy product that hints at a way back into a locked vault has
  undone the claim it is there to make.

**And one answer is over length on purpose.** Q19 runs to five sentences
because the three things the scanner still misses are the honest half of it.
Trimming it trims the limits, which is the direction this product does not
trim. The owner's call.

**What none of these 25 answers does** is claim a capability that is not in
`docs/CLAIMS.md` or in a test. The ones that lean hardest on evidence — Q12,
Q14, Q15, Q16, Q17, Q19 — each name a test file you can run from the root of
this repository, and `docs/CLAIMS.md` carries the command beside every one.

## Still to do in paper 118, not done here

Step 3 ends at this file, and the paper says stop. Not started, in the paper's
own order:

- **Step 5** — the FAQ page in three languages, bound to the site gates as §6
  and `C-13` are, so a product change reds the page instead of leaving it
  stale.
- **Step 6** — `FAQPage` JSON-LD only if it matches the visible text exactly.
- **Step 7** — the three standalone pages (Q1, Q3, Q4).
- **The four small technical items**, which need no owner review because they
  change no sentence: absolute URLs in `hreflang`, Open Graph and Twitter tags,
  a `SoftwareApplication` JSON-LD on the home page true to the site's own facts,
  and a link to GitHub **Releases** on the download pages. The paper leaves
  their timing to me; they can land the moment the lead says go, independently
  of this review.

*Written on branch `feat/the-questions-before-the-name`, from `1cc2733`. No
page, no engine change, no app feature. Z Privacy's product code stays paused.*
