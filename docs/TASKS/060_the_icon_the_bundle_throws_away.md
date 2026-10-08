# 060 · The icon the bundle throws away

**Found:** 8 Oct 2026, 18:19:35, from the owner's session log — not from the
screen. The first finding of the night, and he did not have to look for it.
**Severity:** cosmetic, and visible in the dock the moment the app opens.
**Mine.** Not built.

---

## What the log said

```
18:19:35  Gtk-WARNING **: Could not load a pixbuf from icon theme.
18:19:35  Gdk-Message : Unable to load  from the cursor theme
```

## The chain, measured end to end

**1 · The bundle ships eight icons and they load.** A probe compiled against
GTK 3.24.41 reads them straight out of the bundle:

```
pixbufs loaded from the bundle    6   (256 128 64 48 32 16)
list on the window after set      6
```

**2 · Then one line throws all six away.**

```
list AFTER gtk_window_set_icon_name()   0
```

`apps/flutter_app/linux/runner/my_application.cc:59` calls

```c
gtk_window_set_icon_name(window, "zprivacy");
```

unconditionally, directly after `gtk_window_set_icon_list`. GTK3 implements
`set_icon_name` by **freeing the icon list** and resolving the name through the
icon theme instead. The comment above that line says the opposite:

> *"Said whether or not a file was found: a desktop file names this, and the
> name costs nothing when the icon is already set."*

**The name does not cost nothing. It costs the icon.**

**3 · And the theme cannot supply a replacement.** On this machine the lookup
appears to succeed and then fails on the file:

```
icon-theme.cache (5 Oct 20:50)  names "zprivacy"           1 occurrence
hicolor/16x16/apps/zprivacy.png                            MISSING
hicolor/32x32 · 64x64 · 128x128 · 256x256                  MISSING
```

A stale cache from an earlier install still claims the icon exists, so
`gtk_icon_theme_has_icon` answers **true** and `lookup_icon` returns a path to a
file that is gone — which is the warning, exactly.

**4 · So the window has no icon at all.** Not a wrong icon, not a fallback: the
bundle carries eight and shows none.

## Why this is not a quirk of this machine

The stale cache only changes *how* it fails. On any machine that unpacks the
tarball without installing a `.desktop` package — **every machine that downloads
us** — there is no `zprivacy` in the icon theme, `set_icon_name` discards the
list all the same, and the lookup fails with nothing behind it. The owner's
laptop is the lucky case: it at least tells us.

## Do

One line, and the order of two statements:

1. Call `gtk_window_set_icon_name` **only when no pixbuf was found** — a
   fallback, not a postscript. The `.desktop` association it was added for is
   worth keeping, but not at the price of the icon.
2. Keep the comment honest: say that the name **replaces** the list in GTK3.
3. Guard, and it must bite: the probe in this paper, as a test — set the list,
   set the name, assert the list is **still six**. Against today's code it must
   fail.

The `Gdk-Message` about the cursor theme is separate and untouched: it is the
GNOME cursor theme, not ours, and nothing of ours asks for a cursor by name.

## The family

A line written to help, which silently undoes the thing it was helping. The same
shape as 058's unconditional `set_permissions`, as the `rerun-if-changed` that
switched off cargo's default in 052, and as every guard we have caught this week:
**the comment states the belief, and the belief is the defect.**

And the method earned its keep tonight. The owner was exploring, not hunting.
**The screen showed him nothing; the log showed me this in the first thirty
seconds** — which is why `run.sh` exists and why a recording alone would not have
been enough.
