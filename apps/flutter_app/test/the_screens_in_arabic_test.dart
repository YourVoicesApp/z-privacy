// 116 · The screens in Arabic, as a person sees them — and as pictures the
// owner can look at.
//
// The owner, 25 October 2026: Arabic means «إمكانية قراءة الشاشات بهذه اللغة».
// `the_screens_read_right_to_left_test` measures the **layout** with the
// direction forced, which is what could be measured before paper 115 wrote the
// words. This file is the other half: the real locale, the real sentences out
// of `app_ar.arb`, and the screens written out as PNGs so that his own look —
// the part of this round no guard can do — is at a path and not a promise.
//
// ## Why this is a test and not a run of the application
//
// A screenshot of the running program needs a desktop, a vault, a document and
// a person's hands. This mounts the same widgets with the same words, at a
// fixed size, which is repeatable and shows exactly what 116 changed. What it
// does **not** show is the window chrome and the system's own font: the shipped
// Linux build asks the machine for a font, and this asks for Noto Sans Arabic
// by name so that the pictures have real glyphs rather than the test font's
// boxes. Said out loud because a picture that looks final and is not is the
// worst kind.
//
// Running it writes the pictures — every run, with no flag:
//
//   LD_LIBRARY_PATH=… flutter test test/the_screens_in_arabic_test.dart
//
// They land in `test/screens_in_arabic/`.
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
import 'package:zprivacy/screens/first_run.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'the_folder_lets_go.dart';
import 'the_bridge_the_tests_speak_through.dart';

final _libPath = theBridgeTheTestsSpeakThrough;

/// An Arabic letter with a name, an account number and a date in it — the three
/// kinds this product is about, in one text, so the pictures show the real
/// thing and not a lorem ipsum.
const _letter = 'حضرة السيد ماركوس فيبر،\n'
    'بخصوص الراتب لشهر أكتوبر: المبلغ المحوّل 4,250.00 يورو\n'
    'رقم الحساب DE89370400440532013000\n'
    'الهاتف 0211 4567890\n'
    'وتفضلوا بقبول فائق الاحترام\n';

/// **Four faces, because the first two pictures were half boxes.**
///
/// `flutter test` draws every glyph as a square unless a real face is loaded,
/// and this file exists to be *looked at*, so the squares had to go. They went
/// in two rounds, and both are worth writing down:
///
///   1. Noto Sans **Arabic** alone drew the Arabic and left the IBAN, the
///      tokens and every control's icon as squares. It is an Arabic face: it
///      carries digits, not `D`, not `E`, not an em dash, and no icon.
///   2. Adding the Latin face as a **second face of the same family** changed
///      nothing. A family's faces are weights and slants, not a fallback
///      chain; the engine picks one and misses stay misses. The Latin face
///      needs its own family name and a place in [ThemeData.fontFamilyFallback],
///      which is the chain the engine really walks.
///
/// So: Arabic leads, Latin follows it for everything the Arabic face has no
/// glyph for, Flutter's own icon font answers for `Icons.*`, and a real
/// monospace face answers for `Zc.token`, which names `'monospace'` outright
/// and therefore reaches neither of the two above.
///
/// The shipped Linux build asks the machine for its fonts and gets whatever
/// that machine has; these are this machine's, named here so that nobody reads
/// a picture as a promise about somebody else's desktop.
const _arabicFace = '/usr/share/fonts/truetype/noto/NotoSansArabic-Regular.ttf';
const _latinFace = '/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf';
const _monoFace = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf';

/// **Flutter's own icon font**, found by walking up from whatever is running
/// this test until the SDK's `cache` folder, rather than written out: a path
/// with somebody's home folder in it is a test that passes on one desk.
///
/// The walk and not a count of parents, because what runs a widget test is
/// `<cache>/artifacts/engine/<platform>/flutter_tester` — measured, after a
/// count written for `<cache>/dart-sdk/bin/dart` quietly skipped both screens.
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

/// **The faces this machine must have for the pictures to mean anything.**
///
/// Without them every glyph is the test font's box, and a golden written from
/// boxes would be compared against boxes on the next desk — green, and about
/// nothing. So the two screens are **skipped** where the faces are absent
/// rather than failed: this file's job is a picture for the owner to look at,
/// and a machine with no Arabic font cannot take one.
List<String> get _facesMissing =>
    [_arabicFace, _latinFace, _monoFace, _iconFace].where((f) => !File(f).existsSync()).toList();

Future<void> _settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

Future<({Ground ground, Workbench bench})> _ready(WidgetTester tester, String name) async {
  late final ({Ground ground, Workbench bench}) made;
  await tester.runAsync(() async {
    final own = Directory('${Directory.systemTemp.path}/zprivacy-ar-$name-$pid');
    removeWhenItLetsGo(own);
    own.createSync(recursive: true);
    addTearDown(() {
      removeWhenItLetsGo(own);
    });
    final ground = Ground();
    await z.vaultLock();
    await z.setDataDir(dir: own.path);
    await z.vaultCreateWithPassphrase(passphrase: 'كلمة مرور للصور');
    final session = await z.openSession(profileId: null, packId: 'ar');
    final bench = Workbench(session: session, profileId: null, packId: 'ar');
    await z.importText(session: session, text: _letter);
    await bench.rescan();
    await ground.refresh();
    made = (ground: ground, bench: bench);
  });
  return made;
}

/// Where the screen is painted from, so that one picture can be taken of it.
const _theWholeScreen = ValueKey<String>('the-whole-screen');

/// **The picture, written — and never compared.**
///
/// `matchesGoldenFile` was the first shape of this and it cannot be: a token
/// is derived from the vault's own key, so `__Z_092C_IBAN_57E8ECC2__` is a
/// different word on every run and the comparison came back 1 314 pixels
/// apart against a picture of the same screen. A golden that cannot be met is
/// a red that teaches nobody anything.
///
/// So these two tests **take** a picture rather than check one. What they
/// assert is what can be true twice: the words are Arabic, the screen painted,
/// and the file is on disk at a path the owner can open. His own look is the
/// measurement this round asked for, and no guard was ever going to do it.
Future<void> _aPictureOf(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_theWholeScreen));
  late final int bytes;
  await tester.runAsync(() async {
    final shot = await boundary.toImage();
    final png = await shot.toByteData(format: ImageByteFormat.png);
    final file = File('test/screens_in_arabic/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(png!.buffer.asUint8List());
    bytes = file.lengthSync();
  });
  // A picture of an empty surface is a few hundred bytes; one of a screen is
  // tens of thousands. The number is a floor and not a measurement of what is
  // in it — the eye that reads it is the owner's.
  expect(bytes, greaterThan(20000),
      reason: 'test/screens_in_arabic/$name.png came out at $bytes bytes, which is '
          'not a picture of a screen');
}

/// The application as a person who chose Arabic meets it: the locale decides
/// the words **and** the direction, through `GlobalWidgetsLocalizations`, which
/// is what `main.dart` hands `MaterialApp` in the product.
Widget _inArabic(Widget child) => MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        fontFamily: 'ArabicLook',
        fontFamilyFallback: const ['LatinLook'],
      ),
      home: RepaintBoundary(key: _theWholeScreen, child: child),
    );

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError(buildTheBridgeFirst);
    }
    await RustLib.init();
    // The sentences' own holder, as `main.dart` sets it before building.
    theSentencesAreNow(const Locale('ar'));
    Future<ByteData> bytes(String path) async =>
        (await File(path).readAsBytes()).buffer.asByteData();
    // Each face under its own family: the chain is `fontFamilyFallback`, not a
    // family with several faces in it. `Zc.token` and `Icons.*` name their
    // families themselves, so those two are answered by name.
    if (_facesMissing.isEmpty) {
      for (final (family, face) in [
        ('ArabicLook', _arabicFace),
        ('LatinLook', _latinFace),
        ('monospace', _monoFace),
        ('MaterialIcons', _iconFace),
      ]) {
        await (FontLoader(family)..addFont(bytes(face))).load();
      }
    }
  });

  testWidgets('the one screen, in Arabic', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _ready(tester, 'screen');
    await tester.pumpWidget(_inArabic(WorkspaceScreen(
      bench: g.bench,
      ground: g.ground,
      onImport: () {}, onAsk: (_) {},
      onVault: () {},
      onSettings: (_) {},
      onReadBack: () {},
    )));
    await _settle(tester);

    // The sentences really are Arabic — a picture of the English words in a
    // mirrored layout would be a picture of nothing.
    expect(sentences.safeAiWillReceive.contains('الذكاء'), isTrue,
        reason: 'the holder is not answering in Arabic: «${sentences.safeAiWillReceive}»');

    expect(find.byType(WorkspaceScreen), findsOneWidget);
    await _aPictureOf(tester, 'the-one-screen');
  }, skip: _facesMissing.isNotEmpty);

  testWidgets('the settings, in Arabic', (tester) async {
    await tester.binding.setSurfaceSize(const Size(520, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = Ground();
    await tester.runAsync(() => ground.refresh());
    await tester.pumpWidget(_inArabic(Scaffold(
      backgroundColor: Zc.paper,
      body: SettingsScreen(ground: ground, onClose: () {}, room: SettingsRoom.language),
    )));
    await _settle(tester, rounds: 3);

    expect(find.byType(SettingsScreen), findsOneWidget);
    await _aPictureOf(tester, 'the-settings');
  }, skip: _facesMissing.isNotEmpty);

  // **And the screen a person meets before any of it** — paper 117 item 6,
  // which is the one the owner asked to be reshaped. Two pictures, because
  // the page has two states and the complaint was about the first of them:
  // the question with nothing promised yet, and the one promise that follows
  // the answer.
  //
  // It is **not** drawn through `_inArabic`: this page runs before there is a
  // setting, so it has no locale of its own and reads every sentence out of
  // the list the button names. A picture of it in a forced Arabic locale would
  // be a picture of a screen that does not exist.
  testWidgets('the first screen, before and after choosing العربية', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = Ground();
    await tester.runAsync(() async {
      await z.vaultLock();
      final own = Directory('${Directory.systemTemp.path}/zprivacy-ar-first-$pid');
      removeWhenItLetsGo(own);
      own.createSync(recursive: true);
      addTearDown(() => removeWhenItLetsGo(own));
      await z.setDataDir(dir: own.path);
      await ground.refresh();
    });
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        fontFamily: 'ArabicLook',
        fontFamilyFallback: const ['LatinLook'],
      ),
      home: RepaintBoundary(
        key: _theWholeScreen,
        child: FirstRunScreen(ground: ground, onStart: (_, {required wantsVault}) {}),
      ),
    ));
    await _settle(tester, rounds: 3);
    await _aPictureOf(tester, 'the-first-screen');

    await tester.tap(find.text(aLanguageInItsOwnWords('ar')));
    await _settle(tester, rounds: 2);
    await _aPictureOf(tester, 'the-first-screen-in-arabic');
  }, skip: _facesMissing.isNotEmpty);
}
