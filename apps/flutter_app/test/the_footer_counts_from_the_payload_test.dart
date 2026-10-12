// 068, the Dart half — the PDF footer's per-kind tally comes from the payload.
//
// **The core's half has been standing since an earlier round**, and its own
// documentation names the defect this half existed to keep alive: the tally
// was computed on this side by walking the bench's *current* tokens and
// keeping those whose string could be found in the outgoing text. Two sources.
// A payload captured **before a session was born** carries tokens the bench no
// longer holds, so the search matched nothing and the footer stated **no kinds
// at all over a fully protected document** — a file with every name hidden,
// described as hiding none.
//
// That is the case this file reproduces, and it is the first test: the bench
// holds nothing, the payload holds its tally, and the footer must state the
// payload's.
//
// **No vault, no file, no native library.** The rule is a named function and
// the mirrors are plain Dart classes, so this measures the arithmetic that was
// wrong without needing anything built — which is also why it can be the first
// thing run after a toolchain outage.
@Timeout(Duration(minutes: 1))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/send_sheet.dart';

/// The naming door, as the core would have taught it. The product passes
/// `Ground.nameOfKind`; `Ground.kinds` is a getter over core state, so a test
/// that insisted on a whole `Ground` would need a vault to measure
/// arithmetic.
String Function(Kind) _namer([Map<Kind, String>? names]) =>
    (k) => (names ?? const {
          Kind.person: 'Person',
          Kind.iban: 'Account number',
        })[k] ??
        '…';

PayloadView _payload(List<KindTally> byKind, {String text = '__Z_1_PERSON_A__'}) =>
    PayloadView(
      text: text,
      protectedCount: 3,
      openSuggestions: 0,
      pageEdges: const [],
      byKind: byKind,
      session: null,
    );

void main() {
  test('the tally is the payload’s, even when the bench holds nothing', () {
    // The exact shape of the defect: a payload captured before a session was
    // born. Nothing on the bench to search, and a fully protected document.
    final tally = footerTally(
      _payload(const [
        KindTally(kind: Kind.person, count: 2),
        KindTally(kind: Kind.iban, count: 1),
      ]),
      _namer(),
    );
    expect(
      tally,
      {'Person': 2, 'Account number': 1},
      reason: 'the footer states $tally for a payload that carries two persons '
          'and an account number — it is counting something other than the '
          'payload, which is how it once stated nothing at all about a fully '
          'protected file',
    );
  });

  test('the control: an empty payload tally stays empty', () {
    // Without this, «the tally equals the payload's» is also what a function
    // that returns its input untouched would satisfy — and so would one that
    // always answered with two persons and an account number.
    expect(
      footerTally(_payload(const []), _namer()),
      isEmpty,
      reason: 'a payload that carries no tally produced one, so the figure is '
          'coming from somewhere that is not the payload',
    );
  });

  test('a name is the core’s or it is not a name', () {
    // `nameOfKind` says «…» before the kind list has loaded rather than
    // inventing a word. The footer inherits that honesty rather than printing
    // an enum.
    final tally = footerTally(
      _payload(const [KindTally(kind: Kind.person, count: 1)]),
      // A door that has not been taught yet — `Ground.nameOfKind` answers
      // «…» until the core says what a kind is called.
      _namer(const {}),
    );
    expect(
      tally.keys.single,
      '…',
      reason: 'the footer named a kind «${tally.keys.single}» before the core '
          'had said what that kind is called',
    );
  });

  test('two kinds sharing one label are summed, not dropped', () {
    final sharesALabel = _namer(const {
      Kind.person: 'Name',
      Kind.company: 'Name',
    });
    expect(
      footerTally(
        _payload(const [
          KindTally(kind: Kind.person, count: 2),
          KindTally(kind: Kind.company, count: 3),
        ]),
        sharesALabel,
      ),
      {'Name': 5},
      reason: 'one of the two kinds vanished from the footer because they '
          'share a label, and a dropped count is a wrong count',
    );
  });
}
