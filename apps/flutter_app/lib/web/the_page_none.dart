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
