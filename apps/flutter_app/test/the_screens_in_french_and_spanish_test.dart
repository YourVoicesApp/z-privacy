// 121 · The screens in French and Spanish, as pictures the lead can read.
//
// Paper 121 asks for the language choice with its line — the translation was
// made with AI, and where to write — and the main screen, each at desktop and
// at phone width. The shape is `the_screens_in_arabic_test.dart`'s and so are
// its reasons: the real locale, the real sentences out of `app_fr.arb` and
// `app_es.arb`, the screens written out as PNGs and never compared (a token is
// a different word on every run), with real faces loaded so a picture is of
// letters and not of the test font's boxes.
//
//   LD_LIBRARY_PATH=… flutter test test/the_screens_in_french_and_spanish_test.dart
//
// They land in `test/screens_in_french_and_spanish/`. The letters are invented.
@Timeout(Duration(minutes: 8))
library;

import 'dart:io';

import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/l10n/app_localizations.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'the_folder_lets_go.dart';
import 'the_bridge_the_tests_speak_through.dart';

const _letters = {
  'fr': 'Madame Claire Dubois,\n'
      'Suite à votre demande du 14 octobre, le virement de 1 250,00 euros a été fait.\n'
      'Compte FR76 3000 6000 0112 3456 7890 189\n'
      'Téléphone 01 42 68 53 00\n'
      'Veuillez agréer, Madame, nos salutations distinguées.\n',
  'es': 'Estimada señora Lucía Romero:\n'
      'Según su solicitud del 14 de octubre, la transferencia de 1.250,00 euros está hecha.\n'
      'Cuenta ES91 2100 0418 4502 0005 1332\n'
      'Teléfono 912 345 678\n'
      'Atentamente,\n',
};

const _latinFace = '/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf';
const _arabicFace = '/usr/share/fonts/truetype/noto/NotoSansArabic-Regular.ttf';
const _monoFace = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf';

String _theIconFace() {
  for (var here = File(Platform.resolvedExecutable).parent;
      here.path != here.parent.path;
      here = here.parent) {
    if (here.path.split(Platform.pathSeparator).last == 'cache') {
      return [here.path, 'artifacts', 'material_fonts', 'MaterialIcons-Regular.otf']
          .join(Platform.pathSeparator);
    }
  }
  return '';
}

final _iconFace = _theIconFace();

List<String> get _facesMissing =>
    [_latinFace, _arabicFace, _monoFace, _iconFace].where((f) => !File(f).existsSync()).toList();

const _theWholeScreen = ValueKey<String>('the-whole-screen');

Future<void> _settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

Future<void> _aPictureOf(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_theWholeScreen));
  late final int bytes;
  await tester.runAsync(() async {
    final shot = await boundary.toImage();
    final png = await shot.toByteData(format: ImageByteFormat.png);
    final file = File('test/screens_in_french_and_spanish/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(png!.buffer.asUint8List());
    bytes = file.lengthSync();
  });
  expect(bytes, greaterThan(15000),
      reason: 'test/screens_in_french_and_spanish/$name.png came out at $bytes bytes');
}

Widget _inThe(String code, Widget child) => MaterialApp(
      locale: Locale(code),
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // «العربية (AR)» stands in the language choice, so the Arabic face
      // follows the Latin one.
      theme: ThemeData(fontFamily: 'LatinLook', fontFamilyFallback: const ['ArabicLook']),
      home: RepaintBoundary(key: _theWholeScreen, child: child),
    );

/// A vault, the language set the way the Language room's press sets it, and
/// — for the main screen — one invented letter in a session.
Future<({Ground ground, Workbench? bench})> _ready(
    WidgetTester tester, String code, String name, {required bool letter}) async {
  late final ({Ground ground, Workbench? bench}) made;
  await tester.runAsync(() async {
    final own = Directory('${Directory.systemTemp.path}/zprivacy-121-$code-$name-$pid');
    removeWhenItLetsGo(own);
    own.createSync(recursive: true);
    addTearDown(() => removeWhenItLetsGo(own));
    final ground = Ground();
    await z.vaultLock();
    await z.setDataDir(dir: own.path);
    await z.vaultCreateWithPassphrase(passphrase: 'une phrase pour les images, assez longue');
    await ground.refresh();
    // The pack is the language's own when this build carries it (paper 120),
    // and English where it does not yet — said, not hidden: the words on the
    // glass are the list's either way.
    final pack = ground.packs.any((p) => p.id == code) ? code : 'en';
    final now = await z.settings();
    await ground.saveConfig(Settings(
      originalPanePercent: now.originalPanePercent,
      columnsInStep: now.columnsInStep,
      safeColumnOpen: now.safeColumnOpen,
      reviewPanelWide: now.reviewPanelWide,
      scanOnImport: now.scanOnImport,
      revealSeconds: now.revealSeconds,
      autoLockMinutes: now.autoLockMinutes,
      packId: pack,
      language: code,
      firstRunDone: true,
      sessionOnly: now.sessionOnly,
    ));
    Workbench? bench;
    if (letter) {
      final session = await z.openSession(profileId: null, packId: pack);
      bench = Workbench(session: session, profileId: null, packId: pack);
      await z.importText(session: session, text: _letters[code]!);
      await bench.rescan();
    }
    await ground.refresh();
    made = (ground: ground, bench: bench);
  });
  return made;
}

void main() {
  setUpAll(() async {
    if (!File(theBridgeTheTestsSpeakThrough).existsSync()) {
      throw StateError(buildTheBridgeFirst);
    }
    await RustLib.init();
    Future<ByteData> bytes(String path) async =>
        (await File(path).readAsBytes()).buffer.asByteData();
    if (_facesMissing.isEmpty) {
      for (final (family, face) in [
        ('LatinLook', _latinFace),
        ('ArabicLook', _arabicFace),
        ('monospace', _monoFace),
        ('MaterialIcons', _iconFace),
      ]) {
        await (FontLoader(family)..addFont(bytes(face))).load();
      }
    }
  });

  for (final code in <String>['fr', 'es']) {
    for (final (width, size) in <(String, Size)>[
      ('desktop', const Size(1400, 900)),
      ('phone', const Size(420, 900)),
    ]) {
      testWidgets('the language choice and its line, in $code, at $width width', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        theSentencesAreNow(Locale(code));
        addTearDown(() => theSentencesAreNow(const Locale('en')));
        final g = await _ready(tester, code, 'settings-$width', letter: false);
        await tester.pumpWidget(_inThe(code, Scaffold(
          backgroundColor: Zc.paper,
          body: SettingsScreen(ground: g.ground, onClose: () {}, room: SettingsRoom.language),
        )));
        await _settle(tester, rounds: 3);
        expect(find.byKey(const ValueKey('the-translation-was-made-with-ai')), findsOneWidget);
        await _aPictureOf(tester, '$code-the-language-choice-$width');
      }, skip: _facesMissing.isNotEmpty);

      // **The one screen has no phone layout** — it is a desktop window
      // (1280 × 720 by default) and its tool row overflows under about 1000
      // pixels in every language, English included. So its «narrow» picture
      // is the narrowest window it is built for, and the phone width is the
      // settings panel's, which is a column and does read at 420.
      testWidgets('the one screen, in $code, at $width width', (tester) async {
        await tester.binding.setSurfaceSize(width == 'phone' ? const Size(1000, 760) : size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        theSentencesAreNow(Locale(code));
        addTearDown(() => theSentencesAreNow(const Locale('en')));
        final g = await _ready(tester, code, 'screen-$width', letter: true);
        await tester.pumpWidget(_inThe(code, WorkspaceScreen(
          bench: g.bench!,
          ground: g.ground,
          onImport: () {}, onAsk: (_) {},
          onVault: () {},
          onSettings: (_) {},
          onReadBack: () {},
        )));
        await _settle(tester);
        expect(find.byType(WorkspaceScreen), findsOneWidget);
        await _aPictureOf(tester, '$code-the-one-screen-${width == 'phone' ? 'narrow' : width}');
      }, skip: _facesMissing.isNotEmpty);
    }
  }
}
