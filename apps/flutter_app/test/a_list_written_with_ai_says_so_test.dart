// **A list written with AI says so, under the choice** — paper 121, the
// owner's ruling of 2 November 2026: French and Spanish were translated with
// AI, and the Language room says that, with the address and the subject a
// correction is filed under. German, Swedish and Arabic were written by people
// and say nothing of the kind.
//
// The language is set the way the room's own press sets it — one value, both
// fields (080) — and read back off the glass, in the language it was set to.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/l10n/app_localizations_es.dart';
import 'package:zprivacy/l10n/app_localizations_fr.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'the_bridge_the_tests_speak_through.dart';
import 'the_folder_lets_go.dart';

const _pass = 'une phrase secrète assez longue pour un coffre';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

Settings withLanguage(Settings c, String code) => Settings(
      scanOnImport: c.scanOnImport,
      revealSeconds: c.revealSeconds,
      autoLockMinutes: c.autoLockMinutes,
      packId: c.packId,
      language: code,
      firstRunDone: c.firstRunDone,
      originalPanePercent: c.originalPanePercent,
      columnsInStep: c.columnsInStep,
      safeColumnOpen: c.safeColumnOpen,
      reviewPanelWide: c.reviewPanelWide,
      sessionOnly: c.sessionOnly,
    );

void main() {
  setUpAll(() async {
    if (!File(theBridgeTheTestsSpeakThrough).existsSync()) {
      throw StateError(buildTheBridgeFirst);
    }
    await RustLib.init();
  });

  for (final code in <String>['fr', 'es', 'de']) {
    testWidgets('the Language room says a list was written with AI when it was ($code)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 950));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final ground = Ground();
      await tester.runAsync(() async {
        final dir = Directory('${Directory.systemTemp.path}/zprivacy-121-$code-$pid');
        removeWhenItLetsGo(dir);
        addTearDown(() => removeWhenItLetsGo(dir));
        await z.vaultLock();
        await z.setDataDir(dir: dir.path);
        await z.vaultCreateWithPassphrase(passphrase: _pass);
        await ground.refresh();
        await ground.saveConfig(withLanguage(ground.config!, code));
      });
      expect(ground.config!.language, code, reason: 'the core kept another language');
      theSentencesAreNow(theLocaleOf(code));
      addTearDown(() => theSentencesAreNow(const Locale('en')));
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(ground: ground, onClose: () {}, room: SettingsRoom.language),
      ));
      await settle(tester);
      final line = find.byKey(const ValueKey('the-translation-was-made-with-ai'));
      if (code == 'de') {
        expect(line, findsNothing, reason: 'the German was written by a person');
        return;
      }
      expect(line, findsOneWidget);
      final said = tester.widget<Text>(line).data!;
      final want = code == 'fr'
          ? AppLocalizationsFr().thisTranslationWasMadeWithAi('Translation (FR)')
          : AppLocalizationsEs().thisTranslationWasMadeWithAi('Translation (ES)');
      expect(said, want, reason: 'the line is not in the list it is about');
      expect(said, contains('zprivacy@mono-peak.com'));
    });
  }
}
