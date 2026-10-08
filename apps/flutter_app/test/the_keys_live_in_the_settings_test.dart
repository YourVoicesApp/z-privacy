// The keys live in the settings — never in the middle of the work.
//
// **The owner, 8 October:** «وضعنا إعدادات الذكاء في شاشة الإعدادات وبالتالي لا
// تظهر أثناء العمل أبداً» — the AI settings are in the settings screen, so they
// never appear during work. **Never** is the word the guards below are about.
//
// Measured on `fcdbabd` before any of this was written, `send_sheet.dart` put a
// `ConnectForm` — endpoint, model, API key — in **four** places:
//
//   1. `_ModelAndMode._provider`, behind «Connect» beside an unconnected
//      provider's name. This one is on the sheet's **first page**, which is
//      the page the sheet opens on: a person who pressed ✨AI to choose a
//      model is one press from a key form.
//   2. the Direct API door, inline, whenever nothing is connected.
//   3. «Change the address, the model, or the key», folded, when something is.
//   4. «Set up a local model», folded, always.
//
// The task named the second. The first is the one a person meets.
//
// The form itself does not move: `settings.dart` already holds it twice, in
// `_AiRoom`, and has since before 063. Nothing is added there. What changes is
// that the sheet stops carrying its own copy and carries a **door** instead.
//
// ---
//
// **Why the door closes the sheet.** 063 made the settings a panel that stands
// over the work — but `showDialog` pushes onto the `Navigator` that
// `MaterialApp` owns, and its overlay is above every route's content, while the
// panel is a `Positioned` inside `ZShell.build`, inside the home route. So with
// the sheet up the panel is below the modal barrier. Measured by the session
// that built 063, on `fcdbabd`:
//
//     panel open, no dialog      doorReaches=true   midReaches=true
//     panel open, dialog route   doorReaches=false  midReaches=false
//
// and — the part worth the sentence — **the panel still paints**, full rect,
// merely dimmed. A person would watch the settings open and find they cannot
// touch them: not a door that failed, a door that opened onto nothing. So the
// sheet closes first, and guard f holds that it does.
//
// **What each guard stands on** is written at each one. The last is an
// **anchor**, not a guard: it is green before this change and after it, and it
// is here because the task's scope line says the three doors and the refusal
// before send must not move.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/settings.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/connect_form.dart';
import 'package:zprivacy/widgets/send_sheet.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _pass = 'ein gutes Passwort für die Einstellungen';
const _doc = 'E-Mail: a.weber@nordstern.de';

/// A name the German pack **offers** rather than decides, so the sheet has an
/// open suggestion to refuse a send over.
const _unsure = 'Der Vorgang wurde von Thomas Müller geprüft.';

Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
}

Future<Ground> _vault(WidgetTester tester, String name) async {
  final ground = Ground();
  await tester.runAsync(() async {
    await z.vaultLock();
    final dir = Directory('${Directory.systemTemp.path}/zprivacy-keys-$name-$pid');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    await z.setDataDir(dir: dir.path);
    await z.vaultCreateWithPassphrase(passphrase: _pass);
    await ground.refresh();
  });
  return ground;
}

/// How many times the sheet asked for the settings panel.
int askedForSettings = 0;

/// The sheet **as the product opens it** — a dialog route over a screen, not a
/// widget mounted in a body. The difference is the whole of why the door has to
/// close it: a `Navigator.pop` only means anything when there is a route to
/// pop, and the modal barrier only exists on the real path.
Future<Workbench> _openSheet(
  WidgetTester tester,
  Ground ground, {
  String text = _doc,
  bool toAiPage = true,
  bool withDoor = true,
}) async {
  late final Workbench bench;
  await tester.runAsync(() async {
    final session = await z.openSession(profileId: null, packId: 'de');
    bench = Workbench(session: session, profileId: null, packId: 'de');
    await z.importText(session: session, text: text);
    await bench.rescan();
    await ground.refresh();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => SendSheet(
                  bench: bench,
                  ground: ground,
                  onSettings: withDoor ? () => askedForSettings++ : null,
                ),
              ),
              child: const Text('open the sheet'),
            ),
          ),
        ),
      ),
    ),
  );
  await settle(tester);
  await tester.tap(find.text('open the sheet'));
  await settle(tester);
  if (toAiPage) {
    await tester.tap(find.text('Continue'));
    await settle(tester);
  }
  return bench;
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  setUp(() {
    askedForSettings = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });

  // e · Stands on the widget type. `ConnectForm` is the key form and nothing
  // else is; if one is anywhere in the tree after the press, the ruling is
  // broken whatever the screen looks like.
  testWidgets('e — «Connect» on the sheet\'s first page opens no key form', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = await _vault(tester, 'first-page');
    final bench = await _openSheet(tester, ground, toAiPage: false);

    final connect = find.textContaining('Connect').hitTestable();
    expect(
      connect,
      findsWidgets,
      reason: 'the sheet offers no provider to connect, so this test proves nothing either way',
    );
    await tester.tap(connect.first);
    await settle(tester);

    expect(
      find.byType(ConnectForm),
      findsNothing,
      reason:
          'an endpoint, a model and an API key opened inside the send sheet — one press from '
          'the page a person reaches by asking for an AI',
    );
    expect(
      askedForSettings,
      1,
      reason: 'the press went nowhere: it opened no form and asked for no settings panel',
    );

    bench.dispose();
  });

  // f · Stands on three facts that have to hold together: no form, a line that
  // says why, and a sheet that is **gone** afterwards. The third is the one
  // that matters — a door that opens the panel without closing the sheet opens
  // a panel the person cannot touch.
  //
  // **What this guard does not hold, said rather than assumed.** It proves the
  // door renders and that pressing it closes the sheet and asks for the panel.
  // It cannot prove the panel then opens, because the panel lives in the shell
  // and the mount here is a bare screen with a recorded callback. That half is
  // guard a of `the_settings_cover_the_work_test.dart`, which presses through
  // the real shell. **The property is whole across the two files and neither
  // one holds it alone** — raised by the session that built 063, after reading
  // this file.
  testWidgets('f — with nothing connected the AI page says so, and its door closes the sheet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = await _vault(tester, 'no-provider');
    final bench = await _openSheet(tester, ground);

    expect(
      find.byType(ConnectForm),
      findsNothing,
      reason: 'the key form is still standing in the send flow, where the owner said it never appears',
    );
    final door = find.widgetWithText(ZButton, 'Open Settings');
    expect(
      door,
      findsWidgets,
      reason: 'nothing connected, no form, and no way to reach the one place a key can be given',
    );

    await tester.tap(door.first);
    await settle(tester);

    expect(askedForSettings, 1, reason: 'the door did not ask for the settings panel');
    expect(
      find.byType(SendSheet),
      findsNothing,
      reason:
          'the sheet is still up, so the panel opens under its modal barrier — it paints in full '
          'and answers nothing, which is worse than a door that did not open',
    );

    bench.dispose();
  });

  // g · Stands on the labels of the two folds that held a form. A fold is not
  // searchable by the type of the thing inside it — it has not built it yet —
  // so the fold's own name is the only honest thing to ask for.
  //
  // Two tests and not one, because «never» has two branches and the first
  // attempt ran them in sequence in one body: it disposed the bench and opened
  // a second sheet while the first dialog route was still mounted, so the sheet
  // rebuilt on a disposed `Workbench` and the test died of its own setup rather
  // than of its subject.
  testWidgets('g1 — with nothing connected, the Local AI door folds no key form', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = await _vault(tester, 'fold-open');
    final bench = await _openSheet(tester, ground);

    expect(
      find.textContaining('Set up a local model'),
      findsNothing,
      reason: 'the Local AI door still folds a key form into the send flow',
    );

    bench.dispose();
  });

  testWidgets('g2 — with a provider connected, no fold and no form either', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = await _vault(tester, 'fold-connected');

    // Connecting stores a credential; it reaches no network — `test_provider`
    // is the call that does, and nothing here calls it.
    await tester.runAsync(() async {
      final rows = ground.providers;
      expect(rows, isNotEmpty, reason: 'this build knows no providers, so the branch cannot be reached');
      final bad = await ground.connect(
        id: rows.first.id,
        credential: 'sk-not-a-real-key-0000',
        baseUrl: 'https://example.invalid/v1',
        model: 'a-model',
      );
      expect(bad, isNull, reason: 'the provider would not connect: $bad');
    });
    addTearDown(() async => z.disconnectProvider(provider: ProviderId(id: ground.providers.first.id)));
    expect(
      ground.providers.any((p) => p.connected),
      isTrue,
      reason: 'nothing is connected, so the connected branch is not being measured',
    );

    final bench = await _openSheet(tester, ground);
    expect(
      find.textContaining('Change the address, the model, or the key'),
      findsNothing,
      reason: 'the Direct API door still folds the endpoint, the model and the key into the send flow',
    );
    expect(
      find.byType(ConnectForm),
      findsNothing,
      reason: 'a key form stands in the send flow once a provider is connected',
    );

    bench.dispose();
  });

  // i · **The claims that came with the form.** `shell_test.dart` used to
  // assert these against the two forms the send sheet mounted — one API KEY,
  // two ADDRESS fields, the loopback sentence — and they are not about the
  // sheet at all: they are about what `ConnectForm` asks for, and they moved
  // with it rather than being dropped.
  //
  // Measured at **444 px**, which is what the panel's content really gets: 480
  // wide with 18 of padding each side (063). A key form that does not read at
  // 444 is a key form in a place nobody can use, and the whole of this ruling
  // is that 444 is now the only place it stands.
  testWidgets('i — the form, in its one home, still asks what it used to', (tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = await _vault(tester, 'its-home');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 480,
            child: SettingsScreen(ground: ground, onClose: () {}),
          ),
        ),
      ),
    );
    await settle(tester);

    // The AI room is the room the panel opens on, so a door that only opens
    // the panel lands where the key is asked for. If that default ever moves,
    // this is the line that will say so.
    expect(
      find.text('AI'),
      findsWidgets,
      reason: 'the panel did not open on the room the key lives in',
    );

    // **The counts come from the core, not from a literal.** The old form of
    // this claim said «one API KEY, two ADDRESS», which was true of the sheet
    // because the sheet only ever mounted `providers.first`. The panel draws a
    // Direct API card for every provider the build knows — measured: six — so
    // a literal here would have been a fact about one screen's shortcut.
    final keyed = ground.providers.where((p) => p.credentialRequired).length;
    expect(keyed, greaterThan(0), reason: 'no provider asks for a key, so this proves nothing');

    expect(
      find.text('API KEY'),
      findsNWidgets(keyed),
      reason: 'the Direct API cards ask for $keyed keys and the screen drew a different number',
    );
    // Where the key would live, which is `shell_test.dart`'s claim and not its
    // wording: the sentence depends on the vault, and the two tests stand on
    // opposite sides of it. `shell_test` had no open vault and read «kept in
    // memory for this run only»; this test opens one, so the promise is the
    // other branch. Asserting that file's literal string here would have gone
    // red for a reason that has nothing to do with where the form lives.
    expect(
      ground.vault,
      VaultState.unlocked,
      reason: 'the vault is not open, so the sentence below is the wrong branch to expect',
    );
    expect(
      find.textContaining('Connecting will seal it in the vault'),
      findsWidgets,
      reason: 'the form does not say where the key would live',
    );

    // A model on this machine is asked for no key at all — one field fewer,
    // not an empty one. So the claim is the **difference**: the Local AI card
    // adds an address and no key.
    expect(
      find.text('ADDRESS'),
      findsNWidgets(ground.providers.length + 1),
      reason: 'one address per provider card and one for the Local AI card — the count disagrees',
    );
    // Twice in the panel, not once as in the sheet: the Local AI card states
    // the rule and the form beneath it states it again. The claim is that the
    // rule is said, not that it is said once.
    expect(find.textContaining('literal loopback address'), findsWidgets);
    expect(find.text('http://127.0.0.1:11434'), findsWidgets);

    // And it reads at this width — nothing of it is pushed off the panel.
    final form = tester.getRect(find.byType(ConnectForm).first);
    expect(
      form.right,
      lessThanOrEqualTo(480.0),
      reason: 'the form runs to x=${form.right.toStringAsFixed(0)} in a 480 px panel',
    );
    expect(
      tester.takeException(),
      isNull,
      reason: 'the form overflowed or threw at the width the panel really gives it',
    );
  });

  // j · **A door labelled «Open Settings» must not close them.**
  //
  // Found by reading the chain rather than the screen: `shell.dart` passes
  // `onSettings` as a **toggle**, and `workspace.dart` hides its own settings
  // door while the panel stands but leaves the ✨AI control on the bar. So the
  // sheet can be opened over an open panel, and its door would have shut the
  // thing it names.
  //
  // Stands on the two states of one screen, in one test, so the second half is
  // the first half's control: with the panel shut the door is there, with it
  // open the door is gone. Either assertion alone could pass for the wrong
  // reason — a sheet that never draws a door would satisfy the second.
  testWidgets('j — the sheet offers no settings door while the panel already stands', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = await _vault(tester, 'already-open');

    late final Workbench bench;
    await tester.runAsync(() async {
      final session = await z.openSession(profileId: null, packId: 'de');
      bench = Workbench(session: session, profileId: null, packId: 'de');
      await z.importText(session: session, text: _doc);
      await bench.rescan();
      await ground.refresh();
    });

    Future<void> openTheSheet({required bool panelStanding}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceScreen(
            bench: bench,
            ground: ground,
            onHome: () {},
            onVault: () {},
            onSettings: () => askedForSettings++,
            settingsOpen: panelStanding,
          ),
        ),
      );
      await settle(tester);
      await tester.tap(find.byTooltip('Choose the AI and what travels to it'));
      await settle(tester);
      await tester.tap(find.text('Continue'));
      await settle(tester);
    }

    // The control first: with the panel shut, the door is drawn.
    await openTheSheet(panelStanding: false);
    expect(
      find.text('Open Settings'),
      findsWidgets,
      reason: 'the sheet draws no door even with the panel shut, so the absence below proves nothing',
    );
    await tester.tap(find.text('Cancel'));
    await settle(tester);

    // And with it standing, no door — because pressing one would have closed it.
    await openTheSheet(panelStanding: true);
    expect(
      find.text('Open Settings'),
      findsNothing,
      reason: 'a door labelled «Open Settings» is offered over an already-open panel, and the '
          'shell\'s callback is a toggle — pressing it would shut them',
    );

    bench.dispose();
  });

  // h · **An anchor, not a guard.** Green before this change and after it. The
  // task's scope line: the sheet keeps its three doors and the review before
  // send, and nothing touches what it sends or when it refuses to.
  testWidgets('h — ANCHOR: the three doors stand, and an open suggestion still refuses the send', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ground = await _vault(tester, 'anchor');

    await tester.runAsync(() async {
      final rows = ground.providers;
      await ground.connect(
        id: rows.first.id,
        credential: 'sk-not-a-real-key-0000',
        baseUrl: 'https://example.invalid/v1',
        model: 'a-model',
      );
    });

    final bench = await _openSheet(tester, ground, text: _unsure);
    expect(bench.openSuggestions, greaterThan(0), reason: 'the fixture scans up nothing unsure');

    for (final door in ['Manual AI', 'Direct API', 'Local AI']) {
      expect(find.text(door), findsWidgets, reason: 'the «$door» door is gone from the sheet');
    }
    expect(find.text('Copy Protected'), findsOneWidget, reason: 'the door that needs no account is gone');

    final send = find.widgetWithText(ZButton, 'Send to Direct API');
    expect(send, findsWidgets, reason: 'a connected provider offers no send button');
    expect(
      tester.widget<ZButton>(send.first).onPressed,
      isNull,
      reason: 'a question with an unanswered suggestion could be sent — the one promise this product makes',
    );

    bench.dispose();
  });
}
