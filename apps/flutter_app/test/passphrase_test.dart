// P1-3 — passphrase entry a person can see and check.
//
// His conditions of 29 September, each its own expectation. The comparison
// happens in Dart because these two fields are **input that has not been
// sent** — presentation state, not a stored security fact — and Rust still
// owns the decision when the call is made.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/vault_forms.dart';

/// The only way to ask «is this field hiding its text?» without reading the
/// text out of it.
bool _hidden(WidgetTester tester, int at) =>
    tester.widgetList<TextField>(find.byType(TextField)).elementAt(at).obscureText;

Future<void> _form(WidgetTester tester, Ground ground) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: VaultKeyForm(ground: ground, creating: true, onDone: () {}),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  setUpAll(() async => RustLib.init());

  testWidgets('both fields start hidden, and each shows on its own', (tester) async {
    final ground = Ground();
    await _form(tester, ground);

    // `Eyebrow` renders its label uppercase, so the field is identified by
    // the control that belongs to it rather than by the drawn text.
    expect(find.byTooltip('Show Passphrase'), findsOneWidget);
    expect(find.byTooltip('Show Confirm passphrase'), findsOneWidget);
    expect(_hidden(tester, 0), isTrue, reason: 'the passphrase starts visible');
    expect(_hidden(tester, 1), isTrue, reason: 'the confirmation starts visible');

    await tester.enterText(find.byType(TextField).at(0), 'a good long passphrase');
    await tester.enterText(find.byType(TextField).at(1), 'a good long passphrase');
    await tester.pump();

    // Show the first only.
    await tester.tap(find.byTooltip('Show Passphrase'));
    await tester.pump();
    expect(_hidden(tester, 0), isFalse);
    expect(_hidden(tester, 1), isTrue, reason: 'showing one showed the other');

    // Then the second as well.
    await tester.tap(find.byTooltip('Show Confirm passphrase'));
    await tester.pump();
    expect(_hidden(tester, 0), isFalse);
    expect(_hidden(tester, 1), isFalse);

    // And back — the values are untouched by looking.
    await tester.tap(find.byTooltip('Hide Passphrase'));
    await tester.tap(find.byTooltip('Hide Confirm passphrase'));
    await tester.pump();
    expect(_hidden(tester, 0), isTrue);
    expect(_hidden(tester, 1), isTrue);
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    for (final f in fields) {
      expect(f.controller!.text, 'a good long passphrase',
          reason: 'toggling visibility changed the value');
    }
  });

  testWidgets('the match state is shown, and the action waits for it', (tester) async {
    final ground = Ground();
    await _form(tester, ground);

    ZButton button() => tester.widget<ZButton>(
          find.ancestor(of: find.text('Create the vault'), matching: find.byType(ZButton)),
        );

    // empty + empty → nothing said, nothing enabled
    expect(find.byKey(const Key('passphrase-match')), findsNothing);
    expect(button().onPressed, isNull, reason: 'an empty pair can be submitted');

    // "abc" + "abd" → do not match, still disabled
    await tester.enterText(find.byType(TextField).at(0), 'abc');
    await tester.enterText(find.byType(TextField).at(1), 'abd');
    await tester.pump();
    expect(find.text('Passphrases do not match'), findsOneWidget);
    expect(button().onPressed, isNull, reason: 'a mismatched pair can be submitted');

    // "abc" + "abc" → match, enabled. Short on purpose: the length rule is the
    // core's, and this button is not claiming the passphrase is any good.
    await tester.enterText(find.byType(TextField).at(1), 'abc');
    await tester.pump();
    expect(find.text('Passphrases match'), findsOneWidget);
    expect(button().onPressed, isNotNull);
  });

  testWidgets('pasting into the confirmation moves the match line at once', (tester) async {
    final ground = Ground();
    await _form(tester, ground);
    await tester.enterText(find.byType(TextField).at(0), 'a good long passphrase');
    await tester.pump();

    // `enterText` replaces the whole value in one go — a paste, not typing.
    await tester.enterText(find.byType(TextField).at(1), 'a good long passphrase');
    await tester.pump();
    expect(find.text('Passphrases match'), findsOneWidget,
        reason: 'the match line only follows keystrokes');
  });

  testWidgets('the passphrase is never a semantics value', (tester) async {
    final ground = Ground();
    final handle = tester.ensureSemantics();
    await _form(tester, ground);
    await tester.enterText(find.byType(TextField).at(0), 'a good long passphrase');
    await tester.pump();

    // Even while shown, the text must not become an accessibility value —
    // that is a way out of the app we do not want to open.
    await tester.tap(find.byTooltip('Show Passphrase'));
    await tester.pump();
    expect(
      find.bySemanticsLabel('a good long passphrase'),
      findsNothing,
      reason: 'the passphrase is announced as a semantics label',
    );
    handle.dispose();
  });
}
