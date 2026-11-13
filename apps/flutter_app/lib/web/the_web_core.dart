// **The core in the visitor's browser, as the trial's screen sees it** — paper
// 122 §2 and §3, ed's `z_web` module (wasm-bindgen, `--target web`).
//
// Every door of that module is synchronous, takes **one JSON string** and
// returns **one JSON string**: `{"ok": …}` or `{"error": "<name>", …}`.
// Offsets are UTF-16 code units over the document's `text` — Dart's own
// string indices, so a mark's `start` and `end` cut a Dart string directly.
//
// Two layers, so a test speaks the same JSON the browser does:
//
//   * [WebDoors] is the module itself: a door's name and the JSON it is
//     given, the JSON it answers. In the browser it is `the_web_doors_js.dart`
//     (`dart:js_interop`, chosen by a conditional import); in a test it is a
//     fake written to ed's shape.
//   * [TheWebCore] reads those answers into the few things the screen needs.
//     Nothing here decides what is protected: every mark, token and restored
//     word is the core's.
//
// **No bridge of the desktop's is reachable from here** — the desktop's
// `src/rust` is flutter_rust_bridge, which the web does not use (the lead,
// after ed's measurement), and a guard walks the web entry's imports.
import 'dart:convert';

/// The module's doors, by name: `z_open`, `z_import_text`, … Each takes the
/// JSON written for it and answers JSON.
abstract interface class WebDoors {
  String call(String door, String json);
}

/// One door's answer: the `ok` value, or the error's name and its fields.
class WebAnswer {
  const WebAnswer.ok(this.value) : error = null, detail = const {};
  const WebAnswer.refused(this.error, [this.detail = const {}]) : value = null;

  /// Read from the module's JSON. Anything else is `bad_answer`, a name of
  /// this side's: the screen never shows a raw string the module returned.
  factory WebAnswer.read(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, Object?>) {
        if (decoded.containsKey('ok')) return WebAnswer.ok(decoded['ok']);
        final name = decoded['error'];
        if (name is String) {
          return WebAnswer.refused(
            name,
            Map<String, Object?>.of(decoded)..remove('error'),
          );
        }
      }
    } on FormatException {
      // Below.
    }
    return const WebAnswer.refused('bad_answer');
  }

  final Object? value;
  final String? error;
  final Map<String, Object?> detail;

  bool get isOk => error == null;
  Map<String, Object?> get map =>
      value is Map<String, Object?> ? value! as Map<String, Object?> : const {};
}

/// A refusal of the core, by its name and fields, as the screen words it.
class WebRefusal implements Exception {
  const WebRefusal(this.name, [this.detail = const {}]);
  final String name;
  final Map<String, Object?> detail;
}

/// A mark the core put on the text: protected, or a suggestion waiting.
class WebMark {
  const WebMark({
    required this.start,
    required this.end,
    required this.state,
    required this.kind,
    required this.source,
    required this.decided,
    this.token,
    this.finding,
  });

  factory WebMark.read(Map<String, Object?> m) => WebMark(
    start: (m['start']! as num).toInt(),
    end: (m['end']! as num).toInt(),
    state: m['state']! as String,
    token: m['token'] as String?,
    kind: m['kind']! as String,
    source: m['source']! as String,
    decided: m['decided'] == true,
    finding: (m['finding'] as num?)?.toInt(),
  );

  final int start;
  final int end;

  /// `protected` or `suggested`.
  final String state;
  final String? token;
  final String kind;

  /// `general_rule`, `language_pack` or `hand` — and `vault`, which the web
  /// has no vault to answer with, read like any other name.
  final String source;
  final bool decided;

  /// The core's finding behind this mark, `null` for a hand mark: what a
  /// suggestion is answered by (`z_answer_finding`).
  final int? finding;

  bool get protected => state == 'protected';
  bool get suggested => state == 'suggested';
  bool holds(int offset) => start <= offset && offset < end;
}

/// The document as the core reads it: its text and its marks.
class WebView {
  const WebView(this.text, this.marks);
  factory WebView.read(Object? v) {
    final m = v is Map<String, Object?> ? v : const <String, Object?>{};
    final marks = m['marks'];
    return WebView(m['text'] as String? ?? '', [
      if (marks is List)
        for (final x in marks)
          if (x is Map<String, Object?>) WebMark.read(x),
    ]);
  }
  static const empty = WebView('', []);

  final String text;
  final List<WebMark> marks;

  WebMark? markAt(int offset) {
    for (final m in marks) {
      if (m.holds(offset)) return m;
    }
    return null;
  }

  int get suggestions => marks.where((m) => m.suggested).length;
}

/// What «Copy protected» copies, and only that — `z_payload_to_take_out`.
class TakeOut {
  const TakeOut(this.text, this.protectedCount, this.openSuggestions);
  final String text;
  final int protectedCount;
  final int openSuggestions;
}

/// One piece of the restored answer: the model's own words, a value put
/// back, or a token nothing could place.
class RestoredPiece {
  const RestoredPiece(this.text, this.piece);
  final String text;

  /// `words`, `restored` or `unresolved`.
  final String piece;
}

class Restored {
  const Restored(this.text, this.pieces);
  final String text;
  final List<RestoredPiece> pieces;
}

/// How far a protection reaches: this place, or every place of the value in
/// the session. Sent by its name, which is the core's own word for it.
enum WebScope { once, conversation }

/// The packs a session can read with, in the app's order.
const webPacks = ['en', 'ar', 'de', 'fr', 'es', 'sv'];

/// **The core's eight doors, read** — one session per page load, held here
/// and nowhere else: no storage of any kind (rule 85 (c)).
class TheWebCore {
  TheWebCore(this.doors);

  final WebDoors doors;
  int? _session;
  Map<String, Object?>? _payload;

  WebAnswer _ask(String door, Map<String, Object?> request) =>
      WebAnswer.read(doors(door, jsonEncode(request)));

  Object? _ok(String door, Map<String, Object?> request) {
    final a = _ask(door, request);
    if (!a.isOk) throw WebRefusal(a.error!, a.detail);
    return a.value;
  }

  Map<String, Object?> _okMap(String door, Map<String, Object?> request) {
    final v = _ok(door, request);
    return v is Map<String, Object?> ? v : const {};
  }

  int get session {
    final s = _session;
    if (s == null) throw const WebRefusal('invalid_session');
    return s;
  }

  bool get isOpen => _session != null;

  /// `z_open` with the scanner's language. A new pack is a new session: the
  /// one before it is let go with the page's memory.
  void open(String pack) {
    final v = _okMap('z_open', {'pack': pack});
    _session = (v['session']! as num).toInt();
    _payload = null;
  }

  WebView importText(String text) {
    _payload = null;
    return WebView.read(
      _okMap('z_import_text', {'session': session, 'text': text})['view'],
    );
  }

  WebView scan() =>
      WebView.read(_okMap('z_scan', {'session': session})['view']);

  /// `z_protect`. A snapped answer is asked once more with the one span it
  /// names, as ed's shape says; any other outcome is the core's to word.
  ({String outcome, WebView view}) protect(
    int start,
    int end, {
    required String kind,
    WebScope scope = WebScope.once,
  }) {
    _payload = null;
    var v = _okMap('z_protect', {
      'session': session,
      'start': start,
      'end': end,
      'kind': kind,
      'scope': scope.name,
    });
    var outcome = _outcomeName(v['outcome']);
    if (outcome == 'snapped') {
      final spans = ((v['outcome']! as Map)['snapped'] as Map)['spans'];
      if (spans is List && spans.length == 1 && spans.single is Map) {
        final one = spans.single as Map;
        v = _okMap('z_protect', {
          'session': session,
          'start': one['start'],
          'end': one['end'],
          'kind': kind,
          'scope': scope.name,
        });
        outcome = _outcomeName(v['outcome']);
      }
    }
    return (outcome: outcome, view: WebView.read(v['view']));
  }

  WebView unprotect(int start, int end) {
    _payload = null;
    return WebView.read(
      _okMap('z_unprotect', {
        'session': session,
        'start': start,
        'end': end,
      })['view'],
    );
  }

  /// **A suggestion answered: protect it, or leave it in the clear** —
  /// `z_answer_finding`, by the finding behind the mark. `z_protect` on a
  /// suggested mark would not decide it (the payload still refuses with
  /// `open_suggestions`), so a suggestion is only ever answered here; «leave»
  /// answers every suggestion of the same value, and the value stays in what
  /// leaves as written. A mark with no finding is a hand mark: `bad_span`.
  WebView answerFinding(WebMark mark, {required bool protect}) {
    final finding = mark.finding;
    if (finding == null) throw const WebRefusal('bad_span');
    _payload = null;
    return WebView.read(
      _okMap('z_answer_finding', {
        'session': session,
        'finding': finding,
        'answer': protect ? 'protect' : 'leave',
      })['view'],
    );
  }

  /// «Copy protected»: the payload is built for this revision, and the text
  /// that may leave is read from the core — never assembled here.
  TakeOut takeOut() {
    _payload =
        (_okMap('z_build_payload', {'session': session})['payload']! as Map)
            .cast<String, Object?>();
    final v = _okMap('z_payload_to_take_out', {'session': session});
    return TakeOut(
      v['text'] as String? ?? '',
      (v['protected_count'] as num?)?.toInt() ?? 0,
      (v['open_suggestions'] as num?)?.toInt() ?? 0,
    );
  }

  bool get hasPayload => _payload != null;

  /// The model's answer, pasted, read back with the real names.
  Restored restore(String pasted) {
    final payload = _payload;
    if (payload == null) throw const WebRefusal('no_payload');
    final answer =
        (_okMap('z_ingest_answer', {
                  'payload': payload,
                  'text': pasted,
                })['answer']!
                as num)
            .toInt();
    final v = _okMap('z_restored_view', {'session': session, 'answer': answer});
    final segments = v['segments'];
    return Restored(v['text'] as String? ?? '', [
      if (segments is List)
        for (final s in segments)
          if (s is Map)
            RestoredPiece(
              s['text'] as String? ?? '',
              s['piece'] as String? ?? 'words',
            ),
    ]);
  }

  static String _outcomeName(Object? outcome) =>
      outcome is Map && outcome.isNotEmpty
      ? outcome.keys.first as String
      : 'unknown';
}
