// The one place in the UI that talks to z_core.
//
// Why it exists at all: the owner's rule for M7 is that no number on screen is
// invented here. So every field below is a value the core handed over, and the
// only way it changes is a call that went to Rust and came back. A screen reads
// these fields; it never computes one.
//
// It also means a mistake is findable: if a count is wrong, it is wrong in the
// core or in the refresh below — never in a widget.
import 'package:flutter/foundation.dart';

// Prefixed on purpose: every line below that says `z.` is a call into Rust, and
// the prefix makes that visible when reading the file rather than guessing.
import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;

/// What the app knows before any document exists: the ground the Workspace stands
/// on, and what Home draws.
class Ground extends ChangeNotifier {
  VaultState vault = VaultState.absent;
  List<ProfileRow> profiles = const [];
  List<PackRow> packs = const [];
  List<ProviderRow> providers = const [];
  int entityCount = 0;
  int valueCount = 0;
  String? trouble;

  /// Read it all again from Rust. Called on open, and after anything that could
  /// have changed it.
  Future<void> refresh() async {
    try {
      vault = await z.vaultState();
      packs = await z.packs();
      providers = await z.providers();
      // Both of these need an open vault; a locked one is not an error, it is a
      // state the UI shows in words.
      profiles = vault == VaultState.unlocked ? await z.profiles() : const [];
      if (vault == VaultState.unlocked) {
        final rows = await z.entities();
        entityCount = rows.length;
        valueCount = rows.fold<int>(0, (sum, e) => sum + e.values);
      } else {
        entityCount = 0;
        valueCount = 0;
      }
      trouble = null;
    } on ApiError catch (e) {
      trouble = e.toString();
    }
    notifyListeners();
  }

  int get connectedProviders => providers.where((p) => p.connected).length;
}

/// One conversation: the document, what was found in it, and what would leave.
///
/// Everything here is refreshed from the core together, because the core's own
/// `revision` ties them: a document view and a scan report from two different
/// revisions would be two different documents.
class Workbench extends ChangeNotifier {
  Workbench({required this.session, required this.profileId, required this.packId});

  final SessionId session;
  final String? profileId;
  final String packId;

  DocumentView? document;
  ScanReport? report;
  List<Finding> findings = const [];
  List<TokenRow> tokens = const [];
  Revision revision = const Revision(n: 0);
  String? trouble;
  bool busy = false;

  /// The outgoing text, and the handle it was built under.
  ///
  /// Rebuilt on every refresh rather than cached, because the core ties a
  /// payload to a `revision`: a view kept from before a change is a view of a
  /// different document, and showing one would be the exact lie this column
  /// exists to prevent.
  PayloadHandle? handle;
  PayloadView? payload;

  /// Chips or plain, on the Safe side. A drawing choice; the string is the same.
  bool chips = true;

  /// The three questions the owner says a user must always be able to answer by
  /// looking. These getters exist so a screen never has to work one out.
  ///
  ///   what do I have?      → [document] (the Original side)
  ///   what will leave?     → the Safe side, built in Rust, from M7.2
  ///   why was this hidden? → [findings], each carrying its own source and reason
  int get protectedCount => report?.auto ?? 0;
  int get openSuggestions => report?.suggested ?? 0;
  int get normalCount => report?.normal ?? 0;

  Future<void> refresh() async {
    try {
      document = await z.documentView(session: session);
      findings = await z.listFindings(session: session);
      tokens = await z.listTokens(session: session);
      revision = await z.sessionRevision(session: session);
      handle = await z.buildPayload(session: session);
      payload = await z.payloadView(handle: handle!);
      trouble = null;
    } on ApiError catch (e) {
      trouble = e.toString();
    }
    notifyListeners();
  }

  /// A scan is not a screen (the behaviour board): it runs on import, and this is
  /// the same call the Rescan button makes later.
  Future<void> rescan() async {
    busy = true;
    notifyListeners();
    try {
      report = await z.scan(session: session);
      trouble = null;
    } on ApiError catch (e) {
      trouble = e.toString();
    }
    busy = false;
    await refresh();
  }

  void showChips(bool on) {
    chips = on;
    notifyListeners();
  }

  @override
  void dispose() {
    // A closed session takes its tokens with it. Nothing is kept behind.
    z.closeSession(session: session).catchError((_) {});
    super.dispose();
  }
}
