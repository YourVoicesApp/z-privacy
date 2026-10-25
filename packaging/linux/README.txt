Z Privacy V1 — Linux x86_64
===========================

Protect what you send to AI. Restore it on your device.

To run it:

    ./zprivacy

Nothing to install. This archive carries the Flutter runtime and the Z Privacy
core with it. It needs a Linux x86_64 desktop with GTK3, which every current
Ubuntu, Debian and Fedora desktop already has.

Your originals stay on this device unless you explicitly export restored text.
Your names live in one encrypted vault file, written under
~/.local/share/zprivacy and nowhere else; beside it Z Privacy writes each
session's own encrypted file and your settings. Beside those, Z Privacy writes
only what you ask for by name: a protected copy, and - since 24 October 2026 -
the restored document as an ordinary PDF where you choose it, which holds your
values in the clear and claims no protection. There is no account and no
Z Privacy server for your documents.

Z Privacy minimizes the sensitive content you send. It does not make you
anonymous to the AI provider.


In your application menu (optional)
-----------------------------------

    ./install-shortcut.sh

That writes exactly two things, both inside your own home: a launcher at
~/.local/share/applications/zprivacy.desktop and the icons under
~/.local/share/icons/hicolor/. It asks for no password and touches nothing
outside your home. To take it back:

    ./install-shortcut.sh --remove


To uninstall
------------

Delete two folders and nothing is left:

    this folder                  — the program
    ~/.local/share/zprivacy      — your vault and settings

If you ran install-shortcut.sh, ./install-shortcut.sh --remove takes the
launcher and the icons back as well.

  LICENSE          Apache License 2.0, the whole text
  NOTICE           who made this, and the one condition the licence carries:
                   if you ship something built on this code, say so there
  BUILD-INFO.txt   which commit this was built from, and its hashes
  third-party/     everything else in here, and the licence it travels under

The interface is English, German, Swedish and Arabic; every sentence it shows
is gathered in one list. The Swedish words were written on 2026-10-23 and the
Arabic words on 2026-10-25, and neither has been read by a native speaker yet.
Arabic is read right to left: choosing it mirrors every screen, and a document
keeps its own direction whatever the interface is doing.
The detection packs are German, English, Swedish and Arabic.

Faruk AB — Aktiebolag (AB), Sweden. Org.nr 559473-3494.
zprivacy@mono-peak.com
