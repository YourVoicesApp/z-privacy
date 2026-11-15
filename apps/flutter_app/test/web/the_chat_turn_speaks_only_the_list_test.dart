// Paper 123, the lead's ruling: the shared turn widget (`ChatTurnView`) holds
// no literal label — «you» and «coded» were English on every screen in every
// language until now. Read from the file: every string literal in it is a key
// (`the-chat-…`), never a word a person reads.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the chat turn widget holds no literal word a person reads', () {
    final source = File('lib/widgets/the_chat_turn.dart').readAsLinesSync();
    final literals = <String>[];
    for (final line in source) {
      final code = line.trimLeft().startsWith('//') ? '' : line;
      for (final m in RegExp(r"""'((?:[^'\\]|\\.)*)'""").allMatches(code)) {
        literals.add(m.group(1)!);
      }
    }
    final words = literals.where(
      (l) =>
          !l.startsWith('package:') &&
          !l.startsWith('dart:') &&
          !RegExp(r'^the-chat-[a-z-]*(\$\w+)?$').hasMatch(l) &&
          // An escape such as `\n` is not a word.
          RegExp('[A-Za-z]').hasMatch(l.replaceAll(RegExp(r'\\.'), '')),
    );
    expect(words, isEmpty);
    // The control: the reading sees a literal where one stands.
    expect(literals, contains('the-chat-unresolved'));
  });
}
