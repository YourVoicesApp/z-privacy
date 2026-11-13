// The runner's own server, as a browser test reaches it —
// `scripts/check_the_trial_in_a_browser.sh` starts it on 127.0.0.1 and names
// it by `--dart-define=Z_TRIAL_SERVER=…`.
//
// Two things a widget test in Chrome cannot do for itself: read the font
// (`rootBundle` never answers there, measured), and read a PDF's text — so
// the PDF's bytes go to the server, which reads them with `pdftotext` and
// answers the text. Nothing leaves 127.0.0.1, and nothing is kept.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

const theTrialServer = String.fromEnvironment('Z_TRIAL_SERVER');

JSPromise<JSObject> _fetch(String url, [JSObject? options]) => globalContext
    .callMethod<JSPromise<JSObject>>('fetch'.toJS, url.toJS, options);

/// The trial's font, from the server.
Future<ByteData> theFontFromTheServer() async {
  final response = await _fetch('$theTrialServer/font').toDart;
  final buffer = await response
      .callMethod<JSPromise<JSArrayBuffer>>('arrayBuffer'.toJS)
      .toDart;
  return ByteData.view(buffer.toDart);
}

/// The text `pdftotext` reads out of [pdf].
Future<String> theTextOfThePdf(Uint8List pdf) async {
  final options = JSObject()
    ..setProperty('method'.toJS, 'POST'.toJS)
    ..setProperty('body'.toJS, pdf.toJS);
  final response = await _fetch('$theTrialServer/pdf', options).toDart;
  return (await response.callMethod<JSPromise<JSString>>('text'.toJS).toDart)
      .toDart;
}
