// Not a browser: each act is recorded, for the tests, and nothing happens.
import 'dart:typed_data';

/// Every act asked of the page, in order: what, of what, and its size.
final List<(String, String, int)> thePageWasAsked = <(String, String, int)>[];

/// The visitor's own copy, offered as a download. True when it was offered.
bool saveToTheDevice(Uint8List bytes, String name) {
  thePageWasAsked.add(('save', name, bytes.length));
  return true;
}

/// One of our own pages, in the same tab.
void goTo(String address) => thePageWasAsked.add(('go', address, 0));

// ---- Scribe's editor (paper 124): the page's acts, recorded the same way.

/// Scribe's editor over the trial: opened, and with [insert] the answer sent
/// «to the editor» (`scribe-insert`).
void openTheEditor({String? insert}) =>
    thePageWasAsked.add(('editor-open', insert ?? '', insert?.length ?? 0));

/// Z's copy, handed to the editor so a paste of it counts as AI (88 (د)) —
/// now, or when it opens.
void handTheCopyToTheEditor(String text) =>
    thePageWasAsked.add(('editor-z-copy', text, text.length));

/// The editor and everything in it, gone: «Start over», or the page left.
void dropTheEditor() => thePageWasAsked.add(('editor-drop', '', 0));
