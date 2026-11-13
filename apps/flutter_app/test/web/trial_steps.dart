// The trial's steps, shared by the VM tests and the browser test: nothing
// here imports `dart:io` or the page's VM half.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/web/the_trial.dart';

const letter =
    'Dear Anna Lindqvist, Björn wrote to anna@example.org about the contract.';

Future<void> write(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(TheTrial.original), text);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

TextEditingController original(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(TheTrial.original)).controller!;

Future<void> caretAt(WidgetTester tester, int offset) async {
  original(tester).selection = TextSelection.collapsed(offset: offset);
  await tester.pump();
}

Future<void> press(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pump();
  await tester.tap(find.byKey(key));
  await tester.pump();
}
