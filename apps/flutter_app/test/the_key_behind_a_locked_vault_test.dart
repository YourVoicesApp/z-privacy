// **A key the vault is holding is not a key that was never given** — the
// owner, 18 October 2026, on the installed `34ed785`.
//
// He asked a question through «Choose who answers», xAI answered, and the chat
// drew the exchange. He typed a second question in the compose box, pressed
// «➤ xAI (Grok)», and read: «No AI provider is connected. Add an address and a
// key first.» His key was given days ago and is sealed in his vault. What had
// happened in between is that the vault auto-locked — his top bar said so, and
// the band under it said the vault layer had not run.
//
// **The cause, in the lines.** `login_for` reads the sealed logins through
// `with_open`, which fails while the vault is shut, and then falls back to
// *this run's* logins, so a sealed key is «no credential in this run» — which
// is what the core's own detail says, and what the glass threw away in favour
// of the reason's wording. The cause was true; the sentence named the wrong
// one and offered the one move the person must not make.
//
// Two guards, in the order he met them: the refusal, and the press after he
// pressed Unlock.
//
// **The clock is not driven from here**, and that is G23: `age_vault_unused`
// is compiled under `test_clock` and never crosses the bridge, so the Dart
// half cannot age a vault. What it can do is put the vault in the state an
// auto-lock leaves behind — `vaultLock()` — and that state is what both guards
// are about. That the auto-lock fires at all is measured in the core's tests.
//
// **Why the presses are settled so long.** The chain behind the arrow is a
// core call started in a widget callback, and under `testWidgets` such a call
// resumes only while the harness is both pumping and letting real time pass.
// Measured while writing this file: three rounds of settling after a perfectly
// good press were not enough for it to reach its first act, and the instrument
// watching for that act read «nothing happened» — a control press with no lock
// anywhere near it behaved exactly the same way. So the length of the settle
// says nothing about the vault, and twenty rounds is the measured answer.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/workspace.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/the_chat.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _pass = 'ein gutes Passwort für den Tresor';

/// A letter with a name a general rule protects on its own, so what leaves
/// carries a token and what comes back has a value to restore.
const _doc = 'Sehr geehrter Herr Thomas Müller,\n'
    'die Rechnung über 42 500 EUR ist beglichen.\n';

Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

/// A bench with a document, every suggestion answered, in a session — and the
/// fake provider connected **while the vault is open**, so its login is sealed
/// in the vault exactly as the owner's is. That is the whole point of the
/// fixture: a login in the vault cannot be read while the vault is shut.
Future<({Ground ground, Workbench bench})> _ready(WidgetTester tester, String name) async {
  final ground = Ground();
  late final Workbench bench;
  await tester.runAsync(() async {
    final dir = Directory('${Directory.systemTemp.path}/zprivacy-lockedkey-$name-$pid');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    addTearDown(() {
      // Best effort, for the race named in `later_is_not_an_answer_test.dart`.
      try {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Left behind rather than red for something no claim here is about.
      }
    });
    await z.vaultLock();
    await z.setDataDir(dir: dir.path);
    await z.vaultCreateWithPassphrase(passphrase: _pass);
    final session = await z.openSession(profileId: null, packId: 'de');
    await z.importText(session: session, text: _doc);
    bench = Workbench(session: session, profileId: null, packId: 'de');
    await bench.rescan();
    for (final f in bench.suggested) {
      await z.answerFinding(session: session, finding: f.id, answer: FindingAnswer.protect);
    }
    await bench.refresh();
    await z.connectProvider(
      provider: const ProviderId(id: 'fake'),
      credential: 'not-a-real-credential',
      baseUrl: null,
      model: null,
    );
    addTearDown(() async => z.disconnectProvider(provider: const ProviderId(id: 'fake')));
    await ground.refresh();
    await bench.refreshModels();
  });
  return (ground: ground, bench: bench);
}

Future<void> _pumpTheWork(WidgetTester tester, ({Ground ground, Workbench bench}) g) async {
  await tester.binding.setSurfaceSize(const Size(1600, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    home: WorkspaceScreen(
      bench: g.bench,
      ground: g.ground,
      onImport: () {},
      onAsk: (_) {},
      onVault: () {},
      onSettings: (_) {},
    ),
  ));
  await settle(tester);
}

/// The first question, through the sheet's own hand, and answered.
Future<void> _askTheFirst(WidgetTester tester, ({Ground ground, Workbench bench}) g) async {
  await tester.runAsync(() async {
    await g.bench.setQuestion('Worum geht es?');
    final bad = await beginThenAsk(g.ground, g.bench, providerId: 'fake');
    expect(bad.refused, isNull, reason: 'the first question did not go: ${bad.refused}');
  });
  await settle(tester);
}

/// The second question, typed into the box and sent with the arrow — the press
/// the owner made, not a call behind it.
Future<void> _pressTheArrow(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(TheChat.compose), text);
  await settle(tester, rounds: 2);
  await tester.tap(find.byKey(TheChat.arrow));
  await settle(tester, rounds: 20);
}

/// The vault shut the way an auto-lock leaves it, and the ground told.
Future<void> _lockIt(WidgetTester tester, Ground ground) async {
  await tester.runAsync(() async {
    await z.vaultLock();
    await ground.refresh();
  });
  await settle(tester);
}

String _onTheGlass(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data)
    .whereType<String>()
    .join(' | ');


/// Every turn the session file holds, unfiltered, straight from the core —
/// **with the session's own number**, because the number is the thing this
/// file is about: a lock takes it away and an unlock gives it back.
Future<({int? session, List<int> chats, bool answered})> _theFile(
  WidgetTester tester,
  Workbench bench,
) async {
  int? open;
  var chats = const <int>[];
  var answered = false;
  await tester.runAsync(() async {
    open = await z.conversationOpen();
    final number = open;
    if (number == null) return;
    final rows = await z.conversationTurns(number: number, bench: bench.session);
    chats = rows.map((t) => t.chatNumber).toList();
    answered = rows.isNotEmpty && rows.every((t) => t.answerAsWritten.isNotEmpty);
  });
  return (session: open, chats: chats, answered: answered);
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  // ------------------------------------------------------------------ guard 1
  //
  // **The refusal names the vault, and both ways out of it.** One sentence has
  // to carry two true things: a key cannot be reached while the vault is shut,
  // and there are two moves from here — unlock it, or give a key for this run,
  // which is what a person who never had one would do.
  testWidgets('a follow-up with the vault locked says so, and not «add a key»', (tester) async {
    final g = await _ready(tester, 'locked');
    addTearDown(g.bench.dispose);
    await _askTheFirst(tester, g);
    await _pumpTheWork(tester, g);
    expect(g.bench.chatTurns, hasLength(1), reason: 'the first answer wrote no turn');

    await _lockIt(tester, g.ground);
    expect(g.ground.vault, VaultState.locked, reason: 'the vault did not lock');

    await _pressTheArrow(tester, 'Und der Betrag?');

    final glass = _onTheGlass(tester);
    expect(
      glass,
      contains('while the vault is locked'),
      reason: 'the refusal does not name the vault — the owner read «no provider '
          'is connected» about a key sealed in his own vault: $glass',
    );
    expect(
      glass,
      contains('Unlock it'),
      reason: 'the refusal names no way out of the state it reports',
    );
    expect(
      glass,
      isNot(contains('No AI provider is connected')),
      reason: 'the sentence still tells him to add a key he gave days ago',
    );
    // Nothing left, and the question is still in the box: it is his writing,
    // and a refusal he can act on is one he can retry.
    expect(g.bench.chatTurns, hasLength(1), reason: 'a refused question wrote a turn');
    expect(
      tester.widget<TextField>(find.byKey(TheChat.compose)).controller!.text,
      'Und der Betrag?',
      reason: 'a question that did not go was taken out of the box',
    );
  });

  // ------------------------------------------------------------------ guard 2
  //
  // **And the press after Unlock, which is the owner's second fact**: «the
  // message did not arrive.» It had — into a session born on the spot, while
  // the chat he was reading stayed in the session before it.
  //
  // `vault_lock` clears `open_conversation`, because the way into a sealed
  // file goes with the master key (064), and its own comment named the other
  // half: «the next unlock **plus an `enter`** brings both back». The unlock
  // half existed and the `enter` half was nobody's, so after an unlock there
  // was no session open at all and the next exit bore one, as rule 55 says it
  // must. The number is not secret — 064 let it go with the key as a side
  // effect of that line, not as a law — so the lock keeps it and the unlock
  // enters it again, by the same door a person would.
  //
  // Measured at the three moments, which is the shape of the fault: the
  // session's own number before the lock, after the unlock, and after the
  // press.
  testWidgets('the unlock gives back the session the lock took, and the chat keeps both',
      (tester) async {
    final g = await _ready(tester, 'unlocked');
    addTearDown(g.bench.dispose);
    await _askTheFirst(tester, g);
    await _pumpTheWork(tester, g);
    final chatBefore = g.bench.openChat;

    final first = await _theFile(tester, g.bench);
    expect(first.session, isNotNull, reason: 'the first ask opened no session');
    expect(first.chats, hasLength(1), reason: 'the first ask wrote no turn');
    expect(first.answered, isTrue, reason: 'the first question was not answered');

    await _lockIt(tester, g.ground);
    await _pressTheArrow(tester, 'Und der Betrag?');
    expect(g.bench.chatTurns, hasLength(1), reason: 'a locked vault let a question out');

    // Unlock, as `vault_forms.dart` does it — the core call, then the ground —
    // and then the read-back the shell asks for, because a document read
    // without the vault layer can be read better once there is one open
    // (`rescanAfterVault`). Nothing here enters a session: that is the core's
    // now, which is the whole point of the fix.
    await tester.runAsync(() async {
      await z.vaultUnlockWithPassphrase(passphrase: _pass);
      await g.ground.refresh();
      await g.bench.rescanAfterVault();
    });
    await settle(tester);
    expect(g.ground.vault, VaultState.unlocked, reason: 'the vault did not open');
    expect(
      g.ground.providers.where((p) => p.id == 'fake').single.connected,
      isTrue,
      reason: 'the sealed login did not survive the lock and the unlock',
    );

    final back = await _theFile(tester, g.bench);
    expect(back.session, first.session,
        reason: 'the unlock did not give back the session the lock took away: '
            '${first.session} became ${back.session}, so the next question would be '
            'answered into a session born on the spot');

    // **The press the owner made.** It is driven by the arrow, and the chain
    // behind it is settled long for the reason written at the top of this file.
    await _pressTheArrow(tester, 'Und der Betrag?');

    final after = await _theFile(tester, g.bench);
    expect(after.session, first.session, reason: 'the question went into another session');
    expect(after.chats, [1, 1],
        reason: 'the two exchanges are not both in the first chat of this session: '
            '${after.chats} — a spent chat number is a thread the panel does not draw');
    expect(after.answered, isTrue, reason: 'the follow-up was not answered');

    // And the panel draws both, in the chat it was drawing before the lock.
    expect(g.bench.chatTurns, hasLength(2),
        reason: 'the thread lost an exchange across the lock');
    expect(g.bench.openChat, chatBefore,
        reason: 'the chat the panel draws is not the one it drew before the lock');
    expect(g.bench.chatProvider, 'fake',
        reason: 'the relock dropped the door the chat had chosen');
    expect(
      tester.widget<TextField>(find.byKey(TheChat.compose)).controller!.text,
      isEmpty,
      reason: 'the question that went is still in the box',
    );
  });
}
