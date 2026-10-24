// «Save as PDF» — the protected text, written as a file on this machine.
//
// The owner, 7 October: «زرُّ النسخ نحافظ عليه كما هو، ونضيف إليه خيار نسخة PDF
// ليقوم التطبيق بحفظ النص في الجهاز كملف PDF.» Copy Protected stays exactly as
// it was; this is a second act beside it, and the only difference between them
// is where the text lands — the clipboard, or a file.
//
// **Neither of them sends anything.** There is no network call in this file and
// no way to reach one from it: the text arrives as a string and leaves as bytes
// on a local path.
//
// ## Why Dart writes the file
//
// Gate G15 allows the filesystem inside `z_core/src` only on the vault's own
// lines, each one marked so the exemptions stay countable. A PDF writer in the
// core would have to break that or earn a second exemption, and neither is
// worth it for a file the person asked for by name. So the core gives the text
// and the numbers; this writes the file.
//
// ## What goes in it, and what does not
//
// The body is the protected text, nothing added. After it, one page more — the
// answer page (079, below). One footer line on every page, the answer page
// included, and only facts a reader can check for themselves:
//
//   * the build stamp — `z_core 0.1.0 · date · sha`, the same line the window
//     shows, so a file can be traced to the build that made it;
//   * how many places were replaced and how many values, by kind;
//   * the sha256 of the protected text, which is the **same string** Copy
//     Protected puts on the clipboard — so the claim is checkable with
//     `sha256sum` and nothing of ours.
//
// No logo, no serial number, no seal. A footer stating a fingerprint is
// evidence; a footer stating a brand is decoration, and decoration that looks
// like proof is the one kind this product may not ship.
//
// **And every word of it is in the language of the session this file left** —
// rule 80, the owner, 21 October 2026, and English where that session has no
// language of its own. The footer, the mark and the answer page's top line go
// *into a file*: the interface stays on this machine and the file travels, so
// what travels is worded for the person who reads the document rather than for
// the person at the screen. Nothing in this file reads `sentences`, the
// interface's holder, for anything that is written into the PDF — the five
// refusals below it do, and they are right to: those are on the glass.
//
// **One mark beside it, and it is a claim about what the page is, not about
// who made it** — 079, the owner, 13 Oct: a hard line between a pdf and a
// z-pdf, so that the protected copy is never mistaken by its own owner for an
// ordinary file. `z-pdf · protected copy`, in the footer's own size and grey,
// in front of the stamp. It is the person's half of the mark; the app's half is
// the token on the answer page, because detection must never rest on a name
// anybody can type.
//
// ## The answer page — 079
//
// The owner's design, sealed on the evening of 13 Oct. A lawyer who writes by
// hand or retypes may not carry the tokens over whole, so the returned
// document needs one thing that always finds its way back:
//
//   * **top:** `Z-pdf : ` and the token of «Zprivacy-svara» — the word
//     protected with **the same session key as the document**, so the page
//     carries an ordinary token of that session and never the key. The core
//     mints it and hands this file the token; the word itself never crosses
//     the bridge, so there is nothing here that could print it in the clear;
//   * **middle:** a circle in a faint line, where the answer is written. No
//     label: a label would have to be Arabic to say what the owner said
//     («الإجابة هنا»), and a word printed here unshaped would be the one
//     visible flaw on the page;
//   * **bottom:** **the same footer every other page of this export carries**
//     — the one widget, called once more, not a second design;
//   * the rest blank.
//
// And **no document metadata at all** — no `/Info` dictionary, so no title, no
// author, no creation timestamp. This file exists to be handed to a model or to
// a person: a document's name is not protected text, and «Müller-Scheidung»
// sitting in `/Title` would travel out of the device inside the very file that
// was made to stop that. The name stays on the local file name, where the owner
// asked for it and where it does not travel.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/l10n/app_localizations.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

/// sha256 of a string, the way a reader would compute it: UTF-8 bytes, lower
/// hex. The footer states this over the protected text, and the protected text
/// is what Copy Protected copies — one number, checkable from the clipboard.
String sha256OfText(String text) => c.sha256.convert(utf8.encode(text)).toString();

/// The strong right-to-left letters, by the blocks they fall in.
///
/// Arabic and its supplements and presentation forms; Hebrew; Syriac, Thaana,
/// NKo and Samaritan between them. **Arabic here is a script, not a language**
/// — Persian and Urdu are written with it and read the same way, so the test
/// is the block and never the pack that happens to be loaded.
final _strongRtl = RegExp(
  r'[֐-׿؀-ۿ܀-ݏݐ-ݿހ-޿'
  r'߀-߿ࠀ-࠿ࢠ-ࣿיִ-ﭏﭐ-﷿ﹰ-﻿]',
);

/// The strong left-to-right letters. Latin, Greek and Cyrillic are enough for
/// what this product reads; anything outside both sets is not strong and does
/// not get a vote.
final _strongLtr = RegExp(r'[A-Za-zÀ-ʯͰ-֏]');

/// A token, which is ours and not the person's writing.
final _token = RegExp(r'__Z_[A-Z0-9_]+__');

/// Which way this one paragraph runs, or null when it has no opinion.
///
/// **The first strong letter decides** — the Unicode rule (UAX #9, P2/P3), not
/// one of ours. So a line opening with an amount or a date takes its direction
/// from the first real word after it, which is how an Arabic payroll line that
/// begins with a number comes out right. A paragraph with no strong letter at
/// all is left to right, as the algorithm says.
///
/// **With one subtraction: a `__Z_…__` token does not vote.** Its letters are
/// Latin and they are *ours* — we put them in the person's line. Counted as
/// strong they would decide the direction of any line whose first word was
/// protected, so protecting an Arabic name would silently lay that line out
/// left to right and the same document would read differently before and after
/// protection. Protection may not change how a document reads; that is close
/// to the whole promise. So the tokens come out before the question is asked.
bool paragraphIsRightToLeft(String paragraph) =>
    paragraphDirection(paragraph) ?? false;

/// True for right to left, false for left to right, **null for a paragraph
/// with no strong letter in it at all** — a blank line, a rule of dashes, a
/// line that is only a figure.
///
/// Null is not «left to right». A neutral line takes the direction of the
/// paragraphs around it, because a blank line between two Arabic paragraphs is
/// part of that Arabic passage and not a left-to-right interruption of it.
/// Treating it as left to right split the passage in three and the blank lines
/// disappeared from the page — found by rendering a letter and looking at it,
/// not by a test.
bool? paragraphDirection(String paragraph) {
  // Replaced by a space rather than removed, so the words either side of a
  // token stay separate words.
  final letters = paragraph.replaceAll(_token, ' ');
  final rtl = _strongRtl.firstMatch(letters);
  final ltr = _strongLtr.firstMatch(letters);
  if (rtl == null && ltr == null) return null;
  if (rtl == null) return false;
  if (ltr == null) return true;
  return rtl.start < ltr.start;
}

/// One run of neighbouring paragraphs that share a direction.
///
/// Grouping matters for more than tidiness: a document with no right-to-left
/// writing in it becomes **exactly one** block, so the page it produces is the
/// page it produced before any of this existed, and a German or Swedish
/// document cannot be disturbed by work done for Arabic.
class DirectionBlock {
  const DirectionBlock(this.rtl, this.text);
  final bool rtl;
  final String text;

  /// The text as it is handed to the writer, with a RIGHT-TO-LEFT MARK in
  /// front of every right-to-left line.
  ///
  /// **Because the bidi library decides the base direction for itself**, by the
  /// same first-strong rule — and it counts the Latin letters of a `__Z_…__`
  /// token, which we put there. So a line beginning with a protected name was
  /// ordered left to right by the library while being right-aligned by us: the
  /// token sat at the left-hand end of a right-aligned Arabic line. Measured on
  /// a rendered page, which is the only place it shows.
  ///
  /// U+200F is strong, zero width and carries no glyph of its own — the page
  /// with it and the page without it are identical wherever the direction was
  /// already right. The isolates U+2067/U+2069 would say it better and were
  /// tried first; DejaVu has no glyph for them and they drew as two `.notdef`
  /// boxes on the page.
  ///
  /// Every line, not just the first: the algorithm works a paragraph at a time
  /// and a block here is several paragraphs.
  String get laidOut => rtl
      ? text.split('\n').map((line) => '\u200F$line').join('\n')
      : text;

  @override
  bool operator ==(Object other) =>
      other is DirectionBlock && other.rtl == rtl && other.text == text;

  @override
  int get hashCode => Object.hash(rtl, text);

  @override
  String toString() => '${rtl ? 'rtl' : 'ltr'}: ${text.replaceAll('\n', '⏎')}';
}

/// Cut the text into runs of paragraphs that share a direction.
///
/// A neutral paragraph — blank, or only figures — joins whatever run it finds
/// itself in and never starts one, so the blank line inside an Arabic passage
/// stays inside it and is still a blank line on the page. Leading neutral
/// lines wait for the first paragraph that has a direction and take it.
List<DirectionBlock> directionBlocks(String text) {
  final out = <DirectionBlock>[];
  bool? dir;
  final held = <String>[];

  void close() {
    if (held.isEmpty) return;
    out.add(DirectionBlock(dir ?? false, held.join('\n')));
    held.clear();
  }

  for (final line in text.split('\n')) {
    final here = paragraphDirection(line);
    if (here != null && dir != null && here != dir) {
      close();
      dir = here;
    } else {
      dir ??= here;
    }
    held.add(line);
  }
  close();
  return out;
}

/// Where a saved PDF goes — **the core's answer, not this file's guess.**
///
/// This read `Platform.environment['HOME']` and built `$home/Documents/zprivacy`
/// from it. On Linux that is right. On Windows `HOME` is not set for a program
/// with a window, so the folder came back empty and every «Save as PDF» ended
/// in the refusal below: the third exit did not exist on the second platform.
///
/// It is the same mistake `z_core/src/data_dir.rs` was written to delete — the
/// vault's folder was decided in Dart in one line just like this one — made
/// again a month later for the other folder. So the answer comes from
/// `default_documents_dir`, which says it in each platform's own terms.
///
/// A refusal still returns the empty string: the sentence a person reads for
/// this belongs to the caller, which writes nothing and says so.
Future<String> protectedPdfFolder() async {
  try {
    return await z.defaultDocumentsDir();
  } on ApiError {
    return '';
  }
}

/// The facts the footer states. Not one of them is **discovered** here — the
/// stamp, the count and the digest all arrive from the caller, and what this
/// class does is add them up and choose the words. A screen that works out its
/// own evidence is a second opinion about a fact, and this project knows where
/// that leads.
class PdfStamp {
  const PdfStamp({
    required this.build,
    required this.places,
    required this.byKind,
    required this.sha256,
  });

  /// `coreVersion()` — the core's own line, verbatim.
  final String build;

  /// How many **places** in the document were replaced. The core's
  /// `PayloadView.protected_count`, which is the count the builder made while
  /// it was building this very text.
  final int places;

  /// How many **values** stand behind those places, by kind: `{'Person': 6}`.
  /// A value protected in four places is one value and four places, and the
  /// footer says both because they are different facts.
  final Map<String, int> byKind;

  /// sha256 of the protected text, lower hex.
  final String sha256;

  int get values => byKind.values.fold(0, (a, b) => a + b);

  /// `Person ×6, Account number ×2` — the count beside the kind, in the kind's
  /// own words as the core gives them. No pluralising: a rule that guesses at
  /// English grammar would guess wrong in the next language, and `×6` is read
  /// the same in all of them.
  ///
  /// **The kind's name is the core's word and not this list's** — `KindRow`
  /// says so at the field: «What to call it. The core's word, not the
  /// screen's». So the one word this house owns here is what stands in place
  /// of the kinds when there are none, and that one is read from the list like
  /// every other. Whether the core answers `kinds` in the session's language
  /// is the core's own question and is not settled by rule 80; it is named
  /// here rather than assumed, because a German footer stating English kind
  /// names would be this seam and nothing else.
  String kindsIn(AppLocalizations t) => byKind.isEmpty
      ? t.noKindsAtAll
      : (byKind.entries.map((e) => '${e.key} ×${e.value}').toList()..sort()).join(', ');

  /// The one line. Long on purpose — a sha256 is sixty-four characters and
  /// shortening it would make it decoration again.
  ///
  /// Single spaces around each `·`, not the two that read better: G25 fails on
  /// a run of spaces inside a sentence, and it is right to — the gate exists
  /// because the owner read a refusal with nineteen spaces in the middle of it.
  /// This is also the separator `core_version()` already uses.
  ///
  /// **A reader rather than a getter, since rule 80.** The words are the
  /// session's and the holder is the interface's, so the list this line is
  /// worded from arrives from the door that is writing the file. The two
  /// counts and the digest are unchanged — they are the caller's facts, and
  /// `×6` reads the same in every language.
  String lineIn(AppLocalizations t) =>
      '$build · ${t.placesReplaced(places)}, '
      '${t.valuesOfTheseKinds(values, kindsIn(t))} · '
      '${t.sha256OfTheProtectedText(sha256)}';
}

/// The footer of one export: the mark, then the stamp of this one request.
///
/// **One function for every page, the answer page included**, so «the same
/// footer» is not two widgets that happen to agree today. The owner: «في الأسفل
/// نفس الترويسة التي تخرج من جميع الأوراق الأخرى في نفس الطلب».
///
/// The mark — «z-pdf · protected copy» — was a `const` in this file until rule
/// 80 and is `t.zPdfProtectedCopy` now, for the same reason as everything else
/// the footer says: it goes into a file, and the file's language is the
/// session's.
pw.Widget _footer(PdfStamp stamp, pw.TextStyle style, AppLocalizations t) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10),
      child: pw.Text('${t.zPdfProtectedCopy} · ${stamp.lineIn(t)}', style: style),
    );

/// Read once per process. The font is 759,720 bytes and the bytes do not change.
ByteData? _font;

Future<pw.Font> _embeddedFont() async {
  _font ??= await rootBundle.load('assets/fonts/DejaVuSans.ttf');
  // `pdf` embeds a **subset**: only the glyphs this text uses reach the file,
  // so a one-page letter costs a few kilobytes of font, not three quarters of a
  // megabyte. DejaVu already carries a name containing neither «Bitstream» nor
  // «Vera», so subsetting does not touch the licence's renaming clause.
  return pw.Font.ttf(_font!);
}

/// The PDF's bytes. Separate from writing them so a test can read the file back
/// without a disk in the way, and so `compress: false` is reachable.
///
/// [answerToken] is the core's token for the answer page's word, and it is
/// **required**: an export without its answer page is not a z-pdf, and a
/// parameter that could be left out is a page somebody will one day leave out.
///
/// [sessionLanguage] is **required and nullable**, by the same argument one
/// paragraph up: `null` is a real answer — «this file left no session, or one
/// nobody asked» — and English is what it means (rule 80). A default would
/// make that answer the silent one, and a file whose language nobody decided
/// is exactly the state this parameter exists to make impossible to reach by
/// accident. `theSentencesAFileCarries` turns the code into the list, in one
/// place, so nothing here knows what an unwritten list is.
Future<Uint8List> buildProtectedPdf({
  required String text,
  required PdfStamp stamp,
  required String answerToken,
  required String? sessionLanguage,
  bool compress = true,
}) async {
  final t = theSentencesAFileCarries(sessionLanguage);
  final font = await _embeddedFont();
  // No title, no author, no producer, no creation date — see the head of this
  // file. `pdf` writes an /Info dictionary only when one of them is given.
  final doc = pw.Document(compress: compress);

  final body = pw.TextStyle(font: font, fontSize: 10.5, lineSpacing: 2.2);
  // `lineSpacing` because the footer line is longer than the page and wraps:
  // without it the digest sat against the row above it and read as a smear.
  final footer = pw.TextStyle(font: font, fontSize: 6.4, lineSpacing: 1.8, color: PdfColors.grey700);
  const margin = pw.EdgeInsets.fromLTRB(44, 44, 44, 52);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: margin,
      footer: (_) => _footer(stamp, footer, t),
      build: (_) => [
        // One Text per run of paragraphs that share a direction, each flowing
        // across pages. `TextOverflow.span` is what makes a Text a spanning
        // widget, so a long document pages itself instead of being pushed
        // whole onto a page it does not fit.
        //
        // Words break on whitespace and never inside a word, which is the
        // property the tokens depend on: a token split across two lines would
        // come out of a reader in halves and restore as nothing. The test
        // checks each token comes back whole rather than trusting this.
        //
        // **`textDirection` is what turns the shaping and the bidi pass on.**
        // `pdf` runs neither unless it is `rtl`; with none set an Arabic line
        // is laid out left to right and comes out **mirrored** — rendered and
        // looked at on 7 October, «السيد» drew as «ديسلا», which still reads as
        // a typeset page to anyone who cannot read the script. Set per
        // paragraph rather than per file, because a client's letter is German
        // and Arabic in the same document and one setting gets one of them
        // wrong. The Latin runs inside an Arabic line — an IBAN, an amount, a
        // `__Z_…__` token — are kept forward by the bidi algorithm itself,
        // which is the part that goes wrong quietly and has its own test.
        //
        // **Wrapped in a Partition, because a Text on its own shrink-wraps.**
        // A MultiPage hands its children a loose width and `RichText` then
        // takes the width of its longest line, so `textAlign: right` aligns
        // inside *that* box and not against the page. Measured on a rendered
        // letter: a block whose lines all fit sat flush left at x=44 while the
        // block above it, which happened to contain one wrapping line and so
        // had been given the full width, sat correctly at x=553 — two Arabic
        // passages in one document aligned two different ways, by accident of
        // line length. A `Partition` constrains its child's width **tightly**
        // and hands `canSpan` and `hasMoreWidgets` straight through, so the
        // paging a long document depends on is untouched. A `Column` with
        // `stretch` gives the same width and does **not** pass spanning
        // through: it threw `PdfTooBigPageException` on the 120-line guard.
        for (final block in directionBlocks(text))
          pw.Partitions(
            children: [
              pw.Partition(
                child: pw.Text(
                  block.laidOut,
                  style: body,
                  textDirection:
                      block.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                  textAlign: block.rtl ? pw.TextAlign.right : pw.TextAlign.left,
                  overflow: pw.TextOverflow.span,
                ),
              ),
            ],
          ),
      ],
    ),
  );

  // **The answer page** — 079. A page of its own, never a continuation of the
  // body: the reader reads it on its own, and a returned document is searched
  // for its first line.
  //
  // The top line is one Text and nothing else beside it, left to right: the
  // token is Latin and ours, and the line is the same in every language the
  // document was written in. The token stays whole because a Text breaks only
  // at whitespace and this line fits the width many times over.
  //
  // The circle is a drawn border and carries no text. Its grey is lighter
  // than the footer's, so the eye reads it as space to write in and not as
  // part of what is printed.
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: margin,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(t.zPdfAnswerLine(answerToken),
              style: body, textDirection: pw.TextDirection.ltr),
          pw.Expanded(
            child: pw.Center(
              child: pw.Container(
                width: 300,
                height: 300,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                ),
              ),
            ),
          ),
          _footer(stamp, footer, t),
        ],
      ),
    ),
  );
  return Uint8List.fromList(await doc.save());
}

/// **The restored document, as an ordinary PDF** — the owner, 24 October 2026
/// (paper 108 item 4): «نجعل وثيقة z-pdf يمكننا حفظها بعد فك التشفير… أعتقد فقط
/// يكفي خيار حفظها في الذاكرة كوثيقة pdf».
///
/// This is **not** a z-pdf and nothing in it says it is one:
///
///   * **no answer page**, so a reader of this file finds no token to write an
///     answer beside — it is not a file that goes to a model and comes back;
///   * **no footer**, so no build stamp, no count of protected places and no
///     digest. Every one of those is evidence *about a protection*, and there
///     is none here;
///   * **no mark.** `z-pdf · protected copy` is a claim about what a page is,
///     and this page is the person's own document with their own values in it.
///     A file that wears that mark and holds values in the clear is the worst
///     thing this product could write.
///
/// So it carries **no sentence at all**, in any language: there is nothing in
/// it but the person's own words. That is also why rule 80 does not reach it —
/// a file with no sentence has no language to be in.
///
/// **The pieces are passed through as they came.** [restored] is
/// `ReturnedDocument.restored`, the core's own list: the words as they
/// arrived, the values put back, and the tokens that stayed tokens. Nothing
/// here looks at `Piece`, searches for `__Z_`, or decides what a token was —
/// a token that could not be resolved stays exactly the token the core handed
/// over, because inventing a name for it would be the one lie this file could
/// tell. One hand flattens the list, here, so no screen does it twice.
///
/// **Except the lines this application itself wrote into the file being read**
/// — see [theDocumentWithoutOurOwnLines], which is where that is decided and
/// why it has to be.
Future<Uint8List> buildPlainPdf({
  required List<Segment> restored,
  bool compress = true,
}) async {
  final font = await _embeddedFont();
  final doc = pw.Document(compress: compress);
  final body = pw.TextStyle(font: font, fontSize: 10.5, lineSpacing: 2.2);
  const margin = pw.EdgeInsets.fromLTRB(44, 44, 44, 52);
  final text = theDocumentWithoutOurOwnLines(restored);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: margin,
      // **No `footer:`**, and that is the whole difference in this call. The
      // body is built exactly as the protected one is — one Text per run of
      // paragraphs that share a direction, inside a `Partition` so a long
      // document pages itself and a right-aligned Arabic block aligns against
      // the page. Both reasons are written out over `buildProtectedPdf` and
      // were paid for there; this reuses the one function that holds them
      // (`directionBlocks`) rather than keeping a second idea of how a page is
      // laid out.
      build: (_) => [
        for (final block in directionBlocks(text))
          pw.Partitions(
            children: [
              pw.Partition(
                child: pw.Text(
                  block.laidOut,
                  style: body,
                  textDirection:
                      block.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                  textAlign: block.rtl ? pw.TextAlign.right : pw.TextAlign.left,
                  overflow: pw.TextOverflow.span,
                ),
              ),
            ],
          ),
      ],
    ),
  );
  return Uint8List.fromList(await doc.save());
}

/// Where a save went, or why it did not happen.
class PdfSaved {
  const PdfSaved.at(this.path) : trouble = null;
  const PdfSaved.trouble(this.trouble) : path = null;

  final String? path;
  final String? trouble;
}

/// A name inside a folder, spelled the way this system spells a path.
///
/// `'$folder/$name'` stood at the two places below. The file landed in the
/// right place on Windows — it takes either separator — and then the one
/// sentence a person reads after a save said «Saved to
/// C:\Users\…\Documents\ZPrivacy/Brief-protected-21-10.pdf», which is not a
/// path any folder window of theirs prints. The suite said the same thing in
/// its own way on 21 October (run 39548354872): «the saved file carries the
/// tokens» looks for the path on the glass, the folder listing hands back
/// `…\Brief-protected-21-10.pdf`, and two spellings of one file do not match.
///
/// The separator is asked of the platform. Gate `G67` refuses the next glued
/// one.
String _inside(String folder, String name) {
  final sep = Platform.pathSeparator;
  // A folder that already ends in a separator — `C:\` is one, and so is a
  // path a person typed with a trailing slash — takes the name as it is.
  if (folder.endsWith(sep) || folder.endsWith('/')) return '$folder$name';
  return '$folder$sep$name';
}

/// Write the protected text to a file and answer where it went.
///
/// It never overwrites: a second save of the same document on the same day
/// becomes `…-2.pdf`. A person who saves twice has two files, not one file they
/// cannot account for.
Future<PdfSaved> saveProtectedPdf({
  required String text,
  required PdfStamp stamp,
  /// The answer page's token, as the core minted it — see [buildProtectedPdf].
  required String answerToken,
  /// **The session's name, for the file name only — never inside the file.**
  ///
  /// It was the *document's* name until 081, which is a name the person chose
  /// for their own file leaving this machine in the one direction nobody looks
  /// at: a folder listing, a backup, a sync. The session's name is ours — and
  /// a session nobody named is «Session N», which says everything a file name
  /// needs to and nothing about anybody.
  required String sessionName,
  /// **The name the person typed for this document** — the owner, 24 October
  /// 2026 (paper 108 item 2): «نجعل اسم الجلسة داخل باسم الوثيقة. والحفظ يحتاج
  /// إلى كتابة اسم للوثيقة من قبل المستخدم».
  ///
  /// 081 took the *document's own* file name out of here and left the session's
  /// alone, and that is what Windows' first read-back fell into: two vaults'
  /// files of one day are both `Session 1-protected-<date>.pdf` in
  /// `Documents\ZPrivacy`, so the second one becomes `…-2.pdf` and nothing in
  /// either name says which work it is. This is **not** 081 reversed: that
  /// round was about a name the app took without being asked, and this is a
  /// name the person is asked for, beside a sentence that says it is not
  /// protected.
  ///
  /// **Empty is refused**, never defaulted: a silent fallback is how a file
  /// gets a name nobody chose. The glass refuses it first — the dialog's Save
  /// is what carries the sentence — and this refuses it again, because a door
  /// that can be called from two places is a door that will be.
  required String documentName,
  /// **The language of the session this file left**, or null where it left
  /// none — rule 80, the owner, 21 October 2026: «بلغة الجلسة التي خرج منها
  /// الملف، والإنجليزية حين لا لغة للجلسة».
  ///
  /// The language of the **file**, never of the glass. A person who reads
  /// German documents in an English interface must not be handed a protected
  /// copy whose footer is English: the interface stays here and the file
  /// travels, and what travels carries the session's words. It is the send
  /// sheet that knows which session a payload belonged to, so the answer
  /// comes down from there — `theLanguageAFileCarries`, one law — and is not
  /// worked out again here.
  required String? sessionLanguage,
  /// Null means the product's own place. A test gives a temporary folder, so a
  /// test run never writes into the person's documents.
  String? folder,
  DateTime? now,
}) async {
  final into = folder ?? await protectedPdfFolder();
  if (into.isEmpty) {
    return PdfSaved.trouble(sentences.couldNotTellWhereDocumentsFolderIs);
  }
  final day = _day(now ?? DateTime.now());
  // **The person's own word first, then ours** — paper 108 item 2. A folder
  // listing sorts by the first thing in the name, and the first thing a person
  // looks for is the document they were working on; the session's name is what
  // tells two vaults' files of one day apart, which is the collision the owner
  // met. The date stays: it is what tells a Tuesday's copy from a Wednesday's,
  // and the `-2` suffix below is for two copies of one day.
  final typed = _clean(documentName);
  if (typed.isEmpty) {
    return PdfSaved.trouble(sentences.aNameIsNeededForThisDocument);
  }
  final stem = '$typed-${_fileStem(sessionName)}-protected-$day';

  try {
    final dir = Directory(into);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    var path = _inside(into, '$stem.pdf');
    var n = 2;
    while (File(path).existsSync()) {
      path = _inside(into, '$stem-$n.pdf');
      n += 1;
      if (n > 200) {
        return PdfSaved.trouble(sentences.thereAreAlready200Files(stem, into));
      }
    }
    final bytes = await buildProtectedPdf(
      text: text,
      stamp: stamp,
      answerToken: answerToken,
      sessionLanguage: sessionLanguage,
    );
    await File(path).writeAsBytes(bytes, flush: true);
    return PdfSaved.at(path);
  } on FileSystemException catch (e) {
    return PdfSaved.trouble(
        sentences.couldNotWriteInto(into, e.osError?.message ?? e.message));
  } catch (e) {
    // **Anything else still has to come back as a sentence.** A missing font
    // asset throws from `buildProtectedPdf`, not from the disk; if that escaped
    // here the button would sit on «Saving…» for the rest of the session with
    // nothing on the screen to say why. A person is told what happened to
    // them, not what happened to a library.
    return PdfSaved.trouble(sentences.couldNotBuildThePdfBecause('$e'));
  }
}

/// **The footer's own mark, and the answer page's own first line** — the two
/// things *this application* wrote into a z-pdf, by the characters it wrote
/// them with.
///
/// Both are safe to match in **any** language, and that is not luck: «z-pdf»
/// is a product name, the same in every pack by the one list's own law
/// (`check_the_one_list`'s `SAME_IN_EVERY_LANGUAGE` names it), and the
/// punctuation after it is what `_footer` and `zPdfAnswerLine` put there. The
/// three packs that exist today read «z-pdf · protected copy», «z-pdf ·
/// geschützte Kopie» and «z-pdf · skyddad kopia», and the answer line is
/// `Z-pdf : <token>` in all three. A guard holds those prefixes against the
/// list, so the day a pack words the mark differently this is red rather than
/// quietly blind.
/// **The product's own name**, which is the same word in every pack by the one
/// list's own law (`SAME_IN_EVERY_LANGUAGE` names it) — and the first thing
/// both of the lines this file writes begin with. Spelled once here so that
/// neither prefix below is a second copy of it.
const _theProductName = 'z-pdf';

/// The footer's mark as `_footer` writes it — «z-pdf · protected copy» and its
/// two translations — and the answer page's top line as `zPdfAnswerLine` does,
/// `«Z-pdf : <token>»`. The lines are compared **lower-cased**, which covers that
/// line's own capital without a second spelling of the name to keep in step.
const _theMarkWeWrite = '$_theProductName ·';
const _theAnswerLineWeWrite = '$_theProductName :';

/// A line of nothing but hexadecimal, which is the digest the footer wraps on
/// to a line of its own. Matched **only** directly under a footer line, so a
/// hash in somebody's own letter is their text and stays.
final _aDigestOnItsOwnLine = RegExp(r'^[0-9a-f]{32,}$');

/// **The person's document, without the two lines we put in the file they are
/// reading back.**
///
/// Measured, 24 October 2026, and this function exists **because** of what the
/// measurement said. `ReturnedDocument.restored` is not the body of the z-pdf:
/// it is everything the reader read out of it, which includes the footer this
/// file writes on every page — mark, build stamp, the count of protected
/// places and the sha256 **of the protected text** — and the answer page's
/// `Z-pdf : <token>` line. Written straight through, the plain copy would
/// carry «z-pdf · protected copy … sha256 of the protected text» over values
/// standing in the clear: a file claiming a protection it does not have, with
/// a digest that no longer describes it. Paper 108's own rule for this item is
/// that nothing in this file may claim protection, and this is what that costs.
///
/// **What is dropped is only ever ours**: a line that begins with the mark, a
/// line that begins with the answer line, and the digest's own wrap directly
/// under the mark. Everything else is the person's, whole and in order — a
/// value, a token that stayed a token, a blank line they typed.
///
/// **The limits, named rather than hidden.** A line of the person's own that
/// *begins* with «z-pdf ·» or «Z-pdf :» would be dropped with ours; that is
/// the narrowest collision available without the core telling us where the
/// body ends, and it is the honest trade for not writing a false claim. And
/// a footer that wrapped on to more than the digest — a longer stamp, a
/// narrower page — would leave its tail behind. **The real answer is a door in
/// the core**: `read_a_document_that_came_back` knows it is reading our own
/// file and could hand back a body with its own pages marked. That is a core
/// round's and is written here so that whoever opens it finds this note.
String theDocumentWithoutOurOwnLines(List<Segment> restored) {
  final lines = restored.map((piece) => piece.text).join().split('\n');
  final kept = <String>[];
  var afterOurFooter = false;
  for (final line in lines) {
    final bare = line.trim();
    final lowered = bare.toLowerCase();
    if (lowered.startsWith(_theMarkWeWrite)) {
      afterOurFooter = true;
      continue;
    }
    if (lowered.startsWith(_theAnswerLineWeWrite)) {
      afterOurFooter = false;
      continue;
    }
    if (afterOurFooter && _aDigestOnItsOwnLine.hasMatch(bare)) {
      continue;
    }
    afterOurFooter = false;
    kept.add(line);
  }
  // The blank lines a page break left at the end are nobody's paragraph.
  return kept.join('\n').trimRight();
}

/// **Write the restored document to the path the person chose.**
///
/// The path comes from the system's own save dialog, through the glass: this
/// product does not decide where a person's own document goes, and there is no
/// folder of ours in this call. A path that cannot be written is a sentence,
/// as everywhere else in this file — never a silence and never a throw that
/// leaves a press on «Saving…».
///
/// **It overwrites**, because the person named the file in their own system's
/// dialog and that dialog is what asks about an existing file. The `…-2.pdf`
/// dance above is for a name *this app* chose, where nobody was asked.
Future<PdfSaved> savePlainPdf({
  required List<Segment> restored,
  required String path,
}) async {
  try {
    final bytes = await buildPlainPdf(restored: restored);
    await File(path).writeAsBytes(bytes, flush: true);
    return PdfSaved.at(path);
  } on FileSystemException catch (e) {
    return PdfSaved.trouble(
        sentences.couldNotWriteInto(path, e.osError?.message ?? e.message));
  } catch (e) {
    return PdfSaved.trouble(sentences.couldNotBuildThePdfBecause('$e'));
  }
}

/// **What to call the file, before the person changes it.** The name of the
/// z-pdf that was read, with `-restored` after it — so the two files stand
/// beside each other in a folder and neither can be mistaken for the other,
/// and so the suggestion is never the name of the file being read **back**:
/// a save dialog proposing the z-pdf's own name is a save dialog proposing to
/// overwrite it.
///
/// Null or nothing left after the cleaning gives `restored.pdf`, which names
/// the act and nobody.
String theNameForARestoredPdf(String? cameFrom) {
  final stem = _clean(cameFrom ?? '');
  return stem.isEmpty ? 'restored.pdf' : '$stem-restored.pdf';
}

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// **A name, made safe to be part of a file name — and nothing invented.**
///
/// Two names reach here now (paper 108 item 2): the session's, which is ours,
/// and the one the person typed for their document. A name either of them
/// wrote may hold a path separator, a dot, or a character this or the other
/// platform's file system refuses — so one hand cleans both, and the empty
/// result is handed back **as empty** for the caller to answer for.
///
///   * everything outside letters, digits, `.`, `_`, space and `-` becomes
///     `-`, which takes `/` and `\` with it (`a_path_is_compared_in_one_spelling`)
///     and the whole of Windows' own refused set — `: * ? " < > |` — in the
///     same stroke, by allowing rather than by listing;
///   * a trailing extension is dropped, so «Mahnung.pdf» does not become
///     «Mahnung.pdf-…-protected-….pdf»;
///   * no leading dot or dash: a hidden file, or a name a shell reads as a
///     flag, is not what anybody asked for;
///   * **40 characters each**, which is this round's own number: two names
///     now share one stem with `-protected-` and a date after them, and
///     60 + 60 + 21 + `.pdf` is 145 characters of file name before the folder
///     it sits in — inside Linux's 255 bytes, and uncomfortably close to
///     Windows' 260 for a whole path once `C:\Users\<somebody>\Documents\
///     ZPrivacy\` is in front of it. 40 + 40 + 21 + 4 is 105.
///
/// **A reserved device name cannot come out of here**, which is Windows' other
/// refusal: `NUL`, `CON`, `COM1` are refused as *whole* stems, and every stem
/// this file builds carries `-protected-<date>` after the two names.
String _clean(String name) {
  var stem = name.trim();
  final dot = stem.lastIndexOf('.');
  if (dot > 0) stem = stem.substring(0, dot);
  stem = stem.replaceAll(RegExp(r'[^\p{L}\p{N}._ -]', unicode: true), '-').trim();
  while (stem.startsWith('.') || stem.startsWith('-')) {
    stem = stem.substring(1);
  }
  if (stem.length > 40) stem = stem.substring(0, 40).trim();
  // A name that was nothing but separators ends as a run of dashes; it names
  // nothing, so it is nothing.
  return stem.replaceAll(RegExp(r'^-+|-+$'), '').trim();
}

/// The session's half of the stem. A session nobody named is «Session N», so
/// this is empty only where there is no session at all — and then the word is
/// ours to choose, which is what it always was.
String _fileStem(String name) {
  final stem = _clean(name);
  return stem.isEmpty ? 'text' : stem;
}
