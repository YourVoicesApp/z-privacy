# 063 · Settings become a panel, and the door stops swallowing the room

**The owner, 8 Oct 2026:** *«نجعل نافذة الإعدادات خيار في الأعلى يفتح قائمة إلى
يمين الشاشة وتغلق بالضغط عليها»* — and the width is **480**, his word.

**Step 2 of four.** Step 1 (`060` + the reach dialog) is measured and committed on
`fix/two-doors-and-an-icon`. Steps 3 and 4 — the bank, then sessions — both live
in the panel this task creates, so nothing after this can start before it.

---

## The defect, measured

`shell.dart:335` is a chain of early returns:

```dart
Widget build(BuildContext context) {
  if (firstRun)       return FirstRunScreen(...);   // :337
  if (_settingsOpen)  return SettingsScreen(...);   // :373   ← swallows everything
  if (_vaultOpen)     return VaultScreen(...);      // :391
  if (bench != null)  return WorkspaceScreen(...);  // :411
  ...                 return the home Stack;
}
```

Settings are **not a panel over the work. They are instead of it.** `onSettings`
is handed to `HomeScreen` and to nothing else (`shell.dart:429`), and the only
control that calls it is one `IconButton` at `home.dart:180`. `widgets/acts.dart`
carries nine labels on a document and settings is not among them.

So the button was not forgotten in the workspace: **it could not have existed
there**, because pressing it would hide the document the person is working on.

That is 061 §5, and it is the reason the owner could not reach settings tonight.

## Do

**1 · `build` keeps its chain, under another name.**
Rename the current body to `Widget _body(BuildContext context)` — unchanged,
every early return intact — and give the class a new `build`:

```dart
@override
Widget build(BuildContext context) {
  return Stack(children: [
    _body(context),
    if (_settingsOpen)
      Positioned(top: 0, right: 0, bottom: 0, width: 480, child: /* the panel */),
  ]);
}
```

The work stays on screen behind it. 480 is the owner's number.

**2 · `SettingsScreen` becomes a panel.** It is a `Scaffold` today
(`settings.dart:44`), 723 lines wide in its assumptions. It must read at 480 and
keep its own scroll; it must not keep a full-screen header with a back arrow,
because there is nothing to go back to any more — the thing behind it never left.

**3 · One control, and the same press closes it.** `_TopBar`
(`workspace.dart:292`) takes `onHome · onPage · onVault · onLockVault`; it takes
`onSettings` the same way, and the control sits beside `VAULT` and `✨AI` at the
bar's right end. The home screen's existing button keeps working and becomes a
toggle too.

**4 · Reachable from every screen that has a bar**, which is the whole point.
Not from the vault screen, where the only act is opening the vault.

## Guards, and they must bite

Written before the fix and watched to fail, as 052's was:

1. A screen test that **opens settings with a document on the bench** and finds
   the document still rendered behind it. Against today's code the document is
   gone, which is the finding.
2. A screen test that **presses the control twice** and finds the panel closed.
3. The 17-pixel overflow at 900 px is an old debt on this build; at 480 the panel
   leaves 420 px for the work at that width. **Measure the narrow case** rather
   than assume it: one test at 900 px with the panel open, and no overflow.

## What this must not do

* **No new settings content.** The bank and the sessions are steps 3 and 4 and
  have their own papers. This task moves a room; it does not furnish it.
* **No change to what settings already hold or write.** `ZCFG` is a closed list
  (`config.rs:14`) and nothing here touches it.

## Why this is not cosmetic

The owner's sentence that reorders everything: *«مع الجلسات لا نحتاج أن نبدأ
العمل بوثيقة — نفتح جلسة ونعمل»*. A session becomes the root, and a session is
reached from this panel. **A panel that cannot open over work is a session that
cannot be opened while working** — so this task is the floor the next two stand
on, and its only job is to stop a door from swallowing the room.
