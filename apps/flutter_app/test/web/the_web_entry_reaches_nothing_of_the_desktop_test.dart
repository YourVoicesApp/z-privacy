// Paper 122 §3.1 and the lead's change to §3: **the web entry never imports
// the flutter_rust_bridge bindings**, nor `dart:io`, nor the desktop's
// `main.dart` — and nothing under `lib/web/` touches any storage (rule 85
// (c)). Read from the files, by walking every import and export the entry
// reaches, both branches of a conditional one included.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _directive = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]([^;]*);''',
  multiLine: true,
);
final _branch = RegExp(r'''if\s*\([^)]*\)\s*['"]([^'"]+)['"]''');

/// Every file of this package the entry reaches, and every import it names.
({Set<String> files, Set<String> names}) reach(String entry) {
  final files = <String>{};
  final names = <String>{};
  final todo = [entry];
  while (todo.isNotEmpty) {
    final path = File(todo.removeLast()).absolute.path;
    if (!files.add(path)) continue;
    final source = File(path).readAsStringSync();
    for (final d in _directive.allMatches(source)) {
      final targets = [
        d.group(1)!,
        ..._branch.allMatches(d.group(2)!).map((b) => b.group(1)!),
      ];
      for (final t in targets) {
        names.add(t);
        if (t.startsWith('package:zprivacy/')) {
          todo.add('lib/${t.substring('package:zprivacy/'.length)}');
        } else if (!t.contains(':')) {
          todo.add(File(path).parent.uri.resolve(t).toFilePath());
        }
      }
    }
  }
  return (files: files, names: names);
}

void main() {
  test('the web entry reaches no bridge, no dart:io and no desktop main', () {
    final r = reach('lib/main_web.dart');
    expect(
      r.files.any((f) => f.endsWith('lib/web/the_trial.dart')),
      isTrue,
      reason: 'the walk reaches the trial',
    );
    expect(
      r.files.any((f) => f.endsWith('lib/web/the_web_doors_js.dart')),
      isTrue,
      reason: 'both branches walked',
    );
    final bad = r.names.where(
      (n) =>
          n.contains('src/rust') ||
          n.contains('flutter_rust_bridge') ||
          n == 'dart:io' ||
          n == 'package:zprivacy/main.dart' ||
          n == 'package:zprivacy/screens/shell.dart',
    );
    expect(bad, isEmpty);
    expect(r.files.where((f) => f.contains('/src/rust/')), isEmpty);
  });

  test(
    'the control bites: the desktop entry reaches the bridge and dart:io',
    () {
      final r = reach('lib/main.dart');
      expect(r.names, contains('dart:io'));
      expect(r.names.any((n) => n.contains('src/rust')), isTrue);
    },
  );

  test('nothing in the web trial names a storage of the browser', () {
    final words = RegExp(
      r'localStorage|sessionStorage|indexedDB|IndexedDB|cookie|caches|CacheStorage|serviceWorker|'
      r'SharedPreferences|shared_preferences|Hive|sqflite',
    );
    final hits = <String>[];
    for (final f in [
      File('lib/main_web.dart'),
      ...Directory('lib/web').listSync().whereType<File>(),
    ]) {
      for (final (i, line) in f.readAsLinesSync().indexed) {
        final code = line.split('//').first;
        if (words.hasMatch(code)) hits.add('${f.path}:${i + 1}: $line');
      }
    }
    expect(hits, isEmpty);
  });
}
