// «I have 17 names for you to look at.»
//
// The owner's measure of this phase is not how many names Z knows; it is how
// few small decisions a person makes before a document is understood. So this
// panel never shows an occurrence. It shows a **name**, once, with what the
// decision is worth — how many places it stands in, and how many pages — and
// three lines of context, because one look should be enough.
//
// Three acts, and what each one means is written where it is pressed:
//
//   Add as family name   teach Z the word, and every place it stands is seen
//   Add person           protect this person, here and now
//   Ignore               not a name; do not ask again in this session
//
// No dictionary editor. Z brings what needs a decision, and nothing else.

import 'dart:async';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/language_list.dart';

class NameReviewPanel extends StatelessWidget {
  const NameReviewPanel({
    super.key,
    required this.bench,
    required this.ground,
    required this.width,
    required this.onVault,
  });

  final Workbench bench;

  /// For the language list under «Your names»: what this build carries and
  /// what is coming, both from the core.
  final Ground ground;
  final double width;

  /// Adding a name writes to the vault, so without one the acts say what they
  /// need and this opens it — the same door, and the same sentence, as the
  /// «Always» button in the review.
  final VoidCallback onVault;

  @override
  Widget build(BuildContext context) {
    final open = bench.openCandidates;
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: Zc.card,
        border: Border(left: BorderSide(color: Zc.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        open.isEmpty
                            ? 'No names to look at'
                            : open.length == 1
                            ? '1 name to look at'
                            : '${open.length} names to look at',
                        style: Zc.h2,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        open.isEmpty
                            ? 'Z knows every name this document uses.'
                            : 'Words this document uses as names, that Z does not know yet.',
                        style: Zc.small.copyWith(color: Zc.ink3),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, size: 18),
                  color: Zc.ink3,
                  onPressed: bench.closeNameReview,
                ),
              ],
            ),
          ),
          Container(height: 1, color: Zc.lineSoft),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: [
                for (final c in open) ...[
                  _Row(bench: bench, candidate: c),
                  Container(height: 1, color: Zc.lineSoft),
                ],
                YourNames(bench: bench, ground: ground, onVault: onVault),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.bench, required this.candidate});

  final Workbench bench;
  final NameCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final places = candidate.occurrences == 1 ? '1 place' : '${candidate.occurrences} places';
    final pages = candidate.pages == 1 ? '1 page' : '${candidate.pages} pages';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  candidate.text,
                  overflow: TextOverflow.ellipsis,
                  style: Zc.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              // What the decision is worth, from the core and not worked out here.
              Text('$places · $pages', style: Zc.tiny.copyWith(color: Zc.ink4)),
            ],
          ),
          const SizedBox(height: 4),
          Text(candidate.why, style: Zc.tiny.copyWith(color: Zc.ink3)),
          const SizedBox(height: 8),
          // Up to three lines, as the document writes them.
          for (final example in candidate.examples)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                example,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Zc.small.copyWith(color: Zc.ink2, fontFamily: Zc.mono),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Act(
                label: candidate.family ? 'Add as family name' : 'Add as given name',
                primary: true,
                onPressed: bench.busy
                    ? null
                    : () => bench.teachName(candidate.text, family: candidate.family),
              ),
              _Act(
                label: 'Ignore',
                onPressed: bench.busy ? null : () => bench.ignoreCandidate(candidate.text),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Act extends StatelessWidget {
  const _Act({required this.label, required this.onPressed, this.primary = false});

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return primary
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: Zc.river,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(label, style: Zc.small.copyWith(color: Colors.white)),
          )
        : TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: Zc.ink,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(label, style: Zc.small),
          );
  }
}

/// **Your names** — what this device knows because you said so.
///
/// The owner is building Swedish and German lists of his own, and until now
/// there was no plain way to put one in: a name had to appear in a document
/// first, be noticed, and be answered. Two acts here, and a list under them, so
/// a person can see their own library without going looking for it.
///
/// Both acts write to the vault, so both say what they need when there is none
/// — the same button-carries-its-state rule as «Always» in the review, and the
/// same door.
class YourNames extends StatefulWidget {
  const YourNames({super.key, required this.bench, required this.ground, required this.onVault});

  final Workbench bench;

  /// For the language list: which packs this build carries, and which are
  /// coming. Both from the core, as everywhere else.
  final Ground ground;
  final VoidCallback onVault;

  @override
  State<YourNames> createState() => _YourNamesState();
}

class _YourNamesState extends State<YourNames> {
  final _text = TextEditingController();
  UserNameKind _kind = UserNameKind.family;
  bool _always = false;
  bool _adding = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _vaultOpen => (widget.bench.snap?.vault ?? VaultState.absent) == VaultState.unlocked;

  /// The open client's own name, or `null` when this conversation is in none.
  ///
  /// The name and not the id: a profile id is `p-<slug>-<n>` and the person
  /// never typed it, which is the rule the vault's own refusals follow.
  String? get _clientName {
    final id = widget.bench.profileId;
    if (id == null) return null;
    for (final p in widget.ground.profiles) {
      if (p.id == id) return p.name;
    }
    return null;
  }

  String get _needs =>
      (widget.bench.snap?.vault ?? VaultState.absent) == VaultState.locked
          ? 'Unlock the vault'
          : 'Needs a vault';

  /// Fire the act and let the bench say what happened. Nothing here awaits the
  /// core: the bench owns the act, the sentence and the busy flag, and this
  /// panel is rebuilt when it notifies.
  void _add() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    _text.clear();
    unawaited(widget.bench.addUserName(text, kind: _kind, always: _always));
  }

  Future<void> _import() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Name lists', extensions: ['csv', 'txt']),
      ],
    );
    if (file == null || !mounted) return;
    final csv = await file.readAsString();
    if (!mounted) return;
    // Which language's list it joins. A list is a language, so this is the
    // same question the top bar asks, with the document's own pack in front.
    final into = await askForALanguage(
      context,
      ground: widget.ground,
      chosen: widget.bench.packId,
      title: 'Which language are these names?',
    );
    if (into == null || !mounted) return;
    // And how far they reach. One question for the whole file, because that is
    // the act: nobody chooses a file of twenty-one names in order to answer
    // twenty-one questions about them (046/F).
    final reach = await askHowFarAListReaches(context, client: _clientName);
    if (reach == null || !mounted) return;
    unawaited(widget.bench.importUserNames(csv, scope: reach.scope, into: into));
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.bench.userNames;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 1, color: Zc.lineSoft),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(child: Text('Your names', style: Zc.h2)),
              Text(
                rows.isEmpty ? '' : '${rows.length}',
                style: Zc.tiny.copyWith(color: Zc.ink4),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Names this device knows because you said so. They are kept in your '
            'vault, on this computer.',
            style: Zc.small.copyWith(color: Zc.ink3),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Act(
                label: _vaultOpen ? 'Add a name' : 'Add a name · $_needs',
                primary: _vaultOpen,
                onPressed: widget.bench.busy
                    ? null
                    : _vaultOpen
                        ? () => setState(() => _adding = !_adding)
                        : widget.onVault,
              ),
              _Act(
                label: _vaultOpen ? 'Import a list' : 'Import a list · $_needs',
                onPressed: widget.bench.busy ? null : (_vaultOpen ? _import : widget.onVault),
              ),

            ],
          ),
          const SizedBox(height: 6),
          Text(
            _vaultOpen
                ? 'A list is a CSV with a «name» and a «type» column: given, family, person or company.'
                : 'Your names live in the vault, so adding one needs it open.',
            style: Zc.tiny.copyWith(letterSpacing: 0, color: Zc.ink4),
          ),
          if (_adding && _vaultOpen) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              autofocus: true,
              style: Zc.body,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Zc.paper,
                hintText: 'Lindqvist',
                hintStyle: Zc.body.copyWith(color: Zc.ink4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Zc.line),
                ),
              ),
              onSubmitted: (_) => _add(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final k in UserNameKind.values)
                  _Pick(
                    label: _kindWord(k),
                    on: _kind == k,
                    onTap: () => setState(() => _kind = k),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Pick(label: 'Suggest', on: !_always, onTap: () => setState(() => _always = false)),
                _Pick(label: 'Always', on: _always, onTap: () => setState(() => _always = true)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _always
                  ? 'Always: protected the moment it appears, in every document.'
                  : 'Suggest: Z marks it and waits for your word.',
              style: Zc.tiny.copyWith(letterSpacing: 0, color: Zc.ink4),
            ),
            const SizedBox(height: 8),
            _Act(label: 'Add', primary: true, onPressed: widget.bench.busy ? null : _add),
          ],
          if (widget.bench.namesSaid != null) ...[
            const SizedBox(height: 10),
            Text(widget.bench.namesSaid!, style: Zc.small.copyWith(color: Zc.river)),
          ],
          const SizedBox(height: 12),
          if (rows.isEmpty && widget.bench.userLists.every((l) => l.names == 0))
            Text(
              _vaultOpen ? 'Nothing yet.' : '',
              style: Zc.small.copyWith(color: Zc.ink4),
            )
          else
            // **Grouped by list.** The owner, 6 October: «we make it possible
            // to create lists inside the vault, for example Arabic, English,
            // German and so on». Each list has its name, how many names are in
            // it, the switch that stops them being used without forgetting
            // them, and the three things that can be done to the list itself.
            for (final list in widget.bench.userLists) ...[
              _ListHead(bench: widget.bench, ground: widget.ground, list: list),
              for (final row in rows.where((r) => r.list == list.name))
                Padding(
                  padding: const EdgeInsets.only(left: 6, bottom: 6),
                  child: Opacity(
                    // A list that is off is not a list that was forgotten, and
                    // the screen says so by showing every name in it, faded.
                    opacity: list.enabled ? 1 : 0.5,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: row.text, style: Zc.body.copyWith(fontWeight: FontWeight.w600)),
                                TextSpan(
                                  text: '  ${_kindWord(row.kind)}${row.always ? " · always" : ""}',
                                  style: Zc.tiny.copyWith(color: Zc.ink4),
                                ),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Forget «${row.text}»',
                          icon: const Icon(Icons.close, size: 15),
                          color: Zc.ink4,
                          visualDensity: VisualDensity.compact,
                          onPressed: widget.bench.busy
                              ? null
                              : () => unawaited(widget.bench.forgetUserName(row)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
        ],
      ),
    );
  }
}

String _kindWord(UserNameKind k) => switch (k) {
      UserNameKind.given => 'given name',
      UserNameKind.family => 'family name',
      UserNameKind.person => 'person',
      UserNameKind.company => 'company',
    };

/// A one-of-these chip, the same shape the send sheet uses for its choices.
class _Pick extends StatelessWidget {
  const _Pick({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: on ? Zc.river.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(color: on ? Zc.river : Zc.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Zc.small.copyWith(
            color: on ? Zc.river : Zc.ink3,
            fontWeight: on ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// One list's own row: its name, how many names are in it, the switch, and the
/// three things that can be done to the list itself.
///
/// The switch is the point of a list. Off is **not** forgotten — every name is
/// still here, drawn faded under the head — so a person can read the same
/// document with a dictionary and without it and see what the dictionary did.
class _ListHead extends StatelessWidget {
  const _ListHead({required this.bench, required this.ground, required this.list});

  final Workbench bench;
  final Ground ground;
  final UserListRow list;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    // The language's own name where there is one, and its id
                    // otherwise — a list for a language this build does not
                    // carry yet is the whole point of letting a person build it.
                    text: languageName(ground, list.name),
                    style: Zc.small.copyWith(
                      fontWeight: FontWeight.w700,
                      color: list.enabled ? Zc.ink : Zc.ink4,
                    ),
                  ),
                  TextSpan(
                    text: '  ${list.names}',
                    style: Zc.tiny.copyWith(color: Zc.ink4),
                  ),
                  if (!list.enabled)
                    TextSpan(text: '  off', style: Zc.tiny.copyWith(color: Zc.amber)),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Tooltip(
            message: list.enabled ? 'Stop using these names' : 'Use these names again',
            child: Switch(
              value: list.enabled,
              onChanged: bench.busy
                  ? null
                  : (on) => unawaited(bench.setListEnabled(list.name, on)),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'What to do with «${list.name}»',
            icon: const Icon(Icons.more_horiz, size: 18, color: Zc.ink4),
            onSelected: (what) => unawaited(_act(context, what)),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'move', child: Text('Move to…')),
              PopupMenuItem(value: 'export', child: Text('Export CSV')),
              PopupMenuItem(value: 'remove', child: Text('Remove list')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _act(BuildContext context, String what) async {
    switch (what) {
      case 'move':
        await _move(context);
      case 'export':
        await _export(context);
      case 'remove':
        // What it costs, before it is done — the same rule forgetting a value
        // follows: the app says the price and a person agrees to it.
        final cost = await bench.listCost(list.name);
        if (!context.mounted) return;
        final sure = await showDialog<bool>(
          context: context,
          builder: (inner) => AlertDialog(
            backgroundColor: Zc.paper,
            title: Text('Remove «${list.name}»?', style: Zc.h2),
            content: Text(
              cost == 1
                  ? 'One name goes with it. Nothing else is touched.'
                  : '$cost names go with it. Nothing else is touched.',
              style: Zc.body,
            ),
            actions: [
              ZButton(label: 'Keep it', onPressed: () => Navigator.of(inner).pop(false)),
              ZButton(label: 'Remove', filled: true, onPressed: () => Navigator.of(inner).pop(true)),
            ],
          ),
        );
        if (sure ?? false) unawaited(bench.forgetList(list.name));
    }
  }

  /// Move the whole list into another language — one question, one act.
  ///
  /// A list learned under the wrong language is a thing that happens: the
  /// owner taught 75 Swedish surnames while the device was set up in German,
  /// and teaching them again one at a time is not a repair. The language is
  /// asked the same way it is asked everywhere else, and the count is said
  /// before the move so nobody moves 75 names meaning to move three.
  Future<void> _move(BuildContext context) async {
    final into = await askForALanguage(
      context,
      ground: ground,
      chosen: bench.packId,
      title: list.names == 1
          ? 'Move one name from ${languageName(ground, list.name)} to…'
          : 'Move ${list.names} names from ${languageName(ground, list.name)} to…',
    );
    if (into == null || into == list.name) return;
    unawaited(bench.moveList(list.name, into));
  }

  /// The list, as the file it could have come from: `name,type,source,licence`.
  Future<void> _export(BuildContext context) async {
    final rows = bench.userNames.where((r) => r.list == list.name);
    final csv = StringBuffer('name,type,source,licence\n');
    for (final row in rows) {
      csv.writeln('${_csv(row.text)},${_kindWord(row.kind).split(' ').first},,');
    }
    final where = await getSaveLocation(suggestedName: '${list.name}.csv');
    if (where == null) return;
    await XFile.fromData(
      Uint8List.fromList(csv.toString().codeUnits),
      mimeType: 'text/csv',
    ).saveTo(where.path);
  }

  static String _csv(String value) =>
      value.contains(',') || value.contains('"') ? '"${value.replaceAll('"', '""')}"' : value;
}

/// One short name, asked for in one field. Used for a new list, a rename, and
/// the name an import suggests from its file.
Future<String?> askForAName(
  BuildContext context, {
  required String title,
  required String hint,
  String? initial,
}) async {
  final field = TextEditingController(text: initial);
  final name = await showDialog<String>(
    context: context,
    builder: (inner) => AlertDialog(
      backgroundColor: Zc.paper,
      title: Text(title, style: Zc.h2),
      content: TextField(
        controller: field,
        autofocus: true,
        style: Zc.body,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: Zc.body.copyWith(color: Zc.ink4),
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (value) => Navigator.of(inner).pop(value.trim()),
      ),
      actions: [
        ZButton(label: 'Cancel', onPressed: () => Navigator.of(inner).pop()),
        ZButton(
          label: 'Save',
          filled: true,
          onPressed: () => Navigator.of(inner).pop(field.text.trim()),
        ),
      ],
    ),
  );
  field.dispose();
  return (name == null || name.isEmpty) ? null : name;
}

/// A language's own name, as the core's table gives it, and the code itself
/// when the table does not know it — which can only happen to a list made by a
/// build that knew a language this one does not.
String languageName(Ground ground, String id) => ground.languageName(id);

/// Which language's list? The same two halves as everywhere else — what this
/// build has rules for, a line, and every other language — because a person
/// builds their Arabic list by hand long before an Arabic pack exists.
/// How far a file of names reaches — asked once for the whole file.
///
/// Three answers, because the core takes a `Scope` and not a flag of its own,
/// and because a client book kept for **this client** and one kept for
/// **everywhere** are different promises. Making one of them the default would
/// be the 046/F defect again under another name: a reach nobody chose.
///
/// Each answer is a whole sentence on its own button, which is P2-5's rule —
/// the name of the act carries what it does and where, and the line above only
/// explains. The words are 046/E's, the same four the dialog, the card, the
/// panel and the explain sheet use: Once · This conversation · This client ·
/// Everywhere. «Once» and «this conversation» are not here, because they are
/// answers about a place in a document and a list has no places in it.
///
/// What comes back: `ListReach.offer` (no scope), `ListReach.thisClient`
/// (`Scope.profile`), `ListReach.everywhere` (`Scope.always`), and `null` when
/// the person closed the question — and then nothing is imported at all.
enum ListReach {
  offer(null),
  thisClient(Scope.profile),
  everywhere(Scope.always);

  const ListReach(this.scope);

  /// The core's own word for this answer. `null` is «offer them and I decide».
  final Scope? scope;
}

Future<ListReach?> askHowFarAListReaches(BuildContext context, {String? client}) {
  return showDialog<ListReach>(
    context: context,
    builder: (inner) => AlertDialog(
      backgroundColor: Zc.paper,
      title: const Text('How far do these names reach?', style: Zc.h2),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Protecting them means Z blackens them the moment they appear, '
              'with no question. Offering them means Z marks them and waits '
              'for you.',
              style: Zc.small.copyWith(color: Zc.ink3),
            ),
            const SizedBox(height: 10),
            Text(
              'You can change any one of them afterwards, name by name.',
              style: Zc.tiny.copyWith(color: Zc.ink4),
            ),
          ],
        ),
      ),
      actions: [
        ZButton(
          label: 'Offer them and I decide',
          onPressed: () => Navigator.of(inner).pop(ListReach.offer),
        ),
        ZButton(
          label: 'Protect them everywhere',
          onPressed: () => Navigator.of(inner).pop(ListReach.everywhere),
        ),
        // The client's own book is offered first among the two protections,
        // and named: «what you learn about one of them does not become a rule
        // about all of them». Without a client open the core refuses it in a
        // sentence, so the button is not drawn rather than drawn to fail.
        if (client != null)
          ZButton(
            label: 'Protect them for $client',
            filled: true,
            onPressed: () => Navigator.of(inner).pop(ListReach.thisClient),
          ),
      ],
    ),
  );
}

Future<String?> askForALanguage(
  BuildContext context, {
  required Ground ground,
  required String chosen,
  required String title,
}) async {
  var picked = chosen;
  return showDialog<String>(
    context: context,
    builder: (inner) => StatefulBuilder(
      builder: (inner, setState) => AlertDialog(
        backgroundColor: Zc.paper,
        title: Text(title, style: Zc.h2),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: LanguageChoices(
              ground: ground,
              chosen: picked,
              onChoose: (id) => setState(() => picked = id),
              // A list may be made for a language this build does not carry:
              // that is how an Arabic list exists before an Arabic pack does.
              plannedChoosable: true,
            ),
          ),
        ),
        actions: [
          ZButton(label: 'Cancel', onPressed: () => Navigator.of(inner).pop()),
          ZButton(label: 'Save', filled: true, onPressed: () => Navigator.of(inner).pop(picked)),
        ],
      ),
    ),
  );
}
