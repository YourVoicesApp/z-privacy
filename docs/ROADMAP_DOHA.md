# The road to Doha — a road map

Not a work plan: no tasks, no owners, no dates. Where we are going, in what order, and how we will know we have arrived. The owner, 14 Oct 2026: «نحن نبني خارطة طريق وليس خطة عمل».

## The destination

**Web Summit Qatar, Doha, 31 Jan – 3 Feb 2027.** ALPHA $1,197; flight, hotel and visa outside it; nothing owed until it is paid.

**What we want from it, in the owner's answer:** Z is free, so nothing is sold to a person who uses it. What is sold is the thing itself. «تطبيق عمره أشهر ولديه مستخدمون بالألف — كم من المستثمرين يريد شراءه؟»

So the road carries one number: **how many people took it.** Today: none.

## What is actually for sale

The app earns nothing and measures nothing, by design. A buyer is not buying its revenue.

- **zprivacy-lib and the contract are the asset** — the only part someone who is not us can put inside their own product. This is the architecture the owner ruled on 13 Oct: the app stays ours; the library is how Z enters other people's systems.
- **The users are the proof** that the boundary works outside this house.
- **The two hosts** show Z inside one business, and between two.

**The app earns the users; the users prove the library.**

## The stations

**1 · The app is finished, in German, English and Swedish.** Arabic is not here, by the owner's ruling that languages come last.
*Why first:* everything after it is spending on something unfinished.
*Arrived when:* the owner runs the whole round himself and finds nothing that stops him.

**2 · It runs on Windows.**
*Why here:* Z is Linux only, and almost nobody who needs Z has Linux. No number on this road can grow before this station. It begins with one friend trying it, not with people — the glass is not yet measured on Windows, and that is said rather than hidden.
*Arrived when:* it installs on a Windows machine that is not the lead's, reads a German letter, protects it, and a paste after Copy Protected carries no name.

**3 · It is published, and what we count is honest.**
*Why here:* a road to people needs a door they can walk through — a download page of its own, in German.
*The rule we do not break:* Z keeps nothing and sends nothing, so we cannot count people and will not start. We count **downloads**, on our own server, and we say «downloads» — never «users», which the product itself forbids us to claim.
*Arrived when:* the owner downloads it from the site the way a stranger would, on a machine that is not his, and it works.

**4 · We learn what one person costs.** A small paid test in Germany alone, at the owner's limit of $100–200.
*Why here:* it is not a campaign and cannot be — that money is some tens of clicks in a country whose privacy and legal words are among the dearest. It is a **measurement**, and it is the measurement an investor asks for.
*Arrived when:* the cost of one download is written down.

**5 · Doha.**
*What the stand shows:* an application people are already taking, and the library that puts Z inside somebody else's product.
*The decision is the owner's:* the full number against what the counter says.

**Beside the road, in the libraries — the same mechanism, unchanged.** The owner, 14 Oct: while the app is finished on Linux and Windows, the libraries go on being built **by the library officer's plan and exactly the present mechanism**: he lays out a round, it is built, the lead attacks it, the lead pushes it, and then the next round. Round after round, in parallel with the stations above.

The round now in the officer's hands is the exchange between two owners — Z travelling with the work from one person to another. Its shape changed on 14 Oct, when the owner ruled that **the answer to a Z document is written inside Z** (087).

## After the first publication in Germany — the accounting system

**The owner, 14 Oct 2026:** «بعد نشر التطبيق بنسخته الأولى في ألمانيا سنقوم بإنشاء نظام محاسبة حقيقي جدّي، من رتبة Fortnox على الأقل… وهنا النقطة التي سوف تقلب المعادلة: باستخدام Z حارساً، والأعمال جميعها داخل التطبيق يقوم بها الذكاء الصناعي. كل خيار هو نص داخلي يقرأه الذكاء الصناعي.»

**Why it turns the equation over.** Accounting is the field that needs AI most and trusts it least. A company's books are its most dangerous data: customers' names, account numbers, salaries, personal numbers, invoices. That is why nobody hands their books to a model today. **Z is what makes it possible** — an accounting system run by AI cannot exist without it. That is the wall no competitor walks through.

**We have built its seed already.** V1-H, the accounting node in `YourVoicesApp/z-ledger-node` (`9bf1e76`, sealed): invented data, Z guarding the boundary to the model, and a second node that holds the first one's tokens and cannot reveal them, 6 of 6. The owner's idea is the grown form of what that round proved small.

**The one principle that must govern it is Z's own.** The model **proposes** an entry; the ledger's laws **verify** it; the person **approves**. Accounting does not accept an entry that is plausible and wrong — but double entry carries its own judge: debit equals credit, the account exists, the VAT rule holds. The model writes; the ledger's law decides; exactly as Z suggests a word and the person decides it.

**The hard part is the law, not the model:**
- **Sweden, Bokföringslagen:** a verification cannot be erased once recorded, records are kept for seven years, every change leaves a trace; SIE files; reporting to Skatteverket.
- **Germany, GoBD:** the same conditions — immutability, traceability, retention — and the DATEV export.

**And a link the owner did not set out to make:** the law demands records that **accept no change**. That is the `.peak` idea of the same day (087) — a closed document, refused when altered. The two ideas meet here.

**What it does to «what is for sale».** Z stays free and is the trust and the reach; the accounting system is the thing that is paid for, and Z inside it is the reason it can exist at all.

**Its shape — the Gate and the Repository (the owner, 14 Oct):** «نجعل التطبيق جزأين: البوابة والمستودع. البوابة هي القسم الذي تدخل فيه البيانات وكل شيء. المستودع هو موطن سيد الذكاء الصناعي، ويعمل بطريقة المفتاح. بحيث تصبح المحاسبة من نوع: أرسل الصور، احصل على البيانات.»

| | what it is | what crosses it |
|---|---|---|
| **The Gate** | where everything enters: photos, invoices, statements | **on the owner's own device** |
| **The Repository** | the home of the model, working by the key | **only protected text reaches it** |

The Gate is Z's boundary itself: behind it, originals that never leave; in front of it, tokens.

**The collision, said plainly.** Z today **refuses images by decision**: a page with no text layer is a photograph, we do not guess what is in it, **and we do not send it anywhere to be read** (`z_core/src/api.rs`, `Refusal`). A photographed receipt carries a name, a card number, an address; sent to a model to be read, all of it leaves in the clear.

**The way through does not break that decision, it fulfils it:** the Gate **reads the photo on the device itself**, turns it into text there, Z protects the text, and only then does the protected text go to the Repository. The decision was «we do not send it anywhere to be read»; reading on the device sends nothing.

> **«Send the photos, get the data»** becomes: the photo enters the Gate, is read on your machine, is protected, **and nothing leaves the Gate but protected text.**

That is a large new capability Z does not have — **reading images on the device** — and it is the heart of the Gate.

**The owner's motive, in the product's own words:** the business owner holds the books and their key in his own hand, with no firm standing between him and his money.

**The owner's own workflow today, the model it replaces (14 Oct):** he keeps his books in Fortnox and photographs every invoice on his phone with the app that serves that accounting system. So the Gate has a phone in it. «لا ندخل بالتفاصيل الآن» — the details wait.

**Open for the owner — parked, not now:**
- **«Works by the key» — which key?** The model's key, which the owner brings for his own model, as Z's send works today; or the session's key, so the Repository holds tokens and only the key's holder restores names; or both.
- **Which country's books first?** Fortnox is Swedish, the company is Swedish, the owner knows the Swedish system and the Swedish pack exists; Germany is where Z publishes first. The lead would start where the company stands.
- **Are amounts private?** The model needs the numbers to do accounting, so they cannot all become tokens — yet a small firm's turnover is itself a secret. This is the first question the system will ask of Z, and it is not answered yet.
- **Does any of it stand in Doha?** An early form of «AI does the books, Z guards them» is a far stronger stand than a free privacy app alone — and far larger to build.

## Not on this road

- **Arabic** — the reading base is a measured defect with its paper (086) and the packs come last; both wait. Doha is Arabic-speaking, which argues for them, but an application nobody can install reaches nobody in any language.
- **`.peak`, the closed document** (087) — parked by the owner. It is the engine of spread once documents are travelling, not before.
- **More document formats.** Three readers cover the office: a PDF arrives, Word is written, text is pasted.
- **Everything in the libraries except the exchange round.**

## What only the owner can decide

- Who, by name or by trade, he can reach — a free product with no advertising and no store travels by the people who already trust him.
- Whether the paid test stays at its limit, or grows on the number it returns.
- Whether Doha is worth its full price when the counter has spoken.
