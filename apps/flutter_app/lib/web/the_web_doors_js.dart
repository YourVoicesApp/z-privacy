// **ed's `z_web` module, in the browser** — paper 122 §2.
//
//     import init, * as z from './z_web.js'; await init();
//
// done once from Dart: `importModule` is the browser's own `import()`, so the
// module and its `.wasm` come from our own origin (`script-src 'self'
// 'wasm-unsafe-eval'`) and nothing else is fetched. Every door after that is a
// synchronous call: one JSON string in, one JSON string out.
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:zprivacy/web/the_web_core.dart';

/// Where the module stands, beside the page's own scripts.
const theModule = './z_web.js';

/// [module] is the page's own `./z_web.js`; a browser test names the one
/// it built, served from 127.0.0.1.
Future<WebDoors> loadTheWebDoors({String module = theModule}) async {
  final loaded = await importModule(module.toJS).toDart;
  final init = loaded.getProperty<JSFunction>('default'.toJS);
  final started = init.callAsFunction();
  if (started.isA<JSPromise>()) await (started as JSPromise).toDart;
  return _JsDoors(loaded);
}

class _JsDoors implements WebDoors {
  _JsDoors(this.module);
  final JSObject module;

  @override
  String call(String door, String json) {
    final f = module.getProperty<JSFunction?>(door.toJS);
    if (f == null) return jsonEncode({'error': 'no_such_door'});
    final answer = f.callAsFunction(null, json.toJS);
    return answer.isA<JSString>()
        ? (answer as JSString).toDart
        : jsonEncode({'error': 'bad_answer'});
  }
}
