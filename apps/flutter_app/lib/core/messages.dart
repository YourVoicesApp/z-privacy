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

/// **A name the person gave, isolated so the sentence keeps its order** — the
/// owner's test of 16 October 2026.
///
/// His session is called «ألماني 1». Inside an English sentence the
/// bidirectional algorithm pulled the digits and the quotes into the Arabic
/// run, and the line drew as
///
///     This document came back from «11 .«ألماني names stay…
///
/// — a sentence whose words are all correct and whose order is nonsense. The
/// fix is one pair of characters: `U+2068 FIRST STRONG ISOLATE` before the
/// name and `U+2069 POP DIRECTIONAL ISOLATE` after it. The algorithm then
/// takes the name's direction from its own first strong character and lays the
/// whole of it out as one unit, so everything around it stays where the
/// sentence put it. Flutter's text layout runs that algorithm, so this is the
/// fix in every widget that draws the string — nothing has to be done at the
/// drawing end.
///
/// **Every name a person chose goes through here**: a session's, a document's,
/// a client's, a value of theirs. Our own words never need it, and a sentence
/// that interpolates a name without it is the defect above waiting for the
/// first person whose language is not ours.
String theirOwnWord(String name) => '\u2068$name\u2069';

/// What a person is told when something the app cannot name goes wrong.
///
/// A new variant added to the contract lands here rather than leaking its debug
/// formatting. `errorIsCovered` exists so a test can prove that never happens
/// silently.
const String unnamedTrouble =
    'Something went wrong. Z Privacy did not complete the action.';

/// **What a preview side claims about the text it draws** — one sentence for
/// the two screens that draw one, since rule 60-أ gave the chat its own band.
///
/// The work surface said it first, beside the Safe column, and the chat's band
/// is the same claim about the same thing: a second literal would be two
/// screens promising the same fact in two wordings, and the drift between them
/// is exactly what a person would read as a difference.
String exactlyWhatWouldLeave(int replaced) =>
    'This is exactly what the AI will receive. $replaced values were replaced.';

/// **Nothing was read, because nobody said in which language** — rule 57-د.
///
/// «Not now» is a real answer and not a failure: no language, no reading, no
/// session, nothing kept. But a press that does nothing and says nothing reads
/// as a broken program — the lesson of 081's emptied clipboard, «المستخدم لا
/// يدرك أنه نفس النسخ القديم» — so the screen says what did not happen and the
/// one thing that would make it happen.
///
/// Two states, two sentences, because they have two next moves: a session that
/// is already open can be given a language in its room, and a session that was
/// never born cannot be given anything.
String noLanguageSoNothingWasRead({required bool aSessionIsOpen}) => aSessionIsOpen
    ? 'Nothing was read. A text is read with one language’s habits, and this '
          'session has never been given one — so Z Privacy did not choose for you. '
          'Read it again and answer, or give the session its language in Settings.'
    : 'Nothing was read. A text is read with one language’s habits, and none was '
          'chosen — so nothing was read and no session was made. Try again and '
          'choose one.';

/// The human sentence for a typed error. The only such function in the app.
String humanMessage(Object error) {
  if (error is! ApiError) return unnamedTrouble;
  return switch (error) {
    ApiError_NotImplemented() =>
      'This part of Z Privacy is not built yet.',
    ApiError_InvalidSession() =>
      'That session is no longer open. Start a new one.',
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
    // 083a. **Short, and true of every door that raises it.** All three exits
    // ask one law in the core now, and this is the sentence they all carry, so
    // it says the two things a person needs at that moment: how many of their
    // own words are waiting, and that nothing went out. The review opens on
    // the first of those words at the same time, which is the rest of the
    // answer (083, rule 12).
    ApiError_OpenSuggestions(:final count) => count == 1
        ? 'One word waits for your answer — nothing left Z.'
        : '$count words wait for your answer — nothing left Z.',
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
    // 050/A. **The place is fine.** This used to be a `StorageRefused`, so a
    // person whose second window had written was told «Z Privacy will not use
    // that location» about a folder that is writable and a file that is
    // intact. It carries no reason from the core because there is only one,
    // and it ends with the two things that work — close the other window, or
    // take in its work — because a refusal without a next move leaves the
    // person holding an open vault they cannot save.
    ApiError_VaultChangedElsewhere() =>
      'Another copy of Z Privacy changed this vault. Close that window, or '
          'lock and unlock here to take in its work.',
    // 058. **The promise, and not only the cause.** Z could write here; it is
    // declining to, because the person took a permission off the folder. So
    // this does not say «will not use that location» — the location is the one
    // they chose and it is perfectly usable — and it does not quietly mend the
    // folder, which is what the core used to do. The promise comes first
    // because it is the part they cannot find out any other way, and both next
    // moves are theirs to pick.
    ApiError_StoragePermissionsKept(:final reason) =>
      'Z Privacy will not change a permission you set, so nothing was saved — '
          '${_lower(reason)}. Change the permission yourself, or choose another '
          'folder.',
    ApiError_DocumentRefused(:final reason, :final detail) => _document(reason, detail),
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
      'That protected value is not in this session.',
    ApiError_NothingToSend() =>
      'There is nothing to send yet. Bring in a document or write some text.',
    ApiError_PayloadRefused(:final reason) => _sentence(reason),
    // 064f. The person did nothing wrong and nothing was created, so the
    // sentence says what did not happen and what to do — never «invalid call».
    // It should not be reachable from this build: the panel hands the open
    // document down. It exists so that no future door can make a session that
    // cannot name the document in front of them.
    ApiError_SessionWithoutItsDocument() =>
      'The session was not started, because Z Privacy could not tell which document you have '
          'open — and a session has to rename what is already protected on it. Nothing was '
          'changed. Open the document and start the session from there.',
    ApiError_PayloadAlreadySent() =>
      'This request was already sent. Prepare it again to send once more.',
    ApiError_NetworkRefused(:final reason, :final detail) =>
      _network(reason, detail),
    // Not a wildcard by accident: the test below walks every variant, so a new
    // one fails that test rather than quietly arriving here.
    _ => unnamedTrouble,
  };
}

/// **«This is already protected — Z put it there.»** — 079 rule 5, the lead's
/// own wording.
///
/// One sentence in one place, because two presses can reach it: the Protect
/// button over a selection, and the column press. They word every other outcome
/// differently on purpose — «protected one cell» is not «protected» — but this
/// one state has one wording, which is 046/L's rule and the defect the send
/// sheet's hint was the weaker half of.
///
/// It is not a failure and does not read like one: the text really is
/// protected, by this program, in the conversation it came from. What a person
/// must not be told is «protected» again, because a second token would then be
/// standing over the first and the answer would come back unreadable.
const String theTokenIsAlreadyOurs = 'This is already protected — Z put it there.';

/// **What each source is called on screen**, and why the mark is there.
///
/// It moved here from `widgets/document_text.dart` the day the outcome
/// sentences were folded: a sentence that names who protected something cannot
/// be written in this file while the name it uses lives in a widget, and `core`
/// may not reach into `widgets`. The chips on the token list and on the acts
/// card read the same four words, which is the point.
String sourceName(Source s) => switch (s) {
  Source.generalRule => 'Rule',
  Source.languagePack => 'Pack',
  Source.vault => 'Vault',
  Source.hand => 'You',
};

/// **Who answered one turn of a chat**, in the words the thread uses — rules
/// 65 and 75c.
///
/// The core resolves this when the turn is written and the three states are
/// its own: «لا نعرف» ليست «لم يكن هناك». A name is never guessed from the
/// provider configured today, because the turn in front of a person may be
/// older than that choice.
String whoAnswered(TurnVia via) => switch (via) {
  TurnVia_Through(:final provider) => provider,
  // The person carried the text out and the answer back, so nothing of ours
  // answered it — and the thread says that rather than naming a key.
  TurnVia_Pasted() => 'brought back by hand',
  // A turn older than the question. The chat draws only this round's turns, so
  // this is the answer to a question the thread cannot ask — and it is still
  // answered, because an absence has more than one cause.
  TurnVia_NotRecorded() => 'not recorded',
};

/// **What one press was made on** — the only thing that changes the sentence an
/// outcome gets, and so the only argument beside the outcome itself.
///
/// A column is not a selection: «Protected 3 cells down that column, the first
/// as T» is not «Protected as T, in 3 places», and a person who pressed on a
/// column is owed a sentence about cells. That difference is a difference of
/// **shape** and it is named here; everything else is one wording for one
/// state, which is 046/L.
enum ProtectAct {
  /// A hand selection in the document, and the Protect button beside it.
  aSelection,

  /// One cell, and the column under it — the press that counts cells.
  aCell,

  /// A place 084's search bar found, pressed from the bar.
  aPlaceTheBarFound,
}

/// **The sentence for what protecting did** — one function, every press.
///
/// Until 15 October each press worded every outcome where the press happened:
/// `widgets/acts.dart` for a selection, `screens/workspace.dart` for a column,
/// `widgets/find_in_document.dart` for the bar. Three exhaustive switches over
/// one enum, and they had already drifted — the bar said «Already protected as
/// T.» where the other two named who by, and wrote `Snapped` in a third
/// wording of its own. The same defect family as 046/L and as the one sentence
/// G32 keeps in one place: a state said in two voices is a product that
/// disagrees with itself, and a sixth variant would have had to be found in
/// three files.
///
/// The switch stays **exhaustive**, so a sixth variant still stops the build —
/// in one place instead of three, which is the whole of the fold. G33 is the
/// half that keeps it one place.
String protectSaid(ProtectOutcome outcome, ProtectAct act) => switch (outcome) {
  // **The one arm whose shape the act changes.** A column that was already
  // protected top to bottom comes back `places: 0`, which is «every cell was
  // already protected» and not «protected in 0 places» — the core's own
  // wording decision, kept word for word from the press that held it.
  ProtectOutcome_Applied(:final token, :final places) => switch (act) {
    ProtectAct.aCell => switch (places) {
      0 => 'Every cell in that column was already protected.',
      1 => 'Protected one cell, as $token.',
      _ => 'Protected $places cells down that column, the first as $token.',
    },
    _ => places == 1
        ? 'Protected as $token.'
        : 'Protected as $token, in $places places.',
  },
  // **Who by, at every press.** The bar left this half out; a person told
  // «already protected» and not told whether that was their own hand or the
  // vault has to go and look.
  ProtectOutcome_AlreadyProtected(:final token, :final source) =>
    'Already protected as $token, by ${sourceName(source).toLowerCase()}.',
  ProtectOutcome_BelongsToEntity(:final entity, :final token) =>
    'That belongs to $entity and keeps its token $token.',
  // One wording, and the act supplies the subject. Nothing changed, and what
  // the act *would* take is said in the same breath so that a second press on
  // «Protect whole items» is a decision and not a surprise.
  ProtectOutcome_Snapped(:final spans) =>
    '${_whatWasPressed(act)} cuts into protected text, so nothing changed. '
        'It would snap to ${spans.length} whole '
        '${spans.length == 1 ? "item" : "items"}.',
  // 079 rule 5. One state, one wording, whichever press reached it.
  ProtectOutcome_StandsOnAToken() => theTokenIsAlreadyOurs,
};

/// What the press was on, as a sentence's subject. Three words, and the reason
/// they are not three sentences is above.
String _whatWasPressed(ProtectAct act) => switch (act) {
  ProtectAct.aSelection => 'The selection',
  ProtectAct.aCell => 'That cell',
  ProtectAct.aPlaceTheBarFound => 'That place',
};

/// **What a document that came back carries, in one sentence** — 079, the
/// import side.
///
/// `null` when there is no token in it at all, which is every ordinary
/// document: a strip that said «0 names came back» over a letter somebody has
/// just opened would be noise where nothing happened.
///
/// **A name that stays a token now has one of two causes, and both are said.**
/// Since 089 every word that took a token is a block in the vault, so a name
/// that did not come back was either protected before this build kept blocks,
/// or it was never this machine's at all. The sentence that stood here until
/// 15 October — «this conversation's own names are kept only while it is open»
/// — was the owner's cost said out loud, and he withdrew it.
///
/// The numbers are the core's, counted by **name** and not by place, and
/// nothing here counts anything.
String? whatCameBack(ReturnedDocument seen) {
  if (seen.tokens == 0) return null;
  // **What the vault changes, and what it does not.** A shut vault cannot name
  // a conversation — the namespace is derived from a key this machine cannot
  // reach — so «a conversation this vault does not hold» would name the wrong
  // cause, and so would «kept only while it is open». What it does **not**
  // change is a bench of that conversation still in memory: its own store
  // holds this run's names, and those come back with the vault shut. So the
  // state decides the wording of an absence and never the count of what came
  // back.
  final shut = seen.vault != VaultState.unlocked;
  final said = <String>[];
  if (seen.broughtBack > 0) {
    // Named by the conversations that actually brought something back, not by
    // every one in the document: «2 names came back from «A» and «B»» when B
    // brought back none would be a sentence with a false half.
    final named = seen.conversations
        .where((c) => c.broughtBack > 0)
        .map((c) => '«${theirOwnWord(c.name)}»')
        .join(' and ');
    if (named.isEmpty) {
      said.add(seen.broughtBack == 1
          ? 'One name came back.'
          : '${seen.broughtBack} names came back.');
    } else {
      said.add(seen.broughtBack == 1
          ? 'One name came back from $named.'
          : '${seen.broughtBack} names came back from $named.');
    }
  } else if (seen.conversations.isNotEmpty) {
    final named = seen.conversations.map((c) => '«${theirOwnWord(c.name)}»').join(' and ');
    said.add('This document came back from $named.');
  }
  if (seen.unresolved.isNotEmpty) {
    final n = seen.unresolved.length;
    if (shut) {
      // The act that would answer it, in the words this file already uses for
      // a vault that may be locked **or** absent («Unlock or create your
      // vault…»): a person with no vault cannot unlock one.
      said.add(n == 1
          ? 'One name is still a token: unlock or create your vault and Z can '
              'look for it.'
          : '$n names are still tokens: unlock or create your vault and Z can '
              'look for them.');
    } else {
      // **Which cause, from the core's own split** — 089 rule 4 asks for the
      // reason and the core already holds the part it can prove. The
      // conversations it could name account for their own unresolved names;
      // what is left over belongs to a namespace this vault does not hold, and
      // the clause below says that one with the handle it has. So this clause
      // speaks only for the names whose session **is** here.
      final here = seen.conversations.fold<int>(0, (sum, c) => sum + c.unresolved);
      if (here > 0) {
        // **Two causes, and this build cannot tell them apart** — the
        // independent attacker's م4, 17 October 2026.
        //
        // It said one of them as a fact: «it was protected before Z Privacy
        // began keeping every protected word». He exported a session's text,
        // changed one hex digit in a token's tail and read the file back — and
        // met that sentence about a file somebody had edited. A token that no
        // longer matches any block has no block for either reason, and nothing
        // in a `ReturnedDocument` separates them: **the law is that a sentence
        // does not state a cause the core has not proved.**
        //
        // So both are named, and the act that answered the owner's own
        // complaint of 16 October — «protect it again in its session» — is
        // also the experiment that tells them apart: if the name comes back
        // from then on it was the first, and if it does not, the file is not
        // the one this program wrote.
        //
        // What **could** prove it is the session's own turns: each one records
        // the tokens its payload was allowed to carry, so a token that no turn
        // of that session ever let out was not minted there. That is a field
        // this reading does not carry, and adding one is a change to the
        // bridge — reported rather than guessed at.
        said.add(here == 1
            ? 'One name stays as a token, and two different things do that: the '
                'word was protected before Z Privacy began keeping every '
                'protected word, or this token was changed after the file left. '
                'Open that document in its session and protect the name again — '
                'if it comes back from then on it was the first, and if it does '
                'not, this file is not the one Z Privacy wrote.'
            : '$here names stay as tokens, and two different things do that: '
                'they were protected before Z Privacy began keeping every '
                'protected word, or the tokens were changed after the file '
                'left. Open those documents in their session and protect the '
                'names again — if they come back from then on it was the '
                'first, and if they do not, this file is not the one Z Privacy '
                'wrote.');
      }
    }
  }
  // The core leaves this empty when there was no vault to hold a conversation,
  // so nothing here asks about the vault a second time: «matches nothing»
  // needs something to match against, and that judgement is the core's.
  if (seen.unknownNamespaces.isNotEmpty) {
    final which = seen.unknownNamespaces.join(', ');
    // «It also» only after something else has been said: a document whose every
    // name belongs elsewhere gets a sentence that stands on its own, because a
    // line beginning «It also» with nothing before it names nothing.
    final also = said.isEmpty ? 'This document carries' : 'It also carries';
    // **And how many stayed tokens**, because since 089 this clause is the only
    // one that speaks for these names: every other token in the document came
    // back from a block, so «3 names stay as tokens» above is about the ones
    // this vault could have held and these are the ones it never could.
    //
    // **Zero is a real case and gets no number.** A conversation that was
    // forgotten takes its key with it, so its namespace is one this vault
    // cannot name — and its words still come back, because a block keeps the
    // token it was given and needs no key. «It also carries 0 names from a
    // conversation this vault does not hold» would be a sentence counting
    // nothing; what is true there is only where they are from.
    final elsewhere = seen.unresolved.length -
        seen.conversations.fold<int>(0, (sum, c) => sum + c.unresolved);
    final many = elsewhere == 1 ? '1 name' : '$elsewhere names';
    final whose = seen.unknownNamespaces.length == 1
        ? 'a session this vault does not hold'
        : 'sessions this vault does not hold';
    // **And the act, which here is that there is none** — the owner, 16
    // October. A namespace this vault cannot name was made by a key that is
    // not on this machine: a conversation that was forgotten took its key with
    // it, and another machine's key was never here. Saying so plainly is the
    // next step; offering one that cannot work would be worse than silence.
    //
    // Two numbers and they are different numbers: how many names there are,
    // and how many keys are missing. A sentence that read one off the other
    // said «11 names … the key that made it» on the owner's own file.
    final it = elsewhere == 1 ? 'it' : 'them';
    final keys = seen.unknownNamespaces.length == 1
        ? 'the key that made $it is'
        : 'the keys that made $it are';
    final nothing = ' Nothing here can put $it back: $keys not in this vault.';
    said.add(elsewhere > 0
        ? '$also $many from $whose ($which).$nothing'
        : '$also names from $whose ($which).$nothing');
  }
  return said.isEmpty ? null : said.join(' ');
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

/// **And the detail, where the core wrote one** — the attacker's ن15 again.
///
/// `MalformedDocument` had one sentence for every shape of broken file, and
/// the core's own detail — «this file does not begin like a PDF», «this PDF
/// lists no pages», «no objects could be read out of this PDF» — never reached
/// the glass. Those are the words a person can act on, and the shape is the
/// one `InsecureUrl` already uses: the core writes the fact, this says it, and
/// the general sentence is kept for a refusal that carries no detail at all.
String _document(Refusal reason, String detail) => switch (reason) {
  Refusal_MalformedDocument() => detail.isEmpty
      ? 'This document is damaged or incomplete.'
      : _sentence(detail),
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
  // **The limits, said with their numbers** — e2's reading of the attacker's
  // B3-4 and this round's خ5 and ن16, both on 17 October, landing on the same
  // seven refusals from two sides. The core names every one of them and says
  // how big the thing was that it refused; the screen collapsed them all into
  // «This file could not be opened safely», which tells a person nothing they
  // can act on — not whether the file is too big, too deep, a bomb, or simply
  // empty. The sentences below are e2's words.
  //
  // **And there is no fallback under them.** A `_ =>` would answer for a
  // variant nobody has written a sentence for, which is how these seven came
  // to read alike in the first place; without it the day somebody adds an
  // eighth is a compile error that names the file to write it in. The
  // contract's twelve are walked in `messages_test` as well, so the two halves
  // agree: a list that is missing a variant is a control that cannot bite.
  //
  // «About», not «exactly», on the size — and the reason changed with ن16 on
  // the same day: the core used to **floor** the megabytes, so a file one byte
  // past 25 MiB measured as 25 and «this file is 25 MiB and the limit is 25
  // MiB» read as a program arguing with itself. It rounds **up** now, so the
  // figure overstates by less than a megabyte and can never understate, which
  // is the direction a refusal's own number must round.
  Refusal_DocumentTooLarge(:final mib, :final limitMib) =>
    'This file is about $mib MiB, and Z Privacy opens documents up to '
        '$limitMib MiB.',
  Refusal_TooManyPages(:final pages, :final limit) =>
    'This document has $pages pages, and Z Privacy opens up to $limit in one '
        'document.',
  Refusal_TextTooLarge(:final limitMib) =>
    'Unpacked, a part of this file is more than $limitMib MiB — more than Z '
        'Privacy reads in one document, so none of it was imported.',
  Refusal_CompressionBomb(:final ratio) =>
    'A part of this file unpacks to more than $ratio times the space it takes '
        'up. No real document does that, so Z Privacy stopped unpacking it '
        'instead of filling the machine.',
  Refusal_TooManyParts(:final parts, :final limit) =>
    'This file lists $parts parts inside it, and a document has tens, not '
        'thousands — Z Privacy opens up to $limit.',
  Refusal_TookTooLong(:final millis) =>
    'Reading this file was still going after ${millis ~/ 1000} seconds, so Z '
        'Privacy stopped. Nothing of it was imported.',
  Refusal_EmptyDocument() =>
    'There is no text in this file for Z Privacy to protect.',
};

/// **A key the vault is holding is not a key that was never given** — the
/// owner, 18 October 2026, who read «No AI provider is connected. Add an
/// address and a key first.» about a key sealed in his own vault after it
/// auto-locked.
///
/// Both moves are named, because the state does not say which one the person
/// needs: a shut vault answers nothing about its contents, so «unlock it» is
/// for the one whose key is in there and «give a key for this run» is for the
/// one who never had one. Naming only the first would be the same guess in the
/// other direction.
///
/// **One sentence, three seats.** It is the refusal a send gets back
/// (`NetworkRefusal.vaultLocked`), and it is what the compose line and the
/// Direct API card say **before** a press — because a person should not have
/// to send a question to find out that the vault is shut. Three places that
/// said it in their own words would drift, and the first time they disagreed
/// the quieter one would win.
const theKeyIsBehindTheLockedVault =
    'Z Privacy cannot reach a key while the vault is locked. Unlock it, or '
    'give a key for this run.';

String _network(NetworkRefusal reason, String detail) => switch (reason) {
  NetworkRefusal_NotConnected() =>
    'No AI provider is connected. Add an address and a key first.',
  // **A key the vault is holding is not a key that was never given** — the
  // owner, 18 October 2026, who read the sentence above about a key sealed in
  // his own vault after it auto-locked, and was told to add one.
  //
  // Both moves are named, because the state does not say which one the person
  // needs: a shut vault answers nothing about its contents, so «unlock it» is
  // for the one whose key is in there and «give a key for this run» is for the
  // one who never had one. Naming only the first would be the same guess in
  // the other direction.
  NetworkRefusal_VaultLocked() => theKeyIsBehindTheLockedVault,
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
  // **The ninth, and it was the one that fell through** — the independent
  // attacker's ن15. «The connection to that provider did not work» fits every
  // other branch here too, which is why it said nothing: not whether the
  // address is wrong, this machine is offline, or the provider is down. The
  // core separates the nine; this is the one it had no sentence for.
  NetworkRefusal_Unreachable() =>
    'That address could not be reached at all — nothing answered. Check that '
        'you are online and that the address is right. Nothing was sent.',
};
