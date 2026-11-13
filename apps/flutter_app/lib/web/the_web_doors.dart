// **Which `WebDoors` a build gets** — chosen at compile time, so the desktop
// and the tests never import `dart:js_interop` and the web never imports
// anything of the desktop's bridge.
export 'the_web_doors_none.dart'
    if (dart.library.js_interop) 'the_web_doors_js.dart';
