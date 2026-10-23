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
session's own encrypted file and your settings. There is no account and no
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
  BUILD-INFO.txt   which commit this was built from, and its hashes
  third-party/     everything else in here, and the licence it travels under

The interface is English and German; every sentence it shows is gathered in one
list, and the Swedish file carries the English words until somebody translates
them.
The detection packs are German, English and Swedish.

Faruk AB — Aktiebolag (AB), Sweden. Org.nr 559473-3494.
zprivacy@mono-peak.com
