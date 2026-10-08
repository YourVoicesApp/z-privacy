// The chat reads like a chat — the writing at the bottom, the answer above it.
//
// **The owner, 8 October:** «الكتابة في أسفل الشاشة والإجابة تظهر في أعلى» —
// the writing at the bottom of the screen, and the answer appears above.
//
// Measured on `22f64e9` before any of this was written: `home.dart` was one
// `ListView`, the `TextField` was its fourth child and `AnswerPanel` its
// eighth. So the person wrote at the **top** and the answer arrived **below**
// the writing — the reverse of every chat they have ever used, and the reverse
// of what the screen is for.
//
// ---
//
// **What each guard stands on**, because a guard that passes without the thing
// it is about is this project's oldest trap, and 046/G's own tests are the
// warning: they are named «the answer appears under the question» and they
// asserted `findsOneWidget`, which is true of any arrangement whatsoever. Every
// assertion in this file is a **rectangle**, read off the render tree after a
// real answer has arrived through the real core:
//
//   a. the composer's box lies **below** the answer's box — two rects.
//   b. the composer is against the **bottom of the window** — its own height
//      against the gap under it, so there is no number to go stale.
//   c. the conversation scrolls and the composer **does not move** — the same
//      two rects before and after a drag, with the conversation's own movement
//      asserted first, because a composer that does not move in a page that
//      does not scroll proves nothing at all.
//   d. the answer is **on the screen** when it arrives, in a window too short
//      to hold the whole page — the rect against the window.
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
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

const _libPath = 'build/linux/x64/debug/bundle/lib/libz_bridge.so';
const _pass = 'ein gutes Passwort für das Gespräch';

/// A question with nothing in it a scanner is unsure of, so the gate is open
/// and these tests measure the arrangement and nothing else.
const _plain = 'Please summarise the rules for quarterly VAT returns.';

/// Long enough that it is a paragraph on the screen rather than a line — a
/// chat's answer takes room, and an arrangement that only works for six words
/// is not the arrangement being asked for.
const _said =
    'Quarterly returns are filed within 30 days of the quarter closing. '
    'The filing is made through the tax authority’s own portal, and the '
    'payment follows the same deadline rather than a later one.';

Future<Ground> _vault(WidgetTester tester, String name) async {
  final ground = Ground();
  await tester.runAsync(() async {
    await z.vaultLock();
    final dir = Directory('${Directory.systemTemp.path}/zprivacy-reads-$name-$pid');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    await z.setDataDir(dir: dir.path);
    await z.vaultCreateWithPassphrase(passphrase: _pass);
    await ground.refresh();
  });
  return ground;
}

/// A conversation that has been asked and answered, through the offline door —
/// the one route that produces a real answer with no provider connected.
Future<Workbench> _answered(WidgetTester tester) async {
  late Workbench chat;
  await tester.runAsync(() async {
    chat = Workbench(session: await z.openSession(packId: 'de'), profileId: null, packId: 'de');
    await z.importText(session: chat.session, text: _plain);
    await chat.rescan();
    chat.rememberCopiedPayload();
    await chat.pasteAnswer(_said);
  });
  return chat;
}

Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 120));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
}

Widget _home(Ground ground, Workbench? chat) => MaterialApp(
  home: HomeScreen(
    ground: ground,
    version: 'z_core 0.1.0',
    chat: chat,
    onImport: () {},
    onType: (_) {},
    onAsk: (_) async {},
    onVault: () {},
    onSettings: () {},
  ),
);

/// The box a person writes in. One `TextField` stands on this screen, and the
/// guards are about **where it is**, so they ask the render tree for its
/// rectangle rather than for its existence.
Rect _composer(WidgetTester tester) => tester.getRect(find.byType(TextField));

Rect _answer(WidgetTester tester) => tester.getRect(find.byType(AnswerPanel));

/// The band the conversation is given — the outermost list on the page.
///
/// Measured as a band and not through the answer's own rectangle, because a
/// sliver lays a child out past the edge it clips it at: the first form of
/// guard a read the answer's rect as ending 25 px **below** the writing box in
/// a `Column`, which no column can do. What `getRect` gives is where a thing
/// was laid out, not what a person can see.
Rect _conversation(WidgetTester tester) => tester.getRect(find.byType(ListView).first);

/// How far the conversation has been scrolled.
///
/// The outermost scroller on this screen, which is the page's own list in both
/// arrangements — read as a **number** rather than as some widget's rectangle,
/// because a widget that scrolls out of a sliver's cache stops being in the
/// tree and a finder then fails for a reason that has nothing to do with the
/// subject. The first attempt at guard c failed exactly that way.
double _scrolled(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;

void main() {
  setUpAll(() async {
    if (!File(_libPath).existsSync()) {
      throw StateError('no $_libPath — run `flutter build linux --debug` first');
    }
    await RustLib.init();
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });

  testWidgets('a — the writing is below the answer, not above it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 760));
    final ground = await _vault(tester, 'below');
    final chat = await _answered(tester);

    await tester.pumpWidget(_home(ground, chat));
    await settle(tester);

    final writing = _composer(tester);
    final thread = _conversation(tester);
    final answer = _answer(tester);

    // The answer is in the conversation, where it scrolls with everything else
    // said. That it is **in** the thread is the half of the claim a rectangle
    // on its own cannot give.
    expect(
      answer.top,
      greaterThanOrEqualTo(thread.top),
      reason: 'the answer begins above the conversation it is supposed to be in',
    );
    expect(
      answer.top,
      lessThan(thread.bottom),
      reason: 'the answer begins below the conversation it is supposed to be in',
    );
    // And nothing of the conversation reaches the writing. One statement about
    // two bands, which is what «answers stacked above it» means.
    expect(
      writing.top,
      greaterThanOrEqualTo(thread.bottom),
      reason:
          'the writing is at y=${writing.top.toStringAsFixed(0)} and the conversation runs to '
          'y=${thread.bottom.toStringAsFixed(0)} — the person writes inside the thread, above '
          'what was said, which is the reverse of every chat they know',
    );

    chat.dispose();
  });

  testWidgets('b — the writing is against the bottom of the window', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 760));
    final ground = await _vault(tester, 'bottom');
    final chat = await _answered(tester);

    await tester.pumpWidget(_home(ground, chat));
    await settle(tester);

    final writing = _composer(tester);

    expect(
      writing.center.dy,
      greaterThan(760 / 2),
      reason:
          'the box a person types in is centred at y=${writing.center.dy.toStringAsFixed(0)} '
          'of 760 — it is in the upper half of the window',
    );

    // The last line the page draws. It belongs to the writing — a chat keeps
    // the line about itself under the box, not under the thread — so it is
    // also the bottom edge of the pinned band, and the composer's own
    // buttons stand between the two.
    final lastLine = find.textContaining('Nothing is uploaded');
    // **On the screen at all**, and said in this file's own words rather than
    // left to a finder's error. In the arrangement this file was written
    // against, this line was the ninth child of one long scroller and was
    // never built: past the end of a scroll nobody moved.
    expect(
      lastLine,
      findsOneWidget,
      reason:
          'the page\'s last line is not on the screen — it lies past the end of a scroller '
          'nobody moved, so nothing on this page is pinned to the window',
    );
    final last = tester.getRect(lastLine);
    expect(
      last.bottom,
      lessThanOrEqualTo(760.0),
      reason:
          'the page\'s last line ends at y=${last.bottom.toStringAsFixed(0)} in a 760 px window — '
          'it is not on the screen, so nothing here is pinned to anything',
    );
    // No fixed number: the composer's own height is the measure. Whatever
    // padding stands under the band, it is less than the box itself — and at
    // the top of a page it could not be.
    final below = 760 - last.bottom;
    expect(
      below,
      lessThan(writing.height),
      reason:
          'there is ${below.toStringAsFixed(0)} px under the page\'s last line and the box is '
          'only ${writing.height.toStringAsFixed(0)} px tall — the band is not against the '
          'bottom of the window',
    );

    chat.dispose();
  });

  testWidgets('c — the conversation scrolls and the writing stays where it is', (tester) async {
    // Short enough that the conversation is taller than the room it has, so
    // there is something to scroll. A test that drags a page which cannot move
    // measures nothing.
    await tester.binding.setSurfaceSize(const Size(1000, 600));
    final ground = await _vault(tester, 'scroll');
    final chat = await _answered(tester);

    await tester.pumpWidget(_home(ground, chat));
    await settle(tester);

    // **Setup, not claim.** Once the answer is kept in view the conversation
    // opens at its end, where a drag upward has nowhere left to go. So this
    // takes it to the top first and measures from there — in the arrangement
    // this file was written against it is already at the top and this does
    // nothing at all.
    await tester.dragFrom(const Offset(80, 150), const Offset(0, 600));
    await settle(tester);

    final writingBefore = _composer(tester);
    final scrolledBefore = _scrolled(tester);

    // A point high on the page and clear of the writing box in both
    // arrangements: inside the 940-wide column, below any fixed strip, above
    // where the composer can stand once it is at the bottom.
    await tester.dragFrom(const Offset(80, 150), const Offset(0, -140));
    await settle(tester);

    // **The control, first.** A composer that does not move in a page that did
    // not scroll proves nothing, and that is the cheapest way for this guard to
    // go green while meaning nothing.
    final scrolledAfter = _scrolled(tester);
    expect(
      scrolledAfter,
      greaterThan(scrolledBefore + 100),
      reason:
          'the conversation did not scroll under the drag — it moved from '
          '${scrolledBefore.toStringAsFixed(0)} to ${scrolledAfter.toStringAsFixed(0)}, so this '
          'test proves nothing either way',
    );

    final writingAfter = _composer(tester);
    expect(
      writingAfter,
      writingBefore,
      reason:
          'the writing moved with the conversation — from y=${writingBefore.top.toStringAsFixed(0)} '
          'to y=${writingAfter.top.toStringAsFixed(0)}. A chat\'s composer is not part of the thread',
    );

    chat.dispose();
  });

  testWidgets('d — the answer is on the screen the moment it arrives', (tester) async {
    // A window too short to hold the page. This is the one that matters: an
    // answer at the end of a scroll nobody moved is an answer the person never
    // sees, and «the answer appears above» would be true of the layout and
    // false of the screen.
    await tester.binding.setSurfaceSize(const Size(900, 520));
    final ground = await _vault(tester, 'onscreen');
    final chat = await _answered(tester);

    await tester.pumpWidget(_home(ground, chat));
    await settle(tester);

    expect(
      find.byType(AnswerPanel),
      findsOneWidget,
      reason: 'the answer was never built — it is below the fold of a scroll nobody moved',
    );
    final answer = _answer(tester);
    expect(
      answer.top,
      greaterThanOrEqualTo(0.0),
      reason: 'the answer begins at y=${answer.top.toStringAsFixed(0)}, above the top of the window',
    );
    expect(
      answer.top,
      lessThan(520.0),
      reason: 'the answer begins at y=${answer.top.toStringAsFixed(0)} in a 520 px window — off the screen',
    );

    chat.dispose();
  });
}
