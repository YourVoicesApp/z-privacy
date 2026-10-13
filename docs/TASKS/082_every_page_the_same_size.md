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
