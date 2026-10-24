// **«Save as PDF» asks for the document's name first** — paper 108 item 2, the
// owner, 24 October 2026: «والحفظ يحتاج إلى كتابة اسم للوثيقة من قبل المستخدم».
//
// Seven presses in four files went straight from the button to a written file.
// They all go through here now, for the reason this house writes helpers at
// all: the next change to that dialog is one edit, and a test that types its
// own path through a product's dialog is a test that stops measuring the
// product the day the dialog moves.
//
// The dialog itself is **pure glass** — no core call, no disk — so a pump is
// the whole of what it needs. Everything after the confirming press is the
// save, and the settling for that belongs to the caller, which already knows
// how long its own fixture takes.
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/widgets/the_name_for_the_file.dart';

/// Press «Save as PDF» and answer the name it asks for.
///
/// [name] is the word a person types. It is never a sentence from the one list
/// — a document's name is the person's own, and a fixture that typed one of our
/// sentences would be measuring the list (G65's own rule, from the other side).
Future<void> saveAsPdfCalled(WidgetTester tester, String name) async {
  await tester.tap(find.text(sentences.saveAsPdf));
  await tester.pumpAndSettle();
  expect(find.byKey(TheNameForTheFile.field), findsOneWidget,
      reason: 'the press wrote a file without asking what to call it');
  await tester.enterText(find.byKey(TheNameForTheFile.field), name);
  await tester.pump();
  await tester.tap(find.byKey(TheNameForTheFile.save));
  await tester.pumpAndSettle();
}
