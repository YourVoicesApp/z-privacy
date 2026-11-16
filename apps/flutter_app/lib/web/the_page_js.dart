// The browser's own two acts, by `dart:js_interop`: a download of bytes held
// in memory, and a navigation to one of our own pages. The bytes become a
// `blob:` address for the one click and are let go at once; nothing is put in
// any storage the page could read again.
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

JSObject get _document => globalContext.getProperty<JSObject>('document'.toJS);
JSObject get _url => globalContext.getProperty<JSObject>('URL'.toJS);

bool saveToTheDevice(Uint8List bytes, String name) {
  final blobType = globalContext.getProperty<JSFunction>('Blob'.toJS);
  final options = JSObject()..setProperty('type'.toJS, 'application/pdf'.toJS);
  final blob = blobType.callAsConstructor<JSObject>(
    <JSAny>[bytes.toJS].toJS,
    options,
  );
  final address = _url.callMethod<JSString>('createObjectURL'.toJS, blob);
  final a = _document.callMethod<JSObject>('createElement'.toJS, 'a'.toJS);
  a
    ..setProperty('href'.toJS, address)
    ..setProperty('download'.toJS, name.toJS);
  a.callMethod<JSAny?>('click'.toJS);
  // Let go once the browser has taken it: revoked at once, a slow download
  // can lose its source.
  Timer(
    const Duration(seconds: 30),
    () => _url.callMethod<JSAny?>('revokeObjectURL'.toJS, address),
  );
  return true;
}

void goTo(String address) {
  final location = globalContext.getProperty<JSObject>('location'.toJS);
  location.callMethod<JSAny?>('assign'.toJS, address.toJS);
}

// ---- Scribe's editor (paper 124, rule 88 (ح)) ------------------------------
//
// Scribe's page, `scribe/` beside this one (`/<lang>/try/scribe/`), in an
// `<iframe>` of our own origin laid over the trial's glass — a DOM element of
// its own, not a Flutter view. The two pages speak by `postMessage`, **our own
// origin only, both ways**, and only with the frame we made:
//
//   here → Scribe:  {type: 'scribe-insert', text}   «Send to the editor»
//                   {type: 'scribe-z-copy', text}   Z's copy (88 (د))
//   Scribe → here:  {type: 'scribe-ready'}          it can take them
//                   {type: 'scribe-close'}          the visitor closed it
//
// What is sent before `scribe-ready` waits here, in order. «Close» hides the
// frame and keeps what the visitor wrote; «Start over» removes it, and with it
// everything in it. Nothing is kept anywhere but in this page's memory.

const _theEditorAddress = 'scribe/';
JSObject? _frame;
bool _frameIsReady = false;
final List<(String, String)> _waitingForTheEditor = <(String, String)>[];
String? _theLastZCopy;
bool _listening = false;

String get _ourOrigin => globalContext
    .getProperty<JSObject>('location'.toJS)
    .getProperty<JSString>('origin'.toJS)
    .toDart;

JSObject? get _frameWindow =>
    _frame?.getProperty<JSObject?>('contentWindow'.toJS);

void _toTheEditor(String type, String text) {
  if (_frame == null) return;
  if (!_frameIsReady) {
    _waitingForTheEditor.add((type, text));
    return;
  }
  final message = JSObject()
    ..setProperty('type'.toJS, type.toJS)
    ..setProperty('text'.toJS, text.toJS);
  _frameWindow?.callMethod<JSAny?>(
    'postMessage'.toJS,
    message,
    _ourOrigin.toJS,
  );
}

void _fromTheEditor(JSObject event) {
  final frame = _frameWindow;
  if (frame == null) return;
  final origin = event.getProperty<JSAny?>('origin'.toJS);
  if (origin == null || !origin.isA<JSString>()) return;
  if ((origin as JSString).toDart != _ourOrigin) return;
  final source = event.getProperty<JSAny?>('source'.toJS);
  if (source == null || !source.strictEquals(frame).toDart) return;
  final data = event.getProperty<JSAny?>('data'.toJS);
  if (data == null || !data.isA<JSObject>()) return;
  final type = (data as JSObject).getProperty<JSAny?>('type'.toJS);
  if (type == null || !type.isA<JSString>()) return;
  switch ((type as JSString).toDart) {
    case 'scribe-ready':
      _frameIsReady = true;
      final waiting = List<(String, String)>.of(_waitingForTheEditor);
      _waitingForTheEditor.clear();
      for (final (t, text) in waiting) {
        _toTheEditor(t, text);
      }
      frame.callMethod<JSAny?>('focus'.toJS);
    case 'scribe-close':
      _frame
          ?.getProperty<JSObject>('style'.toJS)
          .setProperty('display'.toJS, 'none'.toJS);
      globalContext.callMethod<JSAny?>('focus'.toJS);
  }
}

void openTheEditor({String? insert}) {
  if (!_listening) {
    _listening = true;
    globalContext.callMethod<JSAny?>(
      'addEventListener'.toJS,
      'message'.toJS,
      _fromTheEditor.toJS,
    );
  }
  var frame = _frame;
  if (frame == null) {
    frame = _document.callMethod<JSObject>('createElement'.toJS, 'iframe'.toJS)
      ..setProperty('src'.toJS, _theEditorAddress.toJS)
      ..setProperty('title'.toJS, 'Scribe'.toJS)
      ..setProperty('id'.toJS, 'scribe-editor'.toJS);
    frame
        .getProperty<JSObject>('style'.toJS)
        .setProperty(
          'cssText'.toJS,
          ('position:fixed;inset:0;width:100%;height:100%;border:0;margin:0;'
                  'z-index:2147483000;background:#25211C;display:block')
              .toJS,
        );
    _frame = frame;
    _frameIsReady = false;
    _waitingForTheEditor.clear();
    final copy = _theLastZCopy;
    if (copy != null) _waitingForTheEditor.add(('scribe-z-copy', copy));
    _document
        .getProperty<JSObject>('body'.toJS)
        .callMethod<JSAny?>('appendChild'.toJS, frame);
  } else {
    frame
        .getProperty<JSObject>('style'.toJS)
        .setProperty('display'.toJS, 'block'.toJS);
    if (_frameIsReady) _frameWindow?.callMethod<JSAny?>('focus'.toJS);
  }
  if (insert != null) _toTheEditor('scribe-insert', insert);
}

void handTheCopyToTheEditor(String text) {
  _theLastZCopy = text;
  _toTheEditor('scribe-z-copy', text);
}

void dropTheEditor() {
  final frame = _frame;
  _frame = null;
  _frameIsReady = false;
  _waitingForTheEditor.clear();
  _theLastZCopy = null;
  frame?.callMethod<JSAny?>('remove'.toJS);
}
