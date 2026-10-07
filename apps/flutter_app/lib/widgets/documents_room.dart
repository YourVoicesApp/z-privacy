// «Documents I saved» — what Z Privacy has produced, from the record and not
// from the folder.
//
// **The owner, 7 October:** «نحتاج إلى زرٍّ داخل التطبيق يعرض وثائق PDF
// المحفوظة» — a button inside the app that shows the saved PDF documents.
//
// And the reason the list is a record rather than a listing of a folder, which
// is the lead's answer to the question he asked in the same breath — «هل هي
// مختومة؟»:
//
//   The file is **fingerprinted, not sealed.** Its footer states the build
//   stamp, the counts by kind and a sha256 of the protected text, and a reader
//   can check every one of those for themselves. What a fingerprint cannot
//   answer is «did this app produce this, and when» — and that is the question
//   a client or a regulator asks. A fingerprint proves the **content**; a
//   record proves the **act**.
//
// A folder can be moved, emptied or synced away. So the row outlives its file,
// and when the file has gone the row says so plainly and keeps everything else
// it knows. **That sentence is the whole reason the record exists**, and it is
// the case this file is tested on first.
//
// What is **not** here: a serial, a seal, and a PIN. Those are 044, and the
// record built under this screen is what makes a serial mean anything — it
// already carries an empty place for one, so the day it exists it costs a
// value and not a migration. Print and e-mail are 046/T.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/session_state.dart';
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/widgets/bits.dart';
import 'package:zprivacy/widgets/document_text.dart' show kindName;

/// Open the room. A dialog, because it is a thing you look at and close, and
/// because it must be reachable from wherever the person is.
Future<void> showDocumentsRoom(BuildContext context, Ground ground) async {
  // Read before it is drawn: a room that opens empty and fills a moment later
  // looks for that moment exactly like a room with nothing in it.
  await ground.readProduced();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => DocumentsRoom(ground: ground),
  );
}

class DocumentsRoom extends StatelessWidget {
  const DocumentsRoom({super.key, required this.ground});

  final Ground ground;

  /// So a test can reach the room without matching on wording.
  static const room = ValueKey<String>('documents-room');

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: DocumentsRoom.room,
      backgroundColor: Zc.paper,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
        child: ListenableBuilder(
          listenable: ground,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Documents I saved', style: Zc.h2),
                    const SizedBox(height: 7),
                    Text(
                      // Said before the list, because it is what makes the list
                      // worth having: the rows are kept here, not read off a
                      // folder, so moving or deleting a file does not lose the
                      // fact that it was made.
                      'Z Privacy keeps this list itself, in your vault. A file you move or '
                      'delete still has its row here.',
                      style: Zc.small.copyWith(color: Zc.ink3),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
              Flexible(child: _body(context)),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ZButton(label: 'Close', onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    // **A locked vault means no list**, and it is told rather than drawn as
    // emptiness. The same rule as everything else in that file.
    if (ground.vault != VaultState.unlocked) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Text(
          'Your vault is locked, so this list is sealed with everything else in it. '
          'Unlock it to see what Z Privacy has produced.',
          style: Zc.body,
        ),
      );
    }
    final rows = ground.produced;
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Text(
          'Nothing yet. Save a protected document as a PDF and it is written down here.',
          style: Zc.body,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      shrinkWrap: true,
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 9),
      itemBuilder: (context, i) => _DocumentTile(row: rows[i], ground: ground),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.row, required this.ground});

  final ProducedDocument row;
  final Ground ground;

  @override
  Widget build(BuildContext context) {
    // **Asked now, not remembered.** The record cannot know what happened to a
    // file after it was written, and a «present» flag stored beside the path
    // would be a fact that goes stale the moment somebody tidies a folder.
    final here = _isHere(row.path);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: Zc.panel(
        fill: here ? Zc.card : Zc.warmCard,
        edge: here ? Zc.line : Zc.clayEdge,
        radius: 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                here ? Icons.description_outlined : Icons.history_outlined,
                size: 17,
                color: here ? Zc.clay : Zc.ink4,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fileName(row.path),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Zc.ink),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'From ${row.fromDocument.isEmpty ? 'text you wrote' : row.fromDocument} · '
                      '${_day(row.madeAt)} · ${row.places} ${row.places == 1 ? 'place' : 'places'} '
                      'replaced, ${_values(row)} ${_values(row) == 1 ? 'value' : 'values'}'
                      '${_kinds(row).isEmpty ? '' : ' (${_kinds(row)})'}',
                      style: Zc.small,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          // **The sentence the record exists for.** Not «missing», not a red
          // cross: what was produced, when, and that the file is no longer
          // where it was put. The row keeps every other fact it had.
          if (!here)
            Padding(
              padding: const EdgeInsets.only(left: 26, bottom: 9),
              child: Text(
                'This document was produced on ${_day(row.madeAt)}; the file is no longer at '
                '${row.path}.',
                style: Zc.small.copyWith(color: Zc.clayDeep),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ZButton(
                  label: 'Open the file',
                  icon: Icons.open_in_new,
                  onPressed: here ? () => unawaited(_open(context, row.path)) : null,
                  hint: here ? null : 'The file is not there any more',
                ),
                ZButton(
                  label: 'Open the folder',
                  icon: Icons.folder_open_outlined,
                  onPressed: () => unawaited(_open(context, _folderOf(row.path))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          // The digest, whole. It is sixty-four characters because that is what
          // a sha256 is, and shortening it would make it decoration — the same
          // reasoning the file's own footer carries.
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              'sha256 of the protected text ${row.sha256}',
              style: Zc.tiny.copyWith(letterSpacing: 0, fontFamily: Zc.mono),
            ),
          ),
        ],
      ),
    );
  }

  /// Hand the path to the desktop and let it decide what opens it.
  ///
  /// `xdg-open` with the path as an **argument**, never a shell line: a file
  /// name with a space or a quote in it is ordinary, and a shell would read it
  /// as syntax. Nothing of the document's content goes anywhere near this — a
  /// path is all it is given, and the path came out of our own record.
  Future<void> _open(BuildContext context, String path) async {
    try {
      final out = await Process.run('xdg-open', [path]);
      if (out.exitCode == 0 || !context.mounted) return;
      _say(context, 'This computer had nothing to open $path with.');
    } on ProcessException {
      if (context.mounted) _say(context, 'Z Privacy could not ask this computer to open $path.');
    }
  }

  void _say(BuildContext context, String what) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(what)));
  }
}

bool _isHere(String path) {
  try {
    return File(path).existsSync();
  } on FileSystemException {
    // A path we cannot even ask about is a path the file is not at.
    return false;
  }
}

String _folderOf(String path) {
  final cut = path.lastIndexOf('/');
  return cut > 0 ? path.substring(0, cut) : path;
}

String _fileName(String path) {
  final cut = path.lastIndexOf('/');
  return cut >= 0 && cut + 1 < path.length ? path.substring(cut + 1) : path;
}

int _values(ProducedDocument row) => row.byKind.fold(0, (a, k) => a + k.count);

/// The kinds in the row's own order, each with its count. The name comes from
/// the core's table, like everywhere else — a screen that spelled a kind itself
/// would be a second opinion about a word.
String _kinds(ProducedDocument row) => row.byKind.isEmpty
    ? ''
    : row.byKind.map((k) => '${kindName(k.kind)} ×${k.count}').join(', ');

String _day(BigInt seconds) {
  final when = DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000);
  return '${when.year.toString().padLeft(4, '0')}-'
      '${when.month.toString().padLeft(2, '0')}-'
      '${when.day.toString().padLeft(2, '0')}';
}
