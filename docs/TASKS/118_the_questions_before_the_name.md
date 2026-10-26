# 118 — The questions people ask before they know Z exists

**Source:** the owner, 26 October 2026. Discovery measured on publishing day showed that Google and AI assistants find Z when asked BY NAME, and do not when asked about the PROBLEM. The English pages say «ChatGPT» 0 times, «GDPR» 0, «anonymize / redact / pseudonymize» 0, «personal data» 0 and «free» 0. His direction: we no longer ask «how do we make Google know Z?», we ask **«what questions does a person ask before knowing Z exists?»**. Builder: **e2** (the site is your seat). Z's product code stays paused: **this paper changes no engine and no app feature for the sake of content.**

## The governing rule (the owner's, verbatim in substance)

**Every answer that describes a capability of Z must rest on `docs/CLAIMS.md` or on a documented test. Where the evidence is not enough, the claim is not published until it is verified.** Z is a privacy product, so it must never overstate its guarantees.

And the owner's distinction, which is the voice of the whole page: not «Z Privacy protects your sensitive information» (a promise from the company), but «What exactly does the AI provider receive when I use Z Privacy?» (a chance to show evidence a person can understand and check). Write the second kind.

## The 25 questions (approved, with the owner's four amendments)

**A · The problem, for someone who does not know Z**
1. Is it safe to paste client documents into ChatGPT?
2. Do AI services use my conversations or files for training? And do they keep them? *(amended: retention and training are two different questions; answer both, and point to each provider's own policy, never paraphrase it as fact)*
3. How can I use AI on documents with personal data without sending the names?
4. What should I consider under GDPR before sending client data to AI? *(amended: not a yes/no. Distinguish data minimisation, the legal obligations, and what Z can and cannot guarantee. It is not legal advice, and the controller's DPO decides)*
5. What is the difference between anonymisation and pseudonymisation?
6. How can an accountant use AI without exposing clients' financial data?
7. How can a lawyer use AI on case files confidentially?
8. Can I use AI on medical or HR documents without revealing who they are about? *(the owner: to be split later into medical and HR, since the risks and regulation differ; one question for this first page)*
9. What happens to my data when I upload a PDF to an AI chatbot?
10. Can I use an AI model on my own computer instead of a cloud service?

**B · How Z solves it, and where it stops**
11. What does Z Privacy do, in one minute?
12. What does the AI actually receive?
13. How do the real names come back into the answer?
14. Does Z see or store my documents?
15. Where are my names kept, and how are they protected?
16. What happens if I forget my passphrase?
17. Which AI services work with Z?
18. Does Z make me anonymous to the AI provider? *(unchanged; the answer begins with «No»)*
19. What does Z detect automatically, and what must I mark myself?
20. Which file types and languages does it support?

**C · Trust and practice**
21. Is Z Privacy free?
22. Is it open source, and can companies use it?
23. How can I check Z's claims myself?
24. Which operating systems does it run on, and why does Windows warn me?
25. Who makes Z Privacy?

No new questions for the first page.

## The order of work (the owner's seven steps)

1. Fix the question list above as written.
2. Write the **English answers**, from CLAIMS and the proven functions only: 2–4 sentences each, plain language, no superlatives.
3. Deliver a **review file** (`docs/faq-review.md` in your branch, not a page yet). It has each question, its answer, and **beside it the evidence: the claim (C-NN) or the test file**, plus «NOT PUBLISHABLE YET: why» for any answer whose evidence is thin. The evidence column is for review, not necessarily for the published text.
4. The owner and the lead review it, technically and linguistically. **Stop here until that review.**
5. After approval: a **FAQ page in three languages** (`/en/faq/`, `/de/faq/`, `/ar/faq/`), linked from the home page and the guide. Bind the factual answers to the site gates as §6 and C-13 are bound, so a later change in the product reds the page instead of leaving it stale.
6. Test the page, the links and the structured data; then publish. **FAQPage JSON-LD only if it matches the visible questions and answers exactly.** It is written for the human first: Google mostly limits FAQ rich results to well-known government and health sites and guarantees nothing ([Google's FAQPage documentation](https://developers.google.com/search/docs/appearance/structured-data/faqpage)). It is not a ranking trick.
7. Then the **three standalone pages**, each worth its own page only because it adds useful information:
   - **Q1, client documents and ChatGPT:** the risks, and the difference between sending the whole document and sending only what is needed.
   - **Q3, AI without sending the names:** a practical page with the data's path, and a before/after example from fixtures only (never a real client).
   - **Q4, GDPR and AI:** data minimisation vs the legal obligations vs the limits of what Z can guarantee.
   The FAQ keeps the short answers and links to these.

## Questions whose answers are technical claims: extra care

16 (passphrase: today there is **no recovery**, and the app says so; the recovery key is designed but **not built**), 15 (the vault: what C-06 states, nothing more), 17 (providers: the measured sentence of 105, two spoken to, four listed, any address changeable, a local model keyless), 20 (file types and languages: what the readers and the four packs prove; Arabic PDFs do not arrive readable yet, so say it), 24 (the unsigned installer and the SmartScreen page, as on the download page). **Do not invent a capability.** If unsure, mark it in the review file.

## Also in scope, small

The three technical gaps found in the same audit, with no content change: absolute URLs in `hreflang`; Open Graph / Twitter tags on the pages (title, description, one chosen image); a `SoftwareApplication` JSON-LD on the home page (free, Windows + Linux, Apache-2.0, Faruk AB, the code repository, the download page), true to the site's own facts. Plus a link to GitHub **Releases** on the download pages. These can land with step 5 or before it, as you judge.

## Measurement

Site gates green in both modes, the review file delivered at step 3 before any page, and after publishing the lead's outside check (the pages answer, and the JSON-LD validates).
