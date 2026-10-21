// **A census that reads path names reads them in one spelling** — 098 item 5,
// from the Windows suite's own record (`dart.json`, run 39548354872).
//
// `Directory.listSync` hands back the separator the platform writes. The same
// file is `lib/core/messages.dart` on Linux and `lib\core\messages.dart` on
// Windows, so a guard that exempts or seeks a path by a typed fragment is a
// guard about the platform it was written on:
//
// ```text
// no widget interprets an ApiError by itself
//   lib\core\messages.dart: ... — the mapper, reported as its own offender
//   lib\src\rust\api\mirrors.freezed.dart: ... — and every generated file with it
// ```
//
// Both exemptions in that census were spelled with `/`, neither matched, and
// the test was red on Windows while measuring nothing on Linux.
//
// One spelling, chosen rather than guessed: the forward slash, because it is
// what the tree itself is written in — every path in this repository, in the
// gates, in the workflow's own globs. Windows accepts it in every API, so this
// is a translation for *comparing*, never for opening a file: a path to open is
// the one the system handed over, untouched.
library;

/// [path] with the platform's separator folded to `/`, for comparing names.
String oneSpelling(String path) => path.replaceAll(r'\', '/');
