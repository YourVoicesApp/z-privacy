# 061 · A library that cannot be built before it is needed

**Found:** 8 Oct 2026, the owner's first pass, in his own words:

> «لم أجد القوائم في الجهاز لأنني لم أعلم أين موضع الخزنة أو أي تطبيق نحن
> نستخدم… اتفقنا أننا نستطيع القوائم من التطبيق / لم أجد الطريقة.»

Two findings, one family. **Measured in the code, not inferred from the
screen.** Not built.

---

## 1 · The only door to a list stands behind a document

There is exactly one, verified by searching every Dart file for a second:

```
_import()            widgets/name_review.dart:282
«Import a list»      widgets/name_review.dart:350     ← the only label
```

Nothing in settings, nothing on the home screen, nothing in the first run. The
only other list act in the whole UI is `setListEnabled` — turning one on or off —
and it lives in the same panel.

The route to that panel:

```
a document open  →  ActsBar  →  «Names»  →  «Import a list»
```

And `ActsBar` is inside the branch that needs a bench. With no document the
workspace renders `_Empty('Nothing is open.')` — `workspace.dart:1230` — and the
button does not exist.

**So a list requires a document.** It also requires an unlocked vault; the label
says so itself:

```dart
label: _vaultOpen ? 'Import a list' : 'Import a list · $_needs',
```

## 2 · And the door announces that it is empty

The «Names» button carries its own hint, `widgets/acts.dart:103`:

> *"Z knows every name this document uses"*

shown exactly when `openCandidates.isEmpty`, and the badge disappears rather than
reading zero. So at the moment a person wants to go in and **add** names, the
button tells them there is nothing in there for them.

## 3 · Why this is heavier than a layout defect

Z's stated job is discovery plus **the user's own libraries**, each session
cheaper than the last. The library is the asset — the thing that makes the second
document cost less than the first.

This design makes the asset **impossible to prepare in advance**. It can only be
built from inside a panel belonging to a document already on the bench. A
first-time user — the stranger at tomorrow's meeting — has no document, so has no
«Names» button, so has no library, so pays full price on the one document they
came to try.

**The owner was right that the feature exists. It exists and cannot be reached,
and a feature that cannot be reached is not a feature.**

## 4 · The app never says where anything is kept

His first sentence was that he did not know where the vault was. That is not his
gap; it is ours. `defaultDataDir()` is fetched at `screens/shell.dart:158` and
used to set the directory — and **never shown to anyone**. A search across every
Dart file for the path, the file name, or the call in a label returns nothing.

A privacy product whose user cannot find their own vault has failed a promise it
never thought to make. The person who most needs to know where the sealed file
lives is the person who chose this product for the sealing.

## Do

Decisions for the owner, not for my hand:

1. **A door to the library that does not need a document.** The library belongs
   to the vault, not to a document, so it belongs where the vault is — not inside
   a panel about one file's findings.
2. **The «Names» hint must not say "nothing here" when the door is behind it.**
   Either the hint names what can be done, or the import moves out.
3. **Say where the vault is**, in one line, somewhere a person can find twice.
   The path is already in hand; nothing needs computing.
4. Guard, and it must bite: a screen test that reaches «Import a list» **with no
   document open**. Against today's code it cannot, which is the finding.

## The family

Same shape as 060, two hours earlier: a thing that is present and inert.
`060` ships eight icons and shows none; `061` ships a library and hides its door.
And the method held — **the screen told him nothing was wrong, because nothing
was wrong on the screen. What was wrong was what the screen never offered.**
That is a defect no guard of ours can catch, and the only instrument for it is a
person meeting the product for the first time, once.
