// Paper 122 §3.2 — the visitor's PDF: built in memory, not a z-pdf (no
// token placed by us, no map, no session number, no /Info), the text as
// written and then the answer, Arabic right to left. Read back with
// `pdftotext`, into a temporary folder of the test's own.
import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/l10n/app_localizations.dart';
import 'package:zprivacy/web/the_trial_pdf.dart';

import '../the_folder_lets_go.dart';
import 'the_trial_test.dart' show fixtureFont;

Future<(String bytes, String text, String boxes)> readBack(
  List<int> pdf,
) async {
  final dir = Directory.systemTemp.createTempSync('trial-pdf-');
  addTearDown(() => removeWhenItLetsGo(dir));
  final f = File('${dir.path}/trial.pdf')..writeAsBytesSync(pdf);
  final text = Process.runSync('pdftotext', [f.path, '-']).stdout as String;
  Process.runSync('pdftotext', ['-bbox', f.path, '${dir.path}/boxes.html']);
  return (
    String.fromCharCodes(pdf),
    text,
    File('${dir.path}/boxes.html').readAsStringSync(),
  );
}

/// The words `pdftotext -bbox` found, with their left edge and their line.
List<(String, double, double)> words(String boxes) => [
  for (final m in RegExp(
    r'<word xMin="([\d.]+)" yMin="([\d.]+)"[^>]*>([^<]*)</word>',
  ).allMatches(boxes))
    (m.group(3)!, double.parse(m.group(1)!), double.parse(m.group(2)!)),
];

void main() {
  final hasPdftotext = Process.runSync('which', ['pdftotext']).exitCode == 0;

  test('English: the two headings, the text as written, then the answer; no '
      '/Info, no token, no footer', () async {
    final t = lookupAppLocalizations(const Locale('en'));
    const asked = 'Dear Anna Lindqvist, Björn wrote about the contract.';
    const answer = 'Thank you, Anna Lindqvist. Björn will hear from us.';
    final pdf = await buildTheTrialPdf(
      yourText: asked,
      exchanges: [(null, answer)],
      t: t,
      pageIsRightToLeft: false,
      font: await fixtureFont(),
      compress: false,
    );
    final (bytes, text, _) = await readBack(pdf);
    for (final info in [
      '/Title',
      '/Author',
      '/Producer',
      '/Creator',
      '/CreationDate',
      '/Info',
    ]) {
      expect(bytes, isNot(contains(info)), reason: info);
    }
    final flat = text.replaceAll(RegExp(r'\s+'), ' ');
    expect(
      flat,
      contains(
        '${t.trialYourText} $asked ${t.trialTheAnswerWithRealNames} $answer',
      ),
    );
    expect(flat, isNot(contains('__Z_')));
    expect(flat, isNot(contains('z-pdf')));
    expect(
      RegExp(r'\f').allMatches(text),
      hasLength(1),
      reason: 'one page, no answer page',
    );
  }, skip: hasPdftotext ? false : 'pdftotext is not on this machine');

  test('a token the core could not place goes into the PDF as the core '
      'returned it (the lead, 13 Nov)', () async {
    final t = lookupAppLocalizations(const Locale('en'));
    final pdf = await buildTheTrialPdf(
      yourText: 'Dear Anna Lindqvist,',
      exchanges: [(null, 'Thank you, __Z_PERSON_99__.')],
      t: t,
      pageIsRightToLeft: false,
      font: await fixtureFont(),
      compress: false,
    );
    final (_, text, _) = await readBack(pdf);
    expect(
      text.replaceAll(RegExp(r'\s+'), ' '),
      contains('Thank you, __Z_PERSON_99__.'),
    );
  }, skip: hasPdftotext ? false : 'pdftotext is not on this machine');

  test(
    'Arabic: the headings and an Arabic paragraph read right to left',
    () async {
      final t = lookupAppLocalizations(const Locale('ar'));
      const asked = 'كتبت آمنة الحسيني رسالة إلى المدرسة.';
      final pdf = await buildTheTrialPdf(
        yourText: asked,
        exchanges: [(null, 'شكراً آمنة الحسيني.')],
        t: t,
        pageIsRightToLeft: true,
        font: await fixtureFont(),
        compress: false,
      );
      final (_, _, boxes) = await readBack(pdf);
      // `pdftotext` hands Arabic back in the order the glyphs stand on the
      // page, as presentation forms; so a word is found by what it carries — the
      // full stop that ends a sentence, the damma of «كُتب» — and the order is
      // read from the page's own x.
      final lines = <double, List<(String, double)>>{};
      for (final w in words(boxes)) {
        lines.putIfAbsent(w.$3, () => []).add((w.$1, w.$2));
      }
      void lastIsLeftmost(bool Function(String) isLast, String what) {
        final line = lines.values.firstWhere((l) => l.any((w) => isLast(w.$1)));
        final leftmost = line.reduce((a, b) => a.$2 <= b.$2 ? a : b);
        expect(
          isLast(leftmost.$1),
          isTrue,
          reason: '$what: the logical last word stands leftmost',
        );
        expect(line.length, greaterThan(1));
      }

      lastIsLeftmost((w) => w.contains('ﺔﺳﺭﺪﻤﻟﺍ'), 'the text as written');
      lastIsLeftmost((w) => w.contains('.ﻲﻨﻴﺴﺤﻟﺍ'), 'the answer');
      lastIsLeftmost(
        (w) => w.contains('\u064F'),
        'the heading «النص كما كُتب»',
      );
    },
    skip: hasPdftotext ? false : 'pdftotext is not on this machine',
  );
}
