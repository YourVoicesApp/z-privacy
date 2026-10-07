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
// The body is the protected text, nothing added. One footer line, and only
// facts a reader can check for themselves:
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

/// sha256 of a string, the way a reader would compute it: UTF-8 bytes, lower
/// hex. The footer states this over the protected text, and the protected text
/// is what Copy Protected copies — one number, checkable from the clipboard.
String sha256OfText(String text) => c.sha256.convert(utf8.encode(text)).toString();

/// Where a saved PDF goes. Said in words on the screen before it is written.
String protectedPdfFolder() {
  final home = Platform.environment['HOME'];
  // No home in the environment is not a place to guess at. The caller shows
  // the refusal; it never writes somewhere else instead.
  if (home == null || home.isEmpty) return '';
  return '$home/Documents/zprivacy';
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
  String get kinds => byKind.isEmpty
      ? 'none'
      : (byKind.entries.map((e) => '${e.key} ×${e.value}').toList()..sort()).join(', ');

  /// The one line. Long on purpose — a sha256 is sixty-four characters and
  /// shortening it would make it decoration again.
  ///
  /// Single spaces around each `·`, not the two that read better: G25 fails on
  /// a run of spaces inside a sentence, and it is right to — the gate exists
  /// because the owner read a refusal with nineteen spaces in the middle of it.
  /// This is also the separator `core_version()` already uses.
  String get line =>
      '$build · $places ${places == 1 ? 'place' : 'places'} replaced, '
      '$values ${values == 1 ? 'value' : 'values'} ($kinds) · '
      'sha256 of the protected text $sha256';
}

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
Future<Uint8List> buildProtectedPdf({
  required String text,
  required PdfStamp stamp,
  bool compress = true,
}) async {
  final font = await _embeddedFont();
  // No title, no author, no producer, no creation date — see the head of this
  // file. `pdf` writes an /Info dictionary only when one of them is given.
  final doc = pw.Document(compress: compress);

  final body = pw.TextStyle(font: font, fontSize: 10.5, lineSpacing: 2.2);
  // `lineSpacing` because the footer line is longer than the page and wraps:
  // without it the digest sat against the row above it and read as a smear.
  final footer = pw.TextStyle(font: font, fontSize: 6.4, lineSpacing: 1.8, color: PdfColors.grey700);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(44, 44, 44, 52),
      footer: (_) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10),
        child: pw.Text(stamp.line, style: footer),
      ),
      build: (_) => [
        // One Text, flowing across pages. `TextOverflow.span` is what makes it
        // a spanning widget, so a long document pages itself instead of being
        // pushed whole onto a page it does not fit.
        //
        // Words break on whitespace and never inside a word, which is the
        // property the tokens depend on: a token split across two lines would
        // come out of a reader in halves and restore as nothing. The test
        // checks each token comes back whole rather than trusting this.
        //
        // **No `textDirection`, so Arabic is not supported here yet — and it
        // fails in the worse of the two ways.** The embedded font carries the
        // glyphs, and `pdf` runs its shaping and its bidi pass only when the
        // direction is `rtl`; with none set, an Arabic line is laid out
        // left to right and comes out **mirrored**. Rendered and looked at on
        // 7 October: «السيد» drew as «ديسلا». That reads as a typeset document
        // at a glance, which is why it is written down here — a page that is
        // visibly empty gets fixed, and a page that is quietly backwards does
        // not. The direction belongs per paragraph, with the Latin tokens
        // isolated inside an RTL run, and that is its own item.
        pw.Text(text, style: body, overflow: pw.TextOverflow.span),
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

/// Write the protected text to a file and answer where it went.
///
/// It never overwrites: a second save of the same document on the same day
/// becomes `…-2.pdf`. A person who saves twice has two files, not one file they
/// cannot account for.
Future<PdfSaved> saveProtectedPdf({
  required String text,
  required PdfStamp stamp,
  /// The document's own name, for the file name only — never inside the file.
  required String documentName,
  /// Null means the product's own place. A test gives a temporary folder, so a
  /// test run never writes into the person's documents.
  String? folder,
  DateTime? now,
}) async {
  final into = folder ?? protectedPdfFolder();
  if (into.isEmpty) {
    return const PdfSaved.trouble(
      'Z Privacy could not tell where your home folder is, so it has not guessed. '
      'Nothing was written.',
    );
  }
  final day = _day(now ?? DateTime.now());
  final stem = '${_fileStem(documentName)}-protected-$day';

  try {
    final dir = Directory(into);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    var path = '$into/$stem.pdf';
    var n = 2;
    while (File(path).existsSync()) {
      path = '$into/$stem-$n.pdf';
      n += 1;
      if (n > 200) {
        return PdfSaved.trouble('There are already 200 files called $stem in $into.');
      }
    }
    final bytes = await buildProtectedPdf(text: text, stamp: stamp);
    await File(path).writeAsBytes(bytes, flush: true);
    return PdfSaved.at(path);
  } on FileSystemException catch (e) {
    return PdfSaved.trouble('Z Privacy could not write into $into — ${e.osError?.message ?? e.message}.');
  } catch (e) {
    // **Anything else still has to come back as a sentence.** A missing font
    // asset throws from `buildProtectedPdf`, not from the disk; if that escaped
    // here the button would sit on «Saving…» for the rest of the session with
    // nothing on the screen to say why. A person is told what happened to
    // them, not what happened to a library.
    return PdfSaved.trouble('Z Privacy could not build the PDF — $e. Nothing was written.');
  }
}

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// A file name out of a document's name. Typed text has no name, and a name
/// from a file may hold a slash or a dot — neither may decide where this is
/// written.
String _fileStem(String name) {
  var stem = name.trim();
  final dot = stem.lastIndexOf('.');
  if (dot > 0) stem = stem.substring(0, dot);
  stem = stem.replaceAll(RegExp(r'[^\p{L}\p{N}._ -]', unicode: true), '-').trim();
  // No leading dot: a hidden file is not what anyone asked for.
  while (stem.startsWith('.') || stem.startsWith('-')) {
    stem = stem.substring(1);
  }
  if (stem.length > 60) stem = stem.substring(0, 60).trim();
  return stem.isEmpty ? 'text' : stem;
}
