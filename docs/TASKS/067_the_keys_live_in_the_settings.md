# 067 · The keys live in the settings: no credential is asked for during work

**The owner, 8 Oct 2026, before sleeping:** *«المهم وأهم شيء هو حذف إعدادات
الذكاء الصناعي تخرج من سياق العمل»* — and the ruling in its short form:
**«لا تظهر أثناء العمل أبداً»**. The third of his three evening items, «النفي» —
the exile of the key form from the send flow.

Built by the design seat on `fix/the-chat-reads-like-a-chat`, three commits of
the branch's seven, measured with 065 as one tree. Final head `e2c9656`.

---

## The task named one door. The measuring found four.

The assignment named `send_sheet.dart`'s `_connectHere` at the Direct API door.
On `fcdbabd` the sheet mounted a `ConnectForm` in **four** places:

1. `_ModelAndMode._provider`, behind «Connect» beside an unreached provider —
   **on the page the sheet opens on.** A person who pressed ✨AI to choose a
   model was one press from an endpoint, a model and an API key. **This is the
   page the owner will look at**, and the worst instance stood on it.
2. the Direct API door, inline, whenever nothing is connected — the one the task
   named. It is the second page, behind Continue.
3. «Change the address, the model, or the key», folded, when something is
   connected.
4. «Set up a local model», folded, always.

All four are gone. `_More` and `_connectHere` went with them as dead code, and
`connect_form.dart` is no longer imported there. Fixing only the named door
would have left the worst instance standing — a search is only as wide as its
claim, again.

**Nothing was added to the settings.** `_AiRoom` already mounted the form at
`settings.dart:260` and `:276`, and `_SettingsScreenState` already defaults
`_room` to `SettingsRoom.ai` — so a door that merely opens the panel lands where
the key is asked for, with no change to `shell.dart` or `settings.dart`. The
ruling has two branches and both are pinned: nothing connected, and something
connected — the second needed a provider connected inside a Dart test, which the
suite had never done before this round.

## The guards, red on `fcdbabd`, bite lines verbatim

- e · «an endpoint, a model and an API key opened inside the send sheet — one
  press from the page a person reaches by asking for an AI» —
  `Found 1 widget with type "ConnectForm"`
- f · «the key form is still standing in the send flow, where the owner said it
  never appears»
- g1 · «the Local AI door still folds a key form into the send flow»
- g2 · «the Direct API door still folds the endpoint, the model and the key into
  the send flow» — the connected branch; the red-first run never reached it
  because it failed at the assertion before it, so it was proven by putting both
  forms back
- f, broken a second time on purpose (`Navigator.pop` removed) · «the sheet is
  still up, so the panel opens under its modal barrier — it paints in full and
  answers nothing, which is worse than a door that did not open»
- j · «a door labelled «Open Settings» is offered over an already-open panel,
  and the shell's callback is a toggle — pressing it would shut them» —
  `Found 2 widgets with text "Open Settings"`
- h · **an anchor, not a guard** — green before and after, on purpose: the three
  doors stand and an open suggestion still refuses the send. An anchor that went
  red would mean the scope guard itself had been broken.

## Guard `i` — two blind assertions, and the closing of them

`i` carries the field claims re-homed from `shell_test.dart` to the panel. It
began the night as the one guard never watched red on its own subject — its
assertions inherited from a test that was already green, which is precisely the
position where a guard is green for the wrong reason. The design seat named the
gap itself and asked for the twenty minutes. Breaking `ConnectForm` found **two
of its three claims did not bite at all**:

* «literal loopback address», unscoped, was satisfied by the **Local AI card's
  own description** at `settings.dart:270` — one widget above the form. The
  form's own sentence deleted, guard green. It was measuring the label on the
  box instead of the box.
* the width was read off the **`ConnectForm`'s own rect**, which cannot move. A
  field given 900 px inside the 444 px column left the form's rect at 444,
  green. That violates the round's own rule — *measure the rect of the thing
  whose position the fault moves, never the rect of the box the fault happens
  inside* — broken by its author in their own file hours after writing it down.
  The ruling is the property; a task's named mechanism is only a starting place.

Re-aimed and red-proven, three bite lines verbatim:

- «the Direct API cards ask for 6 keys and the screen drew a different number»
- «the form itself no longer states the loopback rule»
- «a field runs off the 480 px panel: [Rect.fromLTRB(336.0, 885.0, 744.0,
  927.0), …]»

`connect_form.dart` was restored byte-for-byte after each break — the final
diff, one test file, confirms it. `i` ended the round the most-tested guard in
it, having been the only untested one an hour before.

## Two colliding tests re-arranged, not excepted

* `a_door_you_can_see_test.dart` claimed «an unconnected provider offers no way
  to connect» — the inline form was its *setup*, so the claim stayed and the
  label became the door's.
* `shell_test.dart` asserted the key form's **fields** — claims about
  `ConnectForm`, so they moved with it to the panel at 444 px. Re-homing
  corrected two of them: the panel draws **six** Direct API cards, one per
  provider from `known()`, where the sheet had mounted only `providers.first` —
  so «one API KEY, two ADDRESS» became counts read from `ground.providers`,
  which also survives `fake_provider` making it seven, the configuration the
  canonical test command enables. (The six cards all titled «Direct API» remain
  a named debt from 063.)

## Numbers and the accounting

The tree is one with 065's — the numbers and the twelve-guards-one-control-one-
anchor accounting are in 065's paper and are the lead's own clean-tree
measurement. Attribution for the round's catches, both ways, is there too.
