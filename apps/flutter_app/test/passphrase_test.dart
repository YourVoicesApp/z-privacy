// P1-3 — passphrase entry a person can see and check.
//
// His conditions of 29 September, each its own expectation. The comparison
// happens in Dart because these two fields are **input that has not been
// sent** — presentation state, not a stored security fact — and Rust still
// owns the decision when the call is made.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/session_state.dart';
import 'dart:io';

import 'package:zprivacy/src/rust/frb_generated.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/vault_forms.dart';
import 'the_folder_lets_go.dart';

/// The only way to ask «is this field hiding its text?» without reading the
/// text out of it.
bool _hidden(WidgetTester tester, int at) =>
    tester.widgetList<TextField>(find.byType(TextField)).elementAt(at).obscureText;

Future<void> _form(WidgetTester tester, Ground ground, {bool changing = false}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: VaultKeyForm(
          ground: ground,
          creating: !changing,
          changing: changing,
          onDone: () {},
        ),
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
          find.ancestor(of: find.text(sentences.createTheVault), matching: find.byType(ZButton)),
        );

    // empty + empty → nothing said, nothing enabled
    expect(find.byKey(const Key('passphrase-match')), findsNothing);
    expect(button().onPressed, isNull, reason: 'an empty pair can be submitted');

    // "abc" + "abd" → do not match, still disabled
    await tester.enterText(find.byType(TextField).at(0), 'abc');
    await tester.enterText(find.byType(TextField).at(1), 'abd');
    await tester.pump();
    expect(find.text(sentences.passphrasesDoNotMatch), findsOneWidget);
    expect(button().onPressed, isNull, reason: 'a mismatched pair can be submitted');

    // "abc" + "abc" → they match, and the button is **still** shut, because
    // eight characters is a condition the core will refuse on.
    //
    // **This block used to end here with the button enabled**, and the comment
    // said «short on purpose: the length rule is the core's, and this button is
    // not claiming the passphrase is any good». The independent attacker's note
    // 5 is what that costs a person: the press is offered, the core refuses it,
    // and the only way to learn the rule is to break it. A gate that does not
    // hand you the key is a wall (046/L) — so the condition is said before the
    // press, not after.
    await tester.enterText(find.byType(TextField).at(1), 'abc');
    await tester.pump();
    expect(find.text(sentences.passphrasesMatch), findsOneWidget);
    expect(
      find.byKey(const Key('passphrase-length')),
      findsOneWidget,
      reason: 'the form does not say the one condition that will refuse this press',
    );
    expect(
      button().onPressed,
      isNull,
      reason: 'a passphrase the core will refuse for its length can be submitted',
    );

    // Eight, and the door opens.
    await tester.enterText(find.byType(TextField).at(0), 'achtzehn');
    await tester.enterText(find.byType(TextField).at(1), 'achtzehn');
    await tester.pump();
    expect(find.byKey(const Key('passphrase-length')), findsNothing,
        reason: 'the condition is still said about a passphrase that meets it');
    expect(button().onPressed, isNotNull);
  });

  testWidgets('the number this form promises is the number the core applies', (tester) async {
    // **A second copy of a rule is measured, never trusted.** The form says
    // «at least N characters» before the press, and N is written in Dart —
    // which the comment in `_go` rightly called a second opinion that will
    // drift. This is the answer to that: the real core is asked which
    // passphrases it takes, on both sides of the number the form promises. The
    // day the core's minimum moves, this reds and names it.
    final dir = Directory.systemTemp.createTempSync('zprivacy-least-');
    addTearDown(() => removeWhenItLetsGo(dir));
    final ground = Ground();
    await tester.runAsync(() async {
      await z.vaultLock();
      await z.setDataDir(dir: dir.path);
      await ground.refresh();
    });

    final oneFewer = 'a' * (VaultKeyForm.leastCharacters - 1);
    final exactly = 'a' * VaultKeyForm.leastCharacters;
    Object? refused;
    await tester.runAsync(() async {
      try {
        await z.vaultCreateWithPassphrase(passphrase: oneFewer);
      } catch (e) {
        refused = e;
      }
    });
    expect(
      refused,
      isNotNull,
      reason: 'the core took ${oneFewer.runes.length} characters, so the form promises more than the core asks',
    );
    expect(File('${dir.path}/vault.zv').existsSync(), isFalse,
        reason: 'a refused passphrase wrote a vault anyway');

    await tester.runAsync(() => z.vaultCreateWithPassphrase(passphrase: exactly));
    expect(File('${dir.path}/vault.zv').existsSync(), isTrue,
        reason: 'the core refused exactly ${exactly.runes.length} characters, so the form promises less than the core asks');
    await tester.runAsync(() => z.vaultLock());
  });

  testWidgets('eight is counted the way the core counts it, not in UTF-16 units', (tester) async {
    // **`runes`, not `length`.** Rust counts `passphrase.chars().count()`;
    // Dart's `String.length` is UTF-16 code units, so seven emoji are
    // fourteen there and seven in the core. A button that read `length` would
    // open on a passphrase the core refuses — the same defect as note 5, one
    // case further along, and invisible to anybody typing Latin letters.
    final ground = Ground();
    await _form(tester, ground);

    ZButton button() => tester.widget<ZButton>(
          find.ancestor(of: find.text(sentences.createTheVault), matching: find.byType(ZButton)),
        );

    const seven = '🜚🜚🜚🜚🜚🜚🜚';
    expect(seven.length, 14, reason: 'the fixture is not made of surrogate pairs');
    expect(seven.runes.length, 7);
    await tester.enterText(find.byType(TextField).at(0), seven);
    await tester.enterText(find.byType(TextField).at(1), seven);
    await tester.pump();
    expect(button().onPressed, isNull,
        reason: 'seven characters opened the door because they were counted as fourteen');

    const eight = '🜚🜚🜚🜚🜚🜚🜚🜚';
    await tester.enterText(find.byType(TextField).at(0), eight);
    await tester.enterText(find.byType(TextField).at(1), eight);
    await tester.pump();
    expect(button().onPressed, isNotNull, reason: 'eight characters were refused');
  });

  testWidgets('pasting into the confirmation moves the match line at once', (tester) async {
    final ground = Ground();
    await _form(tester, ground);
    await tester.enterText(find.byType(TextField).at(0), 'a good long passphrase');
    await tester.pump();

    // `enterText` replaces the whole value in one go — a paste, not typing.
    await tester.enterText(find.byType(TextField).at(1), 'a good long passphrase');
    await tester.pump();
    expect(find.text(sentences.passphrasesMatch), findsOneWidget,
        reason: 'the match line only follows keystrokes');
  });

  /// Changing is the **more** dangerous place to type blind: the vault
  /// already holds work, and the screen's own warning says there is no way
  /// back. It used to ask for the new passphrase exactly once.
  testWidgets('changing confirms the new passphrase too', (tester) async {
    final ground = Ground();
    await _form(tester, ground, changing: true);

    expect(find.byTooltip('Show Current passphrase'), findsOneWidget);
    expect(find.byTooltip('Show New passphrase'), findsOneWidget);
    expect(find.byTooltip('Show Confirm new passphrase'), findsOneWidget);

    ZButton button() => tester.widget<ZButton>(
          find.ancestor(of: find.text(sentences.changeIt), matching: find.byType(ZButton)),
        );

    await tester.enterText(find.byType(TextField).at(0), 'the old one');
    await tester.enterText(find.byType(TextField).at(1), 'the new one');
    await tester.pump();
    expect(button().onPressed, isNull, reason: 'a new passphrase can be set unconfirmed');

    await tester.enterText(find.byType(TextField).at(2), 'the new ONE');
    await tester.pump();
    expect(find.text(sentences.passphrasesDoNotMatch), findsOneWidget);
    expect(button().onPressed, isNull);

    await tester.enterText(find.byType(TextField).at(2), 'the new one');
    await tester.pump();
    expect(find.text(sentences.passphrasesMatch), findsOneWidget);
    expect(button().onPressed, isNotNull);

    // And the line never compares current with new — those are meant to differ.
    await tester.enterText(find.byType(TextField).at(0), 'the new one');
    await tester.pump();
    expect(find.text(sentences.passphrasesMatch), findsOneWidget,
        reason: 'the line is comparing the current passphrase with the new one');
  });

  /// The last of his list: a matching pair goes through and really makes a
  /// vault — the form is wired to the core, not only to itself.
  testWidgets('submitting a matching pair creates the vault', (tester) async {
    final dir = Directory.systemTemp.createTempSync('zprivacy-passphrase-');
    addTearDown(() => removeWhenItLetsGo(dir));
    final ground = Ground();
    await tester.runAsync(() async {
      await z.setDataDir(dir: dir.path);
      await ground.refresh();
    });
    expect(ground.vault, VaultState.absent);

    await _form(tester, ground);
    await tester.enterText(find.byType(TextField).at(0), 'a good long passphrase');
    await tester.enterText(find.byType(TextField).at(1), 'a good long passphrase');
    await tester.pump();

    // The trap documented at the head of `shell_test.dart`: a future into
    // Rust never completes inside the fake-async zone, and Argon2 at 64 MiB
    // takes real wall-clock time. So the press is made and then real time is
    // allowed to pass, in rounds, until the core has answered.
    await tester.tap(find.text(sentences.createTheVault));
    for (var i = 0; i < 40 && ground.vault != VaultState.unlocked; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }

    expect(ground.vault, VaultState.unlocked, reason: 'the form did not create a vault');
    expect(File('${dir.path}/vault.zv').existsSync(), isTrue, reason: 'no vault on disk');
    await tester.runAsync(() => z.vaultLock());
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
