// 046/G · the home is the conversation.
//
// **The owner, 7 October:** «after the vault I go to a chat screen — does it
// exist?» The measured answer was no, and the measurement is worth keeping:
// `shell.dart` put the vault in front of the home and then showed a composer;
// the model lived in a sheet reachable only from the Workspace, which exists
// only once a document is open; and the answer lived in a third destination.
// **From the home there was no door to a model at all.**
//
// So three things are held here, and the third is the one that matters most:
//
//   1. with no document open, a question can be asked from the home;
//   2. its answer appears **in the same screen** rather than in a third
//      destination — and since 8 October it stands above the writing and
//      not below it, which `the_chat_reads_like_a_chat_test.dart` measures;
//   3. **it cannot be asked while a suggestion is unanswered**, and the
//      reason is on the button rather than in a message afterwards.
//
// On what is reachable in a test and what is not: a model needs a connected
// provider, and a test has none — `model_gateway_test.dart` holds that door's
// refusal. The door that completes the loop offline is the one a person uses
// when they take the safe text to a model themselves, and it produces a real
// answer through the real core. That is the door used here, and the thing
// under test is not the network: it is that the answer arrives **in this
// screen** instead of in a third one.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 4))
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/screens/answer.dart';
import 'package:zprivacy/screens/home.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _pass = 'ein gutes Passwort für das Gespräch';

/// A question with nothing in it a scanner could be unsure about.
const _plain = 'Please summarise the rules for quarterly VAT returns.';

/// A question with a name in it that the German pack **offers** rather than
/// decides — so the gate has something to hold.
const _unsure = 'Der Vorgang wurde von Thomas Müller geprüft.';

Future<Ground> _vault(WidgetTester tester, String name) async {
  final ground = Ground();
  await tester.runAsync(() async {
    await z.vaultLock();
    final dir = Directory('${Directory.systemTemp.path}/zprivacy-chat-$name-$pid');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    await z.setDataDir(dir: dir.path);
    await z.vaultCreateWithPassphrase(passphrase: _pass);
    await ground.refresh();
  });
  return ground;
}

/// What the shell does, in the one place a test can drive it: open a session
/// with the settings' pack, read the line in, scan.
Future<Workbench> _ask(WidgetTester tester, Workbench? had, String text) async {
  late Workbench chat;
  await tester.runAsync(() async {
    chat = had ?? Workbench(
      session: await z.openSession(packId: 'de'),
      profileId: null,
      packId: 'de',
    );
    await z.importText(session: chat.session, text: text);
    await chat.rescan();
  });
  return chat;
}

Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 120));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
}

Widget _home(Ground ground, Workbench? chat, {void Function(String)? onType}) => MaterialApp(
      home: HomeScreen(
        ground: ground,
        version: 'z_core 0.1.0',
        chat: chat,
        onImport: () {},
        onType: onType ?? (_) {},
        onAsk: (_) async {},
        onVault: () {},
        onSettings: () {},
      ),
    );

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  setUp(() {
    // The clipboard is the system's. Nothing here reads it except through this.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });

  testWidgets('the home has a door to a model with no document open', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 1000));
    final ground = await _vault(tester, 'door');

    await tester.pumpWidget(_home(ground, null));
    await settle(tester);

    expect(
      find.text('Ask the AI'),
      findsOneWidget,
      reason: 'the home has no door to a model — the owner asked for the chat screen',
    );
    // And it is not pressable on an empty line, with the reason beside it: the
    // same shape every blocked act in this app has.
    final button = tester.widget<ZButton>(find.widgetWithText(ZButton, 'Ask the AI'));
    expect(button.onPressed, isNull);
    expect(find.textContaining('Write or paste something first'), findsWidgets);
  });

  testWidgets('the answer appears in the same screen, not in a third one', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 1100));
    final ground = await _vault(tester, 'answer');

    // A plain question: nothing in it a scanner is unsure of, so the gate is
    // open and this measures the answer and nothing else.
    final chat = await _ask(tester, null, _plain);
    expect(chat.openSuggestions, 0, reason: 'the fixture is not a plain question');

    // The offline door: the safe text is taken out, and the answer brought
    // back. The core restores it against the payload it was bound to.
    await tester.runAsync(() async {
      chat.rememberCopiedPayload();
      await chat.pasteAnswer('Quarterly returns are filed within 30 days.');
    });

    await tester.pumpWidget(_home(ground, chat));
    await settle(tester);

    expect(
      find.byType(AnswerPanel),
      findsOneWidget,
      reason: 'the answer is not in this screen — it is still a third destination',
    );
    expect(find.textContaining('Quarterly returns are filed'), findsWidgets);
    // Everything `answer.dart` carries comes with it, unchanged: both views,
    // and the two named copies. The clipboard warning is the confirmation
    // dialog, which `Copy Restored` opens — pinned by `paste_test.dart`.
    expect(find.text('Restored'), findsOneWidget);
    expect(find.text('As the model wrote it'), findsOneWidget);
    expect(find.textContaining('Copy'), findsWidgets);

    chat.dispose();
  });

  testWidgets('a question with an unanswered suggestion cannot be asked, and says why', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 1100));
    final ground = await _vault(tester, 'gate');

    final chat = await _ask(tester, null, _unsure);
    expect(
      chat.openSuggestions,
      greaterThan(0),
      reason: 'the fixture scans up nothing unsure, so this test proves nothing',
    );

    // The line has to hold the question for the button to be about it.
    await tester.pumpWidget(_home(ground, chat));
    await settle(tester);
    await tester.enterText(find.byType(TextField), _unsure);
    await settle(tester);

    final button = tester.widget<ZButton>(find.widgetWithText(ZButton, 'Ask the AI'));
    expect(
      button.onPressed,
      isNull,
      reason: 'a question with an unanswered suggestion could be sent — the one promise',
    );
    expect(
      find.textContaining('Answer the'),
      findsWidgets,
      reason: 'the button does not carry the reason it cannot be pressed',
    );
    // And the way through it is on the screen, not left to be guessed.
    expect(find.textContaining('not certain yet'), findsWidgets);
    expect(find.text('Open the question and answer them'), findsOneWidget);

    chat.dispose();
  });

  testWidgets('the gate opens once the suggestions are answered', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 1100));
    final ground = await _vault(tester, 'opens');

    final chat = await _ask(tester, null, _unsure);
    expect(chat.openSuggestions, greaterThan(0));

    // Answer every one of them — «no, that is not a name» is an answer.
    await tester.runAsync(() async {
      for (final f in await z.listFindings(session: chat.session)) {
        if (f.state == MarkState.suggested) {
          await z.answerFinding(session: chat.session, finding: f.id, answer: FindingAnswer.notSensitive);
        }
      }
      await chat.refresh();
    });
    expect(chat.openSuggestions, 0, reason: 'answering did not close them');

    await tester.pumpWidget(_home(ground, chat));
    await settle(tester);
    await tester.enterText(find.byType(TextField), _unsure);
    await settle(tester);

    final button = tester.widget<ZButton>(find.widgetWithText(ZButton, 'Ask the AI'));
    expect(
      button.onPressed,
      isNotNull,
      reason: 'the gate stayed shut after every suggestion was answered',
    );
    expect(find.textContaining('not certain yet'), findsNothing);

    chat.dispose();
  });
}
