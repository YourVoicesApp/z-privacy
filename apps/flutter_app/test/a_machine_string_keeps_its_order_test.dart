// 116 · **A string the machine owns keeps its order inside an Arabic
// sentence** — the third part of the paper's first item.
//
// Mirroring puts the controls on the other side of the glass. It does nothing
// about what happens *inside* a line, and that is where this round's remaining
// defect was: Arabic runs right to left, a path or a token runs left to right,
// and the bidirectional algorithm decides where the pieces between them go. It
// decides correctly by its own rules — and those rules are not what anybody
// wants when the left-to-right run is one indivisible thing of ours.
//
// ## What was measured on this tree, before anything was changed
//
// Two sentences came out in a spelling nobody wrote:
//
//   * «حُفظ في /home/…/brief-restored.pdf» drew as
//     `home/…/brief-restored.pdf/`. The leading `/` is a neutral sitting
//     between Arabic and Latin, so it took the **paragraph's** direction and
//     went to the far end of the path. That is `a_path_is_compared_in_one_
//     spelling` arriving through the layout rather than through a comparison;
//   * the sentence for a save dialog that could not be opened carries the
//     system's own words, and those end in a quote — `…path = '/home/x.pdf'`
//     drew with that closing quote at the **front** of the line.
//
// And two came out right: a token — one, two or three of them — and a reason
// the core phrased in English. A token reads correctly with no help at all,
// and is drawn in **three** runs while doing it: the leading `__` and the
// trailing `__` are neutrals that belong to the Arabic around them, and the
// two displacements cancel. `__Z_…__` survives by being symmetric, which is a
// property of the token's shape and not a law, so the token sentences are
// isolated here too — and the symmetry is held below, so the day a token's
// shape changes this file says so instead of the glass.
//
// The same symmetry is why the **document** needs nothing: guard 6 measures
// that the two tokens of one name land on the glass spelled exactly as the
// core wrote them, which is the half of «protection may not change how a
// document reads» this round could have broken and did not.
//
// ## This file and the gate are two halves
//
// Here: **the physics** — that the two code points really do what is claimed,
// on this engine, in this layout, with the bare form measured beside the fixed
// one so the guard cannot be green about a thing that was never broken.
//
// In `gates.sh` (G72): **the sites** — that every sentence of ours carrying a
// path, a token or the core's own English goes through `theMachinesOwnWord`.
// One of those is drawn by a widget this file cannot reach without a vault and
// a written file, which is the half a gate reads better.
@Timeout(Duration(minutes: 3))
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/messages.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';

/// A path of the shape this product shows a person after a save.
const _path = '/home/monopeaks/Documents/brief-restored.pdf';

/// What a save dialog that will not open says on this platform — the system's
/// own words, quotes and all, which is what reaches `couldNotAskWhereToSaveIt`.
const _systemSaid =
    "FileSystemException: cannot open, path = '/home/monopeaks/x.pdf'";

const _token = '__Z_092C_IBAN_57E8ECC2__';

/// Three tokens for one name, which is the ordinary shape since 085 ruling 1:
/// a name the app read for itself is one token per word.
const _threeTokens =
    '__Z_A1B2_PERSON_C3D4__ __Z_E5F6_PERSON_G7H8__ __Z_I9J0_PERSON_K1L2__';

/// **[part] in the order a person's eye meets it**, left edge first.
///
/// Every character is asked for its own box and the lot is sorted by where it
/// was painted. For a run that came out whole this is [part] back again; for
/// one the algorithm took apart it is the spelling actually on the glass,
/// which is the thing worth putting in a failure message.
String _asDrawn(WidgetTester tester, String whole, String part) {
  final paragraph = tester.renderObject<RenderParagraph>(find.byType(RichText).first);
  final at = whole.indexOf(part);
  expect(at, isNot(-1),
      reason: 'the fixture does not contain the string it claims to measure: «$part»');
  final drawn = <(double, String)>[];
  for (var i = 0; i < part.length; i++) {
    final box = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: at + i, extentOffset: at + i + 1));
    if (box.isEmpty) continue;
    drawn.add((box.first.left, part[i]));
  }
  drawn.sort((a, b) => a.$1.compareTo(b.$1));
  return drawn.map((c) => c.$2).join();
}

/// Where [part] was painted, as one box. The caller has already said, or is
/// about to measure, that it came out in one piece.
TextBox _boxOf(WidgetTester tester, String whole, String part) {
  final paragraph = tester.renderObject<RenderParagraph>(find.byType(RichText).first);
  final at = whole.indexOf(part);
  expect(at, isNot(-1), reason: 'the fixture does not hold «$part»');
  final boxes = paragraph
      .getBoxesForSelection(TextSelection(baseOffset: at, extentOffset: at + part.length));
  expect(boxes, isNotEmpty, reason: '«$part» was not painted at all');
  return boxes.first;
}

/// How many bidirectional runs [part] was broken into. One is whole.
int _runsOf(WidgetTester tester, String whole, String part) {
  final paragraph = tester.renderObject<RenderParagraph>(find.byType(RichText).first);
  final at = whole.indexOf(part);
  return paragraph
      .getBoxesForSelection(TextSelection(baseOffset: at, extentOffset: at + part.length))
      .length;
}

/// The sentence on the glass, in a paragraph that runs the way the interface
/// runs. **One line and no wrapping**: a wrapped line is reported as a second
/// box, which would read exactly like a torn run and is not one.
Future<void> _drawn(WidgetTester tester, String line,
    {TextDirection reading = TextDirection.rtl}) async {
  await tester.pumpWidget(Directionality(
    textDirection: reading,
    child: Align(
      alignment: Alignment.topLeft,
      child: Text(line, softWrap: false, maxLines: 1),
    ),
  ));
}

void main() {
  setUp(() async {
    theSentencesAreNow(const Locale('ar'));
  });
  tearDown(() => theSentencesAreNow(const Locale('en')));

  // ------------------------------------------------------------------ guard 1
  //
  // The path, both ways round, and the bare half first: if the day comes when
  // the engine lays a bare path out in one piece, this line reds and the whole
  // of `theMachinesOwnWord` can be looked at again.
  testWidgets('a path is drawn in the spelling it was written in', (tester) async {
    await tester.binding.setSurfaceSize(const Size(3000, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bare = sentences.savedToWhere(_path);
    await _drawn(tester, bare);
    expect(_asDrawn(tester, bare, _path), 'home/monopeaks/Documents/brief-restored.pdf/',
        reason: 'the fault this round fixed is not there to fix any more — a bare '
            'path no longer loses its leading slash to the end of the line');
    expect(_runsOf(tester, bare, _path), 2, reason: 'and it is no longer torn in two');

    final ours = sentences.savedToWhere(theMachinesOwnWord(_path));
    await _drawn(tester, ours);
    expect(_asDrawn(tester, ours, _path), _path,
        reason: 'the path is still drawn in a spelling no folder window prints');
    expect(_runsOf(tester, ours, _path), 1,
        reason: 'the path is drawn in pieces with the isolate on');
  });

  // ------------------------------------------------------------------ guard 2
  //
  // The system's own words, which end in a quote — the second thing measured
  // wrong, and the one that shows the fault is not about slashes: it is about
  // whatever neutral happens to sit at the edge of a Latin run.
  testWidgets('the system’s own words keep their punctuation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(3000, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bare = sentences.couldNotAskWhereToSaveIt(_systemSaid);
    await _drawn(tester, bare);
    expect(_asDrawn(tester, bare, _systemSaid).startsWith("'"), isTrue,
        reason: 'the closing quote no longer jumps to the front of the line, so this '
            'fixture is measuring nothing');

    final ours = sentences.couldNotAskWhereToSaveIt(theMachinesOwnWord(_systemSaid));
    await _drawn(tester, ours);
    expect(_asDrawn(tester, ours, _systemSaid), _systemSaid,
        reason: 'the system said one thing and the glass drew another');
  });

  // ------------------------------------------------------------------ guard 3
  //
  // **The luck, pinned.** A token reads correctly with no isolate because
  // `__Z_…__` has the same neutrals at both ends and the two displacements
  // cancel — and it is drawn in three runs while it does so. Both halves are
  // written down: the first is what a later reader would call «so why did you
  // change it», and the second is the answer.
  testWidgets('a bare token reads right, in three runs, by its own symmetry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(3000, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final part in [_token, _threeTokens]) {
      final bare = sentences.protectedAs(part);
      await _drawn(tester, bare);
      expect(_asDrawn(tester, bare, part), part,
          reason: 'a bare token no longer reads in order — the luck this guard '
              'records has run out, and that is a finding, not a failure');
      expect(_runsOf(tester, bare, part), 3,
          reason: 'the ends of a bare token no longer belong to the Arabic around '
              'it, so the reason for isolating it has changed');
    }
  });

  // ------------------------------------------------------------------ guard 4
  //
  // **The product's own function, not a sentence written here.** `protectSaid`
  // is the one place every press words its outcome (G33), so these are the
  // real strings a person is shown after protecting a word.
  testWidgets('the sentence a press writes draws its token in one piece', (tester) async {
    await tester.binding.setSurfaceSize(const Size(3000, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final (act, outcome) in [
      (ProtectAct.aSelection, const ProtectOutcome.applied(token: _token, places: 1)),
      (ProtectAct.aSelection, const ProtectOutcome.applied(token: _token, places: 3)),
      (ProtectAct.aCell, const ProtectOutcome.applied(token: _token, places: 1)),
      (ProtectAct.aCell, const ProtectOutcome.applied(token: _token, places: 4)),
      (
        ProtectAct.aSelection,
        const ProtectOutcome.alreadyProtected(
            token: _token, source: Source.vault, sourceDetail: 'Z Vault')
      ),
      (
        ProtectAct.aSelection,
        const ProtectOutcome.belongsToEntity(entity: 'ماركوس فيبر', token: _token)
      ),
    ]) {
      final said = protectSaid(outcome, act);
      expect(said.contains(_token), isTrue,
          reason: 'the sentence for $outcome does not carry its token at all: «$said»');
      await _drawn(tester, said);
      expect(_runsOf(tester, said, _token), 1,
          reason: 'the token is drawn in pieces in «$said»');
      expect(_asDrawn(tester, said, _token), _token,
          reason: 'the token on the glass is not the token in the sentence: «$said»');
    }
  });

  // ------------------------------------------------------------------ guard 5
  //
  // A reason the **core** phrased: English this list does not translate and
  // could not, because it names a folder, a permission, a state of the disk.
  // Through `humanMessage`, the one function that turns a typed error into
  // language. It read correctly bare, and is held here so that it keeps doing
  // so now that it goes through the isolate.
  testWidgets('a reason the core phrased is drawn in one piece', (tester) async {
    await tester.binding.setSurfaceSize(const Size(3000, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const reason = 'the vault: the data directory is a symlink';
    for (final said in [
      humanMessage(const ApiError.storageRefused(reason: reason)),
      humanMessage(const ApiError.storagePermissionsKept(reason: reason)),
    ]) {
      // The sentence lower-cases what it is handed, so the fixture is matched
      // in the spelling the screen draws.
      final drawn = reason.toLowerCase();
      expect(said.contains(drawn), isTrue,
          reason: 'the sentence does not carry the core’s reason: «$said»');
      await _drawn(tester, said);
      expect(_runsOf(tester, said, drawn), 1,
          reason: 'the reason is torn across the sentence: «$said»');
      expect(_asDrawn(tester, said, drawn), drawn,
          reason: 'the reason is drawn in another order: «$said»');
    }
  });

  // ------------------------------------------------------------------ guard 6
  //
  // **The document, which is not ours to isolate — and does not need to be.**
  //
  // «حضرة السيد ماركوس فيبر» protects into «حضرة السيد» and two tokens, one
  // per word (085 ruling 1), and the first look at 116's own pictures said
  // the two had changed places: the body of the token standing for «ماركوس»
  // really is painted to the **left** of the body of the one for «فيبر».
  //
  // The boxes say what is happening, and it is the token's symmetry again.
  // Each `__Z_…__` is three runs, the outer pairs of underscores belong to
  // the Arabic, and they swap to the **outside of the whole pair**. The
  // glyphs that land on the glass, read left to right, are the two tokens
  // spelled exactly as the core wrote them — so «protection may not change
  // how a document reads» holds, and nothing here may be «fixed».
  //
  // It matters that this is written down rather than left as a thing nobody
  // looked at: inserting the isolate here is the obvious next move and it
  // would be **wrong** twice over — it would move every offset a selection, a
  // copy and an exit are measured in, and it would put two code points into
  // the one text this product may not touch.
  testWidgets('two tokens for one name are drawn as the core wrote them', (tester) async {
    await tester.binding.setSurfaceSize(const Size(3000, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // The person's own line first, so the fixture is known to be right to
    // left before anything is claimed about what protection did to it.
    const asWritten = 'حضرة السيد ماركوس فيبر،';
    await _drawn(tester, asWritten);
    expect(_boxOf(tester, asWritten, 'ماركوس').left,
        greaterThan(_boxOf(tester, asWritten, 'فيبر').left),
        reason: 'the Arabic words are not laid out right to left, so this fixture '
            'cannot say anything about what protection does to them');

    const one = '__Z_A1B2_PERSON_C3D4__';
    const two = '__Z_E5F6_PERSON_G7H8__';
    const pair = '$one $two';
    for (final line in [
      'حضرة السيد $pair،',
      'حضرة السيد $pair',
      'وتفضلوا بقبول $pair الاحترام',
    ]) {
      await _drawn(tester, line);
      expect(_asDrawn(tester, line, pair), pair,
          reason: 'the tokens on the glass are not the tokens in the document: «$line»');
    }
  });

  // ------------------------------------------------------------------ guard 7
  //
  // **The boring direction**, pinned so the fix is known to cost nothing where
  // nothing was wrong: in German the same sentence is one run and the same
  // spelling, with the isolate and without it.
  testWidgets('German is one run either way', (tester) async {
    await tester.binding.setSurfaceSize(const Size(3000, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    theSentencesAreNow(const Locale('de'));

    for (final line in [
      sentences.savedToWhere(_path),
      sentences.savedToWhere(theMachinesOwnWord(_path)),
    ]) {
      await _drawn(tester, line, reading: TextDirection.ltr);
      expect(_runsOf(tester, line, _path), 1,
          reason: 'a left-to-right sentence tore its own path: «$line»');
      expect(_asDrawn(tester, line, _path), _path,
          reason: 'a left-to-right sentence drew the path in another order: «$line»');
    }
  });
}
