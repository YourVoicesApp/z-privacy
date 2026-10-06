// The Workspace — the centre of everything.
//
// The frame: the top bar that says what ground this conversation stands on, and
// the band under it that reports the scan. Both are real: the counts are the
// core's `ScanReport`, and the vault line is the core's own `VaultState`, carried
// inside that report so the two can never disagree.
//
// And the two columns, which are the product's essence and not decoration:
//
//   left   the document as written, with what the scanner did drawn over it.
//          Nothing here is replaced, and nothing here can reach the network.
//   right  the request itself. Not a preview of it, not a rebuilt copy of it —
//          the string the core will hand to a provider, shown as it stands.
//
// They are side by side and typographically identical on purpose. The whole
// claim of this product is that a person can compare them.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/acts.dart';
import 'package:zprivacy/widgets/document_text.dart';
import 'package:zprivacy/screens/answer.dart';
import 'package:zprivacy/widgets/name_review.dart';
import 'package:zprivacy/widgets/review.dart';
import 'package:zprivacy/widgets/send_sheet.dart';
import 'package:zprivacy/widgets/tokens.dart';
import 'package:zprivacy/widgets/vault_forms.dart';
import 'package:zprivacy/widgets/why_sheet.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    required this.bench,
    required this.ground,
    required this.onHome,
    required this.onVault,
  });

  final Workbench bench;
  final Ground ground;
  final VoidCallback onHome;

  /// Open the vault screen over this one. Required rather than optional: a
  /// Workspace that cannot reach the vault has buttons that refuse into a
  /// sentence nobody sees, which is exactly what 041-B is about.
  final VoidCallback onVault;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  /// What the last act did, in the core's terms. Kept on screen rather than
  /// flashed in a toast: a user should be able to look back at what happened.
  String? _said;

  /// The anchor the Original column drops in at the focused finding.
  final _focusKey = GlobalKey();
  int? _wasFocused;

  /// The word a person just pressed, and where on the screen they pressed it.
  ///
  /// The owner, 6 October: «the suggested names must appear on the text itself,
  /// not as a separate list, and the choices a small message that disappears
  /// when it is pressed». So the choice is a bubble at the word, and the review
  /// panel is what somebody opens from the Review button when they want the
  /// list of what is left — never what a press on a word opens.
  Finding? _choosing;
  Offset _choosingAt = Offset.zero;

  void _closeBubble() {
    if (_choosing != null) setState(() => _choosing = null);
  }

  /// Go to a page by pointing the column's own anchor at it.
  ///
  /// The anchor already exists — it is how «page 17» in the review list became
  /// a place a person arrives at — so going to a page is choosing which finding
  /// it points at: the first one on that page.
  void _goToPage(int page) {
    final onIt = widget.bench.findings.where((f) => f.place?.page == page);
    if (onIt.isEmpty) {
      // Nothing was found on it, so there is nothing to point at — and saying
      // so is better than a jump that does not happen.
      setState(() => _said = 'Page $page has nothing the scanner marked.');
      return;
    }
    widget.bench.focusOn(onIt.first.id);
  }

  /// «Page 17» has to be a place you arrive at, not a label. When the review
  /// list points somewhere new, the column scrolls there after the frame that
  /// drew the anchor.
  void _jumpIfMoved() {
    final now = widget.bench.focused;
    if (now == _wasFocused) return;
    _wasFocused = now;
    if (now == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _focusKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.3,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bench = widget.bench;
    _jumpIfMoved();
    return ListenableBuilder(
      listenable: bench,
      // Alt+Left is the back door of every document reader there is, and the
      // owner reached for it before he found the arrow. `CallbackShortcuts`
      // needs somewhere for the keys to land, so the focus node under it is
      // autofocused: nothing else on this screen takes focus on arrival.
      builder: (context, _) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): widget.onHome,
          // A bubble closes the way every small thing closes.
          const SingleActivator(LogicalKeyboardKey.escape): _closeBubble,
        },
        child: Focus(
        autofocus: true,
        child: Scaffold(
        body: Stack(
          children: [
        Column(
          children: [
            _TopBar(
              bench: bench,
              ground: widget.ground,
              onHome: widget.onHome,
              onPage: _goToPage,
            ),
            _Band(bench: bench, onVault: widget.onVault),
            if (bench.trouble != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                child: Trouble(bench.trouble!),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  // A side panel takes a third of the window, never more than
                  // 460 and never less than 280: the two columns are the product
                  // and must stay readable behind whatever is open over them.
                  final panel = (box.maxWidth * 0.33).clamp(280.0, 460.0);
                  return Row(
                    children: [
                      Expanded(
                        child: _Columns(
                          bench: bench,
                          ground: widget.ground,
                          said: _said,
                          focusKey: _focusKey,
                          onSay: (line) => setState(() => _said = line),
                          onChoose: (mark, at) {
                            // The finding behind the mark, by the place it
                            // stands: a mark carries no id, and the span is
                            // what the two share.
                            final found = bench.findings.where(
                              (f) => f.span.start == mark.span.start && f.span.end == mark.span.end,
                            );
                            if (found.isEmpty) return;
                            setState(() {
                              _choosing = found.first;
                              _choosingAt = at;
                            });
                          },
                        ),
                      ),
                      // The names panel takes the same place as the review
                      // panel: one panel at a time, and the one asked for.
                      if (bench.reviewingNames)
                        NameReviewPanel(bench: bench, ground: widget.ground, width: panel, onVault: widget.onVault)
                      else if (bench.reviewOpen)
                        ReviewPanel(bench: bench, width: panel, onVault: widget.onVault),
                      if (bench.tokensOpen)
                        TokensPanel(bench: bench, width: panel),
                      if (bench.showing != null)
                        AnswerPanel(bench: bench, width: panel),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        // The choice at the word. Over everything, because it belongs to the
        // word and not to a column; and nothing else on this screen moves while
        // it is open.
        if (_choosing != null) ...[
          Positioned.fill(
            // A press anywhere else closes it and does nothing — the owner's
            // «disappears when it is pressed» cuts both ways.
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeBubble,
            ),
          ),
          ChoiceBubble(
            bench: bench,
            finding: _choosing!,
            at: _choosingAt,
            onVault: widget.onVault,
            onDone: _closeBubble,
          ),
        ],
          ],
        ),
      ),
      ),
      ),
    );
  }
}

/// The seven things that change the ground the Workspace stands on. In M7.1 they
/// *report* — each becomes an act in its own milestone, and the behaviour board
/// already says what each must ask before it changes an open document.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.bench,
    required this.ground,
    required this.onHome,
    required this.onPage,
  });

  final Workbench bench;
  final Ground ground;
  final VoidCallback onHome;

  /// Go to a page: the Original column scrolls to the first finding on it.
  final void Function(int page) onPage;

  @override
  Widget build(BuildContext context) {
    final doc = bench.document;
    final profile = bench.profileId == null
        ? 'Everywhere'
        : ground.profiles
              .firstWhere(
                (p) => p.id == bench.profileId,
                orElse: () =>
                    ProfileRow(id: bench.profileId!, name: bench.profileId!, languages: const []),
              )
              .name;
    // What actually ran, not what the session was opened with. A profile may
    // run two rule sets at once, and naming only one of them here would say
    // «German» over a document whose English label had just been detected.
    final active = ground.profiles
        .where((p) => p.id == bench.profileId)
        .expand((p) => p.languages)
        .toList();
    final ran = active.isEmpty ? [bench.packId] : active;
    final packLabel = ran
        .map(
          (id) => ground.packs
              .firstWhere((p) => p.id == id, orElse: () => _unknownPack(id))
              .label,
        )
        .join(' · ');
    final pack = _unknownPack(ran.join('+'), label: packLabel);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
      decoration: const BoxDecoration(
        color: Zc.card,
        border: Border(bottom: BorderSide(color: Zc.line)),
      ),
      child: Row(
        children: [
          // The way back, with an arrow on it. The mark beside it went home
          // too, and still does — but nothing on a logo says «back», and the
          // owner spent his first evening without a way out of a document.
          Tooltip(
            message: 'Back to your documents · Alt+Left',
            child: TextButton.icon(
              onPressed: onHome,
              icon: const Icon(Icons.arrow_back, size: 17),
              label: const Text('Documents', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(
                foregroundColor: Zc.ink,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // The mark goes home too, and still does. The **word** beside it
          // steps aside while a document is open: the bar overflowed by 50 px
          // at 964 wide once the back control and the AI door were on it
          // (measured), and of everything standing there the product's own
          // name is the one thing a person is not reading — the document's
          // name is the identity of this moment, and the mark still says whose
          // app this is.
          Tooltip(
            message: 'Z Privacy · home',
            child: InkWell(
              onTap: onHome,
              borderRadius: BorderRadius.circular(9),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    const ZMark(size: 28),
                    if (doc == null) ...[
                      const SizedBox(width: 10),
                      const Text(
                        'Z Privacy',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Zc.ink,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          if (doc != null) ...[
            Icon(
              doc.kind == DocumentKind.pdf
                  ? Icons.picture_as_pdf_outlined
                  : doc.kind == DocumentKind.docx
                  ? Icons.article_outlined
                  : Icons.notes_outlined,
              size: 16,
              color: Zc.ink3,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                doc.name.isEmpty ? 'Typed text' : doc.name,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Zc.ink,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Text(
              doc.pages == 1 ? '1 page' : '${doc.pages} pages',
              style: Zc.small.copyWith(color: Zc.ink4),
            ),
          ],
          const Spacer(),
          _ProfileFact(bench: bench, ground: ground, value: profile),
          // The rule set, and a way to change it. Every pack this build carries
          // comes from the core's own list — nothing here is written in Dart —
          // and the one that ran is marked. Switching is a rescan, which is why
          // it says so before it happens rather than afterwards.
          PopupMenuButton<String>(
            tooltip: 'Read this document with another rule set',
            enabled: !bench.busy && ground.packs.isNotEmpty,
            onSelected: (id) => bench.switchPack(id),
            itemBuilder: (_) => [
              for (final p in ground.packs)
                PopupMenuItem<String>(
                  value: p.id,
                  child: Row(
                    children: [
                      Icon(
                        ran.contains(p.id) ? Icons.check : Icons.check_box_outline_blank,
                        size: 15,
                        color: ran.contains(p.id) ? Zc.river : Colors.transparent,
                      ),
                      const SizedBox(width: 8),
                      Text(p.label, style: Zc.small),
                    ],
                  ),
                ),
              // A line, and under it what is coming. The owner, 6 October: the
              // list shows both, and the line is what tells them apart. They
              // are disabled, so pressing one does nothing at all — and the
              // list of them is the core's, never this file's.
              if (ground.plannedPacks.isNotEmpty) const PopupMenuDivider(),
              for (final planned in ground.plannedPacks)
                PopupMenuItem<String>(
                  enabled: false,
                  child: Row(
                    children: [
                      const SizedBox(width: 23),
                      Text(planned.label, style: Zc.small.copyWith(color: Zc.ink4)),
                      const SizedBox(width: 10),
                      Text('coming', style: Zc.tiny.copyWith(color: Zc.ink4)),
                    ],
                  ),
                ),
            ],
            child: _Fact(label: 'Pack', value: pack.label),
          ),
          _Fact(
            label: 'Vault',
            value: switch (bench.snap?.vault ?? ground.vault) {
              VaultState.unlocked => 'Unlocked',
              VaultState.locked => 'Locked',
              VaultState.absent => 'None',
            },
            tint: (bench.snap?.vault ?? ground.vault) == VaultState.unlocked
                ? Zc.river
                : Zc.ink4,
          ),
          // **Which page.** The owner, 7 October: a page must show its
          // beginning and its end — and once it does, a person wants to go to
          // one. The column scrolls to the first finding on that page, or to
          // the page's own edge when nothing on it was found.
          if (doc != null && doc.pages > 1) ...[
            const SizedBox(width: 10),
            PopupMenuButton<int>(
              tooltip: 'Go to a page',
              onSelected: onPage,
              itemBuilder: (_) => [
                for (var page = 1; page <= doc.pages; page++)
                  PopupMenuItem<int>(value: page, child: Text('Page $page', style: Zc.small)),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Page', style: Zc.small.copyWith(color: Zc.ink3, fontWeight: FontWeight.w600)),
                  const Icon(Icons.arrow_drop_down, size: 18, color: Zc.ink3),
                ],
              ),
            ),
          ],
          // The AI door, open at any time. The choice of provider, model and
          // mode is not a reward for finishing the review: it is the first
          // thing a person wants to see, and the review gates the **send**.
          if (doc != null) ...[
            const SizedBox(width: 14),
            Tooltip(
              message: 'Choose the AI and what travels to it',
              child: TextButton.icon(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => SendSheet(bench: bench, ground: ground),
                ),
                icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                label: const Text('AI', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  foregroundColor: Zc.clay,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
          // Numbers about this document, for a person who cannot send us the
          // document itself. The core writes every line of it.
          if (doc != null) ...[
            const SizedBox(width: 6),
            CopyReportButton(
              compact: true,
              onCopy: () async {
                await Clipboard.setData(ClipboardData(text: await bench.reportText()));
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// A row for a language the core did not send one for: a profile may name a
/// pack this build no longer carries, and the bar still has to say its name.
/// Everything the core would have filled stays empty, because Dart knows none
/// of it and may not invent it.
PackRow _unknownPack(String id, {String? label}) => PackRow(
      id: id,
      label: label ?? id,
      locale: '',
      version: '',
      ownRules: const [],
      provenance: '',
      given: 0,
      family: 0,
    );

class _ProfileFact extends StatelessWidget {
  const _ProfileFact({
    required this.bench,
    required this.ground,
    required this.value,
  });

  final Workbench bench;
  final Ground ground;
  final String value;

  @override
  Widget build(BuildContext context) {
    final enabled = ground.vault == VaultState.unlocked;
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: InkWell(
        onTap: enabled
            ? () => showDialog<void>(
                context: context,
                builder: (_) => ProfileSwitcher(bench: bench, ground: ground),
              )
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Eyebrow('Profile'),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Zc.ink2,
                    ),
                  ),
                  if (enabled) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.expand_more, size: 14, color: Zc.ink4),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileSwitcher extends StatefulWidget {
  const ProfileSwitcher({super.key, required this.bench, required this.ground});

  final Workbench bench;
  final Ground ground;

  @override
  State<ProfileSwitcher> createState() => _ProfileSwitcherState();
}

class _ProfileSwitcherState extends State<ProfileSwitcher> {
  String? _trouble;
  late List<ProfileRow> _profiles;

  @override
  void initState() {
    super.initState();
    _profiles = [...widget.ground.profiles];
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.bench.profileId;
    return Dialog(
      backgroundColor: Zc.paper,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Profiles', style: Zc.h2),
              const SizedBox(height: 6),
              Text(
                'Choose which client dictionary this conversation uses. The profile ID stays '
                'inside the vault; the display name is what people see.',
                style: Zc.small,
              ),
              const SizedBox(height: 16),
              _row(
                title: 'Everywhere',
                subtitle:
                    'Only identities and rules that apply to every profile.',
                active: current == null,
                onSwitch: current == null ? null : () => _switch(null),
              ),
              for (final p in _profiles)
                _row(
                  title: p.name,
                  subtitle: p.id,
                  active: current == p.id,
                  onSwitch: current == p.id ? null : () => _switch(p.id),
                  onRename: () => _rename(p),
                ),
              const SizedBox(height: 12),
              ZButton(
                label: 'Create profile',
                icon: Icons.add,
                onPressed: _create,
              ),
              if (_trouble != null) ...[
                const SizedBox(height: 12),
                Trouble(_trouble!),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  const Spacer(),
                  ZButton(
                    label: 'Done',
                    filled: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row({
    required String title,
    required String subtitle,
    required bool active,
    required VoidCallback? onSwitch,
    VoidCallback? onRename,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: Zc.panel(
        fill: active ? Zc.clayWash : Zc.card,
        edge: active ? Zc.clayEdge : Zc.lineSoft,
        radius: 9,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Zc.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Zc.tiny.copyWith(letterSpacing: 0, color: Zc.ink4),
                ),
              ],
            ),
          ),
          if (onRename != null) ...[
            ZButton(label: 'Rename', onPressed: onRename),
            const SizedBox(width: 8),
          ],
          ZButton(
            label: active ? 'Active' : 'Switch',
            filled: !active,
            onPressed: onSwitch,
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    final made = await showDialog<ProfileRow>(
      context: context,
      builder: (_) => ProfileForm(ground: widget.ground),
    );
    if (!mounted || made == null) return;
    setState(() {
      _profiles = [..._profiles.where((p) => p.id != made.id), made];
      _trouble = null;
    });
    await widget.ground.refresh();
    final bad = await widget.bench.switchProfile(made.id);
    if (!mounted) return;
    setState(() => _trouble = bad);
  }

  Future<void> _rename(ProfileRow profile) async {
    final renamed = await showDialog<ProfileRow>(
      context: context,
      builder: (_) => ProfileForm(profile: profile, ground: widget.ground),
    );
    if (!mounted || renamed == null) return;
    setState(() {
      _profiles = [for (final p in _profiles) p.id == renamed.id ? renamed : p];
      _trouble = null;
    });
    await widget.ground.refresh();
    await widget.bench.refresh();
    if (mounted) setState(() => _trouble = null);
  }

  Future<void> _switch(String? profileId) async {
    final bad = await widget.bench.switchProfile(profileId);
    if (!mounted) return;
    setState(() => _trouble = bad);
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.tint});

  final String label;
  final String value;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Eyebrow(label),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: tint ?? Zc.ink2,
            ),
          ),
        ],
      ),
    );
  }
}

/// «Scanned on import — 7 protected automatically · 2 need your word · 428 normal».
/// Every one of those numbers is `ScanReport`, straight from the core.
class _Band extends StatelessWidget {
  const _Band({required this.bench, required this.onVault});

  final Workbench bench;

  /// The way to the vault from the band's own line. The line said «No vault»
  /// and could not be pressed: the owner read it, agreed with it, and had
  /// nowhere to go.
  final VoidCallback onVault;

  @override
  Widget build(BuildContext context) {
    final r = bench.report;
    final locked = (r?.vault ?? VaultState.absent) != VaultState.unlocked;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 11, 18, 11),
      decoration: const BoxDecoration(
        color: Zc.clayWash,
        border: Border(bottom: BorderSide(color: Zc.clayEdge)),
      ),
      child: Row(
        children: [
          if (bench.busy) ...[
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Zc.clayDeep,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Scanning…',
              style: TextStyle(fontSize: 13, color: Zc.clayDeep),
            ),
          ] else if (r == null) ...[
            const Text(
              'Not scanned yet',
              style: TextStyle(fontSize: 13, color: Zc.clayDeep),
            ),
          ] else ...[
            const Icon(Icons.check, size: 15, color: Zc.clayDeep),
            const SizedBox(width: 8),
            Text(
              // A scan nobody asked for says why it happened, rather than
              // calling itself manual.
              bench.scanNote != null
                  ? 'Last scan: ${bench.scanNote}'
                  : switch (bench.scanOrigin) {
                      ScanOrigin.onImport => 'Scanned on import',
                      ScanOrigin.rescan => 'Last scan: manual rescan',
                      ScanOrigin.notScanned => 'Not scanned yet',
                    },
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Zc.clayDeep,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                '${bench.snap?.autoProtected ?? 0} protected automatically · ${bench.openSuggestions} need your word · ${bench.normalCount} normal',
                style: const TextStyle(fontSize: 13, color: Zc.clayDeep),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const Spacer(),
          // Said out loud, because a locked vault means the app cannot recognise
          // your own people. The core puts the state in the report for this line.
          //
          // Flexible, not a bare Text: this band is the one place where two long
          // sentences meet, and a narrow window must shorten a warning rather
          // than overflow it off the screen where nobody reads it.
          if (locked && r != null)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(left: 14),
                child: InkWell(
                  onTap: onVault,
                  borderRadius: BorderRadius.circular(7),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            r.vault == VaultState.locked
                                ? 'Vault locked — rules and pack ran, the vault layer did not'
                                : 'No vault — nothing is recognised by name',
                            style: Zc.small.copyWith(
                              color: Zc.amber,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // The act, in the band, where the fact is. «Create» and
                        // «Unlock» are different moves and the line knows which
                        // one this is — the same distinction the core's two
                        // refusals make.
                        Text(
                          r.vault == VaultState.locked ? 'Unlock' : 'Create a vault',
                          style: Zc.small.copyWith(
                            color: Zc.clayDeep,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The two columns.
class _Columns extends StatefulWidget {
  const _Columns({
    required this.bench,
    required this.ground,
    required this.said,
    required this.onSay,
    required this.focusKey,
    required this.onChoose,
  });

  final Workbench bench;
  final Ground ground;
  final String? said;
  final void Function(String) onSay;
  final GlobalKey focusKey;
  final void Function(Mark mark, Offset at) onChoose;

  @override
  State<_Columns> createState() => _ColumnsState();
}

/// **The handle between the two columns.**
///
/// The owner, 6 October: «the ability to change the size of the two screens,
/// the text screen and the result screen». Dragged with the mouse, and neither
/// side may fall below [_floor] — the whole claim of this product is that a
/// person can compare the two sides, and a column that has been dragged shut
/// cannot be compared with anything.
///
/// Where it was left is a per-device preference and lives in `settings.zcfg`
/// beside the first-run flag: the Workspace is drawn long before any vault
/// exists, so the vault is the one place it could not live.
class _ColumnsState extends State<_Columns> {
  static const double _floor = 280;

  /// The Original column, for the test that drags the handle.
  static const originalPane = ValueKey<String>('workspace-original-pane');

  /// What the file says, until a drag says otherwise. Null means «not yet read».
  double? _percent;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final bench = widget.bench;
    final ground = widget.ground;
    final doc = bench.document;
    final safe = bench.payload;
    final kept = (ground.config?.originalPanePercent ?? 50).toDouble();
    final percent = _percent ?? kept;

    return LayoutBuilder(
      builder: (context, box) {
        // The handle is three pixels of grab and one of line. Below the floor
        // on either side it simply does not go: a column dragged shut is a
        // comparison nobody can make.
        const handle = 7.0;
        final usable = box.maxWidth - handle;
        final lowest = usable <= _floor * 2 ? usable / 2 : _floor;
        final left = (usable * percent / 100).clamp(lowest, usable - lowest);

        return Row(
          children: [
            SizedBox(
              // Named, so a test can measure the column itself rather than
              // something inside it.
              key: _ColumnsState.originalPane,
              width: left,
              child: _Side(
                eyebrow: 'Original — local only',
                rule: 'Never sent to AI · Send cannot read this side',
                tint: Zc.ink4,
                footer: doc == null
                    ? null
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.said != null) _Said(widget.said!),
                          ActsBar(bench: bench, ground: ground, onSay: widget.onSay),
                        ],
                      ),
                child: doc == null
                    ? const _Empty('Nothing is open.')
                    : Builder(
                        builder: (inner) => OriginalText(
                          text: doc.text,
                          marks: doc.marks,
                          focus: bench.focusedFinding?.span,
                          focusKey: widget.focusKey,
                          onSelection: (start, end) => bench.select(
                            end > start ? Span(start: start, end: end) : null,
                          ),
                          // Tapping a protected word asks the question this
                          // whole layer exists to answer.
                          onAsk: (mark) => _ask(inner, bench, doc, mark),
                          // And tapping one that is still waiting answers it.
                          onChoose: widget.onChoose,
                        ),
                      ),
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) => setState(() => _dragging = true),
                onHorizontalDragUpdate: (drag) {
                  final wanted = (left + drag.delta.dx).clamp(lowest, usable - lowest);
                  setState(() => _percent = wanted / usable * 100);
                },
                onHorizontalDragEnd: (_) {
                  setState(() => _dragging = false);
                  // `_percent` and not the `percent` this build closed over:
                  // that one is where the handle **was** when the drag began,
                  // and writing it back remembers the wrong place. Measured by
                  // the test that drags twice.
                  _remember(_percent ?? percent);
                },
                child: SizedBox(
                  width: handle,
                  child: Center(
                    child: Container(
                      width: 1,
                      color: _dragging ? Zc.clay : Zc.line,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _Side(
                eyebrow: 'Safe — AI will receive',
                rule: 'The request itself, not a preview of it',
                tint: Zc.clay,
                trailing: _ChipSwitch(bench: bench),
                footer: safe == null
                    ? null
                    : _SafeFooter(payload: safe, bench: bench, ground: ground),
                child: safe == null
                    ? const _Empty('There is nothing to send yet.')
                    : SafeText(text: safe.text, chips: bench.chips),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Where the handle was left, kept for the next time this document is open.
  ///
  /// Written through the core's settings, which is the only durable per-device
  /// store this app has and already holds the first-run flag. Nothing of the
  /// person's work goes with it: it is a number between 20 and 80, and the core
  /// clamps it again on the way in.
  void _remember(double percent) {
    final config = widget.ground.config;
    if (config == null) return;
    final rounded = percent.round().clamp(20, 80);
    if (rounded == config.originalPanePercent) return;
    unawaited(widget.ground.saveConfig(Settings(
      scanOnImport: config.scanOnImport,
      revealSeconds: config.revealSeconds,
      autoLockMinutes: config.autoLockMinutes,
      packId: config.packId,
      language: config.language,
      firstRunDone: config.firstRunDone,
      originalPanePercent: rounded,
      sessionOnly: config.sessionOnly,
    )));
  }
}

/// What the last act did. In the core's words, with its numbers.
class _Said extends StatelessWidget {
  const _Said(this.line);

  final String line;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      decoration: const BoxDecoration(
        color: Zc.card,
        border: Border(top: BorderSide(color: Zc.lineSoft)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 15, color: Zc.clay),
          const SizedBox(width: 9),
          Expanded(
            child: Text(line, style: Zc.small.copyWith(color: Zc.ink2)),
          ),
        ],
      ),
    );
  }
}

/// «Why is this protected?» — asked of the core, drawn by the sheet, and if
/// something is forgotten the document is scanned again so the screen matches
/// what the app now knows.
Future<void> _ask(
  BuildContext context,
  Workbench bench,
  DocumentView doc,
  Mark mark,
) async {
  final why = await bench.why(mark.span);
  if (why == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => WhySheet(
      why: why,
      word: doc.text.substring(mark.span.start, mark.span.end),
      span: mark.span,
      onChanged: bench.rescan,
      onUnprotect: (span) async => bench.unprotect(span),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.what);

  final String what;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Text(
        what,
        style: Zc.small.copyWith(color: Zc.ink4),
        textAlign: TextAlign.center,
      ),
    ),
  );
}

/// «Chips / Plain». Both draw the same string; one of them draws it the way the
/// model will read it, character for character.
class _ChipSwitch extends StatelessWidget {
  const _ChipSwitch({required this.bench});

  final Workbench bench;

  @override
  Widget build(BuildContext context) {
    Widget one(String label, bool chips) {
      final on = bench.chips == chips;
      return InkWell(
        onTap: () => bench.showChips(chips),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: on ? Zc.clayWash : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: on ? Zc.clayEdge : Colors.transparent),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: on ? Zc.clayDeep : Zc.ink4,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        one('Chips', true),
        const SizedBox(width: 4),
        one('Plain', false),
      ],
    );
  }
}

/// The sentence under the Safe column. It is the one place the app admits that
/// an unanswered suggestion is **still the real text** — which is what G12 is
/// about, said in words where the consequence is visible.
class _SafeFooter extends StatelessWidget {
  const _SafeFooter({
    required this.payload,
    required this.bench,
    required this.ground,
  });

  final PayloadView payload;
  final Workbench bench;
  final Ground ground;

  @override
  Widget build(BuildContext context) {
    final open = payload.openSuggestions;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 11, 18, 13),
      decoration: BoxDecoration(
        color: open > 0 ? Zc.amberWash : Zc.warmCard,
        border: const Border(top: BorderSide(color: Zc.lineSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            open == 0
                ? 'This is exactly what the AI will receive. ${payload.protectedCount} values were replaced.'
                : open == 1
                ? 'One suggestion is still open. Until you answer it, it stands here as written — '
                      'real text on this side.'
                : '$open suggestions are still open. Until you answer them, they stand here as '
                      'written — the only real text on this side.',
            style: Zc.small.copyWith(
              color: open > 0 ? Zc.amber : Zc.ink3,
              fontWeight: open > 0 ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 10),
          // Wrap: the hint beside a disabled button is a whole sentence, and a
          // narrow column must put it on the next line rather than off the edge.
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              ZButton(
                // «Review», not «Send»: this press opens the review sheet and
                // nothing leaves. The owner's rule of 29 September — **a
                // button's name describes the act its own press causes, not
                // one that may happen two steps later.**
                //
                // Not «Review & Send» either: after reviewing, a person may
                // take the manual path with Copy Protected and never send at
                // all, so «Send» would still be a promise we do not keep.
                //
                // And not the bare «Review», because the left column already
                // has one — that opens the list of suggestions. Two buttons
                // with one word meaning two things is a smaller version of the
                // same fault. This names what the press shows: the exact text
                // that would leave, which is the sheet's own first heading.
                label: 'Review what will leave',
                filled: true,
                icon: Icons.fact_check_outlined,
                // Disabled while anything is open — and the reason is beside it,
                // because «send anyway» does not exist and never will.
                onPressed: open > 0
                    ? null
                    : () => showDialog<bool>(
                        context: context,
                        builder: (_) => SendSheet(bench: bench, ground: ground),
                      ),
                hint: open > 0 ? 'Answer the review first' : null,
              ),
              if (bench.answers.isNotEmpty && bench.showing == null)
                ZButton(
                  label: 'Show the answer',
                  icon: Icons.subject,
                  onPressed: () => bench.show(bench.answers.last),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.eyebrow,
    required this.rule,
    required this.tint,
    required this.child,
    this.trailing,
    this.footer,
  });

  final String eyebrow;
  final String rule;
  final Color tint;
  final Widget child;
  final Widget? trailing;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(eyebrow, color: tint),
                    const SizedBox(height: 4),
                    Text(rule, style: Zc.tiny.copyWith(letterSpacing: 0)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        Container(height: 1, color: Zc.lineSoft),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            child: child,
          ),
        ),
        ?footer,
      ],
    );
  }
}
