// 064 · The name at the exit — the question asked where the text leaves.
//
// The owner's rule: a session is born of the act that needs it, and the name is
// asked once, there. The panel's Sessions room is the deliberate path and has
// its own file; this one holds the other path — the person who never pressed
// that button and is one press away from taking text out of the machine.
//
// ## What this file can measure, and what it cannot
//
// **A widget that awaits the core does not resume under `testWidgets`.** It is
// why no test in this app presses «Create the vault», and it is written above
// `begin` in `a_session_is_a_room_in_the_panel_test.dart`. So the wire «this
// press reaches `conversationBegin` with `bench:`» is not provable here, and no
// guard below pretends to press it. What is provable, and is:
//
//   * the strip's three states, on the glass, each distinguishable from the
//     other two — the whole reason a person can know whose names are leaving;
//   * the doors staying live while the question stands: it asks, it does not gate;
//   * an empty name taking nothing out — by the clipboard, with its control
//     beside it, because a zero is only worth quoting next to a one;
//   * **the press copying what the bench holds at the press, not what the last
//     build captured** — a real press, a real clipboard probe;
//   * `beginThenRead`'s order, driven through the ground inside `runAsync`: the
//     text it hands back wears the session's names and none of the pre-birth
//     ones, and its sentence carries the core's own number.
//
// The other end of that last property is in the core, from the other seat:
// `every_token_that_leaves_belongs_to_the_session` in
// `z_core/tests/a_session_carries_its_own_key.rs`. Two files, one property,
// each holding its own end — and the wire between them named here rather than
// implied by a green press.
//
// Needs the native library, so run once:  flutter build linux --debug
@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/send_sheet.dart';

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _wide = Size(1200, 1000);

/// One value the general rules protect on their own, and nothing else to argue
/// about: one token, so «the pre-birth name» is a single string to look for.
const _letter = 'Bitte überweisen Sie auf IBAN DE02120300000000202051 bis Freitag.';
const _other = 'Zahlung an IBAN DE44500105175407324931, Freitag bestätigt.';
const _nothingToProtect = 'Hej, allt är bra idag.';

/// The one value the general rules take out of [_letter]. Named so that a
/// guard can look for it **in what a person would paste**, which is the only
/// place the owner's 12 October leak was ever visible.
const _theValue = 'DE02120300000000202051';

Future<void> _settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await tester.pumpAndSettle();
}

Directory _ownDir(String name) {
  final own = Directory('${Directory.systemTemp.path}/zprivacy-exit-$name-$pid');
  if (own.existsSync()) own.deleteSync(recursive: true);
  addTearDown(() {
    if (own.existsSync()) own.deleteSync(recursive: true);
  });
  return own;
}

/// Captures clipboard writes — a widget test has no system clipboard.
///
/// A copy of `_ClipboardProbe` in `shell_test.dart:1674`, which is private to
/// that file, and of the smaller one in `copy_report_test.dart:57`. Three copies
/// of one instrument want a `test/support/` this suite does not have; inventing
/// that structure inside this round would be picking a surface nobody asked for,
/// so it is named here as a debt instead.
///
/// `text` starts at a sentinel so that a **false read** — a probe that answers
/// something nobody wrote — is visible as itself. A guard about what a person
/// would *paste* sets it to the thing they would really have had there.
///
/// **[wrote] keeps the order, not only the count** — 081. The owner's rule is
/// «empty the clipboard, then decide», and an order is a sequence: a count can
/// say «two writes happened» while the copy came first and the emptying wiped
/// it, which is the one failure that would look like success in every other
/// instrument here.
class _ClipboardProbe {
  _ClipboardProbe(this.tester);

  final WidgetTester tester;
  String? text = 'SENTINEL';

  /// Every write, in the order it was made.
  final List<String?> wrote = <String?>[];

  int get writes => wrote.length;

  void install() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            final args = Map<String, dynamic>.from(call.arguments as Map);
            text = args['text'] as String?;
            wrote.add(text);
            return null;
          case 'Clipboard.getData':
            if (text == null) return null;
            return <String, dynamic>{'text': text};
          case 'Clipboard.hasStrings':
            return <String, dynamic>{'value': text != null && text!.isNotEmpty};
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
  }
}

/// A bench with a scanned document, and the ground, with no widget at all.
Future<({Workbench bench, Ground ground})> _benchOnly(
  String name, {
  bool withAVault = true,
  String text = _letter,
  String documentName = '',
}) async {
  final own = _ownDir(name);
  final ground = Ground();
  await z.vaultLock();
  await z.setDataDir(dir: own.path);
  if (withAVault) {
    await z.vaultCreateWithPassphrase(passphrase: 'ett lösenord för utgången');
  }
  final session = await z.openSession(profileId: null, packId: 'de');
  final bench = Workbench(session: session, profileId: null, packId: 'de');
  if (documentName.isEmpty) {
    await z.importText(session: session, text: text);
  } else {
    // **A file with a name on it** — the only fixture in which «the saved file
    // is named after the session, not the document» can be told from «there
    // was no document name anyway». Typed text has none.
    await z.importDocument(
      session: session,
      name: documentName,
      bytes: Uint8List.fromList(utf8.encode(text)),
      kind: DocumentKind.txt,
    );
  }
  await bench.rescan();
  await ground.refresh();
  return (bench: bench, ground: ground);
}

/// The sheet, open on its second page — where the two exits are.
///
/// `Continue` is dead while the payload is null, so **arriving at the doors is
/// itself a measurement**: a guard that stands here has proven a payload exists
/// on the way in, and no guard in this file mounts the doors any other way.
Future<({Workbench bench, Ground ground, Directory out})> _atTheDoors(
  WidgetTester tester,
  String name, {
  bool withAVault = true,
  String text = _letter,
  bool toTheDoors = true,
  String documentName = '',
}) async {
  late final ({Workbench bench, Ground ground}) made;
  await tester.runAsync(() async {
    made = await _benchOnly(
      name,
      withAVault: withAVault,
      text: text,
      documentName: documentName,
    );
  });
  final out = _ownDir('$name-pdf')..createSync(recursive: true);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SendSheet(bench: made.bench, ground: made.ground, saveFolder: out.path),
    ),
  ));
  await _settle(tester);
  final onward = find.text('Continue');
  expect(onward, findsOneWidget, reason: 'the sheet did not open on its first page');
  expect(
    tester.widget<ZButton>(find.widgetWithText(ZButton, 'Continue')).onPressed,
    isNotNull,
    reason: 'Continue is dead, so there is no payload and this fixture proves nothing',
  );
  if (toTheDoors) {
    await tester.tap(onward);
    await _settle(tester);
  }
  return (bench: made.bench, ground: made.ground, out: out);
}

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  // ------------------------------------------------------------------ guard 3
  testWidgets('a session open: no question, and the line says whose names these are',
      (tester) async {
    await tester.binding.setSurfaceSize(_wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _atTheDoors(tester, 'open');

    // Through the ground, not the press — the harness, not the product.
    final renamed = await tester.runAsync(
      () => g.ground.beginSession('VAT questions', bench: g.bench.session),
    );
    expect(renamed, isNotNull, reason: 'the birth was refused: ${g.ground.trouble}');
    await tester.runAsync(() => g.bench.refresh());
    await _settle(tester);

    expect(
      find.descendant(
        of: find.byType(SendSheet),
        matching: find.textContaining('VAT questions'),
      ),
      findsOneWidget,
      reason: 'the sheet does not name the session whose names are about to leave',
    );
    // This is the guard that proves the two states are **distinguishable**,
    // which is the whole reason the small line exists. The band's own «this
    // conversation has no session yet» went with the field in 081; what is
    // left is the sheet's one line, and it must not say both things.
    expect(find.textContaining('No session yet'), findsNothing,
        reason: 'the sheet says a session is open and that there is none');
  });

  // ------------------------------------------------------------------ guard 4
  //
  // **081 · what the person pastes after our button is ours.** This guard used
  // to assert `probe.text == 'SENTINEL'` — that the app *wrote* nothing — and
  // it was green through the owner's 12 October leak, because the app did not
  // write the original out: it left it lying there. The clipboard started at a
  // sentinel nobody would ever have on it, so the one state that matters —
  // «the last thing the person copied is still there» — was not in the
  // fixture at all. A guard green for the wrong reason.
  //
  // So the clipboard starts holding the document's **own original text**, which
  // is exactly how it happened: the German letter was copied minutes earlier
  // for the same day's chat-language experiment (080). The subject is no longer
  // what the app wrote; it is what a paste would read.
  //
  // **And the refusal itself is gone** — the owner's first ruling, 13 Oct: a
  // press that needs a session gets one, called «Session N» by the core's own
  // number. 064's «the name is asked once, at the exit» asked a question a
  // person who only wanted their text out never came for, and answered a wrong
  // answer with a small line they did not see. The field stays for anyone who
  // does want to name it; an empty one is no longer a wall.
  //
  // **Driven through the ground, not by a tap** — for the reason at the top of
  // this file: the birth awaits the core, and a widget callback that awaits
  // the core does not resume under `testWidgets`. The old refusal needed no
  // core call, which is why a tap could measure it; a door that no longer
  // refuses cannot be measured that way, and pretending otherwise would be a
  // guard that proves the test harness.
  testWidgets('a nameless exit births «Session N» instead of refusing',
      (tester) async {
    await tester.binding.setSurfaceSize(_wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final probe = _ClipboardProbe(tester)..install();
    probe.text = _letter;
    final g = await _atTheDoors(tester, 'nameless', toTheDoors: false);
    expect(g.ground.aSessionWouldBeBorn, isTrue,
        reason: 'the fixture already has a session, so nothing here is a birth');

    // Read before the act: the birth renames every token on the bench, and the
    // text that leaves must wear the new names and none of these.
    final beforeTheBirth = g.bench.tokens.first.token;

    // **Nothing is typed, because there is nowhere to type it** — 081: the
    // owner had the field deleted. The exit takes no name at all.
    final out = await tester.runAsync(
      () => beginThenRead(g.ground, g.bench),
    );
    await _settle(tester);

    // **A session exists, and the core named it.**
    expect(out!.refused, isNull,
        reason: 'a nameless exit was refused: ${out.refused}');
    final born = g.ground.openSession;
    expect(born, isNotNull,
        reason: 'nothing was born and nothing was refused either: ${g.ground.trouble}');
    expect(g.ground.openSessionRow?.name, 'Session $born',
        reason: 'a session nobody named must carry its own number as its name, so '
            'the sessions list is a list of things and not of blanks');
    expect(out.said, isNotNull, reason: 'the birth said nothing about itself');

    // **And nothing older than the press survived it** — the leak itself, in
    // the only terms it was ever visible in.
    expect(probe.wrote, [''],
        reason: 'the exit must empty the clipboard first, whatever it then decides; '
            'it wrote ${probe.wrote}');

    // **What may leave wears this session's names.**
    expect(out.view, isNotNull, reason: 'the birth happened and nothing may leave');
    expect(out.view!.text, isNot(contains(_theValue)),
        reason: 'the text that may leave carries the value the scan protected');
    expect(out.view!.text, isNot(contains(beforeTheBirth)),
        reason: 'the text that may leave wears a name minted before the session '
            'existed, so the session it claims is not the one that named it');
    expect(out.view!.session?.number, born,
        reason: 'the payload belongs to another session than the one just born');

    expect(find.textContaining('Give it a name first'), findsNothing,
        reason: 'the refusal the owner met is still on the glass');
    expect(find.textContaining('name it on the page before'), findsNothing,
        reason: 'the sheet still points at a field that does not exist');

    // **The control: the press itself still copies.** With the session now
    // open no core call is awaited, so a real tap resumes — and the clipboard
    // is emptied again before it is written.
    await tester.tap(find.text('Continue'));
    await _settle(tester);
    await tester.tap(find.text('Copy Protected'));
    await _settle(tester);
    expect(probe.wrote, ['', '', g.bench.payload!.text],
        reason: 'the press did not empty the clipboard and then copy: ${probe.wrote}');
    expect(probe.text, isNot(contains(_theValue)),
        reason: 'the text a person would now paste carries the value the scan '
            'protected — the original walks out through the door');
  });

  // ----------------------------------------------------------------- guard 4b
  //
  // **The second exit, driven the same way.** One door fixed and one forgotten
  // is the shape 081 is about: the rule belongs to the press, so each press is
  // asked. Save as PDF writes a file rather than the clipboard, and the
  // clipboard must be empty after it all the same — the owner's order is
  // «empty the clipboard, look at the session, then write the file or do not».
  //
  // **And the file's own name is measured here**, because it was found on the
  // way: the saved file was called after the *document* — `Brief_Weber-…` — so
  // a name a person had in a file name left this machine in the clear, in the
  // one direction nobody thinks to look, a folder listing. The session's name
  // is ours to choose; theirs is theirs.
  testWidgets('the PDF door empties the clipboard, births one, and names the file after it',
      (tester) async {
    await tester.binding.setSurfaceSize(_wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final probe = _ClipboardProbe(tester)..install();
    probe.text = _letter;
    final g = await _atTheDoors(
      tester,
      'pdf-nameless',
      toTheDoors: false,
      documentName: 'Brief_Weber.txt',
    );
    expect(g.bench.document?.name, 'Brief_Weber.txt',
        reason: 'the fixture has no document name, so «named after the session» '
            'could not be told from «there was no other name»');

    // The birth through the ground, for the reason guard 4 gives; then the
    // press itself, which from here awaits no core call and resumes.
    final out = await tester.runAsync(
      () => beginThenRead(g.ground, g.bench),
    );
    expect(out!.refused, isNull, reason: 'the nameless exit was refused: ${out.refused}');
    await tester.runAsync(() => g.bench.refresh());
    await _settle(tester);
    await tester.tap(find.text('Continue'));
    await _settle(tester);
    await tester.tap(find.text('Save as PDF'));
    await _settle(tester, rounds: 16);

    final born = g.ground.openSession;
    expect(born, isNotNull,
        reason: 'the PDF door refused for want of a name: ${g.ground.trouble}');
    expect(probe.wrote.every((w) => w == ''), isTrue,
        reason: 'the PDF door writes a file and no clipboard content, so every write '
            'it made must be an emptying: ${probe.wrote}');
    expect(probe.wrote, isNotEmpty, reason: 'nothing emptied the clipboard at all');

    final saved = g.out.listSync().whereType<File>().toList();
    expect(saved, hasLength(1), reason: 'the press did not write one file');
    final named = saved.first.uri.pathSegments.last;
    expect(named, contains('Session $born'),
        reason: '«$named» is not named after the session that owns it');
    expect(named, isNot(contains('Brief_Weber')),
        reason: '«$named» carries the person’s own file name out of the machine, '
            'where a folder listing reads it');
  });

  // ------------------------------------------------------------------ guard 5
  testWidgets('the press copies what the bench holds now, not what the build captured',
      (tester) async {
    await tester.binding.setSurfaceSize(_wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final probe = _ClipboardProbe(tester)..install();
    final g = await _atTheDoors(tester, 'fresh');

    // **A session first, through the ground.** Without one the band stands,
    // and a press with an empty field is refused for want of a name — which is
    // guard 4's property, not this one. Measured, not assumed: the first run of
    // this guard copied nothing, because `document.name` is empty for text that
    // was typed rather than opened, so the pre-filled field was empty.
    final renamed = await tester.runAsync(
      () => g.ground.beginSession('VAT questions', bench: g.bench.session),
    );
    expect(renamed, isNotNull, reason: 'the birth was refused: ${g.ground.trouble}');
    await tester.runAsync(() => g.bench.refresh());
    await _settle(tester);

    final captured = g.bench.payload!.text;
    final beforeToken = g.bench.tokens.first.token;

    // The document changes under the sheet, and **no frame is pumped after
    // it** — so the press lands on the tree that was built before the change
    // and its closure holds the older payload. That is the shape of the fault
    // a birth at the exit walks into: the act changes the bench, and nothing
    // rebuilds between the act and the clipboard.
    await tester.runAsync(() async {
      await z.importText(session: g.bench.session, text: _other);
      await g.bench.rescan();
    });
    final held = g.bench.payload!.text;
    expect(held, isNot(captured), reason: 'the fixture did not change the payload');

    await tester.tap(find.text('Copy Protected'));
    await _settle(tester);

    // **The order, as a sequence and not a count** — empty first, then copy.
    expect(probe.wrote, ['', held],
        reason: 'the press did not empty the clipboard and then copy what the bench '
            'holds now, in that order; it wrote ${probe.wrote}');
    expect(probe.text, held, reason: 'the clipboard carries the captured text, not the bench’s');
    expect(probe.text!.contains(beforeToken), isFalse,
        reason: 'a token from before the change left this machine');
  });

  // ------------------------------------------------------------------ guard 6
  testWidgets('beginThenRead hands back the session’s names, and the core’s number',
      (tester) async {
    late final ({Workbench bench, Ground ground}) g;
    await tester.runAsync(() async => g = await _benchOnly('order'));

    final before = g.bench.payload!;
    final beforeToken = g.bench.tokens.first.token;
    expect(before.session, isNull, reason: 'the fixture already belongs to a session');
    expect(before.text.contains(beforeToken), isTrue, reason: 'the fixture protects nothing');

    final out = await tester.runAsync(
      () => beginThenRead(g.ground, g.bench),
    );
    expect(out, isNotNull, reason: 'runAsync could not run the order at all');
    expect(out!.view, isNotNull, reason: 'nothing may leave: ${out.refused}');

    final view = out.view!;
    // Provenance: the text that would leave says which session it belongs to —
    // and since 081 that session is named by its own number, because the exit
    // has no name to give it and asks for none.
    expect(view.session, isNotNull, reason: 'the text that would leave belongs to no session');
    expect(view.session!.name, nameForSession(view.session!.number),
        reason: 'the session the text belongs to is not named by its own number');
    // And what actually leaves: not one pre-birth name among it. This is the
    // property the core holds from its own end; here it is held of the string
    // the exit would put on the clipboard.
    expect(view.text.contains(beforeToken), isFalse,
        reason: 'the pre-birth name «$beforeToken» is still in the text that would leave');
    expect(view.text, isNot(before.text), reason: 'the text did not change at all');

    // The sentence is the core's number, in the house's one wording — never a
    // count of the screen's own.
    expect(out.renamed, isNotNull);
    expect(out.renamed, g.bench.tokens.length,
        reason: 'the core renamed ${out.renamed} of ${g.bench.tokens.length} tokens');
    expect(out.said, sessionBegunSaid(out.renamed!, hadDocument: true),
        reason: 'the exit writes its own wording instead of the house’s');
  });

  // ------------------------------------------------------------------ guard 6b
  test('a zero gets its own sentence, not «0 names»', () async {
    final g = await _benchOnly('zero', text: _nothingToProtect);
    expect(g.bench.tokens, isEmpty,
        reason: 'the fixture protects something, so this is not the zero case');

    final out = await beginThenRead(g.ground, g.bench);
    expect(out.view, isNotNull, reason: 'nothing may leave: ${out.refused}');
    expect(out.renamed, 0);
    expect(out.said, contains('needed renaming'),
        reason: 'the zero was printed as a number instead of being read aloud');
    expect(out.said, isNot(contains('0 ')), reason: '«0 names» is not a sentence');
  });

  // ------------------------------------------------------------------ guard 7
  //
  // **The question may not cost a door its place on the glass.** The human run
  // of 046/O lost Copy Protected, Paste AI answer and Send from here below the
  // window at 1280×720, and `shell_test`'s journeys were written to walk that
  // size rather than trust `takeException`. The band stands in exactly the
  // state the owner meets on a fresh machine — a vault, no session yet — so it
  // is measured at his smallest plausible window, with the band standing.
  //
  // It found what it was written to find: the band as first drawn pushed
  // «Direct API» 34px under the fold. The three doors' titles are asserted,
  // not the buttons, because a title is the door's own anchor and a scrolled
  // door is a door a person has to look for.
  testWidgets('with no session yet, every door is on the glass at 1280×720',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final g = await _atTheDoors(tester, 'small');
    expect(g.ground.aSessionWouldBeBorn, isTrue,
        reason: 'a session is already open, so this is not the state being measured');

    final view = tester.binding.renderViews.first.size;
    for (final label in ['Manual AI', 'Paste AI answer', 'Direct API']) {
      final it = find.text(label);
      expect(it, findsOneWidget, reason: '«$label» is not in the tree at all');
      final r = tester.getRect(it);
      expect(
        r.top >= -1 && r.bottom <= view.height + 1 && r.height > 8,
        isTrue,
        reason: '«$label» at $r is off a $view window with no session open',
      );
    }
    expect(g.ground.openSession, isNull);
  });

  // ------------------------------------------------------------------ guard 8
  //
  // **A door must still answer while the question stands**, and a rect cannot
  // tell you that it will. Guard 7 holds the doors' places against the view;
  // this one presses, because the fault it was written for is invisible to a
  // rect: `the_keys_live_in_the_settings` went red with «Open Settings» at
  // y 850–893 on a 950-tall window — **inside the window and under the sheet's
  // own scroller**, clipped, with `tester.tap` deriving an offset that «would
  // not hit test on the specified widget». Only a press sees a clip.
  //
  // Reproduced here before it was fixed, so it is this file's finding and not
  // somebody's fixture. One thing it also measured, and reported rather than
  // absorbed: at **1280×720 with nothing connected that door is already under
  // the scroll with nothing of mine on the page** — switched off entirely and
  // the press still missed. That fault predates 064.
  testWidgets('with no session yet, the settings door still answers',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var asked = 0;
    late final ({Workbench bench, Ground ground}) made;
    await tester.runAsync(() async => made = await _benchOnly('door'));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SendSheet(
          bench: made.bench,
          ground: made.ground,
          onSettings: () => asked += 1,
        ),
      ),
    ));
    await _settle(tester);
    await tester.tap(find.text('Continue'));
    await _settle(tester);
    expect(made.ground.aSessionWouldBeBorn, isTrue,
        reason: 'a session is already open, so this is not the state being measured');

    final door = find.widgetWithText(ZButton, 'Open Settings');
    expect(door, findsWidgets, reason: 'no way to reach the one place a key is given');
    await tester.tap(door.first);
    await _settle(tester);
    expect(asked, 1, reason: 'the door is on the glass and did not answer the press');
  });

  // ---------------------------------------------------------- the vault is shut
  testWidgets('no vault: no question is asked, and the text says it has no session',
      (tester) async {
    await tester.binding.setSurfaceSize(_wide);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final probe = _ClipboardProbe(tester)..install();
    final g = await _atTheDoors(tester, 'novault', withAVault: false);

    expect(g.ground.vault, isNot(VaultState.unlocked));
    expect(g.ground.aSessionWouldBeBorn, isFalse,
        reason: 'the shut vault could still make a session, so this measures nothing');
    expect(find.textContaining('made for this document alone'), findsOneWidget,
        reason: 'nothing says these names belong to no session');

    // And the door still works, because protection never needed the vault.
    await tester.tap(find.text('Copy Protected'));
    await _settle(tester);
    expect(probe.wrote, ['', g.bench.payload!.text],
        reason: 'a shut vault stopped a copy that sends nothing, or the emptying that '
            'comes before it: ${probe.wrote}');
    expect(probe.text, g.bench.payload!.text);
  });
}
