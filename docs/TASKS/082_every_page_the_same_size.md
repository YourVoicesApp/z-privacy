# 082 · Every page the same size — the page is a sheet, not a line between paragraphs

**Opened by the owner, 13 Oct 2026.** The two columns already move together («ممتاز»). Three things remain about pages, and one untested case.

## Today (d882c5f)

A page is not drawn as a page. The reader leaves a form feed between pages; both columns paint a **page-edge line** where it falls (`PageEdgePainter`, `apps/flutter_app/lib/widgets/document_text.dart:573` and `:802`; the payload's own edges come from the core, `PayloadView.page_edges`). So a page that holds one line is one line tall, and a full page is tall — the eye reads a stream with rules across it, not sheets.

## The owner's rulings

1. **A page carries its text as it is.** A page with a large picture and ten words brings over the ten words, nothing invented to stand for the picture.
2. **Every page is drawn at one uniform size**, whatever it holds — one line or forty.
3. **A small visual difference the eye can see between pages:** white page, slightly less white page, alternating.
4. **Text inside a table — never tried yet.** To be measured before anything is built.

## Measure before building

- **Tables:** a real PDF with a table (a payslip, an invoice with columns — `Lohnabrechnung` is the nearest fixture, and it is text, so a real table PDF is needed from the owner's own files) → what the reader hands over: cell order, row order, what separates cells (space, tab, line break), in de/en/sv/ar. Shown to the owner as screenshots, both columns.
- **Uniform size, the open question for the owner:** «one size» = the tallest page of this document, or a fixed sheet proportion (A4)? A page whose text is longer than the sheet — does the sheet grow, or does the text scroll inside it? The lead's suggestion: A4 proportion at the column's width, and a page longer than that grows (text is never clipped — protection may not change how a document reads, and neither may the frame).
- **Both columns:** the Original and the safe column draw the same sheets at the same heights, so they still move together (the W8/073 alignment must survive — a guard: sheet N starts at the same scroll offset in both columns).
- **Typed and pasted text** (no pages): one sheet, or no sheets? Lead's suggestion: no page frame for text that never had pages.

## Seat and order

Design seat (sheets, tints) with the Dart seat for alignment; the core already says where pages fall. Order: after 076 selection, unless the owner places it earlier. The table measurement can run any time — it changes nothing.

## 13 Oct night — the size, ruled

The owner: **every sheet is 15 cm wide and 20 cm tall, for every page, whatever the number of lines it holds.** One line or forty, the sheet is the same.

- The proportion is fixed (3 : 4); on screen the sheet is drawn at the column's width with that proportion, so «cm» means the shape, and on an exported page it means the size.
- **Measure before building:** the longest page in the corpus and in a real table PDF — does its text fit a 15×20 sheet at the document font? If a page's text does not fit, the measurement is shown to the owner before anything is decided; text is never clipped (protection may not change how a document reads, and neither may the frame).
- The owner also kept both column switches («In step / Apart» and «Chips / Plain»): «simple choices that really leave a mark» stay.

## 13 Oct night — the Z sheet, sealed by the owner («نعتمد الأرقام والأسلوب الحالي»)

1. **The Z sheet is 15 cm wide × 20 cm tall.** Every page Z shows or makes is one Z sheet.
2. **Bringing a page onto a Z sheet scales it** by the ratio between the source page's size and the Z sheet — the source is shrunk to fit, not reflowed into another font.
3. **A document Z generates from the chat** (a text sent to protection) is laid out on Z sheets: **a 3 cm empty margin at the top and a 2 cm empty margin at the bottom; the remaining 15 cm hold the text in 15 lines** (one line per centimetre). The owner's correction: the margins are measured in centimetres of the 20 cm sheet.
4. **The PDFs Z exports use the same Z sheet and the same margins.**
5. **Why the empty rows** (the owner): the person must have room to add **their own letterhead at the top and their own stamp at the bottom** — Z's paper is meant to be carried into real offices.
6. Unchanged from above: alternating white between sheets; text never clipped; the protection request is the measure (chat without protection, and chat about an already-protected document, get no sheets).

**The lead's reading, to show the owner on the glass before it is called done:** the 3 cm top and 2 cm bottom margins are blank on *every* sheet of a generated document and an export; on a scaled source page they are added around the scaled content. The answer page of 079 follows the same sheet: its «Z-pdf : Zprivacy-svara» line sits in the first text row, the export's footer in the bottom margin.
