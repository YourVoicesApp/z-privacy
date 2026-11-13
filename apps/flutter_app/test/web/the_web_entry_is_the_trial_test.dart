// Paper 122 §3.5 — pinned first: the web entry point is the trial's chat, not
// today's desktop shell (rule 85).
import 'package:flutter_test/flutter_test.dart';
import 'package:zprivacy/main.dart' show ZPrivacyApp;
import 'package:zprivacy/main_web.dart';

void main() {
  test('the web entry is not the desktop application', () {
    expect(theWebRoot(), isNot(isA<ZPrivacyApp>()));
  });
}
