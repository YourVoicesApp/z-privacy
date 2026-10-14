# 087 · A closed document of our own — `.peak`

**Opened by the owner, 14 Oct 2026.** «الوثائق التي نصدرها من Z تكون بلاحقة مثل `.peak` مثلاً، وتكون وثائق مغلقة لا تقبل أي تعديل.»

## What it is for — three jobs, not one

1. **Identity.** A document that came out of Z is recognised by its name, not by a mark the eye has to find. Paper 079 already rules that every document leaving Z carries its mark twice, one for the eye and one for the machine; an extension of our own is the third and plainest.
2. **The token stays whole.** A `.peak` is written and read by us alone, so no editor can cut `__Z_AB12_PERSON_8F31__` in half or normalise a letter inside it. This is the very requirement V1-I had to impose on a PDF writer from outside (token integrity, no token split across a line); in our own format it is a property, not a condition.
3. **It carries no metadata we did not write.** A PDF carries a producer string, font names, an XMP block — surfaces where a name can leave without anyone intending it (the file-name leak of 081 was exactly this class). A format of ours carries what we put in it and nothing else.

## The shape — the lead's reading, for the owner's word

### `.peak` stands beside the PDF, never instead of it

The purpose of the Z sheet (082) is that Z's paper can be **carried into real offices**: 15 × 20 cm, 3 cm of empty top for the person's own letterhead, 2 cm of bottom for the stamp. An office accepts a PDF. A lawyer who receives a `.peak` and has no Z has received a wall.

So: **PDF for the world, `.peak` for Z to Z.** Both from the same Z sheets, both under the same law — no key, no value map, nothing but the safe text (C1, C2).

### «Accepts no modification» — what we can actually promise

A file on a disk can always be altered; nobody can make bytes immutable. What is in our power, and is worth more, is this:

> **A `.peak` that has been changed is refused, and says why.**

That we can measure and guarantee: the file carries a seal over its own content, and Z reads it fail-closed, exactly as the PDF reader already refuses a page it cannot read faithfully rather than half-reading it (`z_core/src/documents/pdf.rs:89`).

**And the seal is integrity, not authenticity** — the same discipline V1-I imposed on its export reference: it proves the file is the one that was written, **not** who wrote it. A signature needs a key and an identity, and both were deliberately deferred. The seal is recorded as a **protocol candidate**, never announced as a signature.

### What a `.peak` holds

- the Z sheets, as sheets (082: 15 × 20, the two margins, the 15 lines);
- the safe text, with every token an atomic span;
- the session's own name as the file's name (081), never the source document's;
- for an exchange (V1-I): the export reference, and the reply-to reference — neither of them secret;
- **never**: a key, a value map, an original value, the vault, session state.

### Open for the owner

- **The name.** `.peak` is the house's name; `.zp` or `.zpk` would be the product's. His word. The lead will check what the extension already means in the world before it is announced anywhere.
- **Can a `.peak` be opened for reading by someone without Z?** The lead's suggestion: no reader of ours outside Z, but **every `.peak` can be exported to PDF by one press**, so a closed document is never a trap.

## When

The paper is written now, as the owner asked. It is **built when V1-I needs a carrier**: that round is exactly a document travelling between two owners, and it plans to travel as a PDF with a writer built to keep tokens whole. That is the moment `.peak` earns its place instead of being a second format for its own sake. Until then nothing is built, and the PDF export stays the only door out.

## The owner's rulings of the same hour — recorded at his word, and parked

**1. The exported document is a new document, legally.** «الوثيقة الأصلية بصيغة PDF موجودة، والوثيقة الصادرة عن Z وثيقة جديدة تماماً… حتى لو كانت تحمل نفس النص، لكن الوثيقتين لا تحملان نفس الأسماء، وقانونياً لا يمكن اعتبارهما وثيقة واحدة.» So it must not pretend to be the original: another name, another extension, its own mark. The words are shared; the names are not.

**2. What leaves is an image of the protected text, not text.** «نصدر وثيقة هي عبارة عن صورة النص بعد التشفير بلاحقة خاصة بنا، هي صورة وليست نص يمكن ضبط تشفيره وتغيير صيغة النص.» The lead's reading of why this is stronger than what he had proposed: the great failure of redaction is a black box drawn over a name while the name stays under it in the file — V1-I had to impose a byte-level scan to catch exactly that. **Under an image there is no text at all**, so that defect is not refused but impossible; and with it go the split token, the altered letter inside a token, and the metadata nobody meant to write. The owner named Adobe himself: the technique is not ours and is not claimed. The differences are that it is our **default** and not an option for those who know; that our protection **returns** by the owner's key where a redaction never does; and that the file never leaves the device.

**3. Z reads what is inside its own file**, so a `.peak` is not «an image only» nor «text only» but our document: the Z sheets, their images, the safe text with its tokens, and the seal.

**4. The format carries the product.** «بدون ورد لا يمكنك فتح ملف ورد، وبدون Z لا يمكن فتح `.peak`.» This is the strongest business argument of the day and it is not a technical one: Word spread because the files were everywhere, so whoever wanted to read what arrived needed Word. Ours spreads by work rather than advertising — a lawyer to a client, an accountant to an office, a doctor to a laboratory — and everyone who receives a document needs Z.

**5. Z is free, entirely** (the owner). So the format's job is reach, not a paywall; the lead's suggestion of a free read-only reader beside a paid product falls with it.

**6. THE ANSWER TO A Z DOCUMENT IS WRITTEN INSIDE Z.** «الإجابة على أي وثيقة من Z تكون من داخل التطبيق، وبذلك نضمن أن الأكواد تنقل كما هي تماماً… حتى لو تغيّر النص تبقى الأكواد. محامٍ وصلته رسالة وأراد الإجابة عليها، فالأكواد تنتقل من الأول إلى الإجابة بطريقة مقفلة تماماً.»

This is the product's shape for the whole of V1-I, and it is cheaper and safer than what that round had planned. The reply is composed **inside Z**, so a token moves as an **object we carry**, never as text a foreign editor might break. What it makes unnecessary, or nearly so, of the lead's six conditions on that round:

| condition | what the ruling does to it |
|---|---|
| 4 · every token survives the carrier byte for byte | still measured, but the carrier is ours and the token is never retyped |
| 4 · no token split at a line's end | **cannot happen**: there is no text for a writer to wrap |
| 5 · a broken token stays ordinary words | still guarded, for a file that arrived altered |
| 5 · a token is never protected a second time | **cannot happen**: an inherited token is carried, not scanned |
| 6 · a token is one atomic unit in the editor | **a property, not a condition** |

And it is exactly the two-owner proof the round was built for: the tokens A owns travel into the reply and restore for A alone; the values B protects become B's own tokens; one document, two restore authorities.

**7. Mono-Peak has the same feature** (the owner): our own mail carries Z documents and their replies. That is the first real shape of the Z network, and it runs on a server we own.

**Parked:** nothing of 087 is built on the owner's word. The dialogue is recorded here so that the reasoning is not lost.

## Guards (when it is built)

- **The seal guard:** one byte changed anywhere in a `.peak` → refused, with a sentence that says the file was changed, never a half-read document.
- **The token guard:** every token written into a `.peak` comes back byte for byte, and no token is split across a line or a sheet.
- **The nothing-else guard:** the bytes of a `.peak` hold no original value, no key and no map — the same byte-level scan V1-I imposes on its PDF, with a planted control string proving the scan can see.
- **The way out guard:** every `.peak` exports to a PDF of the same sheets.
