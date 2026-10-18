import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_sv.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('sv'),
  ];

  /// The refusal a send gets back when a provider's key is sealed in a locked vault, and the same sentence the compose line and the Direct API card say before a press. Both moves are named because a shut vault answers nothing about its contents.
  ///
  /// In en, this message translates to:
  /// **'Z Privacy cannot reach a key while the vault is locked. Unlock it, or give a key for this run.'**
  String get theKeyIsBehindTheLockedVault;

  /// Under an empty thread in the chat, when an answer came back and no session could keep it.
  ///
  /// In en, this message translates to:
  /// **'This answer is on your screen and nowhere else: no session is open to keep it, so closing the app ends it with the chat.'**
  String get theChatKeepsNothing;

  /// One press on a word Z Privacy had already protected: the Protect button over a selection, and the column press.
  ///
  /// In en, this message translates to:
  /// **'This is already protected — Z put it there.'**
  String get theTokenIsAlreadyOurs;

  /// The last resort for an outcome no sentence names: what did not happen, never «invalid call».
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Z Privacy did not complete the action.'**
  String get unnamedTrouble;

  /// Beside a preview side — the work surface's Safe column and the chat's own band — about the text it draws. One sentence for both, so two screens cannot word one fact two ways.
  ///
  /// In en, this message translates to:
  /// **'This is exactly what the AI will receive. {replaced} values were replaced.'**
  String exactlyWhatWouldLeave(int replaced);

  /// Rule 57-د, when «Not now» answers the language question and a session is already open: what did not happen, and the two ways to make it happen.
  ///
  /// In en, this message translates to:
  /// **'Nothing was read. A text is read with one language’s habits, and this session has never been given one — so Z Privacy did not choose for you. Read it again and answer, or give the session its language in Settings.'**
  String get noLanguageAndASessionIsOpen;

  /// Rule 57-د, the same answer where no session exists yet: nothing can be given a language, so the only move is to choose one.
  ///
  /// In en, this message translates to:
  /// **'Nothing was read. A text is read with one language’s habits, and none was chosen — so nothing was read and no session was made. Try again and choose one.'**
  String get noLanguageAndNoSession;

  /// The sentence for ApiError.notImplemented.
  ///
  /// In en, this message translates to:
  /// **'This part of Z Privacy is not built yet.'**
  String get troubleNotImplemented;

  /// ApiError.invalidSession.
  ///
  /// In en, this message translates to:
  /// **'That session is no longer open. Start a new one.'**
  String get troubleInvalidSession;

  /// ApiError.invalidHandle — the payload a press names is not the one the session has.
  ///
  /// In en, this message translates to:
  /// **'This request is no longer current. Review the text again before sending.'**
  String get troubleInvalidHandle;

  /// ApiError.stalePayload — the document moved under a prepared request.
  ///
  /// In en, this message translates to:
  /// **'The document changed after this request was prepared. Review it again, so that what you send is what you last saw.'**
  String get troubleStalePayload;

  /// ApiError.vaultLocked — every door that needs the vault open. Not the network refusal of the same name, which is about a key and says both moves.
  ///
  /// In en, this message translates to:
  /// **'Your vault is locked. Unlock it to use what it knows.'**
  String get troubleVaultLocked;

  /// ApiError.vaultRequired — an act that would keep something for tomorrow, with no vault to keep it in.
  ///
  /// In en, this message translates to:
  /// **'Unlock or create your vault before saving this for future use.'**
  String get troubleVaultRequired;

  /// ApiError.vaultAuthenticationFailed — both causes named, because the app cannot tell them apart and neither can the person without being told.
  ///
  /// In en, this message translates to:
  /// **'Could not unlock the vault. The passphrase may be incorrect, or the vault may be corrupted or modified.'**
  String get troubleVaultAuthenticationFailed;

  /// ApiError.unsupportedKdfParameters — a vault written by another build's key derivation.
  ///
  /// In en, this message translates to:
  /// **'This vault uses unsupported security settings.'**
  String get troubleUnsupportedKdfParameters;

  /// ApiError.trailingVaultData — bytes after the sealed end, so the file is refused rather than half-read.
  ///
  /// In en, this message translates to:
  /// **'This vault file has extra data after its end and was not opened.'**
  String get troubleTrailingVaultData;

  /// ApiError.providerUnavailable — the id names no provider this build carries.
  ///
  /// In en, this message translates to:
  /// **'That AI provider is not available in this build.'**
  String get troubleProviderUnavailable;

  /// 083a — an exit refused because a suggestion is open, in the singular. «nothing left Z» is the second half a person needs at that moment.
  ///
  /// In en, this message translates to:
  /// **'One word waits for your answer — nothing left Z.'**
  String get oneWordWaits;

  /// 083a — the same refusal in the plural, with the core's own count.
  ///
  /// In en, this message translates to:
  /// **'{count} words wait for your answer — nothing left Z.'**
  String wordsWait(int count);

  /// ApiError.vaultAbsent — an empty or missing vault file, which is «there is none» and not «it is locked».
  ///
  /// In en, this message translates to:
  /// **'There is no vault on this device yet. Create one to keep anything for tomorrow.'**
  String get troubleVaultAbsent;

  /// ApiError.vaultAlreadyExists — the one refusal that protects a person's own bytes from a second «create».
  ///
  /// In en, this message translates to:
  /// **'A vault already exists on this device, and Z Privacy will not write over it.'**
  String get troubleVaultAlreadyExists;

  /// ApiError.storageRefused — the place is at fault, and the core's own reason names which one and why. The reason arrives lower-cased, as the core wrote it.
  ///
  /// In en, this message translates to:
  /// **'Z Privacy will not use that location — {reason}'**
  String troubleStorageRefused(String reason);

  /// A column press that found nothing left to do: the core answers «places: 0», which is this and not «protected in 0 places».
  ///
  /// In en, this message translates to:
  /// **'Every cell in that column was already protected.'**
  String get everyCellWasAlreadyProtected;

  /// A column press that protected a single cell. {token} is the core's own placeholder name — never translated.
  ///
  /// In en, this message translates to:
  /// **'Protected one cell, as {token}.'**
  String protectedOneCell(String token);

  /// A column press over several cells. The token named is the first one, as the core reports it.
  ///
  /// In en, this message translates to:
  /// **'Protected {places} cells down that column, the first as {token}.'**
  String protectedCellsDownTheColumn(int places, String token);

  /// One place protected by a press on a selection or on a place the bar found.
  ///
  /// In en, this message translates to:
  /// **'Protected as {token}.'**
  String protectedAs(String token);

  /// The same press where the value stands in more than one place: one token, every place.
  ///
  /// In en, this message translates to:
  /// **'Protected as {token}, in {places} places.'**
  String protectedAsInPlaces(String token, int places);

  /// A press on a word that is protected already, with who by — a rule, a pack, the vault, or the person. {who} comes from the source names below, lower-cased by the caller.
  ///
  /// In en, this message translates to:
  /// **'Already protected as {token}, by {who}.'**
  String alreadyProtectedBy(String token, String who);

  /// A press on a value the vault holds for a client: the token is that client's and does not change here.
  ///
  /// In en, this message translates to:
  /// **'That belongs to {entity} and keeps its token {token}.'**
  String belongsToEntity(String entity, String token);

  /// A press whose selection crosses a protected word, where snapping would take a single whole item. {what} is the subject below.
  ///
  /// In en, this message translates to:
  /// **'{what} cuts into protected text, so nothing changed. It would snap to 1 whole item.'**
  String pressCutsIntoProtectedTextOne(String what);

  /// The same refusal where snapping would take several whole items, so a second press is a decision and not a surprise.
  ///
  /// In en, this message translates to:
  /// **'{what} cuts into protected text, so nothing changed. It would snap to {items} whole items.'**
  String pressCutsIntoProtectedTextMany(String what, int items);

  /// The subject of the sentence above, when the press was on a selection.
  ///
  /// In en, this message translates to:
  /// **'The selection'**
  String get theSelection;

  /// The subject of the same sentence, when the press was on a table cell.
  ///
  /// In en, this message translates to:
  /// **'That cell'**
  String get thatCell;

  /// The subject of the same sentence, when the press came from a place the search bar found.
  ///
  /// In en, this message translates to:
  /// **'That place'**
  String get thatPlace;

  /// Who protected a word: one of Z Privacy's own rules. Stands in «Already protected as …, by rule.» and in the review's own lines.
  ///
  /// In en, this message translates to:
  /// **'Rule'**
  String get sourceRule;

  /// Who protected a word: the language pack. «Sprachpaket» is the house's word for a pack.
  ///
  /// In en, this message translates to:
  /// **'Pack'**
  String get sourcePack;

  /// Who protected a word: the vault knew the value already.
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get sourceVault;

  /// Who protected a word: the person's own hand.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get sourceYou;

  /// Rule 66 — who answered one turn of a chat, where the person carried the text out and the answer back, so no key of ours answered it.
  ///
  /// In en, this message translates to:
  /// **'brought back by hand'**
  String get answeredByHand;

  /// Who answered a turn older than this round: an absence with more than one cause, said rather than guessed.
  ///
  /// In en, this message translates to:
  /// **'not recorded'**
  String get answeredNotRecorded;

  /// 079, the import side — a returning document whose single name was put back, with no session to name it by.
  ///
  /// In en, this message translates to:
  /// **'One name came back.'**
  String get oneNameCameBack;

  /// The same line for several names, with the core's own count.
  ///
  /// In en, this message translates to:
  /// **'{count} names came back.'**
  String namesCameBack(int count);

  /// The same, naming the sessions that brought something back — only those, never every session in the document. {sessions} is already isolate-marked and joined by the caller.
  ///
  /// In en, this message translates to:
  /// **'One name came back from {sessions}.'**
  String oneNameCameBackFrom(String sessions);

  /// The plural of the line above.
  ///
  /// In en, this message translates to:
  /// **'{count} names came back from {sessions}.'**
  String namesCameBackFrom(int count, String sessions);

  /// A returning document whose sessions are known but which put no name back — so it says where it came from and claims nothing else.
  ///
  /// In en, this message translates to:
  /// **'This document came back from {sessions}.'**
  String thisDocumentCameBackFrom(String sessions);

  /// A returning document with one name Z could not put back, where the vault is shut or absent — both acts named, because a person with no vault cannot unlock one.
  ///
  /// In en, this message translates to:
  /// **'One name is still a token: unlock or create your vault and Z can look for it.'**
  String get oneNameIsStillATokenVaultShut;

  /// The plural of the line above.
  ///
  /// In en, this message translates to:
  /// **'{count} names are still tokens: unlock or create your vault and Z can look for them.'**
  String namesAreStillTokensVaultShut(int count);

  /// 089 rule 4 and the independent attacker's م4: a token with no block has no block for either reason, and this build cannot tell them apart — so both are named and the experiment that separates them is given. Do not shorten this one.
  ///
  /// In en, this message translates to:
  /// **'One name stays as a token, and two different things do that: the word was protected before Z Privacy began keeping every protected word, or this token was changed after the file left. Open that document in its session and protect the name again — if it comes back from then on it was the first, and if it does not, this file is not the one Z Privacy wrote.'**
  String get oneNameStaysATokenTwoCauses;

  /// The plural of the line above, word for word in the same two causes.
  ///
  /// In en, this message translates to:
  /// **'{count} names stay as tokens, and two different things do that: they were protected before Z Privacy began keeping every protected word, or the tokens were changed after the file left. Open those documents in their session and protect the names again — if they come back from then on it was the first, and if they do not, this file is not the one Z Privacy wrote.'**
  String namesStayTokensTwoCauses(int count);

  /// A document the reader could not parse, where the core reported no detail of its own.
  ///
  /// In en, this message translates to:
  /// **'This document is damaged or incomplete.'**
  String get refusalMalformedDocument;

  /// A PDF with its own password: Z Privacy does not ask for one, so the next move is the person's.
  ///
  /// In en, this message translates to:
  /// **'This PDF is password-protected. Remove the password and try again.'**
  String get refusalEncryptedPdf;

  /// A one-page scan with no text layer. The second half is the law: nothing is imported half-read.
  ///
  /// In en, this message translates to:
  /// **'This PDF is a picture of a page with no text in it, so nothing could be read — and Z Privacy will not import a document it cannot see.'**
  String get refusalScannedOnePage;

  /// The same refusal for a scan of several pages.
  ///
  /// In en, this message translates to:
  /// **'This PDF is {pages} pages of pictures with no text in them, so nothing could be read.'**
  String refusalScannedPages(int pages);

  /// A page whose encoding this build cannot turn into characters, with the core's own percentage. Two ways out are named.
  ///
  /// In en, this message translates to:
  /// **'Only {readablePercent}% of page {page} decoded into characters, so this document is refused rather than half-read. Open it and save it as text, or paste the text in.'**
  String refusalUnsupportedEncoding(int readablePercent, int page);

  /// A page whose structure the reader does not support — said of the page, because that is what the core named.
  ///
  /// In en, this message translates to:
  /// **'Page {page} is built in a way this build cannot read.'**
  String refusalUnreadableStructure(int page);

  /// A file over the one-document limit, with both numbers the core's.
  ///
  /// In en, this message translates to:
  /// **'This file is about {mib} MiB, and Z Privacy opens documents up to {limitMib} MiB.'**
  String refusalDocumentTooLarge(int mib, int limitMib);

  /// A document over the page limit.
  ///
  /// In en, this message translates to:
  /// **'This document has {pages} pages, and Z Privacy opens up to {limit} in one document.'**
  String refusalTooManyPages(int pages, int limit);

  /// A part inside a container that unpacks past the limit: nothing is imported, which is the half a person needs.
  ///
  /// In en, this message translates to:
  /// **'Unpacked, a part of this file is more than {limitMib} MiB — more than Z Privacy reads in one document, so none of it was imported.'**
  String refusalTextTooLarge(int limitMib);

  /// A compression bomb, with the core's own ratio and the reason the reading stopped.
  ///
  /// In en, this message translates to:
  /// **'A part of this file unpacks to more than {ratio} times the space it takes up. No real document does that, so Z Privacy stopped unpacking it instead of filling the machine.'**
  String refusalCompressionBomb(int ratio);

  /// A container listing more parts than any real document has.
  ///
  /// In en, this message translates to:
  /// **'This file lists {parts} parts inside it, and a document has tens, not thousands — Z Privacy opens up to {limit}.'**
  String refusalTooManyParts(int parts, int limit);

  /// A reading that ran past its own clock. The caller hands over whole seconds, from the core's milliseconds.
  ///
  /// In en, this message translates to:
  /// **'Reading this file was still going after {seconds} seconds, so Z Privacy stopped. Nothing of it was imported.'**
  String refusalTookTooLong(int seconds);

  /// A file that read clean and held no text at all.
  ///
  /// In en, this message translates to:
  /// **'There is no text in this file for Z Privacy to protect.'**
  String get refusalEmptyDocument;

  /// A send with no credential anywhere — and no vault that could be holding one, which is what tells this apart from the vault-locked refusal.
  ///
  /// In en, this message translates to:
  /// **'No AI provider is connected. Add an address and a key first.'**
  String get networkNotConnected;

  /// An address that is not https and not a machine on this computer, where the core reported no detail to quote.
  ///
  /// In en, this message translates to:
  /// **'That address is not safe to send to.'**
  String get networkInsecureUrl;

  /// A host that answered with a redirect: the payload and the credential were addressed to that host and go nowhere else.
  ///
  /// In en, this message translates to:
  /// **'That address sent us somewhere else. Z Privacy does not follow redirects with your text, so nothing was sent.'**
  String get networkRedirected;

  /// The provider's own status, and the one thing a person wants to know afterwards.
  ///
  /// In en, this message translates to:
  /// **'The provider refused the request with status {status}. Nothing of your document was kept by Z Privacy.'**
  String networkBadStatus(int status);

  /// No answer inside the core's own window.
  ///
  /// In en, this message translates to:
  /// **'The provider did not answer in time. Nothing else was sent.'**
  String get networkTimeout;

  /// An answer over the limit: it is not read at all rather than read in part.
  ///
  /// In en, this message translates to:
  /// **'The answer was larger than {limitKib} KiB and was not read.'**
  String networkResponseTooLarge(int limitKib);

  /// Checked before a socket is opened, so a huge document is refused here rather than turned into an unreasonable request.
  ///
  /// In en, this message translates to:
  /// **'This text is {kib} KiB and the provider accepts {limitKib} KiB in one request.'**
  String networkPayloadTooLarge(int kib, int limitKib);

  /// An answer that arrived but not in the shape the provider promised.
  ///
  /// In en, this message translates to:
  /// **'The provider answered with something that is not an answer.'**
  String get networkUnreadable;

  /// No host at the other end. Both checks are named, and the last half is the one the person needs.
  ///
  /// In en, this message translates to:
  /// **'That address could not be reached at all — nothing answered. Check that you are online and that the address is right. Nothing was sent.'**
  String get networkUnreachable;

  /// 050/A — two windows over one vault. The place is fine; what happened is that somebody else wrote, and both ways out are named.
  ///
  /// In en, this message translates to:
  /// **'Another copy of Z Privacy changed this vault. Close that window, or lock and unlock here to take in its work.'**
  String get troubleVaultChangedElsewhere;

  /// A folder whose permissions would have to be changed to write in it: the program does not touch them, and says both ways out. The reason is the core's, lower-cased.
  ///
  /// In en, this message translates to:
  /// **'Z Privacy will not change a permission you set, so nothing was saved — {reason}. Change the permission yourself, or choose another folder.'**
  String troubleStoragePermissionsKept(String reason);

  /// A selection the core could not turn into a span.
  ///
  /// In en, this message translates to:
  /// **'That selection could not be read. Try selecting the words again.'**
  String get troubleBadSpan;

  /// A press in a table's gutter: the law is that the program does not guess which column was meant.
  ///
  /// In en, this message translates to:
  /// **'That press landed in the space between two columns, so it names no value — and Z Privacy will not choose a column for you.'**
  String get troubleBetweenColumns;

  /// A token whose value this session's key cannot name.
  ///
  /// In en, this message translates to:
  /// **'That protected value is not in this session.'**
  String get troubleUnknownToken;

  /// An exit with nothing behind it, with the two doors in named.
  ///
  /// In en, this message translates to:
  /// **'There is nothing to send yet. Bring in a document or write some text.'**
  String get troubleNothingToSend;

  /// 064f — a birth that could not name the document it would rename. It says what did not happen and what to do, never «invalid call».
  ///
  /// In en, this message translates to:
  /// **'The session was not started, because Z Privacy could not tell which document you have open — and a session has to rename what is already protected on it. Nothing was changed. Open the document and start the session from there.'**
  String get troubleSessionWithoutItsDocument;

  /// A payload that has already left: the same one does not go twice.
  ///
  /// In en, this message translates to:
  /// **'This request was already sent. Prepare it again to send once more.'**
  String get troublePayloadAlreadySent;

  /// The tail of a sentence that quotes the core's own reason, where the core gave none. Lower-cased because it stands inside another sentence.
  ///
  /// In en, this message translates to:
  /// **'the reason was not reported.'**
  String get theReasonWasNotReported;

  /// 079 — the first words of the «names from a session this vault does not hold» sentence, when nothing has been said yet. A piece of one sentence: the pieces are ordered «carries · names · from · (handle) · nothing-here».
  ///
  /// In en, this message translates to:
  /// **'This document carries'**
  String get carriesFirst;

  /// The same opening where a sentence has already been said about this document, so this one adds rather than repeats.
  ///
  /// In en, this message translates to:
  /// **'It also carries'**
  String get carriesAlso;

  /// 079 — a returning document carrying one name whose session this vault has no key for. One sentence and not pieces, because German does not keep the English order; {also} is «This document carries» or «It also carries», and {which} is the namespace's own handle.
  ///
  /// In en, this message translates to:
  /// **'{also} 1 name from a session this vault does not hold ({which}). Nothing here can put it back: the key that made it is not in this vault.'**
  String carriesOneNameFromElsewhere(String also, String which);

  /// The same, several names from one session this vault does not hold.
  ///
  /// In en, this message translates to:
  /// **'{also} {count} names from a session this vault does not hold ({which}). Nothing here can put them back: the key that made them is not in this vault.'**
  String carriesNamesFromOneSessionElsewhere(
    String also,
    int count,
    String which,
  );

  /// The same, several names from more than one session this vault does not hold.
  ///
  /// In en, this message translates to:
  /// **'{also} {count} names from sessions this vault does not hold ({which}). Nothing here can put them back: the keys that made them are not in this vault.'**
  String carriesNamesFromSessionsElsewhere(
    String also,
    int count,
    String which,
  );

  /// 079's own corner: a document whose unresolved names are all accounted for by sessions that could be named, so there is no count to give — «0 names» would be a sentence counting nothing. {whose} and {keys} are the singular or plural halves, handed over by the caller; the composition is the one place in this list where pieces remain, and it is here because the sentence says «names» with no number.
  ///
  /// In en, this message translates to:
  /// **'{also} names from {whose} ({which}). Nothing here can put them back: {keys} not in this vault.'**
  String carriesNamesFromElsewhereWithNoCount(
    String also,
    String whose,
    String which,
    String keys,
  );

  /// A piece of the one composed sentence above: whose the names are, in the singular.
  ///
  /// In en, this message translates to:
  /// **'a session this vault does not hold'**
  String get aSessionThisVaultDoesNotHold;

  /// The same piece in the plural.
  ///
  /// In en, this message translates to:
  /// **'sessions this vault does not hold'**
  String get sessionsThisVaultDoesNotHold;

  /// A piece of the same sentence: which keys are missing, in the plural, as the no-count case always is.
  ///
  /// In en, this message translates to:
  /// **'the keys that made them are'**
  String get theKeyThatMadeThemIs;

  /// 079 — the joiner between two sessions' own names in «One name came back from «A» and «B».» A word on the glass, so it is in the list: German joins with «und», and the spaces are part of it because the names are already isolate-marked and must not touch it.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get andBetweenNames;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'sv'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'sv':
      return AppLocalizationsSv();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
