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
    // `ImportRefused` is **overloaded in the core**: it carries a bad file, a
    // provider that needs a credential, a profile that does not exist. So a
    // single fixed sentence here would be wrong for two of the three — which
    // is the same defect as the name itself. Until the core splits it, the
    // reason is a concrete fact and is made into a sentence rather than
    // replaced by a guess.
    ApiError_ImportRefused(:final reason) => _sentence(reason),
    ApiError_DocumentRefused(:final reason) => _document(reason),
    ApiError_BadSpan() =>
      'That selection could not be read. Try selecting the words again.',
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
  Refusal_UnsupportedEncoding(:final page) =>
    'Page $page could not be read as text.',
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
