// One value shown at a time, for as long as the core says — and no longer.
//
// The authority is in Rust. `revealValue` starts the clock, `revealState` is
// asked what is left of it, `hideValue` ends it. Nothing in this file keeps a
// value on screen: the ticker below draws a number for a person to read, and
// drops what is shown in the same frame the core answers 0 — or answers about a
// different value, because the core allows exactly one at a time and this holds
// the same rule on the Dart side.
//
// It has its own file because two rooms now hold a value this way: the identity
// card, and «Values I taught» in the vault list. A second copy of the machine
// would have been a second place to lose the lesson that `reveal_row_test.dart`
// pins — **expiry changes the content, never the geometry** — and the copy that
// lost it would still have looked right.
import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:zprivacy/src/rust/api/mirrors.dart';
import 'package:zprivacy/src/rust/third_party/z_core/api.dart' as z;
import 'package:zprivacy/core/messages.dart';

mixin RevealHold<T extends StatefulWidget> on State<T> {
  RevealedValue? _shown;
  int _shownId = 0;
  int _remaining = 0;
  Timer? _tick;

  /// What is drawn for [valueId] right now, or null when it is hidden.
  RevealedValue? shownFor(int valueId) => _shownId == valueId ? _shown : null;

  /// Milliseconds the **core** says are left. Read, never counted down here.
  int get remainingMs => _remaining;

  /// The line beside the value: what it is, in the core's time.
  String revealLabel(int valueId) => shownFor(valueId) == null
      ? 'Hidden'
      : 'Revealed · ${(_remaining / 1000).ceil()}s';

  /// Ask for one value. Any trouble is handed back as a sentence; this decides
  /// nothing about where it is shown.
  Future<void> reveal(
    int entity,
    int valueId, {
    void Function(String)? onTrouble,
  }) async {
    try {
      final v = await z.revealValue(entity: entity, valueId: valueId);
      if (!mounted) return;
      setState(() {
        _shown = v;
        _shownId = valueId;
        _remaining = v.ttlMs;
      });
      _watch();
    } on ApiError catch (e) {
      if (mounted) onTrouble?.call(humanMessage(e));
    }
  }

  void _watch() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) async {
      late final RevealState state;
      try {
        state = await z.revealState();
      } catch (_) {
        // The core could not be asked. Hiding is the only honest answer: this
        // file says the authority is in Rust, and a value kept because the
        // question failed would make that untrue. Same rule as `syncReveals`.
        if (!mounted) return;
        setState(() {
          _shown = null;
          _remaining = 0;
        });
        _tick?.cancel();
        _tick = null;
        return;
      }
      if (!mounted) return;
      final over = state.remainingMs == 0 ||
          state.valueId == null ||
          state.valueId != _shownId;
      setState(() {
        _remaining = state.remainingMs;
        if (over) _shown = null;
      });
      if (over) {
        _tick?.cancel();
        _tick = null;
      }
    });
  }

  Future<void> hideNow() async {
    _tick?.cancel();
    _tick = null;
    await z.hideValue();
    if (!mounted) return;
    setState(() {
      _shown = null;
      _remaining = 0;
    });
  }

  /// Drop what is held without asking the core anything — for a rebuild that
  /// replaced the rows under it.
  void dropShown() {
    _tick?.cancel();
    _tick = null;
    _shown = null;
    _remaining = 0;
  }

  /// From `dispose`: the screen is going, so nothing may stay revealed behind
  /// it. Not awaited, because `dispose` cannot.
  void endReveal() {
    _tick?.cancel();
    _tick = null;
    _shown = null;
    unawaited(z.hideValue());
  }
}
