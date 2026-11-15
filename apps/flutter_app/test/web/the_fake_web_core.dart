// **ed's `z_web` module, faked to its shape** — paper 122 part B.
//
// Every door takes one JSON string and answers one JSON string, `{"ok": …}`
// or `{"error": "<name>", …}`, exactly as the lead forwarded ed's shape; an
// unknown field or a missing one is `bad_request`, as a serde door with
// `deny_unknown_fields` answers. Offsets are UTF-16 code units, which are
// Dart's own.
//
// The «scanner» here is a toy and says so: a fixed list of invented values.
// What it proves is the screen's side of the shape — which door is asked, with
// what, and what is drawn from the answer — never what the real core finds.
// Fixture text only.
import 'dart:convert';

import 'package:zprivacy/web/the_web_core.dart';

class FakeWebDoors implements WebDoors {
  /// Values the toy scanner protects by itself, and the kind it gives them.
  final Map<String, String> automatic = {
    'Anna Lindqvist': 'person',
    'anna@example.org': 'email',
    'آمنة الحسيني': 'person',
  };

  /// Values it only suggests: a person's word to answer.
  final Map<String, String> suggested = {'Björn': 'person'};

  /// Every door asked, with the JSON it was given.
  final List<(String, Map<String, Object?>)> asked = [];
  Iterable<String> get doorsAsked => asked.map((a) => a.$1);

  int _sessions = 0;
  int _findings = 0;

  /// Tokens minted over the fake's life: a closed session's numbers are never
  /// handed out again, so its tokens restore nothing in the next one.
  int _minted = 0;
  int? _session;
  String _pack = 'en';
  String _text = '';
  int _revision = 0;
  final List<Map<String, Object?>> _marks = [];
  final Map<String, String> _tokens = {}; // token → value
  final Map<int, String> _answers = {};

  // The chat (paper 123): the next question and its marks, what each payload
  // carried out, and the turns.
  String _qText = '';
  final List<Map<String, Object?>> _qMarks = [];
  final Map<int, String> _carried = {};
  final List<Map<String, Object?>> _turns = [];
  bool _closed = false;

  /// Every session `z_close` let go of.
  final List<int> closed = [];
  Map<String, Object?>? _payload;

  String get pack => _pack;

  /// The finding id the last reading gave [value], for a guard to compare.
  int? findingOf(String value) => _lastFinding[value];
  final Map<String, int> _lastFinding = {};

  @override
  String call(String door, String json) {
    final Map<String, Object?> r;
    try {
      r = (jsonDecode(json) as Map).cast<String, Object?>();
    } on Object {
      return _err('bad_request');
    }
    asked.add((door, r));
    return switch (door) {
      'z_open' => _open(r),
      'z_import_text' => _import(r),
      'z_scan' => _scan(r),
      'z_protect' => _protect(r),
      'z_unprotect' => _unprotect(r),
      'z_answer_finding' => _answer(r),
      'z_build_payload' => _build(r),
      'z_payload_to_take_out' => _takeOut(r),
      'z_ingest_answer' => _ingest(r),
      'z_restored_view' => _restored(r),
      'z_set_question' => _setQuestion(r),
      'z_question_to_take_out' => _questionToTakeOut(r),
      'z_end_the_chat' => _endTheChat(r),
      'z_turns' => _turnsOf(r),
      'z_close' => _close(r),
      _ => _err('no_such_door'),
    };
  }

  static String _ok(Object? v) => jsonEncode({'ok': v});
  static String _err(String name, [Map<String, Object?> more = const {}]) =>
      jsonEncode({'error': name, ...more});

  bool _fields(
    Map<String, Object?> r,
    Set<String> required, [
    Set<String> optional = const {},
  ]) =>
      required.every(r.containsKey) &&
      r.keys.every((k) => required.contains(k) || optional.contains(k));

  String? _checkSession(Map<String, Object?> r) =>
      r['session'] == _session ? null : _err('invalid_session');

  Map<String, Object?> get _view => {
    'text': _text,
    'marks': [..._marks]
      ..sort((a, b) => (a['start']! as int).compareTo(b['start']! as int)),
  };

  String _open(Map<String, Object?> r) {
    if (!_fields(r, {'pack'}) || !webPacks.contains(r['pack'])) {
      return _err('bad_request');
    }
    _pack = r['pack']! as String;
    _session = ++_sessions;
    _text = '';
    _marks.clear();
    _payload = null;
    return _ok({'session': _session});
  }

  String _tokenFor(String value, String kind) {
    for (final e in _tokens.entries) {
      if (e.value == value) return e.key;
    }
    final t =
        '__Z_${kind.toUpperCase()}_${(++_minted).toString().padLeft(2, '0')}__';
    _tokens[t] = value;
    return t;
  }

  void _read() {
    _marks.removeWhere((m) => m['source'] != 'hand');
    void find(Map<String, String> values, String state) {
      for (final e in values.entries) {
        var at = _text.indexOf(e.key);
        while (at >= 0) {
          final end = at + e.key.length;
          final taken = _marks.any(
            (m) => (m['start']! as int) < end && at < (m['end']! as int),
          );
          if (!taken) {
            _marks.add({
              'start': at,
              'end': end,
              'state': state,
              'token': state == 'protected' ? _tokenFor(e.key, e.value) : null,
              'kind': e.value,
              'source': e.value == 'email' ? 'general_rule' : 'language_pack',
              'decided': state == 'protected',
              'finding': ++_findings,
            });
            _lastFinding[e.key] = _findings;
          }
          at = _text.indexOf(e.key, end);
        }
      }
    }

    find(automatic, 'protected');
    find(suggested, 'suggested');
    _revision++;
    _payload = null;
  }

  String _import(Map<String, Object?> r) {
    if (!_fields(r, {'session', 'text'})) return _err('bad_request');
    final bad = _checkSession(r);
    if (bad != null) return bad;
    _text = r['text']! as String;
    _marks.clear();
    _read();
    return _ok({'view': _view});
  }

  String _scan(Map<String, Object?> r) {
    if (!_fields(r, {'session'})) return _err('bad_request');
    final bad = _checkSession(r);
    if (bad != null) return bad;
    _read();
    return _ok({
      'auto': _marks.where((m) => m['state'] == 'protected').length,
      'suggested': _marks.where((m) => m['state'] == 'suggested').length,
      'normal': 0,
      'view': _view,
    });
  }

  bool _isWordEdge(int i) =>
      i <= 0 ||
      i >= _text.length ||
      RegExp(r'[\s.,;:!?]').hasMatch(_text[i - 1]) ||
      RegExp(r'[\s.,;:!?]').hasMatch(_text[i]);

  String _protect(Map<String, Object?> r) {
    if (!_fields(r, {'session', 'start', 'end', 'kind'}, {'scope'})) {
      return _err('bad_request');
    }
    final bad = _checkSession(r);
    if (bad != null) return bad;
    final start = r['start']! as int, end = r['end']! as int;
    if (start < 0 || end > _text.length || start >= end) {
      return _err('bad_span');
    }
    for (final m in _marks) {
      if ((m['start']! as int) < end &&
          start < (m['end']! as int) &&
          m['state'] == 'protected') {
        return _ok({
          'outcome': {
            'already_protected': {'token': m['token'], 'source': m['source']},
          },
          'view': _view,
        });
      }
    }
    // A span that cuts a word snaps to the whole word, once.
    if (!_isWordEdge(start) || !_isWordEdge(end)) {
      var s = start, e = end;
      while (s > 0 && !RegExp(r'\s').hasMatch(_text[s - 1])) {
        s--;
      }
      while (e < _text.length && !RegExp(r'[\s.,;:!?]').hasMatch(_text[e])) {
        e++;
      }
      return _ok({
        'outcome': {
          'snapped': {
            'spans': [
              {'start': s, 'end': e},
            ],
          },
        },
        'view': _view,
      });
    }
    final value = _text.substring(start, end);
    final kind = r['kind']! as String;
    final token = _tokenFor(value, kind);
    var places = 0;
    final everywhere = r['scope'] == 'conversation';
    var at = everywhere ? _text.indexOf(value) : start;
    while (at >= 0) {
      final e = at + value.length;
      _marks.removeWhere(
        (m) => (m['start']! as int) < e && at < (m['end']! as int),
      );
      _marks.add({
        'start': at,
        'end': e,
        'state': 'protected',
        'token': token,
        'kind': kind,
        'source': 'hand',
        'decided': true,
        'finding': null,
      });
      places++;
      if (!everywhere) break;
      at = _text.indexOf(value, e);
    }
    _revision++;
    return _ok({
      'outcome': {
        'applied': {'token': token, 'places': places},
      },
      'view': _view,
    });
  }

  String _unprotect(Map<String, Object?> r) {
    if (!_fields(r, {'session', 'start', 'end'})) return _err('bad_request');
    final bad = _checkSession(r);
    if (bad != null) return bad;
    final start = r['start']! as int, end = r['end']! as int;
    final gone = _marks
        .where(
          (m) =>
              m['state'] == 'protected' &&
              (m['start']! as int) < end &&
              start < (m['end']! as int),
        )
        .toList();
    if (gone.isEmpty) {
      return _ok({
        'outcome': {'nothing_to_undo': <String, Object?>{}},
        'view': _view,
      });
    }
    _marks.removeWhere(gone.contains);
    _revision++;
    return _ok({
      'outcome': {
        'undone': {
          'tokens': gone.map((m) => m['token']).toSet().length,
          'places': gone.length,
        },
      },
      'view': _view,
    });
  }

  // ed's final shape: `{"session","finding","answer"}`, «always» is not on
  // the web, an unknown finding is `unknown_token`, and «leave» answers every
  // suggestion of the same value.
  String _answer(Map<String, Object?> r) {
    if (!_fields(r, {'session', 'finding', 'answer'})) {
      return _err('bad_request');
    }
    final bad = _checkSession(r);
    if (bad != null) return bad;
    final answer = r['answer'];
    if (answer == 'always') return _err('not_on_web');
    if (answer != 'protect' && answer != 'leave') return _err('bad_request');
    final i = _marks.indexWhere((m) => m['finding'] == r['finding']);
    if (i < 0) return _err('unknown_token');
    final m = _marks[i];
    final value = _text.substring(m['start']! as int, m['end']! as int);
    if (answer == 'protect') {
      _marks[i] = {
        ...m,
        'state': 'protected',
        'token': _tokenFor(value, m['kind']! as String),
        'decided': true,
      };
    } else {
      _marks.removeWhere(
        (x) =>
            x['state'] == 'suggested' &&
            _text.substring(x['start']! as int, x['end']! as int) == value,
      );
      suggested.remove(value);
    }
    _revision++;
    return _ok({
      'outcome': {
        'auto': _marks.where((x) => x['state'] == 'protected').length,
        'suggested': _open_,
        'normal': 0,
      },
      'view': _view,
    });
  }

  /// The app's question scan (046/N), as ed's core runs it: every value it
  /// finds is protected at once — a question never holds a suggestion — and a
  /// value already protected in the document comes back as the same token,
  /// with source `vault` («already protected in this document»).
  void _scanTheQuestion() {
    _qMarks.clear();
    final protectedInTheDocument = {
      for (final m in _marks)
        if (m['state'] == 'protected')
          _text.substring(m['start']! as int, m['end']! as int),
    };
    for (final e in {...automatic, ...suggested}.entries) {
      var at = _qText.indexOf(e.key);
      while (at >= 0) {
        final end = at + e.key.length;
        if (!_qMarks.any(
          (m) => (m['start']! as int) < end && at < (m['end']! as int),
        )) {
          _qMarks.add({
            'start': at,
            'end': end,
            'state': 'protected',
            'token': _tokenFor(e.key, e.value),
            'kind': e.value,
            'source': protectedInTheDocument.contains(e.key)
                ? 'vault'
                : 'language_pack',
            'decided': false,
            'finding': null,
          });
        }
        at = _qText.indexOf(e.key, end);
      }
    }
  }

  String get _questionLeaves {
    final marks = _qMarks.where((m) => m['state'] == 'protected').toList()
      ..sort((a, b) => (b['start']! as int).compareTo(a['start']! as int));
    var out = _qText;
    for (final m in marks) {
      out = out.replaceRange(
        m['start']! as int,
        m['end']! as int,
        m['token']! as String,
      );
    }
    return out;
  }

  // `{"session","text"}` → `{"text","marks"}`: what would leave, and the
  // marks over what was typed.
  String _setQuestion(Map<String, Object?> r) {
    if (!_fields(r, {'session', 'text'})) return _err('bad_request');
    final bad = _checkSession(r);
    if (bad != null) return bad;
    _qText = r['text']! as String;
    _scanTheQuestion();
    _revision++;
    _payload = null;
    return _ok({'text': _questionLeaves, 'marks': _qMarks});
  }

  /// What `ask_model` hands its model: the one exchange before, protected,
  /// then the question alone.
  String get _theChat {
    final out = StringBuffer();
    if (_turns.isNotEmpty) {
      final t = _turns.last;
      out.write('${t['question']}\n\n${t['answer']}\n\n');
    }
    out.write(_questionLeaves);
    return out.toString();
  }

  String _questionToTakeOut(Map<String, Object?> r) {
    if (!_fields(r, {'session'})) return _err('bad_request');
    final bad = _checkSession(r);
    if (bad != null) return bad;
    if (_qText.trim().isEmpty) return _err('nothing_to_send');
    // An open suggestion can only be the document's (a question holds none).
    if (_open_ > 0) return _err('open_suggestions', {'count': _open_});
    final id = _revision * 10 + 2;
    _payload = {'id': id, 'session': _session, 'revision': _revision};
    _carried[id] = _questionLeaves;
    return _ok({'text': _theChat, 'payload': _payload});
  }

  int _chats = 1;
  String _endTheChat(Map<String, Object?> r) {
    if (!_fields(r, {'session'})) return _err('bad_request');
    final bad = _checkSession(r);
    if (bad != null) return bad;
    return _ok({'chat': ++_chats});
  }

  // ed's shape: `{"chat":n,"turns":[{chat, question_as_it_left,
  // answer_as_written, question:{text,segments}, answer:{text,segments},
  // unresolved}]}` — the coded forms and the restored ones.
  String _turnsOf(Map<String, Object?> r) {
    if (!_fields(r, {'session'})) return _err('bad_request');
    final bad = _checkSession(r);
    if (bad != null) return bad;
    Map<String, Object?> restored(String raw) {
      final segments = _segmentsOf(raw);
      return {
        'text': segments.map((x) => x['text']).join(),
        'segments': segments,
      };
    }

    return _ok({
      'chat': _chats,
      'turns': [
        for (final t in _turns)
          {
            'chat': t['chat'],
            'question_as_it_left': t['question'],
            'answer_as_written': t['answer'],
            'question': restored(t['question']! as String),
            'answer': restored(t['answer']! as String),
            'unresolved': [
              for (final m in RegExp(
                r'__Z_[A-Z0-9_]+__',
              ).allMatches(t['answer']! as String))
                if (!_tokens.containsKey(m.group(0))) m.group(0),
            ],
          },
      ],
    });
  }

  /// `z_close`: the session and everything it holds go from memory; a later
  /// call with its id is refused by name, and its tokens restore nothing.
  String _close(Map<String, Object?> r) {
    if (!_fields(r, {'session'})) return _err('bad_request');
    final bad = _checkSession(r);
    if (bad != null) return bad;
    closed.add(_session!);
    _session = null;
    _closed = true;
    _tokens.clear();
    _answers.clear();
    _turns.clear();
    _carried.clear();
    _marks.clear();
    _qMarks.clear();
    _text = '';
    _qText = '';
    return _ok(<String, Object?>{});
  }

  bool get wasClosed => _closed;

  int get _open_ => _marks.where((m) => m['state'] == 'suggested').length;

  String? _cannotLeave() {
    if (_text.trim().isEmpty) return _err('nothing_to_send');
    if (_open_ > 0) return _err('open_suggestions', {'count': _open_});
    return null;
  }

  String get _protectedText {
    final marks = _marks.where((m) => m['state'] == 'protected').toList()
      ..sort((a, b) => (b['start']! as int).compareTo(a['start']! as int));
    var out = _text;
    for (final m in marks) {
      out = out.replaceRange(
        m['start']! as int,
        m['end']! as int,
        m['token']! as String,
      );
    }
    return out;
  }

  String _build(Map<String, Object?> r) {
    if (!_fields(r, {'session'})) return _err('bad_request');
    final bad = _checkSession(r) ?? _cannotLeave();
    if (bad != null) return bad;
    _payload = {
      'id': _revision * 10 + 1,
      'session': _session,
      'revision': _revision,
    };
    _carried[_revision * 10 + 1] = _protectedText;
    return _ok({'payload': _payload});
  }

  String _takeOut(Map<String, Object?> r) {
    if (!_fields(r, {'session'})) return _err('bad_request');
    final bad = _checkSession(r) ?? _cannotLeave();
    if (bad != null) return bad;
    return _ok({
      'text': _protectedText,
      'protected_count': _marks.where((m) => m['state'] == 'protected').length,
      'open_suggestions': 0,
    });
  }

  String _ingest(Map<String, Object?> r) {
    if (!_fields(r, {'payload', 'text'})) return _err('bad_request');
    final p = r['payload'];
    if (p is! Map || p['session'] != _session) return _err('invalid_handle');
    if (p['revision'] != _revision) {
      return _err('stale_payload', {
        'expected': _revision,
        'got': p['revision'],
      });
    }
    final id = _answers.length + 1;
    _answers[id] = r['text']! as String;
    _turns.add({
      'chat': _chats,
      'question': _carried[p['id']] ?? '',
      'answer': r['text'],
    });
    return _ok({'answer': id});
  }

  List<Map<String, Object?>> _segmentsOf(String raw) {
    final segments = <Map<String, Object?>>[];
    var at = 0;
    for (final m in RegExp(r'__Z_[A-Z0-9_]+__').allMatches(raw)) {
      if (m.start > at) {
        segments.add({'text': raw.substring(at, m.start), 'piece': 'words'});
      }
      final value = _tokens[m.group(0)];
      segments.add(
        value == null
            ? {'text': m.group(0), 'piece': 'unresolved'}
            : {'text': value, 'piece': 'restored'},
      );
      at = m.end;
    }
    if (at < raw.length) {
      segments.add({'text': raw.substring(at), 'piece': 'words'});
    }
    return segments;
  }

  String _restored(Map<String, Object?> r) {
    if (!_fields(r, {'session', 'answer'})) return _err('bad_request');
    final bad = _checkSession(r);
    if (bad != null) return bad;
    final raw = _answers[r['answer']];
    if (raw == null) return _err('invalid_handle');
    final segments = _segmentsOf(raw);
    return _ok({
      'text': segments.map((s) => s['text']).join(),
      'segments': segments,
    });
  }
}
