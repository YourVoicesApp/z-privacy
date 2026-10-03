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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/acts.dart';
import 'package:zprivacy/widgets/document_text.dart';
import 'package:zprivacy/screens/answer.dart';
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
  });

  final Workbench bench;
  final Ground ground;
  final VoidCallback onHome;

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
      builder: (context, _) => Scaffold(
        body: Column(
          children: [
            _TopBar(bench: bench, ground: widget.ground, onHome: widget.onHome),
            _Band(bench: bench),
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
                        ),
                      ),
                      if (bench.reviewOpen)
                        ReviewPanel(bench: bench, width: panel),
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
  });

  final Workbench bench;
  final Ground ground;
  final VoidCallback onHome;

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
              .firstWhere((p) => p.id == id, orElse: () => PackRow(id: id, label: id))
              .label,
        )
        .join(' · ');
    final pack = PackRow(id: ran.join('+'), label: packLabel);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
      decoration: const BoxDecoration(
        color: Zc.card,
        border: Border(bottom: BorderSide(color: Zc.line)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onHome,
            borderRadius: BorderRadius.circular(9),
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: Row(
                children: [
                  ZMark(size: 28),
                  SizedBox(width: 10),
                  Text(
                    'Z Privacy',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Zc.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 22),
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
          _Fact(label: 'Pack', value: pack.label),
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
          // Numbers about this document, for a person who cannot send us the
          // document itself. The core writes every line of it.
          if (doc != null) ...[
            const SizedBox(width: 14),
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
  const _Band({required this.bench});

  final Workbench bench;

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
              switch (bench.scanOrigin) {
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
            ),
        ],
      ),
    );
  }
}

/// The two columns.
class _Columns extends StatelessWidget {
  const _Columns({
    required this.bench,
    required this.ground,
    required this.said,
    required this.onSay,
    required this.focusKey,
  });

  final Workbench bench;
  final Ground ground;
  final String? said;
  final void Function(String) onSay;
  final GlobalKey focusKey;

  @override
  Widget build(BuildContext context) {
    final doc = bench.document;
    final safe = bench.payload;

    return Row(
      children: [
        Expanded(
          child: _Side(
            eyebrow: 'Original — local only',
            rule: 'Never sent to AI · Send cannot read this side',
            tint: Zc.ink4,
            footer: doc == null
                ? null
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (said != null) _Said(said!),
                      ActsBar(bench: bench, ground: ground, onSay: onSay),
                    ],
                  ),
            child: doc == null
                ? const _Empty('Nothing is open.')
                : Builder(
                    builder: (inner) => OriginalText(
                      text: doc.text,
                      marks: doc.marks,
                      focus: bench.focusedFinding?.span,
                      focusKey: focusKey,
                      onSelection: (start, end) => bench.select(
                        end > start ? Span(start: start, end: end) : null,
                      ),
                      // Tapping a protected word asks the question this whole
                      // layer exists to answer.
                      onAsk: (mark) => _ask(inner, bench, doc, mark),
                    ),
                  ),
          ),
        ),
        Container(width: 1, color: Zc.line),
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
