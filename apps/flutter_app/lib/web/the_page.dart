// **What the trial asks of the page it stands in** — two acts, chosen at
// compile time like the doors: save a file the visitor asked for, and follow
// one of our own links. No storage of any kind is here, or anywhere in
// `lib/web/` (a guard reads the folder): leaving the page keeps nothing
// (rule 85 (c)).
export 'the_page_none.dart' if (dart.library.js_interop) 'the_page_js.dart';
