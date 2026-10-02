// The four marks: what the line says, and what the wash says.
//
// The design boards promised four marks on the word itself — solid for what a
// person decided, dashed for what a layer decided on its own, wavy for what is
// still waiting, dotted for what was put back in the answer. The build had two
// (a wash, and a wavy underline for a suggestion), so the source of a word was
// readable only in the Why sheet or the tokens panel.
//
// Two facts, two channels, as the board puts it: **the line says who decided,
// the wash says whether the vault knew the name.** They are different
// questions — the pack may have found a name while a person chose to protect
// it — and the core has kept them apart since task 034 (`Mark.source` and
// `Mark.decided`). This is the screen catching up with the contract.
//
// Measured before it was promised: `TextDecorationStyle.dashed` and `dotted`
// are painted distinctly on this backend, at the document's own size.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/answer.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/document_text.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';

/// Deliberately plain: «Blaues Dach» is a name only the vault can know, the
/// IBAN is a shape any language finds, «Herr Thomas Müller» is what the German
/// pack asks about, and «Mai» is what a person protects by hand.
const _doc = 'Projekt Blaues Dach läuft seit Mai.\n'
    'IBAN: DE89370400440532013000\n'
    'Ansprechpartner: Herr Thomas Müller\n';

Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
  }
  await tester.pumpAndSettle();
}

Span spanOf(String needle) {
  final at = _doc.indexOf(needle);
  var start = 0;
  for (final r in _doc.substring(0, at).runes) {
    start += String.fromCharCode(r).length;
  }
  var len = 0;
  for (final r in needle.runes) {
    len += String.fromCharCode(r).length;
  }
  return Span(start: start, end: start + len);
}

/// The style of the drawn run whose text is exactly [text], inside [within].
///
/// Read from the span tree rather than from a picture: what is asserted is the
/// decoration the screen asked for, which is the thing this change is about.
TextStyle? styleOf(WidgetTester tester, String text, {required Finder within}) {
  // Both columns draw with `SelectableText.rich`, so the spans hang off the
  // widget rather than off a `RichText` in the tree.
  final texts = tester.widgetList<SelectableText>(
    find.descendant(of: within, matching: find.byType(SelectableText)),
  );
  for (final t in texts) {
    TextStyle? found;
    t.textSpan?.visitChildren((span) {
      if (span is TextSpan && span.text == text) {
        found = span.style;
        return false;
      }
      return true;
    });
    if (found != null) return found;
  }
  return null;
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  /// A vault that knows one project, a document that names it, one value found
  /// by a general rule, one question the pack asks, and one word protected by
  /// hand. Everything the four marks have to tell apart, in one screen.
  Future<Workbench> aMarkedDocument(WidgetTester tester, Ground ground) async {
    late final Workbench bench;
    await tester.runAsync(() async {
      await z.vaultLock();
      final dir = Directory('${Directory.systemTemp.path}/zprivacy-marks-$pid');
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      await z.setDataDir(dir: dir.path);
      await z.vaultCreateWithPassphrase(passphrase: 'ein gutes Passwort');
      final entity = await z.createEntity(
        kind: EntityKind.client,
        label: 'Nordstern',
        profileId: null,
      );
      await z.setValue(
        entity: entity,
        kind: Kind.project,
        text: 'Blaues Dach',
        policy: Policy.always,
      );
      await ground.refresh();

      final session = await z.openSession(packId: 'de');
      await z.importText(session: session, text: _doc);
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await bench.rescan();
      await z.protect(
        session: session,
        span: spanOf('Mai'),
        scope: Scope.conversation,
        kind: Kind.custom,
      );
      await bench.refresh();
    });
    return bench;
  }

  Future<void> pumpWorkspace(
    WidgetTester tester,
    Workbench bench,
    Ground ground,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(bench: bench, ground: ground, onHome: () {}),
      ),
    );
    await settle(tester);
  }

  testWidgets('a word a person protected is drawn with a solid line', (
    tester,
  ) async {
    final ground = Ground();
    final bench = await aMarkedDocument(tester, ground);
    await pumpWorkspace(tester, bench, ground);

    final style = styleOf(tester, 'Mai', within: find.byType(OriginalText));
    expect(style, isNotNull, reason: 'the hand-protected word is not drawn as its own run');
    expect(style!.decoration, TextDecoration.underline);
    expect(
      style.decorationStyle,
      TextDecorationStyle.solid,
      reason: 'a person decided this one, and the line is what says so',
    );
    expect(style.decorationThickness, 1.5);
    expect(style.decorationColor, Zc.clay);
    bench.dispose();
  });

  testWidgets('a word a layer protected on its own is drawn dashed', (
    tester,
  ) async {
    final ground = Ground();
    final bench = await aMarkedDocument(tester, ground);
    await pumpWorkspace(tester, bench, ground);

    final style = styleOf(
      tester,
      'DE89370400440532013000',
      within: find.byType(OriginalText),
    );
    expect(style, isNotNull, reason: 'the IBAN is not drawn as its own run');
    expect(
      style!.decorationStyle,
      TextDecorationStyle.dashed,
      reason: 'no person decided this one; a general rule did',
    );
    expect(style.decorationThickness, 1.5);
    bench.dispose();
  });

  testWidgets(
    'a word the vault knew keeps the vault wash, and the line still says who decided',
    (tester) async {
      final ground = Ground();
      final bench = await aMarkedDocument(tester, ground);
      await pumpWorkspace(tester, bench, ground);

      final style = styleOf(
        tester,
        'Blaues Dach',
        within: find.byType(OriginalText),
      );
      expect(style, isNotNull, reason: 'the vault-known name is not drawn as its own run');
      // The wash is the vault's: «the app knows who this is».
      expect(style!.backgroundColor, Zc.riverWash);
      expect(style.color, Zc.river);
      // And the line is a different fact: nobody decided it by hand.
      expect(
        style.decorationStyle,
        TextDecorationStyle.dashed,
        reason: 'two facts, two channels: the wash says the vault knew, the line says who decided',
      );
      bench.dispose();
    },
  );

  testWidgets('a suggestion stays wavy, whoever found it', (tester) async {
    final ground = Ground();
    final bench = await aMarkedDocument(tester, ground);
    await pumpWorkspace(tester, bench, ground);

    expect(bench.suggested, isNotEmpty, reason: 'the pack asked nothing, so this proves nothing');
    // `Finding` carries where it sits, not what it says — the core does not
    // hand the user's words back without being asked. Dart strings are UTF-16
    // and so are the spans, so this is the same slice the screen drew.
    final at = bench.suggested.first.span;
    final waiting = _doc.substring(at.start, at.end);
    final style = styleOf(tester, waiting, within: find.byType(OriginalText));
    expect(style, isNotNull, reason: 'the suggestion «$waiting» is not drawn as its own run');
    expect(
      style!.decorationStyle,
      TextDecorationStyle.wavy,
      reason: 'waiting beats the source: it is still the real text, and that is what must show',
    );
    expect(style.decorationThickness, 2.0);
    expect(style.decorationColor, Zc.amberEdge);
    bench.dispose();
  });

  testWidgets('a value put back in the answer is drawn dotted', (tester) async {
    final ground = Ground();
    final bench = await aMarkedDocument(tester, ground);
    await tester.runAsync(() async {
      bench.rememberCopiedPayload();
      await bench.pasteAnswer('Verstanden:\n${bench.payload!.text}');
    });
    await pumpWorkspace(tester, bench, ground);

    expect(find.byType(AnswerPanel), findsOneWidget);
    final style = styleOf(
      tester,
      'Blaues Dach',
      within: find.byType(AnswerPanel),
    );
    expect(style, isNotNull, reason: 'the restored value is not drawn as its own run');
    expect(
      style!.decorationStyle,
      TextDecorationStyle.dotted,
      reason: 'put back here, locally — the fourth mark',
    );
    expect(style.decorationThickness, 1.5);
    expect(style.decorationColor, Zc.clayDeep);
    bench.dispose();
  });
}
