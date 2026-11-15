// Paper 122 §3.5 — **nothing is written to storage, checked in a browser
// after a full flow** (rule 85 (c): leaving the page keeps nothing).
//
//     flutter test --platform chrome test/web_browser/
//
// The trial runs in Chrome with the fake of ed's shape, from writing to the
// restored document, and then the browser itself is asked: localStorage,
// sessionStorage, cookies, IndexedDB, Cache Storage and service workers. Every
// one must be empty — not «unchanged»: the trial may not be the first to
// write, and nothing else on this page writes either.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/web/the_trial.dart';

import '../web/the_fake_web_core.dart';
import '../web/trial_steps.dart';
import 'the_trial_server.dart';

JSObject get _window => globalContext;

Future<Map<String, Object?>> whatTheBrowserKeeps() async {
  final local = _window.getProperty<JSObject>('localStorage'.toJS);
  final session = _window.getProperty<JSObject>('sessionStorage'.toJS);
  final document = _window.getProperty<JSObject>('document'.toJS);
  final indexed = _window.getProperty<JSObject>('indexedDB'.toJS);
  final databases = await indexed
      .callMethod<JSPromise<JSArray>>('databases'.toJS)
      .toDart;
  final caches = _window.getProperty<JSObject>('caches'.toJS);
  final cacheNames = await caches
      .callMethod<JSPromise<JSArray>>('keys'.toJS)
      .toDart;
  final navigator = _window.getProperty<JSObject>('navigator'.toJS);
  final workers = navigator.getProperty<JSObject>('serviceWorker'.toJS);
  final registrations = await workers
      .callMethod<JSPromise<JSArray>>('getRegistrations'.toJS)
      .toDart;
  return {
    'localStorage': local.getProperty<JSNumber>('length'.toJS).toDartInt,
    'sessionStorage': session.getProperty<JSNumber>('length'.toJS).toDartInt,
    'cookie': document.getProperty<JSString>('cookie'.toJS).toDart,
    'indexedDB': databases.length,
    'caches': cacheNames.length,
    'serviceWorkers': registrations.length,
  };
}

const nothing = {
  'localStorage': 0,
  'sessionStorage': 0,
  'cookie': '',
  'indexedDB': 0,
  'caches': 0,
  'serviceWorkers': 0,
};

void main() {
  testWidgets(
    'two turns and «Start over» in Chrome leave no storage behind',
    (tester) async {
      expect(
        await tester.runAsync(whatTheBrowserKeeps),
        nothing,
        reason: 'before',
      );
      final doors = FakeWebDoors();
      // The clipboard over memory: a test never touches the real one.
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        TrialApp(
          language: 'en',
          doors: () async => doors,
          font: theFontFromTheServer,
        ),
      );
      await tester.pump();
      await tester.pump();
      await write(tester, letter);
      final b = letter.indexOf('Björn');
      tester
          .widget<TextField>(find.byKey(TheTrial.original))
          .controller!
          .selection = TextSelection.collapsed(
        offset: b + 1,
      );
      await tester.pump();
      await press(tester, TheTrial.protectIt);
      await press(tester, TheTrial.copyProtected);
      await tester.enterText(
        find.byKey(TheTrial.answer),
        'Thank you, __Z_PERSON_01__.',
      );
      await tester.pump();
      await press(tester, TheTrial.restore);
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      expect(
        find.byKey(TheTrial.document),
        findsOneWidget,
        reason: 'the flow reached the document',
      );
      await press(tester, TheTrial.copyDocument);
      expect(copied.last, contains('Thank you, Anna Lindqvist.'));

      // Paper 123: a second turn through the chat, then «Start over».
      await tester.enterText(
        find.byKey(TheTrial.compose),
        'Will Anna Lindqvist sign it?',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await press(tester, TheTrial.copyProtected);
      final token = RegExp(
        r'__Z_PERSON_[0-9]+__',
      ).firstMatch(copied.last)!.group(0)!;
      await tester.enterText(find.byKey(TheTrial.answer), 'Yes, $token will.');
      await tester.pump();
      await press(tester, TheTrial.restore);
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      expect(
        find.text('Yes, Anna Lindqvist will.', findRichText: true),
        findsOneWidget,
        reason: 'the second turn reached the document',
      );
      await press(tester, TheTrial.startOver);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TheTrial.erase));
      await tester.pumpAndSettle();
      expect(doors.closed, isNotEmpty, reason: 'the session was closed');
      expect(find.byKey(TheTrial.document), findsNothing);

      expect(
        await tester.runAsync(whatTheBrowserKeeps),
        nothing,
        reason: 'after two turns and a start over',
      );
      // Skipped with no Z_TRIAL_SERVER: run scripts/check_the_trial_in_a_browser.sh.
    },
    skip: theTrialServer.isEmpty,
  );
}
