// **The name of the file a person is about to save** — the owner, 24 October
// 2026, paper 108 item 2: «نجعل اسم الجلسة داخل باسم الوثيقة. والحفظ يحتاج إلى
// كتابة اسم للوثيقة من قبل المستخدم».
//
// ## Why it is asked at all
//
// Until today a protected copy was named `<session>-protected-<date>.pdf`, and
// the session's name is ours: a session nobody named is «Session 1». So two
// vaults' copies of one day arrive in `Documents\ZPrivacy` under one name, the
// second becomes `…-2.pdf`, and nothing in either name says which work it is.
// That is what Windows' first read-back of 22 October fell into, and the owner
// met it as «the same name».
//
// ## The sentence beside the field, and why it is not optional
//
// **A file name is not protected and cannot be.** It leaves with the file, in
// a folder listing, a backup, a sync, an attachment — the one direction nobody
// looks at. 081 is why the app stopped taking the document's own name by
// itself; this asks for one, so the thing 081 was about has to be said out
// loud where the typing happens: «The file name stays as you type it. Don't
// put real names in it.» A privacy product that asks for a name and says
// nothing about where it goes is teaching the wrong lesson quietly.
//
// ## Nothing is decided here
//
// This returns the word and nothing else: no cleaning, no shortening, no
// spelling of a path. `core/protected_pdf.dart` has one hand for that
// (`_clean`), and a second opinion about what a safe file name is would be a
// second answer about one file.
import 'package:flutter/material.dart';

import 'package:zprivacy/core/palette.dart';
import 'package:zprivacy/core/sentences.dart';

/// The dialog, by what it is — so a guard reaches the field and the press
/// without knowing the words on them.
class TheNameForTheFile {
  const TheNameForTheFile._();

  static const field = ValueKey<String>('the-name-for-the-file');
  static const save = ValueKey<String>('the-name-for-the-file-save');
  static const cancel = ValueKey<String>('the-name-for-the-file-cancel');
}

/// Ask for the document's name. `null` is «not now» — the press is off, and
/// **nothing has happened**: no session is born, no file is written, and the
/// person is where they were.
///
/// An empty name is refused **with a sentence**, in the dialog, and the dialog
/// stays open: a press that silently invents a name is how a file ends up
/// called something nobody chose. There is no controller — one `onChanged` and
/// a local word need no lifecycle, and a controller made here would be
/// disposed while the route was still animating out (the Sessions room's own
/// measured lesson).
Future<String?> askForTheNameOfTheDocument(BuildContext context) async {
  var word = '';
  var refused = false;
  return showDialog<String>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, again) {
        void pressed() {
          if (word.trim().isEmpty) {
            again(() => refused = true);
            return;
          }
          Navigator.of(dialog).pop(word.trim());
        }

        return AlertDialog(
          backgroundColor: Zc.paper,
          title: Text(sentences.nameThisDocument, style: Zc.h2),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: TheNameForTheFile.field,
                  autofocus: true,
                  onChanged: (typed) {
                    word = typed;
                    if (refused && typed.trim().isNotEmpty) {
                      again(() => refused = false);
                    }
                  },
                  onSubmitted: (_) => pressed(),
                  style: Zc.body.copyWith(color: Zc.ink),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Zc.card,
                    isDense: true,
                    hintText: sentences.whatIsThisDocumentCalled,
                    hintStyle: Zc.body.copyWith(color: Zc.ink4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Zc.line),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // The one thing this dialog must say, in the house's own
                // «honest» grey: it is a limit and not an instruction, and it
                // is read before the typing and not after it.
                Text(sentences.theFileNameIsNotProtected, style: Zc.small),
                if (refused) ...[
                  const SizedBox(height: 10),
                  Text(
                    sentences.aNameIsNeededForThisDocument,
                    style: Zc.small.copyWith(color: Zc.amber),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              key: TheNameForTheFile.cancel,
              onPressed: () => Navigator.of(dialog).pop(),
              child: Text(sentences.notNow),
            ),
            TextButton(
              key: TheNameForTheFile.save,
              onPressed: pressed,
              child: Text(sentences.saveIt),
            ),
          ],
        );
      },
    ),
  );
}
