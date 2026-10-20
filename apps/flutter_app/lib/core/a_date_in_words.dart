// **A date, in the words of the language the glass is in** — 092, 20 October
// 2026.
//
// There were two of these: `vault.dart`'s `_taughtOn` and `why_sheet.dart`'s
// `_day`, each with its **own** `const months` list of twelve English
// abbreviations. Two copies of one formatter and twenty-four hand-written
// words, and the day a month read wrong in one of them it would have read
// right in the other.
//
// The lead's ruling of 19 October — «delete the hand-written months, ask `intl`
// with the locale, no key» — so the twelve words are `intl`'s, out of the
// locale's own table (CLDR), and there is one function.
//
// **The order stays the house's**: `d MMM y`, so an English screen reads «20
// Oct 2026» exactly as it did and a German one reads «20 Okt. 2026». Asking
// `intl` for `yMMMd` instead would give each locale its full convention and
// change the English line too, which is not what this round is for.
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:zprivacy/core/sentences.dart';

/// **`intl`'s month words have to be loaded before they can be asked for.**
///
/// `DateFormat('d MMM y', 'de')` throws `LocaleDataException` until
/// `initializeDateFormatting()` has run — found by `vault_screen_test`, which
/// mounts a list of taught values with no delegates above it, and it would
/// have thrown on the glass too for any frame drawn before
/// `flutter_localizations` had loaded its own data.
///
/// Loaded here, once, on the first date any screen draws: nothing for a run
/// that draws none, no sweep through sixty test files, and nothing for the app
/// root to remember. **A real `if` and not an `assert`** — an `assert` is
/// stripped from a release build, and this is the line that makes the next one
/// work.
bool _dateWordsLoaded = false;

/// The day a thing happened, from the core's own seconds.
///
/// The fact is the timestamp; this is only how it reads. A zero is not a date
/// and says so in the language of the glass.
String theDayItWas(int seconds) {
  if (!_dateWordsLoaded) {
    initializeDateFormatting();
    _dateWordsLoaded = true;
  }
  if (seconds == 0) return sentences.taughtOnUnknown;
  final day = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  return DateFormat('d MMM y', sentences.localeName).format(day);
}
