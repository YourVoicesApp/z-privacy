// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppLocalizationsSv extends AppLocalizations {
  AppLocalizationsSv([String locale = 'sv']) : super(locale);

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

  @override
  String get thisLanguageName => 'Svenska';

  @override
  String get languageWord => 'Language';

  @override
  String get chooseALanguage => 'Choose a language to continue.';

  @override
  String get noAccount => 'No account.';

  @override
  String get noAds => 'No ads.';

  @override
  String get noAnalytics => 'No analytics.';

  @override
  String get noZPrivacyServer => 'No Z Privacy server.';

  @override
  String get originalDataStaysHere =>
      'Your original data stays on this device unless you explicitly copy restored content.';

  @override
  String get onlyTheProtectedVersionIsSent =>
      'Only the protected version is sent to AI through Z Privacy.';

  @override
  String get theseRulesWillBeEnabled =>
      'The English privacy rules will be enabled.';

  @override
  String get start => 'Start';

  @override
  String get yourVault => 'Your vault';

  @override
  String get createAVault => 'Create a vault';

  @override
  String get vaultWhy =>
      'Every word you protect lives here, for as long as you keep this vault: the names you add, the values you teach, and the keys to any AI you connect. It stays on this computer, and nothing is written anywhere else.';

  @override
  String get onePassphrase =>
      'One passphrase, kept on this device. Everything Z learns while you work — your names, your lists, your decisions — is kept in it.';

  @override
  String get byYourVoices => 'by YourVoices';

  @override
  String pageHasNothingMarked(int page) {
    return 'Page $page has nothing the scanner marked.';
  }

  @override
  String get addADocumentPdfWordOrText => 'Add a document — PDF, Word or text';

  @override
  String get addADocumentOrWriteToTheAi =>
      'Add a document — or write to the AI in the first part, with no document at all.';

  @override
  String get originalLocalOnly => 'Original — local only';

  @override
  String get neverSentToAiSendCannotRead =>
      'Never sent to AI · Send cannot read this side';

  @override
  String get yourDocumentArrivesHere =>
      'Your document arrives here, as it is written. Nothing on this side can reach the network.';

  @override
  String get safeAiWillReceive => 'Safe — AI will receive';

  @override
  String get theRequestItselfNotAPreview =>
      'The request itself, not a preview of it';

  @override
  String get whatAnAiWouldReceiveStandsHere =>
      'What an AI would receive stands here beside the original, word for word, before anything is sent.';

  @override
  String get theChatTitle => 'The chat';

  @override
  String get yourQuestionsAndWhatCameBack =>
      'Your questions, and what came back';

  @override
  String get theChatOpensHereWithTheFirstAnswer =>
      'The chat opens here with the first answer, and every question after it carries what was already said.';

  @override
  String get typedText => 'Typed text';

  @override
  String get onePage => '1 page';

  @override
  String pagesCount(int pages) {
    return '$pages pages';
  }

  @override
  String get vaultLabel => 'Vault';

  @override
  String get vaultIsUnlocked => 'Unlocked';

  @override
  String get vaultIsLocked => 'Locked';

  @override
  String get vaultIsNone => 'None';

  @override
  String get openZVault => 'Open Z Vault';

  @override
  String get lockNow => 'Lock now';

  @override
  String get openZVaultOrLockItNow => 'Open Z Vault, or lock it now';

  @override
  String get goToAPage => 'Go to a page';

  @override
  String pageNumber(int page) {
    return 'Page $page';
  }

  @override
  String get pageWord => 'Page';

  @override
  String get chooseTheAiAndWhatTravels =>
      'Choose the AI and what travels to it';

  @override
  String get readThisDocumentWithAnotherRuleSet =>
      'Read this document with another rule set';

  @override
  String get generalRulesOnly => 'General rules only';

  @override
  String get packLabel => 'Pack';

  @override
  String packWithGeneralRules(String pack) {
    return '$pack · general rules';
  }

  @override
  String get everywhere => 'Everywhere';

  @override
  String get profile => 'Profile';

  @override
  String get profiles => 'Profiles';

  @override
  String get chooseWhichClientDictionary =>
      'Choose which client dictionary this session uses. The profile ID stays inside the vault; the display name is what people see.';

  @override
  String get onlyIdentitiesForEveryProfile =>
      'Only identities and rules that apply to every profile.';

  @override
  String get createProfile => 'Create profile';

  @override
  String get done => 'Done';

  @override
  String get rename => 'Rename';

  @override
  String get profileActive => 'Active';

  @override
  String get profileSwitch => 'Switch';

  @override
  String get readItBack => 'Read it back';

  @override
  String get scanning => 'Scanning…';

  @override
  String get notScannedYet => 'Not scanned yet';

  @override
  String get asItWasKept => 'As it was kept';

  @override
  String lastScanNote(String note) {
    return 'Last scan: $note';
  }

  @override
  String get scannedOnImport => 'Scanned on import';

  @override
  String get lastScanManualRescan => 'Last scan: manual rescan';

  @override
  String alreadyProtectedNothingScanned(int marks) {
    return '$marks already protected · nothing scanned in this run';
  }

  @override
  String protectedAutomaticallyNeedYourWord(int auto, int open, int normal) {
    return '$auto protected automatically · $open need your word · $normal normal';
  }

  @override
  String get vaultLockedRulesAndPackRan =>
      'Vault locked — rules and pack ran, the vault layer did not';

  @override
  String get noVaultNothingRecognisedByName =>
      'No vault — nothing is recognised by name';

  @override
  String get unlock => 'Unlock';

  @override
  String get removeTheDocument => 'Remove the document';

  @override
  String get nothingIsOpen => 'Nothing is open.';

  @override
  String get thereIsNothingToSendYet => 'There is nothing to send yet.';

  @override
  String get readingWhatThoseLinesHold => 'Reading what those lines hold…';

  @override
  String oneLineProtectedOpen(int protected, int open) {
    return '1 line · $protected protected in it · $open open';
  }

  @override
  String linesProtectedOpen(int lines, int protected, int open) {
    return '$lines lines · $protected protected in them · $open open';
  }

  @override
  String get pressAValueToProtectEveryHeldLine =>
      'Press a value to protect the same cell in every held line.';

  @override
  String get letTheLinesGo => 'Let the lines go';

  @override
  String get inStep => 'In step';

  @override
  String get apart => 'Apart';

  @override
  String get drawnAsChips => 'Chips';

  @override
  String get drawnPlain => 'Plain';

  @override
  String get oneSuggestionStillOpen =>
      'One suggestion is still open. Until you answer it, it stands here as written — real text on this side.';

  @override
  String suggestionsStillOpen(int open) {
    return '$open suggestions are still open. Until you answer them, they stand here as written — the only real text on this side.';
  }

  @override
  String get chooseWhoAnswers => 'Choose who answers';

  @override
  String get showTheChat => 'Show the chat';

  @override
  String get whatWouldYouLikeToAskTheAi => 'What would you like to ask the AI?';

  @override
  String get whatShouldTheAiDoWithThis => 'What should the AI do with this?';

  @override
  String get askAQuestionOrPasteALetter =>
      'Ask a question, or paste a whole letter here.';

  @override
  String get reconcileSectionAgainstSection =>
      'Reconcile section A against section B and tell me where the difference is.';

  @override
  String get inWhatWillLeave => 'In what will leave';

  @override
  String get addItToWhatWillLeave => 'Add it to what will leave';

  @override
  String get aDocumentCanBeSentWithNoRequest =>
      'A document can be sent with no request, and then the model is given no instruction';

  @override
  String get takeItOut => 'Take it out';

  @override
  String get yourRequestNothingToProtect =>
      'Your request is in the Safe column, with nothing in it to protect.';

  @override
  String get yourRequestOneValueReplaced =>
      'Your request is in the Safe column, with one value replaced.';

  @override
  String yourRequestValuesReplaced(int count) {
    return 'Your request is in the Safe column, with $count values replaced.';
  }

  @override
  String get oneRequestAtATime =>
      'One request at a time — a new question replaces this one, and the chat keeps every exchange.';

  @override
  String get oneQuestionLeftGoToIt => '1 question left — go to it';

  @override
  String questionsLeftGoToTheFirst(int open) {
    return '$open questions left — go to the first';
  }

  @override
  String get protectIt => 'Protect it';

  @override
  String get leaveItInTheClear => 'Leave it in the clear';

  @override
  String theOneLeftIsKind(String kind) {
    return 'The one left is $kind.';
  }

  @override
  String get showWhatTheAiWillReceive => 'Show what the AI will receive';

  @override
  String get hideThisColumn => 'Hide this column';

  @override
  String get narrowThisPanel => 'Narrow this panel';

  @override
  String get widenThisPanel => 'Widen this panel';

  @override
  String get oneExchangeCarriedIntoTheNext =>
      'One exchange, carried into the next question.';

  @override
  String exchangesCarriedIntoTheNext(int count) {
    return '$count exchanges, carried into the next question.';
  }

  @override
  String get putTheChatAwayItIsNotEnded =>
      'Put the chat away — it is not ended';

  @override
  String get theFirstAnswerOpensTheChatHere =>
      'The first answer opens the chat here. Every question after it carries what was already said.';

  @override
  String get askSomethingElseAboutThis => 'Ask something else about this…';

  @override
  String get pasteTheAnswerYouWereGiven => 'Paste the answer you were given…';

  @override
  String get addItToTheChat => 'Add it to the chat';

  @override
  String get notNow => 'Not now';

  @override
  String get copyTheChat => 'Copy the chat';

  @override
  String get addAnAnswer => 'Add an answer';

  @override
  String get endTheChat => 'End the chat';

  @override
  String get theChatIsOnYourClipboard =>
      'The chat is on your clipboard, protected — bring the answer back with «Add an answer».';

  @override
  String get couldNotReadTheClipboard =>
      'Z Privacy could not read the clipboard.';

  @override
  String get thereIsNoTextOnTheClipboard =>
      'There is no text on the clipboard.';

  @override
  String get hideTheText => 'Hide the text';

  @override
  String get showTheText => 'Show the text';

  @override
  String get theTextWithYourNamesBack =>
      'The text, with your names back — on this device';

  @override
  String get thisAnswerCarriesOneUnknownToken =>
      'This answer carries 1 token this session does not know — it was made in another session.';

  @override
  String thisAnswerCarriesUnknownTokens(int count) {
    return 'This answer carries $count tokens this session does not know — they were made in another session.';
  }

  @override
  String get copyRestored => 'Copy Restored';

  @override
  String get theMarkedWordsWerePutBackHere =>
      'The marked words were put back here, on this device. The model never saw them.';

  @override
  String get theDottedWordsWerePutBackHere =>
      'The dotted words were put back here, on this device. The struck ones are tokens this session cannot put back.';

  @override
  String get copyRestoredTextQuestion => 'Copy restored text?';

  @override
  String get thisWillPlaceTheRealValues =>
      'This will place the real protected values on your system clipboard. Other applications may be able to read the clipboard.';

  @override
  String get cancel => 'Cancel';

  @override
  String get restoredTextCopied =>
      'Restored text copied to the system clipboard.';

  @override
  String get chooseWhoAnswersInTheMiddleFirst =>
      'Choose who answers in the middle column first';

  @override
  String sendThisQuestionTo(String name) {
    return 'Send this question to $name';
  }

  @override
  String get writeAQuestionFirst => 'Write a question first.';

  @override
  String get settings => 'Settings';

  @override
  String get roomPrivacy => 'Privacy';

  @override
  String get roomLanguageAndRules => 'Language & rules';

  @override
  String get roomVaultAndSecurity => 'Vault & security';

  @override
  String get roomSessions => 'Sessions';

  @override
  String get languageAndRulesWhat =>
      'A privacy pack is a detection engine, not the language of the interface — and more than one pack can run in a single scan, so this is a starting point rather than the only rules allowed.';

  @override
  String get appLanguage => 'App language';

  @override
  String get appLanguageWhat =>
      'The language a session is read with when it has none of its own — and which habits the scanner knows in it: salutations, company forms, the way a customer number is written. A session created with a language of its own keeps that one; this is what every other text is read with. The interface follows this choice.';

  @override
  String theInterfaceIsEnglishUntilTranslated(String language) {
    return '$language: the detection pack is $language; the interface is English until its sentences are translated.';
  }

  @override
  String get myPrivacyRules => 'My privacy rules';

  @override
  String get myPrivacyRulesWhat =>
      'Not built yet. Rules you write yourself — a customer number format only your office uses, a project codename — will live here, beside the pack rather than inside it.';

  @override
  String get vaultAndSecurityWhat =>
      'The key, the lock, and where a credential lives.';

  @override
  String get zVault => 'Z Vault';

  @override
  String get vaultOpenWhat =>
      'Open. Your identities are loaded and the fourth detection layer is running.';

  @override
  String get vaultLockedWhat =>
      'Locked. The rules and the pack still run — an IBAN is still caught — but not who it belongs to.';

  @override
  String get vaultAbsentWhat =>
      'Not created on this device. Nothing is recognised by name.';

  @override
  String unlockedWithIdentities(int count) {
    return 'Unlocked · $count identities';
  }

  @override
  String get zPdfReadBack => 'z-pdf — read a protected document back';

  @override
  String get zPdfWhat =>
      'The reverse act. A document that left this app with tokens in it is read back into its own names, here, from your vault — and it is never scanned, never protected and never put on a bench. Nothing of it is sent anywhere.';

  @override
  String get openThisPanelFromTheApp =>
      'Open this panel from the app to choose a file.';

  @override
  String get chooseAZPdfFile => 'Choose a z-pdf file';

  @override
  String get lockTheVaultAfter => 'Lock the vault after';

  @override
  String get minutesUnusedZeroIsNever => 'minutes unused · 0 = never';

  @override
  String get lockTheVaultAfterWhat =>
      'Kept by the vault itself, not by a timer in a screen: every way into it checks the clock first, so a bug in the interface cannot leave it open.';

  @override
  String get encryptedLocalCredentialStorage =>
      'Encrypted local credential storage';

  @override
  String get credentialHomesWhat =>
      'A provider key has two homes and no third: sealed inside the vault when one is open, or in memory for this run when there is none. Never a file in the clear, and never returned to the interface — there is no call in the whole contract that gives one back.';

  @override
  String get credentialSealedInTheVault => 'sealed in the vault';

  @override
  String get credentialInMemory => 'in memory, gone when the app closes';

  @override
  String get credentialNoKeyStored => 'no key stored';

  @override
  String get noProviderHoldsACredential => 'No provider holds a credential.';

  @override
  String get deviceBoundProtection => 'Device-bound protection';

  @override
  String get deviceBoundWhat =>
      'Not built yet. A key tied to this device’s own authentication would sit above the layer above, without changing what is stored — the same records, one more lock.';

  @override
  String get sessionsWhat =>
      'A session keeps its own key, and the keys are in the vault.';

  @override
  String get theVaultIsShutNoSessions =>
      'The vault is shut, so there are no sessions to show. Open it and they come back — the conversations themselves were never in it.';

  @override
  String get eachSessionHasItsOwnEncryption =>
      'Each session has its own encryption. The same name in two sessions takes two different tokens, and in one session it takes the same one wherever it appears — so a session is how you choose what an AI can line up and what it cannot.';

  @override
  String get newSession => 'New session';

  @override
  String get newSessionWhat =>
      'A name and a language, both yours to choose: the language is how Z reads every text in this session, and it is asked once here. It becomes the session you are working in straight away. Anything already protected on the document in front of you is renamed into it — nothing has been sent yet, so nothing that left is affected.';

  @override
  String get whatIsThisOneAbout => 'What is this one about?';

  @override
  String get begin => 'Begin';

  @override
  String get noSessionsYet => 'No sessions yet';

  @override
  String get noSessionsYetWhat =>
      'One is born the first time you copy safe text or ask for a PDF — it is not refused for want of a name, it takes its own number for one, and you can rename it here. You never have to make one by hand first.';

  @override
  String theOneYouAreIn(String when, String exchanges) {
    return '$when · $exchanges · the one you are in';
  }

  @override
  String get workInThisSession => 'Work in this session';

  @override
  String get enter => 'Enter';

  @override
  String get renameThisSession => 'Rename this session';

  @override
  String get deleteThisSession => 'Delete this session';

  @override
  String get oneExchange => '1 exchange';

  @override
  String exchangesCount(int count) {
    return '$count exchanges';
  }

  @override
  String renameSessionNumber(int number) {
    return 'Rename session $number?';
  }

  @override
  String theNumberStaysWhatItIs(int number) {
    return 'The number stays $number — it is what this session is, and nothing that was protected in it changes. Only the word on the row does.';
  }

  @override
  String get keepTheName => 'Keep the name';

  @override
  String get renameIt => 'Rename it';

  @override
  String deleteNamed(String name) {
    return 'Delete «$name»?';
  }

  @override
  String get thisDestroysTheKey =>
      'This destroys the key this session was protected with.';

  @override
  String get everyDocumentCanNeverBeUnprotected =>
      'Every document and every message protected in it can never be unprotected again — not by you, and not by Z Privacy. The key was the only thing that could have done it, and it will not exist.';

  @override
  String get anythingYouSentStaysAsItWas =>
      'Anything you sent out of this session stays exactly as it was. What goes is the way back from it.';

  @override
  String get keepIt => 'Keep it';

  @override
  String get deleteTheSession => 'Delete the session';

  @override
  String get oneProtectedPlace => '1 protected place';

  @override
  String protectedPlacesCount(int count) {
    return '$count protected places';
  }

  @override
  String get renameThisDocument => 'Rename this document';

  @override
  String renameHandle(String handle) {
    return 'Rename $handle?';
  }

  @override
  String theNameIsWhatYouRead(String handle) {
    return 'The name is what you read in this list. $handle stays what it is: a number is spent once and never given to another document.';
  }

  @override
  String get aNameForThisDocument => 'A name for this document';

  @override
  String get roomAi => 'AI';

  @override
  String get aiWhat =>
      'Three ways to ask a model. The first needs no account at all.';

  @override
  String get manualAi => 'Manual AI';

  @override
  String get manualAiWhat =>
      'Use an AI chat you already have. Copy the safe text out of the Workspace, paste it into whatever model you use, and bring the answer back. Nothing to set up, nothing to pay for, and the restoring works exactly the same.';

  @override
  String get alwaysAvailableFirstDoor =>
      'Always available — it is the «Choose who answers» sheet, first door.';

  @override
  String get directApi => 'Direct API';

  @override
  String get directApiWhat =>
      'Connect to a remote AI provider with your API credential. The key goes in once and never comes back out — no screen in this app can show it to you again.';

  @override
  String get atThisAddressNoCredential =>
      'At this address no credential is needed.';

  @override
  String get protocol => 'Protocol';

  @override
  String get connectedKeySealed => 'Connected · key sealed in the vault';

  @override
  String get connectedKeyThisRunOnly =>
      'Connected · key kept for this run only';

  @override
  String get connectedNoKeyNeeded => 'Connected · no key needed';

  @override
  String get notConnected => 'Not connected';

  @override
  String get localAi => 'Local AI';

  @override
  String get localAiWhat =>
      'Runs through an AI service on this computer — llama.cpp, Ollama, LM Studio, anything that answers the same shape. No key, no account, and the request never leaves this computer. Plain http is accepted only for a literal loopback address.';

  @override
  String get models => 'Models';

  @override
  String get privacyWhat =>
      'What the app does by itself, and how far it goes without asking.';

  @override
  String get noVaultSoThisRunOnly =>
      'There is no vault open, so these are for this run only. The vault is the one file this app writes — without it, nothing is remembered.';

  @override
  String get scanOnArrival => 'Scan a document the moment it arrives';

  @override
  String get scanOnArrivalWhat =>
      'No dialog, no button. Turning this off means a document sits unprotected until you press Rescan — which is exactly the moment the boards were written to avoid.';

  @override
  String get answerEverySuggestion => 'Answer every suggestion before sending';

  @override
  String get answerEverySuggestionWhat =>
      'Not a setting. A suggestion that has not been answered is never quietly treated as safe, and there is no «send anyway» — not here, not in a hidden flag, not anywhere in the code.';

  @override
  String get aRevealedValueStaysFor => 'A revealed value stays for';

  @override
  String get aRevealedValueStaysForWhat =>
      'Revealing draws on the screen and never writes into what leaves. This is only how long it stays drawn.';

  @override
  String get tokenRotation => 'Token rotation';

  @override
  String get tokenRotationWhat =>
      'Not built yet. When it is, it will live here: whether a permanent token keeps its number across sessions, or is drawn again each time so two sessions cannot be linked by it.';
}
