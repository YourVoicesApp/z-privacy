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
