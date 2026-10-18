// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get theKeyIsBehindTheLockedVault =>
      'Z Privacy cannot reach a key while the vault is locked. Unlock it, or give a key for this run.';

  @override
  String get theChatKeepsNothing =>
      'This answer is on your screen and nowhere else: no session is open to keep it, so closing the app ends it with the chat.';

  @override
  String get theTokenIsAlreadyOurs =>
      'This is already protected — Z put it there.';

  @override
  String get unnamedTrouble =>
      'Something went wrong. Z Privacy did not complete the action.';

  @override
  String exactlyWhatWouldLeave(int replaced) {
    return 'This is exactly what the AI will receive. $replaced values were replaced.';
  }

  @override
  String get noLanguageAndASessionIsOpen =>
      'Nothing was read. A text is read with one language’s habits, and this session has never been given one — so Z Privacy did not choose for you. Read it again and answer, or give the session its language in Settings.';

  @override
  String get noLanguageAndNoSession =>
      'Nothing was read. A text is read with one language’s habits, and none was chosen — so nothing was read and no session was made. Try again and choose one.';

  @override
  String get troubleNotImplemented =>
      'This part of Z Privacy is not built yet.';

  @override
  String get troubleInvalidSession =>
      'That session is no longer open. Start a new one.';

  @override
  String get troubleInvalidHandle =>
      'This request is no longer current. Review the text again before sending.';

  @override
  String get troubleStalePayload =>
      'The document changed after this request was prepared. Review it again, so that what you send is what you last saw.';

  @override
  String get troubleVaultLocked =>
      'Your vault is locked. Unlock it to use what it knows.';

  @override
  String get troubleVaultRequired =>
      'Unlock or create your vault before saving this for future use.';

  @override
  String get troubleVaultAuthenticationFailed =>
      'Could not unlock the vault. The passphrase may be incorrect, or the vault may be corrupted or modified.';

  @override
  String get troubleUnsupportedKdfParameters =>
      'This vault uses unsupported security settings.';

  @override
  String get troubleTrailingVaultData =>
      'This vault file has extra data after its end and was not opened.';

  @override
  String get troubleProviderUnavailable =>
      'That AI provider is not available in this build.';

  @override
  String get oneWordWaits => 'One word waits for your answer — nothing left Z.';

  @override
  String wordsWait(int count) {
    return '$count words wait for your answer — nothing left Z.';
  }

  @override
  String get troubleVaultAbsent =>
      'There is no vault on this device yet. Create one to keep anything for tomorrow.';

  @override
  String get troubleVaultAlreadyExists =>
      'A vault already exists on this device, and Z Privacy will not write over it.';

  @override
  String troubleStorageRefused(String reason) {
    return 'Z Privacy will not use that location — $reason';
  }

  @override
  String get everyCellWasAlreadyProtected =>
      'Every cell in that column was already protected.';

  @override
  String protectedOneCell(String token) {
    return 'Protected one cell, as $token.';
  }

  @override
  String protectedCellsDownTheColumn(int places, String token) {
    return 'Protected $places cells down that column, the first as $token.';
  }

  @override
  String protectedAs(String token) {
    return 'Protected as $token.';
  }

  @override
  String protectedAsInPlaces(String token, int places) {
    return 'Protected as $token, in $places places.';
  }

  @override
  String alreadyProtectedBy(String token, String who) {
    return 'Already protected as $token, by $who.';
  }

  @override
  String belongsToEntity(String entity, String token) {
    return 'That belongs to $entity and keeps its token $token.';
  }

  @override
  String pressCutsIntoProtectedTextOne(String what) {
    return '$what cuts into protected text, so nothing changed. It would snap to 1 whole item.';
  }

  @override
  String pressCutsIntoProtectedTextMany(String what, int items) {
    return '$what cuts into protected text, so nothing changed. It would snap to $items whole items.';
  }

  @override
  String get theSelection => 'The selection';

  @override
  String get thatCell => 'That cell';

  @override
  String get thatPlace => 'That place';

  @override
  String get sourceRule => 'Rule';

  @override
  String get sourcePack => 'Pack';

  @override
  String get sourceVault => 'Vault';

  @override
  String get sourceYou => 'You';

  @override
  String get answeredByHand => 'brought back by hand';

  @override
  String get answeredNotRecorded => 'not recorded';

  @override
  String get oneNameCameBack => 'One name came back.';

  @override
  String namesCameBack(int count) {
    return '$count names came back.';
  }

  @override
  String oneNameCameBackFrom(String sessions) {
    return 'One name came back from $sessions.';
  }

  @override
  String namesCameBackFrom(int count, String sessions) {
    return '$count names came back from $sessions.';
  }

  @override
  String thisDocumentCameBackFrom(String sessions) {
    return 'This document came back from $sessions.';
  }

  @override
  String get oneNameIsStillATokenVaultShut =>
      'One name is still a token: unlock or create your vault and Z can look for it.';

  @override
  String namesAreStillTokensVaultShut(int count) {
    return '$count names are still tokens: unlock or create your vault and Z can look for them.';
  }

  @override
  String get oneNameStaysATokenTwoCauses =>
      'One name stays as a token, and two different things do that: the word was protected before Z Privacy began keeping every protected word, or this token was changed after the file left. Open that document in its session and protect the name again — if it comes back from then on it was the first, and if it does not, this file is not the one Z Privacy wrote.';

  @override
  String namesStayTokensTwoCauses(int count) {
    return '$count names stay as tokens, and two different things do that: they were protected before Z Privacy began keeping every protected word, or the tokens were changed after the file left. Open those documents in their session and protect the names again — if they come back from then on it was the first, and if they do not, this file is not the one Z Privacy wrote.';
  }

  @override
  String get refusalMalformedDocument =>
      'This document is damaged or incomplete.';

  @override
  String get refusalEncryptedPdf =>
      'This PDF is password-protected. Remove the password and try again.';

  @override
  String get refusalScannedOnePage =>
      'This PDF is a picture of a page with no text in it, so nothing could be read — and Z Privacy will not import a document it cannot see.';

  @override
  String refusalScannedPages(int pages) {
    return 'This PDF is $pages pages of pictures with no text in them, so nothing could be read.';
  }

  @override
  String refusalUnsupportedEncoding(int readablePercent, int page) {
    return 'Only $readablePercent% of page $page decoded into characters, so this document is refused rather than half-read. Open it and save it as text, or paste the text in.';
  }

  @override
  String refusalUnreadableStructure(int page) {
    return 'Page $page is built in a way this build cannot read.';
  }

  @override
  String refusalDocumentTooLarge(int mib, int limitMib) {
    return 'This file is about $mib MiB, and Z Privacy opens documents up to $limitMib MiB.';
  }

  @override
  String refusalTooManyPages(int pages, int limit) {
    return 'This document has $pages pages, and Z Privacy opens up to $limit in one document.';
  }

  @override
  String refusalTextTooLarge(int limitMib) {
    return 'Unpacked, a part of this file is more than $limitMib MiB — more than Z Privacy reads in one document, so none of it was imported.';
  }

  @override
  String refusalCompressionBomb(int ratio) {
    return 'A part of this file unpacks to more than $ratio times the space it takes up. No real document does that, so Z Privacy stopped unpacking it instead of filling the machine.';
  }

  @override
  String refusalTooManyParts(int parts, int limit) {
    return 'This file lists $parts parts inside it, and a document has tens, not thousands — Z Privacy opens up to $limit.';
  }

  @override
  String refusalTookTooLong(int seconds) {
    return 'Reading this file was still going after $seconds seconds, so Z Privacy stopped. Nothing of it was imported.';
  }

  @override
  String get refusalEmptyDocument =>
      'There is no text in this file for Z Privacy to protect.';

  @override
  String get networkNotConnected =>
      'No AI provider is connected. Add an address and a key first.';

  @override
  String get networkInsecureUrl => 'That address is not safe to send to.';

  @override
  String get networkRedirected =>
      'That address sent us somewhere else. Z Privacy does not follow redirects with your text, so nothing was sent.';

  @override
  String networkBadStatus(int status) {
    return 'The provider refused the request with status $status. Nothing of your document was kept by Z Privacy.';
  }

  @override
  String get networkTimeout =>
      'The provider did not answer in time. Nothing else was sent.';

  @override
  String networkResponseTooLarge(int limitKib) {
    return 'The answer was larger than $limitKib KiB and was not read.';
  }

  @override
  String networkPayloadTooLarge(int kib, int limitKib) {
    return 'This text is $kib KiB and the provider accepts $limitKib KiB in one request.';
  }

  @override
  String get networkUnreadable =>
      'The provider answered with something that is not an answer.';

  @override
  String get networkUnreachable =>
      'That address could not be reached at all — nothing answered. Check that you are online and that the address is right. Nothing was sent.';

  @override
  String get troubleVaultChangedElsewhere =>
      'Another copy of Z Privacy changed this vault. Close that window, or lock and unlock here to take in its work.';

  @override
  String troubleStoragePermissionsKept(String reason) {
    return 'Z Privacy will not change a permission you set, so nothing was saved — $reason. Change the permission yourself, or choose another folder.';
  }

  @override
  String get troubleBadSpan =>
      'That selection could not be read. Try selecting the words again.';

  @override
  String get troubleBetweenColumns =>
      'That press landed in the space between two columns, so it names no value — and Z Privacy will not choose a column for you.';

  @override
  String get troubleUnknownToken =>
      'That protected value is not in this session.';

  @override
  String get troubleNothingToSend =>
      'There is nothing to send yet. Bring in a document or write some text.';

  @override
  String get troubleSessionWithoutItsDocument =>
      'The session was not started, because Z Privacy could not tell which document you have open — and a session has to rename what is already protected on it. Nothing was changed. Open the document and start the session from there.';

  @override
  String get troublePayloadAlreadySent =>
      'This request was already sent. Prepare it again to send once more.';

  @override
  String get theReasonWasNotReported => 'the reason was not reported.';

  @override
  String get carriesFirst => 'This document carries';

  @override
  String get carriesAlso => 'It also carries';

  @override
  String carriesOneNameFromElsewhere(String also, String which) {
    return '$also 1 name from a session this vault does not hold ($which). Nothing here can put it back: the key that made it is not in this vault.';
  }

  @override
  String carriesNamesFromOneSessionElsewhere(
    String also,
    int count,
    String which,
  ) {
    return '$also $count names from a session this vault does not hold ($which). Nothing here can put them back: the key that made them is not in this vault.';
  }

  @override
  String carriesNamesFromSessionsElsewhere(
    String also,
    int count,
    String which,
  ) {
    return '$also $count names from sessions this vault does not hold ($which). Nothing here can put them back: the keys that made them are not in this vault.';
  }

  @override
  String carriesNamesFromElsewhereWithNoCount(
    String also,
    String whose,
    String which,
    String keys,
  ) {
    return '$also names from $whose ($which). Nothing here can put them back: $keys not in this vault.';
  }

  @override
  String get aSessionThisVaultDoesNotHold =>
      'a session this vault does not hold';

  @override
  String get sessionsThisVaultDoesNotHold =>
      'sessions this vault does not hold';

  @override
  String get theKeyThatMadeThemIs => 'the keys that made them are';

  @override
  String get andBetweenNames => ' and ';
}
