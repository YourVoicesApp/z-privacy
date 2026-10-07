// The one place a typed error becomes a sentence a person reads.
//
// The owner's rule of 29 September, and the whole reason this file exists:
//
//     **No widget interprets an ApiError by itself.**
//
// Otherwise one error says three different things on three screens within a
// month, and the app starts disagreeing with itself — which is the family of
// defect this project has spent two rounds hunting.
//
// The division of labour is deliberate:
//
//   * **Rust** keeps typed errors. It does not send English at the user; the
//     `reason`/`detail` strings it carries are facts (an address, a size, a
//     status), not phrasing.
//   * **Flutter** turns the type into language, here and nowhere else.
//
// Before this file, `ApiError.importRefused(reason: …)` reached the screen with
// the enum's own debug formatting around it — and `importRefused` was the wrong
// word anyway: it was printed when a **Connect** was refused.
import 'package:zprivacy/src/rust/api/mirrors.dart';

/// What a person is told when something the app cannot name goes wrong.
///
/// A new variant added to the contract lands here rather than leaking its debug
/// formatting. `errorIsCovered` exists so a test can prove that never happens
/// silently.
const String unnamedTrouble =
    'Something went wrong. Z Privacy did not complete the action.';

/// The human sentence for a typed error. The only such function in the app.
String humanMessage(Object error) {
  if (error is! ApiError) return unnamedTrouble;
  return switch (error) {
    ApiError_NotImplemented() =>
      'This part of Z Privacy is not built yet.',
    ApiError_InvalidSession() =>
      'That conversation is no longer open. Start a new one.',
    ApiError_InvalidHandle() =>
      'This request is no longer current. Review the text again before sending.',
    ApiError_StalePayload() =>
      'The document changed after this request was prepared. Review it again, '
          'so that what you send is what you last saw.',
    ApiError_VaultLocked() =>
      'Your vault is locked. Unlock it to use what it knows.',
    ApiError_VaultRequired() =>
      'Unlock or create your vault before saving this for future use.',
    ApiError_VaultAuthenticationFailed() =>
      'Could not unlock the vault. The passphrase may be incorrect, or the '
          'vault may be corrupted or modified.',
    ApiError_UnsupportedKdfParameters() =>
      'This vault uses unsupported security settings.',
    ApiError_TrailingVaultData() =>
      'This vault file has extra data after its end and was not opened.',
    ApiError_ProviderUnavailable() =>
      'That AI provider is not available in this build.',
    ApiError_OpenSuggestions(:final count) => count == 1
        ? 'One suggestion is still waiting for your word.'
        : '$count suggestions are still waiting for your word.',
    // The core split `ImportRefused` on 30 September, so this no longer has to
    // word one sentence for three unrelated stories. Each of these is a
    // different next move for the person: change what you entered · name
    // something else · make a vault · nothing you typed is wrong.
    ApiError_InputRefused(:final reason) => _sentence(reason),
    ApiError_NotFound(:final reason) => _sentence(reason),
    ApiError_VaultAbsent() =>
      'There is no vault on this device yet. Create one to keep anything for tomorrow.',
    ApiError_VaultAlreadyExists() =>
      'A vault already exists on this device, and Z Privacy will not write over it.',
    // Not the person's doing, and said so — the fault is in a location, and
    // the reason names which one and why.
    ApiError_StorageRefused(:final reason) =>
      'Z Privacy will not use that location — ${_lower(reason)}',
    ApiError_DocumentRefused(:final reason) => _document(reason),
    ApiError_BadSpan() =>
      'That selection could not be read. Try selecting the words again.',
    // 046/Q. **Why, and not merely that it will not** (the lead's condition):
    // the press was read without trouble, so «could not be read» would be
    // false, and the person's next move is to press on a value rather than to
    // press again in the same place. Snapping to the nearest cell would have
    // needed no sentence at all — and would have been the app deciding which
    // column he meant.
    ApiError_BetweenColumns() =>
      'That press landed in the space between two columns, so it names no '
          'value — and Z Privacy will not choose a column for you.',
    ApiError_UnknownToken() =>
      'That protected value is not in this conversation.',
    ApiError_NothingToSend() =>
      'There is nothing to send yet. Bring in a document or write some text.',
    ApiError_PayloadRefused(:final reason) => _sentence(reason),
    ApiError_PayloadAlreadySent() =>
      'This request was already sent. Prepare it again to send once more.',
    ApiError_NetworkRefused(:final reason, :final detail) =>
      _network(reason, detail),
    // Not a wildcard by accident: the test below walks every variant, so a new
    // one fails that test rather than quietly arriving here.
    _ => unnamedTrouble,
  };
}

/// A fact from the core, made into something a person reads: a capital at the
/// front and a full stop at the end. The core writes facts, not phrasing, and
/// this is the seam where the two meet.
/// A core fact folded into the middle of a sentence: lower-cased at its first
/// letter and closed with a stop, so «Z Privacy will not use that location —
/// the vault folder: a symlink…» reads as one line rather than two halves.
String _lower(String fact) {
  final trimmed = fact.trim();
  if (trimmed.isEmpty) return 'the reason was not reported.';
  final lowered = trimmed[0].toLowerCase() + trimmed.substring(1);
  return lowered.endsWith('.') ? lowered : '$lowered.';
}

String _sentence(String fact) {
  final trimmed = fact.trim();
  if (trimmed.isEmpty) return unnamedTrouble;
  final capitalised = trimmed[0].toUpperCase() + trimmed.substring(1);
  return capitalised.endsWith('.') ? capitalised : '$capitalised.';
}

String _document(Refusal reason) => switch (reason) {
  Refusal_MalformedDocument() => 'This document is damaged or incomplete.',
  Refusal_EncryptedPdf() =>
    'This PDF is password-protected. Remove the password and try again.',
  Refusal_ScannedPdfNoTextLayer(:final pages) => pages == 1
      ? 'This PDF is a picture of a page with no text in it, so nothing could '
            'be read — and Z Privacy will not import a document it cannot see.'
      : 'This PDF is $pages pages of pictures with no text in them, so nothing '
            'could be read.',
  // The core measured two things here and the screen used to pass on neither:
  // how much of the page decoded, and what a person can do about it. Read
  // without them — «Page 5 could not be read as text» — it sounds like the app
  // took a page of words for a picture, which is what the owner read it as.
  Refusal_UnsupportedEncoding(:final page, :final readablePercent) =>
    'Only $readablePercent% of page $page decoded into characters, so this '
        'document is refused rather than half-read. Open it and save it as '
        'text, or paste the text in.',
  Refusal_UnreadableStructure(:final page) =>
    'Page $page is built in a way this build cannot read.',
  _ => 'This file could not be opened safely.',
};

String _network(NetworkRefusal reason, String detail) => switch (reason) {
  NetworkRefusal_NotConnected() =>
    'No AI provider is connected. Add an address and a key first.',
  // The detail names the rule and gives a working example — a fact the person
  // needs in order to fix it, not phrasing.
  NetworkRefusal_InsecureUrl() =>
    detail.isEmpty ? 'That address is not safe to send to.' : _sentence(detail),
  NetworkRefusal_Redirected() =>
    'That address sent us somewhere else. Z Privacy does not follow redirects '
        'with your text, so nothing was sent.',
  NetworkRefusal_BadStatus(:final status) =>
    'The provider refused the request with status $status. Nothing of your '
        'document was kept by Z Privacy.',
  NetworkRefusal_Timeout() =>
    'The provider did not answer in time. Nothing else was sent.',
  NetworkRefusal_ResponseTooLarge(:final limitKib) =>
    'The answer was larger than ${limitKib} KiB and was not read.',
  NetworkRefusal_PayloadTooLarge(:final kib, :final limitKib) =>
    'This text is ${kib} KiB and the provider accepts '
        '${limitKib} KiB in one request.',
  NetworkRefusal_Unreadable() =>
    'The provider answered with something that is not an answer.',
  _ => 'The connection to that provider did not work.',
};
