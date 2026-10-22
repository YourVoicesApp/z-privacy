// **The one place this application hands an address to the machine** — paper
// 100, rule 83, 22 October 2026.
//
// The owner's law for the guide is «one text in one place»: the page lives on
// the site, and the app carries a single line that opens it. So something here
// has to ask the operating system to open a browser, and this file is that
// something — alone, small, and easy to read in full, because «the privacy
// product starts a process» is a sentence that deserves one file a reviewer can
// finish.
//
// ## What goes out, exactly
//
// One address, built by [theGuideAddress] from a constant host and a language
// code chosen out of a fixed set. **No value, no document, no path of the
// person's, and nothing from the vault** can reach this file: it takes a
// `String` that the caller built from its own constants, and the one caller
// does exactly that. A reviewer's question — «can a name leave through the
// browser?» — is answered by the signature plus its one call site, not by
// trust.
//
// ## Why not a package
//
// `url_launcher` is the ordinary answer and it was not taken. It is a
// **plugin**: it would add a native half to the Linux build and to the Windows
// build, a line in each generated plugin registrant and a CMake dependency —
// days after the Windows job was finally made to package and sign (098 items
// 7–9). The whole need is one well-known command per platform, and a plugin
// that changes two build graphs to run `xdg-open` is a larger thing to audit
// than the command itself.
//
// ## Why the command is a value and not a call
//
// [theCommandToOpen] answers **what would be run** without running it, so a
// guard can measure the command on a machine where no browser may be started
// and no test can open a window by accident. The press calls [openInTheBrowser],
// which is that same value handed to `Process.start`. One of them is measured;
// the other is the two lines that cannot be measured without a desktop.
import 'dart:io';

/// **The languages the guide page exists in**, as the site serves them.
///
/// `ar` is in the set because the site has an Arabic guide page. No interface
/// language reaches it **today** — there is no `app_ar.arb`, so `theLocaleOf`
/// answers English for `ar` and the app never asks for that page — and it is
/// written here rather than left out so that the day an Arabic interface is
/// written, the guide follows it with no edit. Said out loud because a branch
/// nothing reaches is otherwise a thing a later reader deletes as dead.
const theGuideSpeaks = {'de', 'en', 'ar'};

/// **The guide's own address, in the language the glass is in** — paper 100.
///
/// [code] is the language the **interface** is showing, which is
/// `theLocaleOf(config.language).languageCode` — the same value `main.dart`
/// applies to the whole application. Not the session's and not the document's:
/// the page walks a person through the controls in front of them, so it is in
/// the language those controls are in. (A **file** that leaves takes the
/// session's language instead — rule 80 — and that is a different law for a
/// different reason, in `core/protected_pdf.dart`.)
///
/// Anything outside [theGuideSpeaks] is English, which is the same fallback the
/// sentences themselves take: a page in a language nobody wrote is not a page.
/// **The whole address is one literal on purpose.** Spelled once in this
/// application and nowhere else — the site's own front page carries the other
/// half of that spelling (`/<lang>/guide`), and `scripts/check_site.sh` holds
/// the two equal, because a link in two places is a link one of the two places
/// has already got wrong.
/// **With its closing slash**, because that is the address the page itself
/// calls canonical (`<link rel="canonical">` on all three). Without it the
/// server answers a redirect, which works and is still two spellings of one
/// page — and the gate holds this literal and the site's own href equal.
String theGuideAddress(String code) =>
    'https://z-privacy.com/${theGuideSpeaks.contains(code) ? code : 'en'}/guide/';

/// What this application would run to open [url], on the platform it is on.
///
/// Each is the platform's own documented opener and takes the address as a
/// **separate argument**, never as part of a command line a shell would parse:
/// there is no shell in `Process.start` as it is called below, so nothing in an
/// address can become a second command. The addresses this product builds hold
/// no space and no metacharacter anyway — that is two reasons rather than one,
/// and the stronger of them is the one that does not depend on the address.
///
///   * Linux — `xdg-open`, the freedesktop opener every desktop here provides;
///   * Windows — `rundll32 url.dll,FileProtocolHandler`, which is the opener
///     that needs no shell. `start` is a `cmd` builtin and would need one;
///   * macOS — `open`. Not a platform this product is built for, and named
///     because a switch that answers for the platforms it knows and throws for
///     the rest says more than one with a silent default.
({String run, List<String> args})? theCommandToOpen(String url) {
  if (Platform.isLinux) return (run: 'xdg-open', args: [url]);
  if (Platform.isWindows) {
    return (run: 'rundll32', args: ['url.dll,FileProtocolHandler', url]);
  }
  if (Platform.isMacOS) return (run: 'open', args: [url]);
  return null;
}

/// Open [url] in whatever the person's machine calls its browser.
///
/// Answers whether the opener could be started — not whether a browser came up,
/// which this process cannot know and must not pretend to. A caller that wants
/// to say something on the glass when nothing happened has the false to say it
/// with.
///
/// `Process.start` with `runInShell` left at its default of false: no shell
/// parses anything here. The process is detached — this application does not
/// wait for a browser to be closed.
Future<bool> openInTheBrowser(String url) async {
  final command = theCommandToOpen(url);
  if (command == null) return false;
  try {
    await Process.start(command.run, command.args,
        mode: ProcessStartMode.detached);
    return true;
  } on ProcessException {
    return false;
  }
}
