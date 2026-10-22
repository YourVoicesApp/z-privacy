// Settings — four small rooms, not one long page.
//
// The owner's division, and the reason it is a division: a person looking for
// «where does my API key live» should not have to scroll past the reveal
// duration to find out.
//
//   AI                 the three doors
//   Privacy            what the app does by itself
//   Language & rules   the detection engine, and the interface
//   Vault & security   the key, the lock, and where a credential lives
//
// Nothing here can make something leave the device. These switches decide only
// how far the app goes on its own — and one of them is missing on purpose:
// there is no «send anyway», not as a setting, not as a hidden flag.
//
// **063 — this is a panel, not a page.** It used to be one of the shell's early
// returns, so opening it unmounted whatever was on the screen: a person with a
// document in front of them could not reach the settings at all, because a
// control that hid their document could not have been put in the top bar. It is
// now 480 wide against the right edge with the work still behind it, which is
// why there is no back arrow on it any more — there is nothing to go back to.
// The owner, 8 October: «نجعل نافذة الإعدادات خيار في الأعلى يفتح قائمة إلى يمين
// الشاشة وتغلق بالضغط عليها», and 480 is his number.
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:zprivacy/core/messages.dart';
import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/sentences.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/core/the_system_browser.dart';
import 'package:zprivacy/widgets/language_list.dart';
import 'package:zprivacy/src/rust/api/core.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/conversation_view.dart';
import 'package:zprivacy/widgets/connect_form.dart';

/// **Appended, never inserted** — 064. The guards name a room rather than its
/// position, so a room added at the end costs the doors nothing.
///
/// **The default is `sessions` since rule 74** (the owner, 18 October 2026:
/// the settings open on the list of what he kept, not on the AI room). The
/// sentence here used to warn that «a changed default would cost everything»
/// to the send sheet's «Open Settings», which relied on landing in the room
/// where a key is asked for — so that reliance is gone: every door that is
/// about a credential now names `SettingsRoom.ai` itself, and the default is
/// free to be what the owner asked for.
enum SettingsRoom { ai, privacy, language, vault, sessions }

/// **The one door to the settings, and the one way back out.**
///
/// The same widget in the top bar, in the home page's heading, and in the
/// panel's own corner — and never two of them at once: every surface that
/// carries it hides it while the panel is open, because the panel covers the
/// right 480 and a second door under it would be a door nobody can press. The
/// bar's padding and the panel's are the same, so the door does not move on the
/// glass when it is pressed: one press opens, the next closes, in the place the
/// finger already is.
///
/// The tooltip names the room and not the act, in both states, because that is
/// what the person is looking for — and because exactly one «Settings» on the
/// screen is the property the 063 guards assert.
class SettingsDoor extends StatelessWidget {
  const SettingsDoor({super.key, required this.open, required this.onTap});

  /// Whether the panel is showing. It changes the tint, not the icon: a toggle
  /// that becomes a different picture is two controls to learn.
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: sentences.settings,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(Icons.tune, size: 17, color: open ? Zc.clayDeep : Zc.ink3),
        ),
      ),
    );
  }
}

/// What a press on a saved document asks the shell to do — 089 rule 9.
///
/// `(number, which, chat)`: the conversation, the document's own number inside
/// its sequence, and which sequence. The panel cannot open a document itself —
/// only the shell holds the bench — so the press travels, exactly as «+» and
/// «z-pdf» do.
typedef OpenKept = void Function(int number, int which, bool chat);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.ground,
    required this.onClose,
    this.room,
    this.bench,
    this.onOpenKept,
    this.onReadBack,
    this.onFromZero,
  });

  final Ground ground;
  final VoidCallback onClose;
  /// **A press on a saved document** — 089 rule 9. Null in a panel built with
  /// no shell behind it (a test of the room itself), and the rows then say so
  /// rather than offering a press that does nothing.
  final OpenKept? onOpenKept;

  /// **A new chat starts from zero** — rule 71, for the two of its three doors
  /// that live in this panel: a session deleted from its room, and a new
  /// session opened. The surface is the shell's bench, so the panel says one
  /// of them happened and the shell is what empties. Null where a guard mounts
  /// the panel with no shell behind it, as `onOpenKept` is.
  final VoidCallback? onFromZero;

  /// **«z-pdf», the door back — and this is where it lives since rule 70.**
  ///
  /// It stood on the first screen, in the «+» menu beside «Add a document»,
  /// and the first screen is gone: the owner's own placing, 17 October —
  /// «نجعل الإعدادات تحتوي على إدخال z-pdf». The press travels exactly as
  /// `onOpenKept` does, because only the shell may open a file chooser and
  /// show the reading over everything.
  ///
  /// Null in a panel built with no shell behind it, and then the room draws no
  /// press rather than a dead one — 083a.
  final VoidCallback? onReadBack;
  final SettingsRoom? room;

  /// **The document open behind the panel, if there is one** — 064f.
  ///
  /// A session begun in the Sessions room must re-derive the names already on
  /// that document, and the core refuses a birth that does not name it. Null is
  /// a panel opened with nothing on the bench, which is legitimate: there is
  /// nothing to rename and the core allows it.
  final SessionId? bench;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// **Rule 74**: the room the settings open on, when a press did not name
  /// one. The owner's own order of what matters — what he kept comes first.
  late SettingsRoom _room = widget.room ?? SettingsRoom.sessions;

  /// **The catalogue, asked for when the panel opens** — 064/C.
  ///
  /// It arrived with the models that moved out of the send sheet. Asked of the
  /// core here rather than kept on the ground beside the providers, because a
  /// second cached copy of one fact is how two screens come to say different
  /// things — the panel reads it when it is opened, which is the only moment
  /// it draws it.
  List<ModelDescriptor> _catalogue = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_readTheCatalogue());
  }

  Future<void> _readTheCatalogue() async {
    try {
      final got = await z.models();
      if (!mounted) return;
      setState(() => _catalogue = got);
    } on ApiError {
      // A panel that cannot list the models still connects them: the room's
      // own forms are what a person came for, and a missing list says so by
      // being missing rather than by taking the room down.
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.ground;
    return ListenableBuilder(
      listenable: g,
      builder: (context, _) => Material(
        color: Zc.paper,
        elevation: 10,
        shape: const Border(left: BorderSide(color: Zc.line)),
        // **The `Material` is what stops what it covers**, and that is measured
        // rather than assumed: a press on the top strip and a press in the
        // middle of the room both end inside this panel and reach nothing in
        // the work behind it. There was a `GestureDetector(opaque)` here first,
        // on the belief that a painted box does not take presses — the guard
        // said the panel was already tight with it taken out, twice, so it went
        // rather than stand as a line claiming work it was not doing. If this
        // ever becomes a plain `Container`, the hit test in
        // `the_settings_cover_the_work_test.dart` is what will say so.
        child: Column(
          children: [
            // The top strip, where the full-screen header used to be. It
            // carries the room's name and the door that shuts it, and the
            // padding is the top bar's own — so the door is at the same point
            // on the glass as the one that opened it.
            Container(
              padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
              decoration: const BoxDecoration(
                color: Zc.card,
                border: Border(bottom: BorderSide(color: Zc.line)),
              ),
              child: Row(
                children: [
                  // The owner's picture in the panel's head too — 072. Small,
                  // because this strip stands over a person's document and the
                  // door that shuts it is the thing they are reaching for.
                  const BrandMark(size: 20),
                  const SizedBox(width: 9),
                  Text(sentences.settings, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Zc.ink)),
                  const Spacer(),
                  // **The build stamp, which rule 70 would otherwise have
                  // taken off the glass altogether.** It stood in the head of
                  // the first screen — «z_core 0.1.0 · date · sha», the core's
                  // own line, verbatim — and it is the one thing a person
                  // sends with a report about a program that misbehaved. The
                  // first screen is gone, so it stands in the head of the one
                  // panel that is about the program rather than about a
                  // document.
                  //
                  // Room to shrink and not room to overflow, which is the
                  // lesson the home's own strip learnt on 3 October: it is
                  // three times the length of «z_core 0.1.0» and the door
                  // beside it is what a person is reaching for.
                  Flexible(
                    child: Text(
                      coreVersion(),
                      style: Zc.tiny.copyWith(fontFamily: Zc.mono),
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SettingsDoor(open: true, onTap: widget.onClose),
                ],
              ),
            ),
            _rooms(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                child: switch (_room) {
                  SettingsRoom.ai => _AiRoom(ground: g, catalogue: _catalogue),
                  SettingsRoom.privacy => _PrivacyRoom(ground: g),
                  SettingsRoom.language => _LanguageRoom(ground: g),
                  SettingsRoom.vault => _VaultRoom(ground: g, onReadBack: widget.onReadBack),
                  SettingsRoom.sessions => _SessionsRoom(
                    ground: g,
                    bench: widget.bench,
                    onOpenKept: widget.onOpenKept,
                    onFromZero: widget.onFromZero,
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The four rooms, across the top rather than down the side.
  ///
  /// They were a 210-wide rail, which left 269 of the panel's 480 for the room
  /// itself. A `Wrap` was chosen over a horizontal scroll on purpose: the four
  /// labels come to a few pixels more than 480, and a strip that has to be
  /// scrolled sideways to find «Vault & security» hides the one room a person
  /// comes here looking for. It flows onto a second line instead, and cannot
  /// overflow at any width. The names are the file's own four and none of them
  /// changed — 063 moves this room, it does not furnish it.
  Widget _rooms() {
    Widget one(SettingsRoom r, String label, IconData icon) {
      final on = _room == r;
      return Material(
        color: on ? Zc.clayWash : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => setState(() => _room = r),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: on ? Zc.clayDeep : Zc.ink3),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                    color: on ? Zc.clayDeep : Zc.ink2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Zc.warmCard,
        border: Border(bottom: BorderSide(color: Zc.line)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          one(SettingsRoom.ai, sentences.roomAi, Icons.hub_outlined),
          one(SettingsRoom.privacy, sentences.roomPrivacy, Icons.shield_outlined),
          one(SettingsRoom.language, sentences.roomLanguageAndRules, Icons.translate),
          one(SettingsRoom.vault, sentences.roomVaultAndSecurity, Icons.lock_outline),
          one(SettingsRoom.sessions, sentences.roomSessions, Icons.layers_outlined),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- AI

class _AiRoom extends StatelessWidget {
  const _AiRoom({required this.ground, this.catalogue = const []});

  final Ground ground;

  /// **Every model this build knows** — 064/C, and this is where the whole
  /// catalogue lives now. The owner, 9 October: the work surfaces name the
  /// model that will answer and list the ones that can; the companies, the
  /// greyed names and the way in belong where a person goes to set something
  /// up.
  final List<ModelDescriptor> catalogue;

  @override
  Widget build(BuildContext context) {
    final rows = ground.providers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title(sentences.roomAi, sentences.aiWhat),
        _Card(
          title: sentences.manualAi,
          what: sentences.manualAiWhat,
          child: Text(
            sentences.alwaysAvailableFirstDoor,
            style: Zc.small.copyWith(color: Zc.ink4),
          ),
        ),
        for (final row in rows)
          _Card(
            // Named for the route a person chose, not the protocol. The
            // protocol is a fact about this card and is stated below, beside
            // the endpoint — which is the only place it answers a question
            // anyone actually has.
            title: sentences.directApi,
            // **And what the vault's state means for this card** — 18
            // October 2026. A sealed login cannot be read while the vault is
            // shut, so this card reports «Not connected» about a provider the
            // person connected weeks ago. The card says why, in the sentence
            // the refusal would have used, rather than leaving a press to
            // discover it.
            what: ground.vault == VaultState.locked && !row.connected
                ? theKeyIsBehindTheLockedVault
                : row.credentialRequired
                    ? sentences.directApiWhat: sentences.atThisAddressNoCredential,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Spec(sentences.protocol, row.label),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _Dot(on: row.connected),
                    const SizedBox(width: 8),
                    Text(
                      switch (row.credentialState) {
                        CredentialState.encryptedInVault => sentences.connectedKeySealed,
                        CredentialState.sessionOnly => sentences.connectedKeyThisRunOnly,
                        CredentialState.missing => row.connected ? sentences.connectedNoKeyNeeded: sentences.notConnected,
                      },
                      style: Zc.small.copyWith(
                        color: row.connected ? Zc.ink2 : Zc.ink4,
                        fontWeight: row.connected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _theirModels(row),
                ConnectForm(ground: ground, row: row, local: false),
              ],
            ),
          ),
        if (rows.isNotEmpty)
          _Card(
            title: sentences.localAi,
            what: sentences.localAiWhat,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Spec(sentences.protocol, rows.first.label),
                const SizedBox(height: 10),
                ConnectForm(ground: ground, row: rows.first, local: true),
              ],
            ),
          ),
      ],
    );
  }

  /// One company's models, by name, with the colour the owner asked for.
  ///
  /// **046/H, the owner on 7 October: «the model that has a key is drawn in a
  /// different colour»** — grey was saying «out of reach» and nothing was
  /// saying «ready», in a list of six companies of which two had keys. The
  /// reading moved here with the catalogue it was about, and `available` is the
  /// core's own word for it, so this screen decides nothing.
  ///
  /// Greyed, never hidden: a model this build can offer is worth seeing before
  /// the key for it is given — the way in is the form directly below.
  Widget _theirModels(ProviderFact row) {
    final theirs = catalogue.where((m) => m.providerId == row.id).toList();
    if (theirs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sentences.models, style: Zc.tiny.copyWith(color: Zc.ink4)),
          const SizedBox(height: 5),
          Wrap(
            spacing: 10,
            runSpacing: 5,
            children: [
              for (final m in theirs)
                Text(
                  m.displayName,
                  style: Zc.small.copyWith(
                    color: m.available ? Zc.ready : Zc.ink3,
                    fontWeight: m.available ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Privacy

class _PrivacyRoom extends StatelessWidget {
  const _PrivacyRoom({required this.ground});

  final Ground ground;

  @override
  Widget build(BuildContext context) {
    final c = ground.config;
    if (c == null) return const Text('…', style: Zc.small);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title(sentences.roomPrivacy, sentences.privacyWhat),
        if (c.sessionOnly) ...[
          Trouble(
            sentences.noVaultSoThisRunOnly,
          ),
          const SizedBox(height: 16),
        ],
        _Switch(
          on: c.scanOnImport,
          title: sentences.scanOnArrival,
          what: sentences.scanOnArrivalWhat,
          onChanged: (v) => ground.saveConfig(_with(c, scanOnImport: v)),
        ),
        _Fixed(
          title: sentences.answerEverySuggestion,
          what: sentences.answerEverySuggestionWhat,
        ),
        _Number(
          value: c.revealSeconds,
          title: sentences.aRevealedValueStaysFor,
          unit: 'seconds',
          min: 3,
          max: 300,
          what: sentences.aRevealedValueStaysForWhat,
          onChanged: (v) => ground.saveConfig(_with(c, revealSeconds: v)),
        ),
        _Fixed(
          title: sentences.tokenRotation,
          what: sentences.tokenRotationWhat,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Language

class _LanguageRoom extends StatelessWidget {
  const _LanguageRoom({required this.ground});

  final Ground ground;

  @override
  Widget build(BuildContext context) {
    final c = ground.config;
    if (c == null) return const Text('…', style: Zc.small);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // **«The interface itself is English.» is deleted, not reworded** —
        // 092 is what made it false. The sentence was true and honest for as
        // long as it was true; a false sentence in a privacy product's own
        // settings is worse than a missing one, and the same deletion was made
        // on the first screen for the same reason.
        _Title(
          sentences.roomLanguageAndRules,
          sentences.languageAndRulesWhat,
        ),
        _Card(
          title: sentences.appLanguage,
          // **And it now says that the interface follows this choice**, which
          // is what the card below it used to claim was not true. One choice
          // writes both values (080), so the card that writes them is where
          // that is said.
          what: sentences.appLanguageWhat,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final p in ground.packs.where((p) => offeredLanguages.contains(p.id)))
                    _Pick(
                      label: p.label,
                      on: c.packId == p.id,
                      // **One value, not two** — 080. The first-run screen
                      // wrote `packId` *and* `language` from one choice; this
                      // card wrote `packId` alone, so the two could disagree
                      // and the product would be reading documents in one
                      // language while naming another. The same choice writes
                      // both, here as there.
                      onTap: () => ground.saveConfig(_with(c, packId: p.id, language: p.id)),
                    ),
                ],
              ),
              // **Which of the two a language is** — rule 56-أ, and the hole
              // this closes was live: Svenska is a real scanner language and
              // not yet an interface language, so pressing it wrote
              // `ui_language = 'sv'` and the app drew `app_sv.arb`, which is
              // the English copy. A person chose Swedish and read English,
              // with nothing on the screen saying so. The setting still keeps
              // their choice — `theLocaleOf` is what falls back — and this
              // line is the screen saying both facts instead of one.
              for (final p in ground.packs.where(
                  (p) => offeredLanguages.contains(p.id) && !theListIsWrittenIn(p.id)))
                Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Text(
                    sentences.theInterfaceIsEnglishUntilTranslated(p.label),
                    style: Zc.tiny.copyWith(letterSpacing: 0),
                  ),
                ),
            ],
          ),
        ),
        // **The «Interface» card is deleted** — rule 35, 19 October 2026.
        //
        // It held two picks whose `onTap` was `() {}` and a line reading «not
        // translated yet», under a paragraph explaining that the German
        // translation was not written. All of it was true when it was written
        // and none of it is now: 092 wrote the German, and the card **above**
        // this one changes the interface language, because one choice writes
        // both values (080). So it was not merely dead — it was a second and
        // false opinion about a thing that works, which is worse than a dead
        // control. Deleted rather than disabled, and rather than reworded:
        // what it was for is now said by the card that does the work.
        // **The guide, in the room whose subject is the language it is in** —
        // paper 100, rule 83, and the paper left the room to this seat.
        //
        // Here and not beside the build stamp: the stamp's strip is the head
        // of the panel, and rule 70 put it there as the one thing a person
        // *sends with a report* — a press does not belong in a strip whose
        // other control is the door that shuts the panel. And here rather
        // than in Privacy because the address itself carries a language: the
        // card above this one is what changes it, so the two stand together
        // and a reader can see that the page follows the choice.
        _GuideCard(ground: ground),
        _Card(
          title: sentences.myPrivacyRules,
          what: sentences.myPrivacyRulesWhat,
          child: const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// **One line that opens the guide page on the site** — paper 100, rule 83.
///
/// The owner's law is «one text in one place»: the page is on the site and the
/// application carries the press, so there is no second copy of the text in
/// here to fall out of step with it.
///
/// **The press's label is the address.** Not «Open» and not «Read the guide»:
/// a press that starts another program should say where it is going before it
/// is pressed, and the address is also what is left to the person by hand if
/// no opener can be started on this machine. It is built by
/// `theGuideAddress`, which spells it once for the whole application.
///
/// Stateful for one bool, which is the refusal. A press that does nothing and
/// says nothing is a dead control (rule 35), and «the opener could not be
/// started» is a real outcome on a machine with no desktop opener — so it has
/// a sentence rather than a silence.
class _GuideCard extends StatefulWidget {
  const _GuideCard({required this.ground});

  final Ground ground;

  /// The press, so a guard reaches it by name and not by its sentence — the
  /// same reason `_VaultRoom.theDoorBack` has one.
  static const thePress = ValueKey<String>('settings-the-guide');

  @override
  State<_GuideCard> createState() => _GuideCardState();
}

class _GuideCardState extends State<_GuideCard> {
  bool _refused = false;

  @override
  Widget build(BuildContext context) {
    // **The language the glass is in**, read the way `main.dart` reads it —
    // `theLocaleOf` of the person's choice, so a language whose list is not
    // written answers English here exactly as the interface does. The guide
    // page is about the controls in front of the person, so it is in the
    // language those controls are in; a **file** that leaves takes the
    // session's language instead, which is rule 80 and a different law.
    final address = theGuideAddress(
        theLocaleOf(widget.ground.config?.language ?? 'en').languageCode);
    return _Card(
      title: sentences.howToUseZPrivacy,
      what: sentences.theGuideOpensInYourBrowser,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ZButton(
              key: _GuideCard.thePress,
              label: address,
              icon: Icons.open_in_new,
              tint: Zc.river,
              onPressed: () async {
                final opened = await openInTheBrowser(address);
                if (!mounted) return;
                setState(() => _refused = !opened);
              },
            ),
          ),
          if (_refused) ...[
            const SizedBox(height: 10),
            Trouble(sentences.couldNotOpenYourBrowser),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Vault

class _VaultRoom extends StatelessWidget {
  const _VaultRoom({required this.ground, this.onReadBack});

  final Ground ground;

  /// **The door back, in the room that holds the key** — rule 70.
  ///
  /// It is here and not in Privacy because of 079 rule 8: the meaning of a
  /// z-pdf lives in the vault, so a locked vault is a standing door and this
  /// is the room that says what the vault is doing. Null means no shell, and
  /// then no press is drawn.
  final VoidCallback? onReadBack;

  /// The press, so a guard can reach it by name rather than by its sentence.
  static const theDoorBack = ValueKey<String>('settings-z-pdf');

  @override
  Widget build(BuildContext context) {
    final c = ground.config;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title(sentences.roomVaultAndSecurity, sentences.vaultAndSecurityWhat),
        _Card(
          title: sentences.zVault,
          what: switch (ground.vault) {
            VaultState.unlocked => sentences.vaultOpenWhat,
            VaultState.locked => sentences.vaultLockedWhat,
            VaultState.absent => sentences.vaultAbsentWhat,
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Dot(on: ground.vault == VaultState.unlocked),
                  const SizedBox(width: 8),
                  Text(
                    switch (ground.vault) {
                      VaultState.unlocked => sentences.unlockedWithIdentities(ground.entityCount),
                      VaultState.locked => sentences.vaultIsLocked,
                      VaultState.absent => sentences.vaultIsNone,
                    },
                    style: Zc.small,
                  ),
                ],
              ),
              // **And which folder it is in** — 098 item 2, from the owner's
              // own Windows machine on 20 October: the installed build asked
              // him to create a new vault with his own vault on the same disc,
              // and no screen in this product named a folder. A package
              // installed from the `.msix` has its `%LOCALAPPDATA%` redirected
              // into the package's own data folder, so one answer in
              // `data_dir.rs` becomes two paths on one machine — and a person
              // who cannot read the folder cannot tell «a second vault» from
              // «my vault is gone».
              //
              // **The folder comes from the core**, through the one list this
              // room already reads (092), and it is the folder the application
              // is *using* rather than the one it would have chosen: the
              // default is right on Linux and right on the installer build, and
              // wrong on exactly the install that needs it.
              //
              // **Two sentences, because one would be false.** With no vault in
              // that folder — the owner's own screen — «your vault is in» would
              // name a file that does not exist, so the label says what the
              // folder is *for* instead. Nothing is pressable: a folder is a
              // fact to read, and moving a vault is its own paper.
              if (c?.dataDir case final folder?) ...[
                const SizedBox(height: 8),
                _Spec(
                  ground.vault == VaultState.absent
                      ? sentences.aVaultHereWouldBeIn
                      : sentences.yourVaultIsIn,
                  folder,
                ),
              ],
            ],
          ),
        ),
        // **«z-pdf» — the door back, and the only way in that is not a way in**
        // (079 rule 3, built as 089 rule 5; moved here by rule 70).
        //
        // Directly under the vault's own state, because that state is what
        // decides whether this press can mean anything: the names a z-pdf
        // carries live in the vault, and with it locked the press opens the
        // vault instead of a file (079 rule 8, held in the shell).
        _Card(
          title: sentences.zPdfReadBack,
          what: sentences.zPdfWhat,
          child: onReadBack == null
              // A press with no shell behind it would open nothing: the room
              // says what the door is and does not draw one.
              ? Text(
                  sentences.openThisPanelFromTheApp,
                  style: Zc.small.copyWith(color: Zc.ink4),
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: ZButton(
                    key: theDoorBack,
                    label: sentences.chooseAZPdfFile,
                    icon: Icons.undo_outlined,
                    tint: Zc.river,
                    onPressed: onReadBack,
                  ),
                ),
        ),
        if (c != null)
          _Number(
            value: c.autoLockMinutes,
            title: sentences.lockTheVaultAfter,
            unit: sentences.minutesUnusedZeroIsNever,
            min: 0,
            max: 240,
            what: sentences.lockTheVaultAfterWhat,
            onChanged: (v) => ground.saveConfig(_with(c, autoLockMinutes: v)),
          ),
        _Card(
          title: sentences.encryptedLocalCredentialStorage,
          what: sentences.credentialHomesWhat,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in ground.providers.where((p) => p.credentialState != CredentialState.missing))
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    '${p.label} · ${switch (p.credentialState) {
                      CredentialState.encryptedInVault => sentences.credentialSealedInTheVault,
                      CredentialState.sessionOnly => sentences.credentialInMemory,
                      CredentialState.missing => sentences.credentialNoKeyStored,
                    }}',
                    style: Zc.small,
                  ),
                ),
              if (ground.providers.every((p) => p.credentialState == CredentialState.missing))
                Text(sentences.noProviderHoldsACredential, style: Zc.small.copyWith(color: Zc.ink4)),
            ],
          ),
        ),
        _Card(
          title: sentences.deviceBoundProtection,
          what: sentences.deviceBoundWhat,
          child: const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- pieces

Settings _with(
  Settings c, {
  bool? scanOnImport,
  int? revealSeconds,
  int? autoLockMinutes,
  String? packId,
  String? language,
  bool? firstRunDone,
}) =>
    Settings(
      scanOnImport: scanOnImport ?? c.scanOnImport,
      revealSeconds: revealSeconds ?? c.revealSeconds,
      autoLockMinutes: autoLockMinutes ?? c.autoLockMinutes,
      packId: packId ?? c.packId,
      language: language ?? c.language,
      firstRunDone: firstRunDone ?? c.firstRunDone,
      // Where the handle between the two columns was left. No screen here
      // changes it; it travels so that saving a setting does not move it.
      originalPanePercent: c.originalPanePercent,
      columnsInStep: c.columnsInStep,
      // **Carried, never set** (046/K). This helper is «change one setting»,
      // and writing a literal here would mean that saving the reveal timer
      // re-opened a column the person had closed — the app changing a state
      // only a press may change, which is the one thing the rule forbids.
      safeColumnOpen: c.safeColumnOpen,
      reviewPanelWide: c.reviewPanelWide,
      sessionOnly: c.sessionOnly,
    );

class _Title extends StatelessWidget {
  const _Title(this.title, this.what);

  final String title;
  final String what;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Zc.h1),
            const SizedBox(height: 7),
            Text(what, style: Zc.body),
          ],
        ),
      );
}

// ---------------------------------------------------------------- Sessions

/// **The owner's sessions** — 064, and the room he asked for: «نجعل داخل
/// الإعدادات إنشاء جلسة جديدة، البنك، وقائمة بأسماء الجلسات السابقة».
///
/// Two of the three are here. **The bank waits for its paper**, which is the
/// lead's own debt as of 9 October — a room is not furnished twice on a guess,
/// so there is no placeholder for it and no half-built card pretending to be
/// one.
///
/// A session is created **two ways and they are the same birth**: deliberately,
/// by the button below, and inevitably, at the first exit for a person who
/// never pressed it. 062 §F once said there would be no such button; that was
/// the lead's inference from a build where only the exit could make one, and
/// the owner's later words supersede it.
class _SessionsRoom extends StatefulWidget {
  const _SessionsRoom({
    required this.ground,
    this.bench,
    this.onOpenKept,
    this.onFromZero,
  });

  final Ground ground;
  final OpenKept? onOpenKept;

  /// Rule 71: a session deleted here, or a new one begun here, ends a chat —
  /// and the surface then starts from zero.
  final VoidCallback? onFromZero;

  /// The document open behind the panel. Passed to the birth so the names on it
  /// move into the new session — see [SettingsScreen.bench].
  final SessionId? bench;

  @override
  State<_SessionsRoom> createState() => _SessionsRoomState();
}

class _SessionsRoomState extends State<_SessionsRoom> {
  final _name = TextEditingController();
  bool _busy = false;

  /// **What the birth actually did**, in the core's own number — 064f.
  ///
  /// The card promises that what is already protected on the open document is
  /// renamed into the new session. Before this the promise was made and the
  /// result was invisible: a birth that renamed nothing returned 0 and the room
  /// showed the same thing as a birth that renamed nine. A promise displayed
  /// and not shown kept is how the panel's own «Begin» hid a defect for a day.
  String? _said;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// **The language this session will be read in** — 080, the owner's first of
  /// two ways. Null until the first build, then the application's own language,
  /// which is what «preselected» means: a person who wants that one presses
  /// nothing.
  String? _packId;

  /// **Create one, with a name and a language** — 080.
  ///
  /// The order is the whole of it, and each step is a different door:
  ///
  ///   1. the birth, which takes its language from the bench if there is one —
  ///      so a session created with a document open starts as that document
  ///      was read;
  ///   2. `conversationSetPack`, by the session's **number**, because the
  ///      choice has to hold whether or not a document is open and
  ///      `switch_pack` needs a bench. This is the core door 080 added;
  ///   3. `switchPack` on the bench, only when there is one, so the document in
  ///      front of the person is re-read in the language of the session it has
  ///      just joined. Without it the row would say «German» over a document
  ///      scanned in English — true of the session, false of what is on screen.
  Future<void> _begin() async {
    final name = _name.text.trim();
    // **A language, chosen by the person** — rule 57a. Not a default: the
    // button is dead without one, and this is the second half of the same law,
    // because a door that can be reached another way has to hold on its own.
    final chosen = _packId;
    if (name.isEmpty || chosen == null || _busy) return;
    setState(() => _busy = true);
    final renamed = await widget.ground.beginSession(name, bench: widget.bench);
    if (renamed != null) {
      final number = widget.ground.openSession;
      if (number != null) await widget.ground.setSessionPack(number, chosen);
      final bench = widget.bench;
      if (bench != null && mounted) await z.switchPack(session: bench, packId: chosen);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (renamed == null) {
        // The refusal is already in `ground.trouble`, in the core's own words.
        _said = null;
        return;
      }
      _name.clear();
      // Worded in `session_state.dart`, where a test can read it — see
      // `sessionBegunSaid`. The room shows the sentence; it does not write it.
      _said = sessionBegunSaid(renamed, hadDocument: widget.bench != null);
    });
    // **Rule 71: a new session opened starts the surface from zero.** Said
    // after the sentence above and not instead of it: the person is told what
    // the birth did — and what it renamed, if it renamed anything — and the
    // surface then empties under the panel they are standing in.
    widget.onFromZero?.call();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.ground;
    if (g.vault != VaultState.unlocked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Title(sentences.roomSessions, sentences.sessionsWhat),
          Trouble(sentences.theVaultIsShutNoSessions),
        ],
      );
    }

    final rows = [...g.sessions]..sort((a, b) => b.number.compareTo(a.number));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title(
          sentences.roomSessions,
          sentences.eachSessionHasItsOwnEncryption,
        ),
        _Card(
          title: sentences.newSession,
          what: sentences.newSessionWhat,
          // **A `Wrap`, because this row broke.** The two language picks put it
          // 66 pixels over the panel's width, measured — a `Row` with an
          // `Expanded` field looked safe and was not, because the fixed
          // children are what overflow. Beside the name while there is room,
          // under it when there is not, and never off the edge: the house's own
          // lesson about a row with no give, which this round paid for twice.
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 210,
                child: TextField(
                  controller: _name,
                  onSubmitted: (_) => _begin(),
                  style: Zc.small,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: sentences.whatIsThisOneAbout,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              // **The language, beside the name** — 080: a session's language is
              // chosen where the session is created, and the application's is
              // already on. Two for now, from the one list that decides what is
              // offered anywhere.
              // **Nothing is pre-marked** — rule 57a, 16 October: «لم يسألني
              // عن لغة الجلسة». This read `_packId ?? appLanguage(g)`, so the
              // application's language was ticked and taken by a person who
              // only pressed «Begin» — a question already answered is not a
              // question. The press is dead until one is chosen.
              for (final p in g.packs.where((p) => offeredLanguages.contains(p.id)))
                _Pick(
                  label: p.label,
                  on: _packId == p.id,
                  onTap: () => setState(() => _packId = p.id),
                ),
              ZButton(
                label: sentences.begin,
                onPressed: (_busy || _packId == null) ? null : _begin,
              ),
            ],
          ),
        ),
        if (_said != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(_said!, style: Zc.small.copyWith(color: Zc.clayDeep)),
          ),
        ],
        if (rows.isEmpty)
          _Fixed(
            title: sentences.noSessionsYet,
            what: sentences.noSessionsYetWhat,
          )
        else
          for (final row in rows)
            _SessionRow(
              ground: g,
              row: row,
              open: row.number == g.openSession,
              bench: widget.bench,
              onOpenKept: widget.onOpenKept,
              onFromZero: widget.onFromZero,
            ),
      ],
    );
  }
}

/// One session: number, name, when, how many exchanges — and the two acts.
class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.ground,
    required this.row,
    required this.open,
    this.bench,
    this.onOpenKept,
    this.onFromZero,
  });

  final Ground ground;
  final ConversationRow row;
  final bool open;
  final OpenKept? onOpenKept;

  /// Rule 71: deleting **this** session, when it is the open one, ends its
  /// chat — and the surface starts from zero.
  final VoidCallback? onFromZero;

  /// The document in front of the person, when there is one: the core names
  /// this session's tokens from its own key, and the reading is better with it.
  final SessionId? bench;

  /// The core's own seconds, drawn as a day. Nothing is computed about it that
  /// the core did not say — the number is read, not invented.
  String get _when {
    final at = DateTime.fromMillisecondsSinceEpoch(row.beganAt.toInt() * 1000);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)} ${two(at.hour)}:${two(at.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(15, 12, 11, 12),
      decoration: Zc.panel(fill: open ? Zc.clayWash : Zc.card, radius: 11),
      child: Row(
        children: [
          Text('${row.number}', style: Zc.small.copyWith(fontFamily: Zc.mono, color: Zc.ink4)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // **075b — the name is the door.** «Selection without showing
                // is half an answer»: this list used to select a session and
                // leave the person standing where they were. Pressing the name
                // opens what the session kept.
                InkWell(
                  key: ConversationView.door,
                  onTap: () => showConversation(context, row, bench: bench),
                  borderRadius: BorderRadius.circular(5),
                  child: Text(
                    row.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: open ? Zc.clayDeep : Zc.ink,
                      decoration: TextDecoration.underline,
                      decorationColor: Zc.line,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  open
                      ? sentences.theOneYouAreIn(_when, _exchanges(row.turns)): '$_when · ${_exchanges(row.turns)}',
                  style: Zc.tiny.copyWith(color: Zc.ink4),
                ),
                // **089 rule 9 — what this session is holding in its preview.**
                // Under the session's own name, as the owner asked, and each
                // one a press that opens it as it was left. Nothing is drawn
                // when a session holds none, which is the ordinary state: a
                // document that left by a door is not kept.
                for (final doc in ground.kept[row.number] ?? const <KeptRow>[])
                  _KeptDocument(
                    ground: ground,
                    session: row.number,
                    doc: doc,
                    onOpen: onOpenKept,
                  ),
              ],
            ),
          ),
          if (!open)
            Tooltip(
              message: sentences.workInThisSession,
              child: TextButton(
                onPressed: () => ground.enterSession(row.number),
                child: Text(sentences.enter, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
            ),
          // **Rename lives here** — the owner's second ruling, 081: a session
          // born of a press is called «Session N», and this is where a person
          // gives it their own word. Beside Delete, inside the session's own
          // rectangle, because the thing being named is this row.
          Tooltip(
            message: sentences.renameThisSession,
            child: IconButton(
              icon: const Icon(Icons.drive_file_rename_outline, size: 17),
              color: Zc.ink3,
              onPressed: () => _rename(context),
            ),
          ),
          Tooltip(
            message: sentences.deleteThisSession,
            child: IconButton(
              icon: const Icon(Icons.delete_outline, size: 17),
              color: Zc.ink3,
              onPressed: () => _confirm(context),
            ),
          ),
        ],
      ),
    );
  }

  static String _exchanges(int turns) =>
      turns == 1 ? sentences.oneExchange: sentences.exchangesCount(turns);

  /// **A new word for this session, and nothing else about it moves** — 081.
  ///
  /// «الرقم هو الهوية ولا يتحرك»: the core's `conversation_rename` changes the
  /// name and touches neither the number, nor the key, nor the file. So this
  /// asks for one word and says that much, rather than warning about a change
  /// that does not happen.
  Future<void> _rename(BuildContext context) async {
    // **No controller.** A `TextEditingController` made here has nowhere to be
    // disposed — this row is stateless — and disposing it when `showDialog`
    // returns disposes it while the route is still animating out: «A
    // TextEditingController was used after being disposed», measured, with a
    // RenderFlex overflow of 99105 pixels behind it as the layout came apart.
    // One `onChanged` and a local word need no lifecycle at all.
    var word = '';
    final said = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Zc.paper,
        title: Text(sentences.renameSessionNumber(row.number), style: Zc.h2),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey<String>('rename-this-session'),
                autofocus: true,
                onChanged: (typed) => word = typed,
                style: Zc.body.copyWith(color: Zc.ink),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Zc.card,
                  isDense: true,
                  // The room's one question, word for word, wherever it is asked.
                  hintText: sentences.whatIsThisOneAbout,
                  hintStyle: Zc.body.copyWith(color: Zc.ink4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Zc.line),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                sentences.theNumberStaysWhatItIs(row.number),
                style: Zc.small,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(sentences.keepTheName),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(word),
            child: Text(sentences.renameIt),
          ),
        ],
      ),
    );
    // Nothing typed is «keep it», not «call it nothing»: the core refuses an
    // empty name, and a refusal here would be this product asking a question
    // it already had an answer to.
    final wanted = said?.trim() ?? '';
    if (wanted.isEmpty || wanted == row.name) return;
    await ground.renameSession(row.number, wanted);
  }

  /// **The warning is a statement, not a caution** — because 064 made it true.
  ///
  /// The lead's own note on the paper: he had told the owner this wording was
  /// stronger than the mechanism required, since a token is derived and a value
  /// still in the vault could be derived again. With a key per session that is
  /// no longer so. The key is destroyed here, and nothing derives anything
  /// afterwards — not the person, not Z Privacy. So the sentence says what
  /// happens rather than warning that something might.
  Future<void> _confirm(BuildContext context) async {
    final gone = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Zc.paper,
        // **The person's own word, isolated** — G44. The sentence lives in the
        // list and the isolate is applied here, which is the pair that G44's
        // own half over `app_en.arb` now checks: a value quoting a placeholder
        // must have a caller that wraps it.
        title: Text(sentences.deleteNamed(theirOwnWord(row.name)), style: Zc.h2),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sentences.thisDestroysTheKey,
                style: Zc.body,
              ),
              const SizedBox(height: 10),
              Text(
                sentences.everyDocumentCanNeverBeUnprotected,
                style: Zc.small,
              ),
              const SizedBox(height: 10),
              Text(
                sentences.anythingYouSentStaysAsItWas,
                style: Zc.small.copyWith(color: Zc.ink4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(sentences.keepIt),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Zc.clayDeep),
            child: Text(sentences.deleteTheSession),
          ),
        ],
      ),
    );
    if (gone != true) return;
    // **Was this the session the surface's work belongs to?** Asked before the
    // delete, because afterwards the core has already let the number go — a
    // `forget` clears `open_conversation` when it was the open one, so reading
    // it after would answer «no» about the very session that was open.
    final itWasTheOpenOne = ground.openSession == row.number;
    await ground.forgetSession(row.number);
    // **Rule 71: the session deleted ends its chat**, and the surface starts
    // from zero. Only its own: deleting *another* session takes nothing off
    // the glass, which is the difference between «its session» in the owner's
    // words and «a session».
    if (itWasTheOpenOne) onFromZero?.call();
  }
}

/// **One document a session is holding in its preview** — 089 rule 9.
///
/// The handle is the core's («doc3», «chat1») and so is the count of protected
/// places: nothing here is worked out on the glass. A press opens it in the
/// preview as it was left; «Rename» changes the name and never the number.
///
/// Why it is a row under the session and not a room of its own: the owner's
/// words — «تُدرج المستندات المحفوظة تحت اسم المحادثة في قائمة المحادثات، كما
/// تُدرج المحادثات اليوم».
class _KeptDocument extends StatelessWidget {
  const _KeptDocument({
    required this.ground,
    required this.session,
    required this.doc,
    this.onOpen,
  });

  /// The key a test presses, one per document, so a press lands on the row it
  /// names rather than on whichever one happens to be first.
  static Key keyFor(int session, String handle) => Key('kept-$session-$handle');

  final Ground ground;
  final int session;
  final KeptRow doc;
  final OpenKept? onOpen;

  @override
  Widget build(BuildContext context) {
    final press = onOpen;
    final what = doc.protected == 1 ? sentences.oneProtectedPlace: sentences.protectedPlacesCount(doc.protected);
    // **Both doors of this document** — rule 69. Worded in
    // `session_state.dart`, where a test reads it without a panel; `null` is
    // «nothing was sent about this one», and then nothing is drawn. The turn
    // carries this document's own handle, so the line is about this row and
    // not about whichever of its neighbours shares a name.
    final doors = theDoorsOfAKeptDocument(
      doc,
      ground.turns[session] ?? const <TurnRow>[],
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
      Row(
        children: [
          const Icon(Icons.description_outlined, size: 14, color: Zc.ink4),
          const SizedBox(width: 7),
          Expanded(
            child: InkWell(
              key: keyFor(session, doc.handle),
              borderRadius: BorderRadius.circular(5),
              // A press that cannot open anything is not drawn as a press —
              // 083a's rule about a button that cannot work.
              onTap: press == null ? null : () => press(session, doc.number, doc.chat),
              child: Text(
                doc.name.isEmpty
                    ? '${doc.handle} · $what'
                    // The document's own name, isolated: «doc1 · ألماني 1 · 3
                    // protected places» loses its order without it.
                    : '${doc.handle} · ${theirOwnWord(doc.name)} · $what',
                overflow: TextOverflow.ellipsis,
                style: Zc.tiny.copyWith(
                  color: Zc.river,
                  decoration: press == null ? null : TextDecoration.underline,
                  decorationColor: Zc.line,
                ),
              ),
            ),
          ),
          Tooltip(
            message: sentences.renameThisDocument,
            child: IconButton(
              icon: const Icon(Icons.drive_file_rename_outline, size: 14),
              color: Zc.ink4,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              padding: EdgeInsets.zero,
              onPressed: () => _rename(context),
            ),
          ),
        ],
      ),
          if (doors != null)
            Padding(
              // Indented to the document's own text, under it, because it is
              // about that document and not about the session's list.
              padding: const EdgeInsets.only(left: 21),
              child: Text(doors, style: Zc.tiny.copyWith(color: Zc.ink4)),
            ),
        ],
      ),
    );
  }

  /// **A new name, and the number does not move.** The same shape as a
  /// session's own rename, and no controller for the same measured reason.
  Future<void> _rename(BuildContext context) async {
    var word = '';
    final said = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Zc.paper,
        title: Text(sentences.renameHandle(doc.handle), style: Zc.h2),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sentences.theNameIsWhatYouRead(doc.handle),
                style: Zc.small.copyWith(color: Zc.ink2),
              ),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                onChanged: (value) => word = value,
                onSubmitted: (value) => Navigator.of(context).pop(value),
                decoration: InputDecoration(hintText: sentences.aNameForThisDocument),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(sentences.keepTheName),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(word),
            child: Text(sentences.rename),
          ),
        ],
      ),
    );
    if (said == null || said.trim().isEmpty) return;
    await ground.renameKept(session, doc.number, doc.chat, said);
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.what, required this.child});

  final String title;
  final String what;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(17),
        decoration: Zc.panel(fill: Zc.card, radius: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Zc.ink)),
            const SizedBox(height: 5),
            Text(what, style: Zc.small),
            const SizedBox(height: 13),
            child,
          ],
        ),
      );
}

/// Something that is not a setting, and says why it is not.
class _Fixed extends StatelessWidget {
  const _Fixed({required this.title, required this.what});

  final String title;
  final String what;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(17),
        decoration: Zc.panel(fill: Zc.warmCard, edge: Zc.lineSoft, radius: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 14, color: Zc.ink4),
                const SizedBox(width: 7),
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Zc.ink2)),
              ],
            ),
            const SizedBox(height: 5),
            Text(what, style: Zc.small),
          ],
        ),
      );
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.on,
    required this.title,
    required this.what,
    required this.onChanged,
  });

  final bool on;
  final String title;
  final String what;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(17, 13, 13, 13),
        decoration: Zc.panel(fill: Zc.card, radius: 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Zc.ink)),
                  const SizedBox(height: 4),
                  Text(what, style: Zc.small),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Switch(value: on, activeThumbColor: Zc.clay, onChanged: onChanged),
          ],
        ),
      );
}

class _Number extends StatelessWidget {
  const _Number({
    required this.value,
    required this.title,
    required this.unit,
    required this.what,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final String title;
  final String unit;
  final String what;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(17),
        decoration: Zc.panel(fill: Zc.card, radius: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Zc.ink)),
                ),
                IconButton(
                  icon: const Icon(Icons.remove, size: 16),
                  color: Zc.ink3,
                  onPressed: value > min ? () => onChanged(_step(value, -1)) : null,
                ),
                Text('$value', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Zc.clayDeep)),
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  color: Zc.ink3,
                  onPressed: value < max ? () => onChanged(_step(value, 1)) : null,
                ),
                Flexible(
                  child: Text(unit, style: Zc.small.copyWith(color: Zc.ink4), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(what, style: Zc.small),
          ],
        ),
      );

  int _step(int from, int by) {
    final step = from >= 60 ? 15 : (from >= 20 ? 5 : 1);
    return (from + by * step).clamp(min, max);
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: on ? Zc.river : Zc.ink4, shape: BoxShape.circle),
      );
}

class _Pick extends StatelessWidget {
  const _Pick({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: on ? Zc.clayWash : Zc.paper,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: on ? Zc.clayEdge : Zc.line),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: on ? Zc.clayDeep : Zc.ink2,
              ),
            ),
          ),
        ),
      );
}


/// A technical fact about a card: its name and its value, small and plain.
///
/// «OpenAI-compatible» lives here — it is how Z Privacy talks to the service,
/// which is worth knowing when you are typing an endpoint, and answers
/// nothing at all when you are choosing a route.
class _Spec extends StatelessWidget {
  const _Spec(this.name, this.value);

  final String name;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(name, style: Zc.tiny.copyWith(color: Zc.ink4, letterSpacing: 0)),
        ),
        Expanded(
          child: Text(value, style: Zc.tiny.copyWith(fontFamily: Zc.mono, letterSpacing: 0)),
        ),
      ],
    );
  }
}
