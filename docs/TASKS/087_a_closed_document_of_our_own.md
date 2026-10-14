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

## Guards (when it is built)

- **The seal guard:** one byte changed anywhere in a `.peak` → refused, with a sentence that says the file was changed, never a half-read document.
- **The token guard:** every token written into a `.peak` comes back byte for byte, and no token is split across a line or a sheet.
- **The nothing-else guard:** the bytes of a `.peak` hold no original value, no key and no map — the same byte-level scan V1-I imposes on its PDF, with a planted control string proving the scan can see.
- **The way out guard:** every `.peak` exports to a PDF of the same sheets.
