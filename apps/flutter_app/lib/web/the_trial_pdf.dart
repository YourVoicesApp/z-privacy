// **The visitor's document** — paper 122 §3.2, rule 85 (b).
//
// Built in memory with the `pdf` package, and **not a z-pdf**: rule 80 does
// not govern it. It holds two things, under two headings in the page's
// language:
//
//   1. the visitor's text **exactly as written**, unprotected;
//   2. the model's answer with the real names put back (the core's
//      `restored_view` text, as it gave it).
//
// It carries no token of ours that was placed, no token map, no session
// number, no footer, no stamp and no /Info (no title, author, producer or
// date): `pdf` writes an /Info dictionary only when one of them is given.
//
// Arabic reads right to left: each run of paragraphs takes the direction the
// desktop's z-pdf gives it (`directionBlocks`, one rule for both), and the
// headings take the page's own direction.
import 'dart:typed_data';

import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:zprivacy/core/the_way_text_reads.dart';
import 'package:zprivacy/l10n/app_localizations.dart';

/// DejaVu Sans, the one font the app already embeds in its PDFs: Latin,
/// Arabic and the Swedish letters, subset into the file by `pdf`.
Future<ByteData> theTrialFont() =>
    rootBundle.load('assets/fonts/DejaVuSans.ttf');

Future<Uint8List> buildTheTrialPdf({
  required String yourText,
  required String answer,
  required AppLocalizations t,
  required bool pageIsRightToLeft,
  required ByteData font,
  bool compress = true,
}) {
  final f = pw.Font.ttf(font);
  final doc = pw.Document(compress: compress);
  final body = pw.TextStyle(font: f, fontSize: 11, lineSpacing: 2.2);
  final heading = pw.TextStyle(font: f, fontSize: 14, color: PdfColors.grey800);
  final headingDirection = pageIsRightToLeft
      ? pw.TextDirection.rtl
      : pw.TextDirection.ltr;

  pw.Widget title(String words) => pw.Partitions(
    children: [
      pw.Partition(
        child: pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10, top: 6),
          child: pw.Text(
            pageIsRightToLeft ? '‏$words' : words,
            style: heading,
            textDirection: headingDirection,
            textAlign: pageIsRightToLeft
                ? pw.TextAlign.right
                : pw.TextAlign.left,
          ),
        ),
      ),
    ],
  );

  List<pw.Widget> paragraphs(String text) => [
    for (final block in directionBlocks(text))
      pw.Partitions(
        children: [
          pw.Partition(
            child: pw.Text(
              block.laidOut,
              style: body,
              textDirection: block.rtl
                  ? pw.TextDirection.rtl
                  : pw.TextDirection.ltr,
              textAlign: block.rtl ? pw.TextAlign.right : pw.TextAlign.left,
              overflow: pw.TextOverflow.span,
            ),
          ),
        ],
      ),
  ];

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(44, 44, 44, 52),
      build: (_) => [
        title(t.trialYourText),
        ...paragraphs(yourText),
        pw.SizedBox(height: 18),
        title(t.trialTheAnswerWithRealNames),
        ...paragraphs(answer),
      ],
    ),
  );
  return doc.save();
}
