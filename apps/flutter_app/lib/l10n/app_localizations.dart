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

  /// A language's own name for itself, on the first screen, in its own panel. Never translated: «Deutsch» is what German calls German.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get thisLanguageName;

  /// The word «language» in each language, for the first screen's eyebrow. Before a choice is made the eyebrow carries both, joined by «·» — composed from the two lists rather than written a third time.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageWord;

  /// The first screen, before a language is chosen: one line per language offered, each in its own language, because a page that asked in English only would be asking the very person who may not read it.
  ///
  /// In en, this message translates to:
  /// **'Choose a language to continue.'**
  String get chooseALanguage;

  /// The first screen's promises, in the panel of the language they are about.
  ///
  /// In en, this message translates to:
  /// **'No account.'**
  String get noAccount;

  /// The first screen's promises.
  ///
  /// In en, this message translates to:
  /// **'No ads.'**
  String get noAds;

  /// The first screen's promises. The German says «no analytics or tracking data», which is the same promise in the words German privacy law uses.
  ///
  /// In en, this message translates to:
  /// **'No analytics.'**
  String get noAnalytics;

  /// The first screen's promises: there is no server of ours anywhere in the product.
  ///
  /// In en, this message translates to:
  /// **'No Z Privacy server.'**
  String get noZPrivacyServer;

  /// The first screen's own statement of the product's law, and the one sentence a person reads before anything else.
  ///
  /// In en, this message translates to:
  /// **'Your original data stays on this device unless you explicitly copy restored content.'**
  String get originalDataStaysHere;

  /// Rule 62 on the first screen. The German is the wording the paper fixed and the owner has read; do not reword it.
  ///
  /// In en, this message translates to:
  /// **'Only the protected version is sent to AI through Z Privacy.'**
  String get onlyTheProtectedVersionIsSent;

  /// What choosing this language actually does, said before Start: it enables that language's rule set. Each language says it of itself, which is why one key carries «The English…» and «Die deutschen…».
  ///
  /// In en, this message translates to:
  /// **'The English privacy rules will be enabled.'**
  String get theseRulesWillBeEnabled;

  /// The press that leaves the first screen.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// The first screen's second panel, after a language is chosen — drawn in the language that was chosen.
  ///
  /// In en, this message translates to:
  /// **'Your vault'**
  String get yourVault;

  /// The press that makes the vault, on the first screen.
  ///
  /// In en, this message translates to:
  /// **'Create a vault'**
  String get createAVault;

  /// What the vault is for, said before it is offered — not a warning and not a sales line, the reason. «Every word you protect» since 089, and that is the owner's own rule rather than a promise widened for effect: every word that takes a token becomes a block in the vault file and is never deleted, so the sentence that says what the vault is for has to say that first. It once read «the values you protect for good», which named only the «always» reach and left the person to find out that the rest was kept too. The last clause is the promise the whole product rests on.
  ///
  /// In en, this message translates to:
  /// **'Every word you protect lives here, for as long as you keep this vault: the names you add, the values you teach, and the keys to any AI you connect. It stays on this computer, and nothing is written anywhere else.'**
  String get vaultWhy;

  /// Under «Create a vault»: what the passphrase is for and where it stays.
  ///
  /// In en, this message translates to:
  /// **'One passphrase, kept on this device. Everything Z learns while you work — your names, your lists, your decisions — is kept in it.'**
  String get onePassphrase;

  /// The byline at the foot of the first page: who publishes Z Privacy. The publisher's name does not change; the word before it does, which is why this is a sentence and not a product name.
  ///
  /// In en, this message translates to:
  /// **'by YourVoices'**
  String get byYourVoices;

  /// Said when «go to a page» lands on a page the scan found nothing on.
  ///
  /// In en, this message translates to:
  /// **'Page {page} has nothing the scanner marked.'**
  String pageHasNothingMarked(int page);

  /// The «+» at the top of the one screen, rule 72-أ: the way in.
  ///
  /// In en, this message translates to:
  /// **'Add a document — PDF, Word or text'**
  String get addADocumentPdfWordOrText;

  /// What the empty first part says: rule 63's second half, that a question needs no document.
  ///
  /// In en, this message translates to:
  /// **'Add a document — or write to the AI in the first part, with no document at all.'**
  String get addADocumentOrWriteToTheAi;

  /// The first column's name. «local only» is the law, not a decoration.
  ///
  /// In en, this message translates to:
  /// **'Original — local only'**
  String get originalLocalOnly;

  /// The first column's rule line: rule 62, and the contract's own promise that no door reads this text.
  ///
  /// In en, this message translates to:
  /// **'Never sent to AI · Send cannot read this side'**
  String get neverSentToAiSendCannotRead;

  /// The first part when it is empty, said once rather than in each half.
  ///
  /// In en, this message translates to:
  /// **'Your document arrives here, as it is written. Nothing on this side can reach the network.'**
  String get yourDocumentArrivesHere;

  /// The middle column's name. The German says «das erhält die KI» because «Safe» as a noun has no German that is not a strongbox.
  ///
  /// In en, this message translates to:
  /// **'Safe — AI will receive'**
  String get safeAiWillReceive;

  /// The middle column's rule line: what stands there is the text that leaves, byte for byte.
  ///
  /// In en, this message translates to:
  /// **'The request itself, not a preview of it'**
  String get theRequestItselfNotAPreview;

  /// The middle part when it is empty.
  ///
  /// In en, this message translates to:
  /// **'What an AI would receive stands here beside the original, word for word, before anything is sent.'**
  String get whatAnAiWouldReceiveStandsHere;

  /// The third part's name, and the head of the chat panel.
  ///
  /// In en, this message translates to:
  /// **'The chat'**
  String get theChatTitle;

  /// The third part's rule line.
  ///
  /// In en, this message translates to:
  /// **'Your questions, and what came back'**
  String get yourQuestionsAndWhatCameBack;

  /// The third part when it is empty — rule 68's own promise, said before it is true.
  ///
  /// In en, this message translates to:
  /// **'The chat opens here with the first answer, and every question after it carries what was already said.'**
  String get theChatOpensHereWithTheFirstAnswer;

  /// The name of a document that came in through the box rather than from a file.
  ///
  /// In en, this message translates to:
  /// **'Typed text'**
  String get typedText;

  /// How many pages the open document has, when it has one.
  ///
  /// In en, this message translates to:
  /// **'1 page'**
  String get onePage;

  /// How many pages the open document has.
  ///
  /// In en, this message translates to:
  /// **'{pages} pages'**
  String pagesCount(int pages);

  /// The work bar's vault field. Not «sourceVault», which names where a finding came from and may be worded differently.
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get vaultLabel;

  /// The vault's state in the work bar.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get vaultIsUnlocked;

  /// The vault's state in the work bar.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get vaultIsLocked;

  /// The vault's state in the work bar when this device has none. Masculine in German, because «Tresor» is.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get vaultIsNone;

  /// The press that opens the vault board.
  ///
  /// In en, this message translates to:
  /// **'Open Z Vault'**
  String get openZVault;

  /// The press that locks the vault at once.
  ///
  /// In en, this message translates to:
  /// **'Lock now'**
  String get lockNow;

  /// The tooltip over the vault field while it is unlocked, when both acts are offered.
  ///
  /// In en, this message translates to:
  /// **'Open Z Vault, or lock it now'**
  String get openZVaultOrLockItNow;

  /// The tooltip over the page chooser.
  ///
  /// In en, this message translates to:
  /// **'Go to a page'**
  String get goToAPage;

  /// One row of the page chooser.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String pageNumber(int page);

  /// The page chooser's own label in the work bar.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get pageWord;

  /// The tooltip over the send door in the work bar.
  ///
  /// In en, this message translates to:
  /// **'Choose the AI and what travels to it'**
  String get chooseTheAiAndWhatTravels;

  /// The tooltip over the pack chooser.
  ///
  /// In en, this message translates to:
  /// **'Read this document with another rule set'**
  String get readThisDocumentWithAnotherRuleSet;

  /// The row that chooses no language pack: the general rules and the person's own lists, and nothing else.
  ///
  /// In en, this message translates to:
  /// **'General rules only'**
  String get generalRulesOnly;

  /// The work bar's pack field. Not «sourcePack», which names where a finding came from. The German is «Sprachpaket», the word the house fixed.
  ///
  /// In en, this message translates to:
  /// **'Pack'**
  String get packLabel;

  /// The pack field when the pack carries no rules of its own.
  ///
  /// In en, this message translates to:
  /// **'{pack} · general rules'**
  String packWithGeneralRules(String pack);

  /// The profile that is no profile: identities and rules that apply to every client.
  ///
  /// In en, this message translates to:
  /// **'Everywhere'**
  String get everywhere;

  /// The work bar's profile field.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// The head of the profile sheet.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get profiles;

  /// What the profile sheet is for, and the one promise about the ID.
  ///
  /// In en, this message translates to:
  /// **'Choose which client dictionary this session uses. The profile ID stays inside the vault; the display name is what people see.'**
  String get chooseWhichClientDictionary;

  /// What «Everywhere» means, under its row.
  ///
  /// In en, this message translates to:
  /// **'Only identities and rules that apply to every profile.'**
  String get onlyIdentitiesForEveryProfile;

  /// The press in the profile sheet.
  ///
  /// In en, this message translates to:
  /// **'Create profile'**
  String get createProfile;

  /// Closes a sheet that asked nothing.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Renames the profile a row names.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// The profile this session is already using.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get profileActive;

  /// Moves this session to the profile a row names.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get profileSwitch;

  /// The door back: z-pdf reads a protected PDF and puts the names back.
  ///
  /// In en, this message translates to:
  /// **'Read it back'**
  String get readItBack;

  /// While the core is reading the document.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get scanning;

  /// A document in the preview that no scan has read.
  ///
  /// In en, this message translates to:
  /// **'Not scanned yet'**
  String get notScannedYet;

  /// 089 rule 9: a document that came back out of a session's own file carries its decisions, so the band says that rather than three zeros.
  ///
  /// In en, this message translates to:
  /// **'As it was kept'**
  String get asItWasKept;

  /// What the core itself says about the last scan.
  ///
  /// In en, this message translates to:
  /// **'Last scan: {note}'**
  String lastScanNote(String note);

  /// The scan happened as the document came in.
  ///
  /// In en, this message translates to:
  /// **'Scanned on import'**
  String get scannedOnImport;

  /// The person asked for the scan themselves.
  ///
  /// In en, this message translates to:
  /// **'Last scan: manual rescan'**
  String get lastScanManualRescan;

  /// A document that came back with its marks, before any scan in this sitting.
  ///
  /// In en, this message translates to:
  /// **'{marks} already protected · nothing scanned in this run'**
  String alreadyProtectedNothingScanned(int marks);

  /// The band over the document: the three numbers the core counted, never computed on the glass.
  ///
  /// In en, this message translates to:
  /// **'{auto} protected automatically · {open} need your word · {normal} normal'**
  String protectedAutomaticallyNeedYourWord(int auto, int open, int normal);

  /// What a scan with a locked vault did and did not do. Protection never needed the vault; names do.
  ///
  /// In en, this message translates to:
  /// **'Vault locked — rules and pack ran, the vault layer did not'**
  String get vaultLockedRulesAndPackRan;

  /// What a scan on a device with no vault can and cannot do.
  ///
  /// In en, this message translates to:
  /// **'No vault — nothing is recognised by name'**
  String get noVaultNothingRecognisedByName;

  /// Opens a vault that exists.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// Rule 71: the document goes and the session stays — 089 rule 9 keeps what was already kept.
  ///
  /// In en, this message translates to:
  /// **'Remove the document'**
  String get removeTheDocument;

  /// The first column with no document in it.
  ///
  /// In en, this message translates to:
  /// **'Nothing is open.'**
  String get nothingIsOpen;

  /// The middle column with neither a document nor a question in it.
  ///
  /// In en, this message translates to:
  /// **'There is nothing to send yet.'**
  String get thereIsNothingToSendYet;

  /// While the core reads the held lines of a table.
  ///
  /// In en, this message translates to:
  /// **'Reading what those lines hold…'**
  String get readingWhatThoseLinesHold;

  /// What one held line of a table holds.
  ///
  /// In en, this message translates to:
  /// **'1 line · {protected} protected in it · {open} open'**
  String oneLineProtectedOpen(int protected, int open);

  /// What the held lines of a table hold.
  ///
  /// In en, this message translates to:
  /// **'{lines} lines · {protected} protected in them · {open} open'**
  String linesProtectedOpen(int lines, int protected, int open);

  /// What holding lines of a table is for.
  ///
  /// In en, this message translates to:
  /// **'Press a value to protect the same cell in every held line.'**
  String get pressAValueToProtectEveryHeldLine;

  /// Stops holding the lines of a table.
  ///
  /// In en, this message translates to:
  /// **'Let the lines go'**
  String get letTheLinesGo;

  /// The two columns scroll together.
  ///
  /// In en, this message translates to:
  /// **'In step'**
  String get inStep;

  /// The two columns scroll on their own.
  ///
  /// In en, this message translates to:
  /// **'Apart'**
  String get apart;

  /// Tokens drawn as marked pieces.
  ///
  /// In en, this message translates to:
  /// **'Chips'**
  String get drawnAsChips;

  /// Tokens drawn as the text itself.
  ///
  /// In en, this message translates to:
  /// **'Plain'**
  String get drawnPlain;

  /// 083 rule 4: a waiting word is real text in the middle column, and the column says so.
  ///
  /// In en, this message translates to:
  /// **'One suggestion is still open. Until you answer it, it stands here as written — real text on this side.'**
  String get oneSuggestionStillOpen;

  /// 083 rule 4, for more than one waiting word.
  ///
  /// In en, this message translates to:
  /// **'{open} suggestions are still open. Until you answer them, they stand here as written — the only real text on this side.'**
  String suggestionsStillOpen(int open);

  /// The send door: the AI is chosen in the middle column, where what leaves is read.
  ///
  /// In en, this message translates to:
  /// **'Choose who answers'**
  String get chooseWhoAnswers;

  /// Brings the third part back after it was put away.
  ///
  /// In en, this message translates to:
  /// **'Show the chat'**
  String get showTheChat;

  /// The box at the foot of the first part, with no document open.
  ///
  /// In en, this message translates to:
  /// **'What would you like to ask the AI?'**
  String get whatWouldYouLikeToAskTheAi;

  /// The box at the foot of the first part, with a document open.
  ///
  /// In en, this message translates to:
  /// **'What should the AI do with this?'**
  String get whatShouldTheAiDoWithThis;

  /// The hint inside the box with no document: rule 63 — what is pasted here enters the preview like a file.
  ///
  /// In en, this message translates to:
  /// **'Ask a question, or paste a whole letter here.'**
  String get askAQuestionOrPasteALetter;

  /// The hint inside the box with a document open: an example of a request about it.
  ///
  /// In en, this message translates to:
  /// **'Reconcile section A against section B and tell me where the difference is.'**
  String get reconcileSectionAgainstSection;

  /// The question is already in the middle column.
  ///
  /// In en, this message translates to:
  /// **'In what will leave'**
  String get inWhatWillLeave;

  /// Puts the typed question into the middle column.
  ///
  /// In en, this message translates to:
  /// **'Add it to what will leave'**
  String get addItToWhatWillLeave;

  /// Why there is no refusal for an empty question: the document alone is a thing that may leave.
  ///
  /// In en, this message translates to:
  /// **'A document can be sent with no request, and then the model is given no instruction'**
  String get aDocumentCanBeSentWithNoRequest;

  /// Takes the question back out of the middle column.
  ///
  /// In en, this message translates to:
  /// **'Take it out'**
  String get takeItOut;

  /// What the core found in the question itself.
  ///
  /// In en, this message translates to:
  /// **'Your request is in the Safe column, with nothing in it to protect.'**
  String get yourRequestNothingToProtect;

  /// What the core found in the question itself.
  ///
  /// In en, this message translates to:
  /// **'Your request is in the Safe column, with one value replaced.'**
  String get yourRequestOneValueReplaced;

  /// What the core found in the question itself.
  ///
  /// In en, this message translates to:
  /// **'Your request is in the Safe column, with {count} values replaced.'**
  String yourRequestValuesReplaced(int count);

  /// Rule 67: one question stands in the middle column, and the thread is where the earlier ones are.
  ///
  /// In en, this message translates to:
  /// **'One request at a time — a new question replaces this one, and the chat keeps every exchange.'**
  String get oneRequestAtATime;

  /// One waiting word in the question, and the press that lands on it.
  ///
  /// In en, this message translates to:
  /// **'1 question left — go to it'**
  String get oneQuestionLeftGoToIt;

  /// Waiting words in the question, and the press that lands on the first.
  ///
  /// In en, this message translates to:
  /// **'{open} questions left — go to the first'**
  String questionsLeftGoToTheFirst(int open);

  /// Answers one waiting word: protect it.
  ///
  /// In en, this message translates to:
  /// **'Protect it'**
  String get protectIt;

  /// Answers one waiting word: leave it as it is.
  ///
  /// In en, this message translates to:
  /// **'Leave it in the clear'**
  String get leaveItInTheClear;

  /// Which kind the one waiting word is, named by the core's own word for the kind.
  ///
  /// In en, this message translates to:
  /// **'The one left is {kind}.'**
  String theOneLeftIsKind(String kind);

  /// Opens the middle column when it was hidden.
  ///
  /// In en, this message translates to:
  /// **'Show what the AI will receive'**
  String get showWhatTheAiWillReceive;

  /// Puts the middle column away.
  ///
  /// In en, this message translates to:
  /// **'Hide this column'**
  String get hideThisColumn;

  /// Narrows the part of the screen this press sits in.
  ///
  /// In en, this message translates to:
  /// **'Narrow this panel'**
  String get narrowThisPanel;

  /// Widens the part of the screen this press sits in.
  ///
  /// In en, this message translates to:
  /// **'Widen this panel'**
  String get widenThisPanel;

  /// Rule 68, under the chat's head: what the thread holds and that it travels.
  ///
  /// In en, this message translates to:
  /// **'One exchange, carried into the next question.'**
  String get oneExchangeCarriedIntoTheNext;

  /// Rule 68, under the chat's head.
  ///
  /// In en, this message translates to:
  /// **'{count} exchanges, carried into the next question.'**
  String exchangesCarriedIntoTheNext(int count);

  /// Rule 71: hiding the third part is not ending the chat, and the tooltip says so rather than letting a person guess.
  ///
  /// In en, this message translates to:
  /// **'Put the chat away — it is not ended'**
  String get putTheChatAwayItIsNotEnded;

  /// The chat panel with no turn in it yet.
  ///
  /// In en, this message translates to:
  /// **'The first answer opens the chat here. Every question after it carries what was already said.'**
  String get theFirstAnswerOpensTheChatHere;

  /// The box at the foot of the thread: the next question of this chat.
  ///
  /// In en, this message translates to:
  /// **'Ask something else about this…'**
  String get askSomethingElseAboutThis;

  /// The box for an answer brought back by hand, from a model answered in a browser.
  ///
  /// In en, this message translates to:
  /// **'Paste the answer you were given…'**
  String get pasteTheAnswerYouWereGiven;

  /// Takes the pasted answer into the thread, against the payload it belongs to.
  ///
  /// In en, this message translates to:
  /// **'Add it to the chat'**
  String get addItToTheChat;

  /// Closes the paste box without adding anything.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// Rule 65's exit: every turn as it left, joined by the core.
  ///
  /// In en, this message translates to:
  /// **'Copy the chat'**
  String get copyTheChat;

  /// Opens the box for an answer brought back by hand.
  ///
  /// In en, this message translates to:
  /// **'Add an answer'**
  String get addAnAnswer;

  /// Rule 71: the chat ends and the surface starts from zero inside the same session.
  ///
  /// In en, this message translates to:
  /// **'End the chat'**
  String get endTheChat;

  /// After «Copy the chat»: what is on the clipboard and what to do next.
  ///
  /// In en, this message translates to:
  /// **'The chat is on your clipboard, protected — bring the answer back with «Add an answer».'**
  String get theChatIsOnYourClipboard;

  /// The platform refused the read.
  ///
  /// In en, this message translates to:
  /// **'Z Privacy could not read the clipboard.'**
  String get couldNotReadTheClipboard;

  /// Nothing to bring back.
  ///
  /// In en, this message translates to:
  /// **'There is no text on the clipboard.'**
  String get thereIsNoTextOnTheClipboard;

  /// Puts a restored answer away again.
  ///
  /// In en, this message translates to:
  /// **'Hide the text'**
  String get hideTheText;

  /// Shows a restored answer.
  ///
  /// In en, this message translates to:
  /// **'Show the text'**
  String get showTheText;

  /// Over a restored answer: the names are back here and the model never saw them.
  ///
  /// In en, this message translates to:
  /// **'The text, with your names back — on this device'**
  String get theTextWithYourNamesBack;

  /// Rule 58: a block crosses a session, and a token from elsewhere cannot be put back here.
  ///
  /// In en, this message translates to:
  /// **'This answer carries 1 token this session does not know — it was made in another session.'**
  String get thisAnswerCarriesOneUnknownToken;

  /// Rule 58, for more than one.
  ///
  /// In en, this message translates to:
  /// **'This answer carries {count} tokens this session does not know — they were made in another session.'**
  String thisAnswerCarriesUnknownTokens(int count);

  /// The press that puts the real values on the system clipboard, after the question below.
  ///
  /// In en, this message translates to:
  /// **'Copy Restored'**
  String get copyRestored;

  /// Under a restored answer in which every token could be put back.
  ///
  /// In en, this message translates to:
  /// **'The marked words were put back here, on this device. The model never saw them.'**
  String get theMarkedWordsWerePutBackHere;

  /// Under a restored answer that carries a token from another session.
  ///
  /// In en, this message translates to:
  /// **'The dotted words were put back here, on this device. The struck ones are tokens this session cannot put back.'**
  String get theDottedWordsWerePutBackHere;

  /// The head of the question asked before real values reach the system clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy restored text?'**
  String get copyRestoredTextQuestion;

  /// What «Copy Restored» does, said before it is done — the one place this app puts real values where another program can read them.
  ///
  /// In en, this message translates to:
  /// **'This will place the real protected values on your system clipboard. Other applications may be able to read the clipboard.'**
  String get thisWillPlaceTheRealValues;

  /// Leaves a question without doing the thing it asked about.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// After the person confirmed it.
  ///
  /// In en, this message translates to:
  /// **'Restored text copied to the system clipboard.'**
  String get restoredTextCopied;

  /// Rule 60-أ's other half: the AI is chosen where what leaves can be read, so the arrow says why it is not live.
  ///
  /// In en, this message translates to:
  /// **'Choose who answers in the middle column first'**
  String get chooseWhoAnswersInTheMiddleFirst;

  /// The arrow at the foot of the thread, naming who will answer.
  ///
  /// In en, this message translates to:
  /// **'Send this question to {name}'**
  String sendThisQuestionTo(String name);

  /// The chat's own refusal for an empty box: said before the clipboard is touched and before any door is asked, because there is nothing to ask about.
  ///
  /// In en, this message translates to:
  /// **'Write a question first.'**
  String get writeAQuestionFirst;

  /// The panel's own name, in its head and on the press that opens it.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// The Privacy room in the panel's list.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get roomPrivacy;

  /// The Language room in the panel's list.
  ///
  /// In en, this message translates to:
  /// **'Language & rules'**
  String get roomLanguageAndRules;

  /// The Vault room in the panel's list.
  ///
  /// In en, this message translates to:
  /// **'Vault & security'**
  String get roomVaultAndSecurity;

  /// The Sessions room in the panel's list.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get roomSessions;

  /// The Language room's own line. **It ended «The interface itself is English.» until 092**, which is what made that false: the sentence is deleted rather than reworded, because the interface now follows this choice.
  ///
  /// In en, this message translates to:
  /// **'A privacy pack is a detection engine, not the language of the interface — and more than one pack can run in a single scan, so this is a starting point rather than the only rules allowed.'**
  String get languageAndRulesWhat;

  /// The card that chooses the language a text with no session language is read with — and, since 080, the interface's own.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get appLanguage;

  /// What the one choice does. The last sentence is new in 092 and replaces the dead «Interface» card: 080 says one choice writes both, so the card that writes them says so.
  ///
  /// In en, this message translates to:
  /// **'The language a session is read with when it has none of its own — and which habits the scanner knows in it: salutations, company forms, the way a customer number is written. A session created with a language of its own keeps that one; this is what every other text is read with. The interface follows this choice.'**
  String get appLanguageWhat;

  /// Rule 56-أ in the room where it bites: a language whose list is still the English source is a real scanner language and not yet an interface language, and the card says which it is rather than switching silently.
  ///
  /// In en, this message translates to:
  /// **'{language}: the detection pack is {language}; the interface is English until its sentences are translated.'**
  String theInterfaceIsEnglishUntilTranslated(String language);

  /// The card for rules a person writes themselves.
  ///
  /// In en, this message translates to:
  /// **'My privacy rules'**
  String get myPrivacyRules;

  /// Rule 35's own shape for a thing that is coming: named, with no control that does nothing.
  ///
  /// In en, this message translates to:
  /// **'Not built yet. Rules you write yourself — a customer number format only your office uses, a project codename — will live here, beside the pack rather than inside it.'**
  String get myPrivacyRulesWhat;

  /// The Vault room's own line.
  ///
  /// In en, this message translates to:
  /// **'The key, the lock, and where a credential lives.'**
  String get vaultAndSecurityWhat;

  /// The vault's own card.
  ///
  /// In en, this message translates to:
  /// **'Z Vault'**
  String get zVault;

  /// The vault's state, said as what it does.
  ///
  /// In en, this message translates to:
  /// **'Open. Your identities are loaded and the fourth detection layer is running.'**
  String get vaultOpenWhat;

  /// The vault's state, said as what still works.
  ///
  /// In en, this message translates to:
  /// **'Locked. The rules and the pack still run — an IBAN is still caught — but not who it belongs to.'**
  String get vaultLockedWhat;

  /// The vault's state on a device that has none.
  ///
  /// In en, this message translates to:
  /// **'Not created on this device. Nothing is recognised by name.'**
  String get vaultAbsentWhat;

  /// The vault's state with the number the core counted.
  ///
  /// In en, this message translates to:
  /// **'Unlocked · {count} identities'**
  String unlockedWithIdentities(int count);

  /// The door back, in the room it lives in since rule 70.
  ///
  /// In en, this message translates to:
  /// **'z-pdf — read a protected document back'**
  String get zPdfReadBack;

  /// What the door back is and, as importantly, the three things it is not. «The door back has no seat»: no session is passed to it.
  ///
  /// In en, this message translates to:
  /// **'The reverse act. A document that left this app with tokens in it is read back into its own names, here, from your vault — and it is never scanned, never protected and never put on a bench. Nothing of it is sent anywhere.'**
  String get zPdfWhat;

  /// Said when the panel is drawn without the shell's own file door behind it.
  ///
  /// In en, this message translates to:
  /// **'Open this panel from the app to choose a file.'**
  String get openThisPanelFromTheApp;

  /// The press that opens the file chooser for the door back.
  ///
  /// In en, this message translates to:
  /// **'Choose a z-pdf file'**
  String get chooseAZPdfFile;

  /// The idle lock's own card.
  ///
  /// In en, this message translates to:
  /// **'Lock the vault after'**
  String get lockTheVaultAfter;

  /// The unit under the idle lock's number.
  ///
  /// In en, this message translates to:
  /// **'minutes unused · 0 = never'**
  String get minutesUnusedZeroIsNever;

  /// Where the lock lives, which is the whole reason it can be trusted. «behalten» is wrong here and «gehalten» is right: nothing is being stored.
  ///
  /// In en, this message translates to:
  /// **'Kept by the vault itself, not by a timer in a screen: every way into it checks the clock first, so a bug in the interface cannot leave it open.'**
  String get lockTheVaultAfterWhat;

  /// The card about where a provider key lives.
  ///
  /// In en, this message translates to:
  /// **'Encrypted local credential storage'**
  String get encryptedLocalCredentialStorage;

  /// The key's two homes, and the contract's own promise about the third.
  ///
  /// In en, this message translates to:
  /// **'A provider key has two homes and no third: sealed inside the vault when one is open, or in memory for this run when there is none. Never a file in the clear, and never returned to the interface — there is no call in the whole contract that gives one back.'**
  String get credentialHomesWhat;

  /// Where this provider's key is, in the list of providers that hold one.
  ///
  /// In en, this message translates to:
  /// **'sealed in the vault'**
  String get credentialSealedInTheVault;

  /// Where this provider's key is, when there is no vault to seal it in.
  ///
  /// In en, this message translates to:
  /// **'in memory, gone when the app closes'**
  String get credentialInMemory;

  /// This provider holds none.
  ///
  /// In en, this message translates to:
  /// **'no key stored'**
  String get credentialNoKeyStored;

  /// The list of providers that hold a key, when it is empty.
  ///
  /// In en, this message translates to:
  /// **'No provider holds a credential.'**
  String get noProviderHoldsACredential;

  /// A card for a thing that is coming.
  ///
  /// In en, this message translates to:
  /// **'Device-bound protection'**
  String get deviceBoundProtection;

  /// What it would and would not change.
  ///
  /// In en, this message translates to:
  /// **'Not built yet. A key tied to this device’s own authentication would sit above the layer above, without changing what is stored — the same records, one more lock.'**
  String get deviceBoundWhat;

  /// The Sessions room's own line. «keeps its own key» is retained, not stored — the key is hers; «hat» says it without either word.
  ///
  /// In en, this message translates to:
  /// **'A session keeps its own key, and the keys are in the vault.'**
  String get sessionsWhat;

  /// Why the room is empty with a locked vault, and the one thing that would otherwise be feared: nothing was lost.
  ///
  /// In en, this message translates to:
  /// **'The vault is shut, so there are no sessions to show. Open it and they come back — the conversations themselves were never in it.'**
  String get theVaultIsShutNoSessions;

  /// What a session is for, said as the thing it buys the person rather than as a mechanism.
  ///
  /// In en, this message translates to:
  /// **'Each session has its own encryption. The same name in two sessions takes two different tokens, and in one session it takes the same one wherever it appears — so a session is how you choose what an AI can line up and what it cannot.'**
  String get eachSessionHasItsOwnEncryption;

  /// The card that creates one.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get newSession;

  /// Rules 57b and 064f: the language is asked as the session is born, and the bench in front of the person is renamed with it.
  ///
  /// In en, this message translates to:
  /// **'A name and a language, both yours to choose: the language is how Z reads every text in this session, and it is asked once here. It becomes the session you are working in straight away. Anything already protected on the document in front of you is renamed into it — nothing has been sent yet, so nothing that left is affected.'**
  String get newSessionWhat;

  /// The hint in the box that names a session — a question, because the name is the person's own word.
  ///
  /// In en, this message translates to:
  /// **'What is this one about?'**
  String get whatIsThisOneAbout;

  /// The press that creates the session.
  ///
  /// In en, this message translates to:
  /// **'Begin'**
  String get begin;

  /// The card in the room before there is one.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet'**
  String get noSessionsYet;

  /// Rule 55 and 081: a birth asks nothing, and the room is where a name is given if one is ever wanted.
  ///
  /// In en, this message translates to:
  /// **'One is born the first time you copy safe text or ask for a PDF — it is not refused for want of a name, it takes its own number for one, and you can rename it here. You never have to make one by hand first.'**
  String get noSessionsYetWhat;

  /// A session's row, when it is the open one.
  ///
  /// In en, this message translates to:
  /// **'{when} · {exchanges} · the one you are in'**
  String theOneYouAreIn(String when, String exchanges);

  /// The press that enters a session.
  ///
  /// In en, this message translates to:
  /// **'Work in this session'**
  String get workInThisSession;

  /// The press on a session's row.
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get enter;

  /// The press that asks for a new word.
  ///
  /// In en, this message translates to:
  /// **'Rename this session'**
  String get renameThisSession;

  /// The press that destroys the key.
  ///
  /// In en, this message translates to:
  /// **'Delete this session'**
  String get deleteThisSession;

  /// How many exchanges a session holds.
  ///
  /// In en, this message translates to:
  /// **'1 exchange'**
  String get oneExchange;

  /// How many exchanges a session holds. «Austausche» is a plural nobody says, which is the lead's own correction in sitting two.
  ///
  /// In en, this message translates to:
  /// **'{count} exchanges'**
  String exchangesCount(int count);

  /// The head of the rename question.
  ///
  /// In en, this message translates to:
  /// **'Rename session {number}?'**
  String renameSessionNumber(int number);

  /// 081: «the number is the identity and does not move». A rename touches the word and nothing else.
  ///
  /// In en, this message translates to:
  /// **'The number stays {number} — it is what this session is, and nothing that was protected in it changes. Only the word on the row does.'**
  String theNumberStaysWhatItIs(int number);

  /// Leaves the rename question without renaming. «behalten» is right: nothing is stored, the name is retained.
  ///
  /// In en, this message translates to:
  /// **'Keep the name'**
  String get keepTheName;

  /// Confirms the rename.
  ///
  /// In en, this message translates to:
  /// **'Rename it'**
  String get renameIt;

  /// The head of the delete question, around the person's own word. The guillemets are the sentence's; the **isolate pair** U+2068/U+2069 is applied by the caller through `theirOwnWord`, and G44's own half over this file checks that every caller of a value quoting a placeholder does so. It was tried inside the value instead, so that no caller could forget it — and `gen-l10n` writes the raw code points into the generated Dart, which the analyzer flags as `text_direction_code_point_in_literal` in a file nobody can fix. Eight unfixable warnings that would hide real ones is a worse trade than a gate, so the gate it is.
  ///
  /// In en, this message translates to:
  /// **'Delete «{name}»?'**
  String deleteNamed(String name);

  /// The first line of the delete question: what the act is.
  ///
  /// In en, this message translates to:
  /// **'This destroys the key this session was protected with.'**
  String get thisDestroysTheKey;

  /// What the act costs, said without softening: the one-way door of rule 59.
  ///
  /// In en, this message translates to:
  /// **'Every document and every message protected in it can never be unprotected again — not by you, and not by Z Privacy. The key was the only thing that could have done it, and it will not exist.'**
  String get everyDocumentCanNeverBeUnprotected;

  /// The half a person needs in order not to fear the wrong thing: the delete reaches the key, not what already left.
  ///
  /// In en, this message translates to:
  /// **'Anything you sent out of this session stays exactly as it was. What goes is the way back from it.'**
  String get anythingYouSentStaysAsItWas;

  /// Leaves the delete question without deleting.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get keepIt;

  /// Confirms the delete.
  ///
  /// In en, this message translates to:
  /// **'Delete the session'**
  String get deleteTheSession;

  /// How many places in a kept document carry a token.
  ///
  /// In en, this message translates to:
  /// **'1 protected place'**
  String get oneProtectedPlace;

  /// How many places in a kept document carry a token.
  ///
  /// In en, this message translates to:
  /// **'{count} protected places'**
  String protectedPlacesCount(int count);

  /// The press on a kept document's row.
  ///
  /// In en, this message translates to:
  /// **'Rename this document'**
  String get renameThisDocument;

  /// The head of the document rename question, by the handle the core gave it.
  ///
  /// In en, this message translates to:
  /// **'Rename {handle}?'**
  String renameHandle(String handle);

  /// The same law as a session's number, for a document's handle.
  ///
  /// In en, this message translates to:
  /// **'The name is what you read in this list. {handle} stays what it is: a number is spent once and never given to another document.'**
  String theNameIsWhatYouRead(String handle);

  /// The hint in the document rename box.
  ///
  /// In en, this message translates to:
  /// **'A name for this document'**
  String get aNameForThisDocument;

  /// The AI room's own name.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get roomAi;

  /// The AI room's own line.
  ///
  /// In en, this message translates to:
  /// **'Three ways to ask a model. The first needs no account at all.'**
  String get aiWhat;

  /// The first way: no account, no key.
  ///
  /// In en, this message translates to:
  /// **'Manual AI'**
  String get manualAi;

  /// The first way, and the one the owner's own demo uses.
  ///
  /// In en, this message translates to:
  /// **'Use an AI chat you already have. Copy the safe text out of the Workspace, paste it into whatever model you use, and bring the answer back. Nothing to set up, nothing to pay for, and the restoring works exactly the same.'**
  String get manualAiWhat;

  /// Where the first way is, on the glass.
  ///
  /// In en, this message translates to:
  /// **'Always available — it is the «Choose who answers» sheet, first door.'**
  String get alwaysAvailableFirstDoor;

  /// The second way: a remote provider with a key.
  ///
  /// In en, this message translates to:
  /// **'Direct API'**
  String get directApi;

  /// The second way, and the promise about the key that the contract keeps.
  ///
  /// In en, this message translates to:
  /// **'Connect to a remote AI provider with your API credential. The key goes in once and never comes back out — no screen in this app can show it to you again.'**
  String get directApiWhat;

  /// A provider at a loopback address asks for no key.
  ///
  /// In en, this message translates to:
  /// **'At this address no credential is needed.'**
  String get atThisAddressNoCredential;

  /// The provider's own protocol, named by the core.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get protocol;

  /// This provider's state.
  ///
  /// In en, this message translates to:
  /// **'Connected · key sealed in the vault'**
  String get connectedKeySealed;

  /// This provider's state with no vault to seal the key in. «aufbewahrt»: the key is stored, in memory.
  ///
  /// In en, this message translates to:
  /// **'Connected · key kept for this run only'**
  String get connectedKeyThisRunOnly;

  /// This provider's state at an address that asks for none.
  ///
  /// In en, this message translates to:
  /// **'Connected · no key needed'**
  String get connectedNoKeyNeeded;

  /// This provider's state.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notConnected;

  /// The third way: a model on this machine.
  ///
  /// In en, this message translates to:
  /// **'Local AI'**
  String get localAi;

  /// The third way, and why http is allowed exactly here and nowhere else.
  ///
  /// In en, this message translates to:
  /// **'Runs through an AI service on this computer — llama.cpp, Ollama, LM Studio, anything that answers the same shape. No key, no account, and the request never leaves this computer. Plain http is accepted only for a literal loopback address.'**
  String get localAiWhat;

  /// The head of a provider's model list.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get models;

  /// The Privacy room's own line.
  ///
  /// In en, this message translates to:
  /// **'What the app does by itself, and how far it goes without asking.'**
  String get privacyWhat;

  /// Why a setting changed here will not be there tomorrow. G15's own promise, said to the person.
  ///
  /// In en, this message translates to:
  /// **'There is no vault open, so these are for this run only. The vault is the one file this app writes — without it, nothing is remembered.'**
  String get noVaultSoThisRunOnly;

  /// The setting that scans on import.
  ///
  /// In en, this message translates to:
  /// **'Scan a document the moment it arrives'**
  String get scanOnArrival;

  /// What turning it off costs.
  ///
  /// In en, this message translates to:
  /// **'No dialog, no button. Turning this off means a document sits unprotected until you press Rescan — which is exactly the moment the boards were written to avoid.'**
  String get scanOnArrivalWhat;

  /// Not a setting, and the card says so.
  ///
  /// In en, this message translates to:
  /// **'Answer every suggestion before sending'**
  String get answerEverySuggestion;

  /// A law drawn where a person looks for a switch, so that its absence is an answer rather than a gap.
  ///
  /// In en, this message translates to:
  /// **'Not a setting. A suggestion that has not been answered is never quietly treated as safe, and there is no «send anyway» — not here, not in a hidden flag, not anywhere in the code.'**
  String get answerEverySuggestionWhat;

  /// The reveal timer's card.
  ///
  /// In en, this message translates to:
  /// **'A revealed value stays for'**
  String get aRevealedValueStaysFor;

  /// What the number does and, more importantly, what it does not.
  ///
  /// In en, this message translates to:
  /// **'Revealing draws on the screen and never writes into what leaves. This is only how long it stays drawn.'**
  String get aRevealedValueStaysForWhat;

  /// A card for a thing that is coming.
  ///
  /// In en, this message translates to:
  /// **'Token rotation'**
  String get tokenRotation;

  /// What the choice would be. «behält» is retained, not stored.
  ///
  /// In en, this message translates to:
  /// **'Not built yet. When it is, it will live here: whether a permanent token keeps its number across sessions, or is drawn again each time so two sessions cannot be linked by it.'**
  String get tokenRotationWhat;
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
