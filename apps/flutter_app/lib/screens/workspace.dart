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
import 'package:zprivacy/widgets/line_gutter.dart';
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

  /// Remember the panel's width, which is a state only a press may change.
  ///
  /// Written through the core's settings beside `columnsInStep`, for the reason
  /// 046/K makes explicit: a state the app may not change by itself is a state
  /// it must be able to remember, or closing the program would change it for
  /// the person at every launch.
  void _rememberPanelWidth(bool wide) {
    final config = widget.ground.config;
    if (config == null || config.reviewPanelWide == wide) return;
    unawaited(widget.ground.saveConfig(config.with_(reviewPanelWide: wide)));
  }

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
      // **Both**, since 046/K. This screen has always read `ground` — the pack
      // label, the handle's remembered position — while listening only to
      // `bench`, so a `ground` change was redrawn whenever the bench happened
      // to notify next. The two column states are changed by a press that
      // touches `ground` and nothing else, so that «happened to» became a
      // column that did not come back. Measured by the rule test: the config
      // said open and the screen still drew the rail.
      listenable: Listenable.merge([bench, widget.ground]),
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
              onVault: widget.onVault,
              onLockVault: () => unawaited(widget.ground.lockVault()),
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
                  // **While a panel is open the document comes to the middle**
                  // (046/K, the owner: «أريد جعل النص في حالة المعاينة ينتقل
                  // إلى نصف الشاشة ليصبح مركزياً بدلاً من تركه إلى جانب
                  // الهامش»).
                  //
                  // `Expanded` took everything the panel left, so at 1920 the
                  // columns were 1460 wide and began hard against the left
                  // edge while the review sat on the right. That edge is the
                  // margin he means.
                  //
                  // Capped at half the window and centred in what is left.
                  // Nothing here touches `_Columns`, the split inside it, or
                  // `originalPanePercent` — the person's own setting keeps its
                  // meaning, applied to a narrower block.
                  final panelOpen = bench.reviewingNames
                      || bench.reviewOpen
                      || bench.tokensOpen
                      || bench.showing != null;
                  // **The panel's second width, reached by a press** (046/K,
                  // the owner: «الطوي والفتح لا يتم تلقائياً، يتم بالضغط على
                  // إشارة محددة»). Wider is a state the person chose and it is
                  // remembered in `zcfg`; nothing here widens by itself.
                  final wide = widget.ground.config?.reviewPanelWide ?? false;
                  final panelWidth = wide
                      ? (box.maxWidth * 0.5).clamp(380.0, 760.0)
                      : panel;
                  return Row(
                    children: [
                      Expanded(
                        child: _Middle(
                          centred: panelOpen,
                          width: box.maxWidth / 2,
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
                      ),
                      // The names panel takes the same place as the review
                      // panel: one panel at a time, and the one asked for.
                      // One arrow for whichever panel is open, because it is
                      // about the panel's width and not about its contents.
                      // Four copies of it would be four places to word one act.
                      if (panelOpen)
                        _PanelArrow(
                          wide: wide,
                          onTap: () => _rememberPanelWidth(!wide),
                        ),
                      if (bench.reviewingNames)
                        NameReviewPanel(bench: bench, ground: widget.ground, width: panelWidth, onVault: widget.onVault)
                      else if (bench.reviewOpen)
                        ReviewPanel(bench: bench, width: panelWidth, onVault: widget.onVault),
                      if (bench.tokensOpen)
                        TokensPanel(bench: bench, width: panelWidth),
                      if (bench.showing != null)
                        AnswerPanel(bench: bench, width: panelWidth),
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
    required this.onVault,
    required this.onLockVault,
  });

  final Workbench bench;
  final Ground ground;
  final VoidCallback onHome;

  /// Go to a page: the Original column scrolls to the first finding on it.
  final void Function(int page) onPage;

  /// The bar's own way to the vault, and its own way to shut it.
  final VoidCallback onVault;
  final VoidCallback onLockVault;

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
    // One name per language, from the core's table — so the bar, the menu and
    // the vault's lists all call a language the same thing.
    final packLabel = ran.map(ground.languageName).join(' · ');
    // «general rules» is said when **nothing** that ran has rules of its own.
    final bare = ran.every((id) => !ground.hasRules(id));

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
              // A line, and under it every other language. The owner, 6
              // October: the list shows both, and the line is what tells them
              // apart — and since 041-Q both halves can be chosen, because a
              // language with no dictionary still has the general rules, the
              // vault, and the person's own list. The list is the core's.
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                enabled: false,
                child: Text('General rules only', style: Zc.tiny),
              ),
              for (final other in ground.languages.where((l) => !l.hasRules))
                PopupMenuItem<String>(
                  value: other.id,
                  child: Row(
                    children: [
                      Icon(
                        ran.contains(other.id) ? Icons.check : Icons.check_box_outline_blank,
                        size: 15,
                        color: ran.contains(other.id) ? Zc.river : Colors.transparent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(other.label, style: Zc.small)),
                      const SizedBox(width: 10),
                      Text(other.id.toUpperCase(), style: Zc.tiny.copyWith(color: Zc.ink4)),
                    ],
                  ),
                ),
            ],
            // The bar names the language — from the core's table, so one
            // language has one name everywhere — and says when all it has is
            // the general rules. «Svenska» and «العربية · general rules» are
            // read the same way: this is what ran.
            child: _Fact(
              label: 'Pack',
              value: bare ? '$packLabel · general rules' : packLabel,
            ),
          ),
          // The permanent door. 041-N made the vault the way in, and the bar
          // was left stating a fact nobody could act on: the only ways back to
          // it from a document were the review panels' buttons, and a person
          // with nothing to review had none. One press opens it; a second,
          // while it is open, shuts it — the thing a person wants when they
          // stand up from the desk.
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
            onTap: () async {
              final open = (bench.snap?.vault ?? ground.vault) == VaultState.unlocked;
              if (!open) {
                onVault();
                return;
              }
              // Open already: the press asks which of the two things it meant.
              final what = await showMenu<String>(
                context: context,
                position: RelativeRect.fromLTRB(1e4, 54, 12, 0),
                color: Zc.paper,
                items: const [
                  PopupMenuItem(value: 'open', child: Text('Open Z Vault')),
                  PopupMenuItem(value: 'lock', child: Text('Lock now')),
                ],
              );
              if (what == 'open') onVault();
              if (what == 'lock') onLockVault();
            },
            hint: (bench.snap?.vault ?? ground.vault) == VaultState.unlocked
                ? 'Open Z Vault, or lock it now'
                : 'Open Z Vault',
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
      builder: (_) => ProfileForm(ground: widget.ground, session: widget.bench.session),
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
  const _Fact({required this.label, required this.value, this.tint, this.onTap, this.hint});

  final String label;
  final String value;
  final Color? tint;

  /// A fact that can be acted on — the vault since 041-N, which is the way in
  /// and so is never absent from the bar.
  final VoidCallback? onTap;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final fact = Padding(
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
    if (onTap == null) return fact;
    return Tooltip(
      message: hint ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: fact,
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

  /// The Safe column. Named for the same reason its neighbour is: a test that
  /// found these two by their position among every scrollable on the screen
  /// would pass or fail on the order of unrelated widgets.
  static const safePane = ValueKey<String>('workspace-safe-pane');

  /// The button that lets the columns go their own way, for the test.
  static const stepLock = ValueKey<String>('workspace-step-lock');

  /// What the file says, until a drag says otherwise. Null means «not yet read».
  double? _percent;
  bool _dragging = false;

  /// One controller each, so one column can be told where the other has gone.
  final _left = ScrollController();
  final _right = ScrollController();

  /// Null until a tap says otherwise, like `_percent`: the file's answer is
  /// the answer until this session's person gives another.
  bool? _inStep;

  /// Which column is being followed right now.
  ///
  /// Without this the two controllers chase each other: moving the right one
  /// fires its own listener, which moves the left, which moves the right. The
  /// column the hand is on leads until it stops.
  String? _leading;

  /// The width each column's text was laid out at, remembered from the build so
  /// the scroll listener can lay the same text out the same way. A different
  /// width would give different page positions, and the columns would step to
  /// the wrong place — quietly, which is worse.
  double _leftWidth = 0;
  double _rightWidth = 0;

  @override
  void initState() {
    super.initState();
    _left.addListener(() => _follow(from: 'left'));
    _right.addListener(() => _follow(from: 'right'));
  }

  @override
  void dispose() {
    _left.dispose();
    _right.dispose();
    super.dispose();
  }

  bool get _stepping =>
      _inStep ?? widget.ground.config?.columnsInStep ?? true;

  /// Move the other column to the place that matches this one.
  void _follow({required String from}) {
    if (!_stepping) return;
    if (_leading != null && _leading != from) return;
    final doc = widget.bench.document;
    final safe = widget.bench.payload;
    if (doc == null || safe == null) return;
    final me = from == 'left' ? _left : _right;
    final other = from == 'left' ? _right : _left;
    if (!me.hasClients || !other.hasClients) return;

    _leading = from;
    final myText = from == 'left' ? doc.text : safe.text;
    final theirText = from == 'left' ? safe.text : doc.text;
    final myEdges = from == 'left' ? edgesOfDocument(doc.text) : safe.pageEdges;
    final theirEdges = from == 'left' ? safe.pageEdges : edgesOfDocument(doc.text);
    final myWidth = from == 'left' ? _leftWidth : _rightWidth;
    final theirWidth = from == 'left' ? _rightWidth : _leftWidth;

    final pairs = alignedEdges(
      myEdges: myEdges,
      myYs: pageEdgeYs(text: myText, style: Zc.document, width: myWidth, edges: myEdges),
      theirEdges: theirEdges,
      theirYs: pageEdgeYs(text: theirText, style: Zc.document, width: theirWidth, edges: theirEdges),
    );
    final target = inStepOffset(
      from: me.offset,
      mine: pairs.mine,
      theirs: pairs.theirs,
      myExtent: me.position.maxScrollExtent,
      theirExtent: other.position.maxScrollExtent,
    );
    if ((other.offset - target).abs() > 0.5) other.jumpTo(target);
    // Released on the next frame rather than here: `jumpTo` fires the other
    // controller's listener before this one returns.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_leading == from) _leading = null;
    });
  }

  /// **Collapse the Safe column, or bring it back — by a press and only by a
  /// press** (046/K).
  ///
  /// The owner's rule in one line: «الطوي والفتح لا يتم تلقائياً، يتم بالضغط
  /// على إشارة محددة». So nothing in this file closes this column when a panel
  /// opens, when the window narrows, when a document arrives or when a scan
  /// ends — and `the_states_change_only_by_a_press_test.dart` is that sentence
  /// as a test.
  ///
  /// Remembered in `zcfg`, like the step lock and the handle's position, for
  /// the reason the rule makes unavoidable: a state the app may not change by
  /// itself must survive the app closing, or closing it would change it.
  void _toggleSafe() {
    final config = widget.ground.config;
    if (config == null) return;
    unawaited(widget.ground.saveConfig(
      config.with_(safeColumnOpen: !config.safeColumnOpen),
    ));
  }

  /// Let them go their own way, or bring them back — and remember which.
  void _toggleStep() {
    final now = !_stepping;
    setState(() => _inStep = now);
    final config = widget.ground.config;
    if (config == null || config.columnsInStep == now) return;
    unawaited(widget.ground.saveConfig(config.with_(columnsInStep: now)));
    if (now) _follow(from: 'left');
  }

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
        // The Safe column's own state, read from the person's settings and
        // never from what else is on screen (046/K).
        final safeOpen = ground.config?.safeColumnOpen ?? true;
        // Closed, the column becomes a rail that still carries its arrow: a
        // handle is what makes a collapse undoable, and a collapse with no
        // handle is a thing a person has lost.
        const rail = 26.0;
        final usable = box.maxWidth - (safeOpen ? handle : rail);
        final lowest = usable <= _floor * 2 ? usable / 2 : _floor;
        final left = safeOpen
            ? (usable * percent / 100).clamp(lowest, usable - lowest)
            // Closed, the Original has the whole of it. The person's own
            // `originalPanePercent` is untouched and is what the column
            // returns to.
            : usable;
        // `_Side` pads its scroll view by 18 on each side; the text is laid out
        // inside that. Kept here so the scroll listener measures the same
        // layout this build drew, never a guess at it.
        _leftWidth = left - 36;
        _rightWidth = usable - left - 36;

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
                controller: _left,
                // The control sits here because this is the column a person
                // reads and scrolls: the complaint it answers was «I work on
                // the first screen and do not find my work on the second».
                trailing: safeOpen ? _StepLock(inStep: _stepping, onTap: _toggleStep) : null,
                footer: doc == null
                    ? null
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // **What a selection of lines is worth, before any
                          // press** (046/Q). Above the acts, because it is the
                          // reason one of them is about to be worth pressing.
                          if (bench.lines != null) _LineBand(bench: bench),
                          if (widget.said != null) _Said(widget.said!),
                          ActsBar(bench: bench, ground: ground, onSay: widget.onSay),
                          // **What should the model do with this?** (046/N.)
                          //
                          // Under the document, where the person is reading
                          // it, because the question is about this document
                          // and nothing else. It is **not** in the send sheet:
                          // that sheet's own row of acts belongs to 046/O in
                          // another worktree, and two sessions editing one row
                          // is how a merge loses a line.
                          _TheQuestion(bench: bench),
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
                          onAsk: (mark) =>
                              _ask(inner, bench, doc, mark, column: _offerFor(bench, doc, mark)),
                          // And tapping one that is still waiting answers it.
                          onChoose: widget.onChoose,
                          // 046/Q — lines are taken in the gutter, words in
                          // the text, so neither gesture has to ask which one
                          // a press meant.
                          heldLines: bench.lines,
                          onLines: (from, to) => unawaited(bench.holdLines(from, to)),
                          onColumn: (offset) => unawaited(_column(bench, offset)),
                        ),
                      ),
              ),
            ),
            if (!safeOpen)
              _SafeRail(onTap: _toggleSafe)
            else
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
            if (safeOpen)
            Expanded(
              key: _ColumnsState.safePane,
              child: _Side(
                eyebrow: 'Safe — AI will receive',
                rule: 'The request itself, not a preview of it',
                tint: Zc.clay,
                trailing: _SafeTrailing(bench: bench, onClose: _toggleSafe),
                controller: _right,
                footer: safe == null
                    ? null
                    : _SafeFooter(payload: safe, bench: bench, ground: ground),
                child: safe == null
                    ? const _Empty('There is nothing to send yet.')
                    : SafeText(
                    text: safe.text,
                    edges: safe.pageEdges,
                    chips: bench.chips,
                  ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// **What the card may offer**, when the word it explains stands inside the
  /// held lines (046/Q).
  ///
  /// The lead's ruling, 7 October: a press on an already-protected cell asks
  /// its question **and** carries the instruction, because on the owner's own
  /// sheet the cell he presses may be the one his list already protected — and
  /// a press that can mean only one of the two loses his intent with no hint
  /// that the act was there.
  ///
  /// `null` when the word is outside the held lines, because the cell's order
  /// is read from **its own** line: offering the act for a word on another line
  /// would protect a column he never pointed at.
  ColumnOffer? _offerFor(Workbench bench, DocumentView doc, Mark mark) {
    final held = bench.lines;
    final hold = bench.linesHold;
    if (held == null || hold == null) return null;
    final lo = held.from < held.to ? held.from : held.to;
    final hi = held.from < held.to ? held.to : held.from;
    final line = lineOfOffset(doc.text, mark.span.start);
    if (line < lo || line > hi) return null;
    return ColumnOffer(
      lines: hold.lines,
      act: () => _column(bench, mark.span.start),
    );
  }

  /// **One press, and the same cell is protected down every held line.**
  ///
  /// No dialog: the lead's ruling of 7 October, resting on the asymmetry L
  /// established — only an act that leaves values **in the clear** asks, and
  /// asks with the number in the sentence. Protecting is never a leak, so it
  /// may happen on one press.
  ///
  /// A press in the gap between two columns comes back as a refusal with its
  /// own name, and `Workbench` turns it into the sentence that says why the app
  /// cannot choose a column. Nothing is snapped to the nearest cell.
  Future<void> _column(Workbench bench, int offset) async {
    final outcome = await bench.protectColumnAt(offset);
    if (outcome == null) {
      // The core refused, and the refusal is already worded. Say it where the
      // acts say everything else, so a press that did nothing cannot look like
      // a press that was not noticed.
      final trouble = bench.trouble;
      if (trouble != null) widget.onSay(trouble);
      return;
    }
    widget.onSay(switch (outcome) {
      ProtectOutcome_Applied(:final token, :final places) => switch (places) {
        0 => 'Every cell in that column was already protected.',
        1 => 'Protected one cell, as $token.',
        _ => 'Protected $places cells down that column, the first as $token.',
      },
      ProtectOutcome_AlreadyProtected(:final token, :final source) =>
        'Already protected as $token, by ${sourceName(source).toLowerCase()}.',
      ProtectOutcome_BelongsToEntity(:final entity, :final token) =>
        'That belongs to $entity and keeps its token $token.',
      ProtectOutcome_Snapped(:final spans) =>
        'That cell cuts into protected text, so nothing changed. It would snap to '
            '${spans.length} whole ${spans.length == 1 ? "item" : "items"}.',
    });
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
    unawaited(widget.ground.saveConfig(config.with_(originalPanePercent: rounded)));
  }
}

/// **«8 lines · 25 protected in them · 0 open»** — what a selection of lines
/// holds, said before anything is pressed (046/Q).
///
/// Not one of these three numbers is worked out here. They come back from
/// `line_selection` in Rust, because they are facts about findings, and a
/// screen that counted them would be a second source for a number the core
/// already holds — the two would disagree the first time a rescan moved one.
///
/// The way out of a selection is here rather than at the head of the gutter,
/// because this band is under the document and always on screen while the
/// gutter's head scrolls away. Nothing releases the lines on its own: an act
/// leaves them held, so the next column is one press away.
class _LineBand extends StatelessWidget {
  const _LineBand({required this.bench});

  final Workbench bench;

  static const band = ValueKey<String>('held-lines-band');

  @override
  Widget build(BuildContext context) {
    final hold = bench.linesHold;
    return Container(
      key: _LineBand.band,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      decoration: const BoxDecoration(
        color: Zc.clayWash,
        border: Border(top: BorderSide(color: Zc.clayEdge)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // Before the core has answered it says nothing rather than a
                  // zero, by the same rule `kindName` follows: a number that is
                  // not known yet is not «none».
                  hold == null
                      ? 'Reading what those lines hold…'
                      : hold.lines == 1
                            ? '1 line · ${hold.protected} protected in it · ${hold.open} open'
                            : '${hold.lines} lines · ${hold.protected} protected in them · '
                                  '${hold.open} open',
                  style: Zc.small.copyWith(color: Zc.clayDeep, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Press a value to protect the same cell in every held line.',
                  style: Zc.tiny.copyWith(letterSpacing: 0),
                ),
              ],
            ),
          ),
          ZButton(
            label: 'Let the lines go',
            icon: Icons.close,
            onPressed: bench.releaseLines,
          ),
        ],
      ),
    );
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
  Mark mark, {
  ColumnOffer? column,
}) async {
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
      column: column,
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

/// Whether the two columns move together.
///
/// 041-L. It says what is true now, not what pressing it will do — the same
/// rule as every other state in this app: «In step» with the link closed, «Apart»
/// with it open. A person who wants to read one column on its own says so once,
/// and the answer is kept beside the handle's position.
class _StepLock extends StatelessWidget {
  const _StepLock({required this.inStep, required this.onTap});

  final bool inStep;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        key: _ColumnsState.stepLock,
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                inStep ? Icons.link : Icons.link_off,
                size: 14,
                color: inStep ? Zc.clayDeep : Zc.ink4,
              ),
              const SizedBox(width: 5),
              Text(
                inStep ? 'In step' : 'Apart',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: inStep ? Zc.clayDeep : Zc.ink4,
                ),
              ),
            ],
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
                hint: null,
              ),
              if (bench.answers.isNotEmpty && bench.showing == null)
                ZButton(
                  label: 'Show the answer',
                  icon: Icons.subject,
                  onPressed: () => bench.show(bench.answers.last),
                ),
            ],
          ),
          // **A gate that does not hand you the key is a wall** (046/L).
          //
          // The owner, 7 October: «في حال كانت ريفو تحتوي على أي خيار، لا يمكن
          // الانتقال إلى الخطوات التالية.» The door stays shut while a question
          // is open — that does not change and it is the one sentence this
          // product rests on. What changes is that the rule is now **answerable
          // in one press from where he stands**: the line says how many are
          // left and what the first one is, it takes him to it, and when there
          // is exactly one it carries the two answers itself.
          //
          // «Answer the review first» said none of that: it named no number, no
          // value and no way through.
          if (open > 0) ...[
            const SizedBox(height: 9),
            _TheWayThrough(bench: bench, ground: ground, open: open),
          ],
        ],
      ),
    );
  }
}

/// **The request that travels with the document** (046/N).
///
/// The owner, 7 October: «ليس لدينا شات — شات مع نموذج… لا يوجد خيار مثلاً
/// مباشرة إلى الشات.» A document used to reach the model with no request at
/// all, so whatever came back was its own guess at what was wanted.
///
/// Three things this widget does **not** do, and each is the point:
///
///   * it does not decide what is sensitive. `setQuestion` hands the sentence
///     to the core, which reads it with the same packs, the same vault and the
///     same lists the document was read with — and with what this document has
///     already protected, so a name that is a token in the sheet is the *same*
///     token here. A field that scanned itself would be a second scanner;
///   * it does not send. The question joins what leaves, and what leaves still
///     leaves through the review and the one gate;
///   * it does not promise a conversation. One question at a time replaces the
///     last, and the line under it says so rather than letting a person
///     discover it by losing something.
class _TheQuestion extends StatefulWidget {
  const _TheQuestion({required this.bench});

  final Workbench bench;

  static const field = ValueKey<String>('workspace-question');
  static const attach = ValueKey<String>('workspace-question-attach');

  @override
  State<_TheQuestion> createState() => _TheQuestionState();
}

class _TheQuestionState extends State<_TheQuestion> {
  late final TextEditingController _text =
      TextEditingController(text: widget.bench.question);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bench = widget.bench;
    final typed = _text.text.trim();
    final attached = bench.question.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      color: Zc.warmCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What should the AI do with this?', style: Zc.tiny.copyWith(color: Zc.ink4)),
          const SizedBox(height: 5),
          Container(
            decoration: Zc.panel(fill: Zc.card, radius: 9),
            padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
            child: TextField(
              key: _TheQuestion.field,
              controller: _text,
              minLines: 2,
              maxLines: 5,
              style: Zc.body,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'Reconcile section A against section B and tell me where the difference is.',
                hintStyle: Zc.small.copyWith(color: Zc.ink4),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 9,
            runSpacing: 7,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ZButton(
                key: _TheQuestion.attach,
                // The act's own name says what it does and where it goes
                // (P2-5). Not «Send»: nothing leaves until the review and the
                // gate are satisfied, and this press does neither.
                label: typed == attached && typed.isNotEmpty
                    ? 'In what will leave'
                    : 'Add it to what will leave',
                icon: Icons.help_outline,
                onPressed: bench.busy || typed == attached
                    ? null
                    : () => unawaited(bench.setQuestion(typed)),
                hint: typed.isEmpty && attached.isEmpty
                    ? 'A document can be sent with no request, and then the model is given no instruction'
                    : null,
              ),
              if (attached.isNotEmpty)
                ZButton(
                  label: 'Take it out',
                  onPressed: bench.busy
                      ? null
                      : () {
                          _text.clear();
                          unawaited(bench.setQuestion(''));
                        },
                ),
            ],
          ),
          if (attached.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              // Measured facts, both of them the core's: how many words of the
              // question were replaced, and that the Safe column is where it
              // can be read before anything is pressed.
              bench.questionMarks.isEmpty
                  ? 'Your request is in the Safe column, with nothing in it to protect.'
                  : bench.questionMarks.length == 1
                      ? 'Your request is in the Safe column, with one value replaced.'
                      : 'Your request is in the Safe column, with ${bench.questionMarks.length} values replaced.',
              style: Zc.tiny.copyWith(letterSpacing: 0, color: Zc.clayDeep),
            ),
            const SizedBox(height: 3),
            // **Two sentences, because two different things are in play**
            // (046/N, the lead's wording and the distinction my own report
            // turned up): the **request** is replaced, and the **answers** are
            // kept. A line saying only «the second question replaces this» is
            // true of the request and misleading about what a person can still
            // see.
            Text(
              'One request at a time — a new question replaces the request, '
              'and the answers are kept.',
              style: Zc.tiny.copyWith(letterSpacing: 0, color: Zc.ink4),
            ),
            const SizedBox(height: 3),
            // **And the one a later tidy-up would delete as redundant.**
            //
            // It is not about this build's shape. It is about what a person
            // will otherwise assume from «answer 1 of 2» — that the model
            // remembered — and that assumption would be ours to have planted.
            // `history` with roles is the deferred debt; until it lands, each
            // question is asked alone, and the screen says so.
            //
            // `the_question_is_on_the_screen_test.dart` guards this sentence by
            // name, for exactly the reason a tidy-up would remove it.
            Text(
              'Each question is asked on its own: the model does not see the '
              'earlier ones.',
              style: Zc.tiny.copyWith(letterSpacing: 0, color: Zc.ink4),
            ),
          ],
        ],
      ),
    );
  }
}

/// **The one question, answerable from here** (046/L).
///
/// Three things, and the third is the owner's own case: how many are left, the
/// way to the first of them, and — when exactly one is open — the two answers
/// on this line so he never has to go looking. On his own sheet, with his list
/// imported, that is the real case: 61 findings and one open question, an
/// address.
///
/// No fourth button that sends anyway. The gate is not loosened; it is handed
/// its key.
class _TheWayThrough extends StatelessWidget {
  const _TheWayThrough({required this.bench, required this.ground, required this.open});

  final Workbench bench;
  final Ground ground;
  final int open;

  static const goKey = ValueKey<String>('workspace-go-to-question');
  static const protectKey = ValueKey<String>('workspace-one-protect');
  static const leaveKey = ValueKey<String>('workspace-one-leave');

  @override
  Widget build(BuildContext context) {
    final waiting = bench.suggested;
    final first = waiting.isEmpty ? null : waiting.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 9,
          runSpacing: 9,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ZButton(
              key: goKey,
              // The number is in the name of the act, not in a line under it
              // (P2-5). «1 question left — go to it» is a different sentence
              // from «Answer the review first», and it is the one a person can
              // act on.
              label: open == 1
                  ? '1 question left — go to it'
                  : '$open questions left — go to the first',
              icon: Icons.east,
              onPressed: first == null
                  ? null
                  : () {
                      bench.openReview(walk: true);
                      bench.focusOn(first.id);
                    },
            ),
            // **And when there is only one, it is answerable right here.**
            if (open == 1 && first != null) ...[
              ZButton(
                key: protectKey,
                label: 'Protect it',
                icon: Icons.shield_outlined,
                onPressed: bench.busy
                    ? null
                    : () => unawaited(bench.answer(first.id, FindingAnswer.protect)),
              ),
              ZButton(
                key: leaveKey,
                label: 'Leave it in the clear',
                onPressed: bench.busy
                    ? null
                    : () => unawaited(bench.answer(first.id, FindingAnswer.notSensitive)),
              ),
            ],
          ],
        ),
        if (open == 1 && first != null) ...[
          const SizedBox(height: 6),
          // What it is, so the two answers above are about something. The kind
          // is the core's own word for it.
          Text(
            'The one left is ${ground.nameOfKind(first.kind).toLowerCase()}.',
            style: Zc.tiny.copyWith(letterSpacing: 0),
          ),
        ],
      ],
    );
  }
}

/// **The Safe column, collapsed to a rail that still carries its arrow.**
///
/// 046/K. The rail exists for one reason and it is the owner's: a person who
/// closed something must be able to open it again, and the only thing that can
/// promise that is a control still on the screen.
class _SafeRail extends StatelessWidget {
  const _SafeRail({required this.onTap});

  final VoidCallback onTap;

  static const named = ValueKey<String>('workspace-safe-rail');

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      decoration: const BoxDecoration(
        color: Zc.warmCard,
        border: Border(left: BorderSide(color: Zc.line)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          IconButton(
            key: named,
            tooltip: 'Show what the AI will receive',
            icon: const Icon(Icons.chevron_left, size: 18),
            color: Zc.clay,
            visualDensity: VisualDensity.compact,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

/// The Safe column's own two controls: the chip switch it has always had, and
/// the arrow that closes the column (046/K).
class _SafeTrailing extends StatelessWidget {
  const _SafeTrailing({required this.bench, required this.onClose});

  final Workbench bench;
  final VoidCallback onClose;

  static const closeKey = ValueKey<String>('workspace-safe-close');

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ChipSwitch(bench: bench),
        IconButton(
          key: closeKey,
          tooltip: 'Hide this column',
          icon: const Icon(Icons.chevron_right, size: 18),
          color: Zc.ink3,
          visualDensity: VisualDensity.compact,
          onPressed: onClose,
        ),
      ],
    );
  }
}

/// **An arrow, and what it does said in its own tooltip.**
///
/// The owner's standing rule of 7 October: «بشرط أن الطوي والفتح لا يتم
/// تلقائياً، يتم بالضغط على إشارة محددة» — a collapse or an expand is always a
/// person's press on a visible control. So this is a control, it says which way
/// it goes, and it is **always drawn while a panel is open**: a collapsed thing
/// that leaves no handle is a thing a person has lost.
class _PanelArrow extends StatelessWidget {
  const _PanelArrow({required this.wide, required this.onTap});

  final bool wide;
  final VoidCallback onTap;

  /// Named, so a test presses the control a person presses.
  static const named = ValueKey<String>('workspace-panel-arrow');

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      child: Column(
        children: [
          const SizedBox(height: 12),
          IconButton(
            key: named,
            // P2-5: the name of the act carries what it does.
            tooltip: wide ? 'Narrow this panel' : 'Widen this panel',
            icon: Icon(wide ? Icons.chevron_right : Icons.chevron_left, size: 18),
            color: Zc.ink3,
            visualDensity: VisualDensity.compact,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

/// Half the window, in the middle of what is left — or the whole of it.
///
/// One widget rather than a conditional tree, so the case where no panel is
/// open is provably the case that existed before 046/K: `centred: false`
/// returns the child untouched.
class _Middle extends StatelessWidget {
  const _Middle({required this.centred, required this.width, required this.child});

  final bool centred;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!centred) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: child,
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
    this.controller,
    this.trailing,
    this.footer,
  });

  final String eyebrow;
  final String rule;
  final Color tint;
  final Widget child;

  /// Given from outside so the two columns can be kept in step (041-L).
  final ScrollController? controller;
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
            controller: controller,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            child: child,
          ),
        ),
        // **The footer gives, and nothing is pushed off the screen.**
        //
        // It used to sit here at its natural height after an `Expanded`, so the
        // moment it grew by a line the column overran — measured at exactly
        // **1 pixel** when 046/N added the request field under the document,
        // which is the same family as the three overflows of 2 October and the
        // 58 of 046/K: a row or a column with no give, breaking on the next
        // string somebody adds.
        //
        // `Flexible` so it takes what it needs up to what is left, and a
        // scroller inside it so a short window scrolls the acts rather than
        // hiding them. The reason a person needs is never the thing that falls
        // off the edge.
        if (footer != null)
          Flexible(
            child: SingleChildScrollView(child: footer),
          ),
      ],
    );
  }
}
