Z Privacy for Windows
=====================

One folder, one executable. Unzip it where you like and run zprivacy.exe from
there — or use the installer, which puts the same files in your own user
folder and makes the shortcuts.

What is in here
---------------

  zprivacy.exe            the application
  z_bridge.dll            its core, where every protection is decided
  flutter_windows.dll     the interface toolkit
  vcruntime140.dll        \
  vcruntime140_1.dll       >  Microsoft's C++ runtime — see below
  msvcp140.dll            /
  data/                   fonts, icons and the application's own assets
  LICENSE                 Z Privacy's licence
  third-party/            everything in here that we did not write, with the
                          licence it travels under
  BUILD-INFO.txt          which commit this was built from, and the two
                          hashes that are the product

Nothing is installed system-wide
--------------------------------

The three Microsoft runtime libraries above travel **with the application** and
are loaded from this folder. A Windows machine does not always have that
runtime — on a clean installation the application would otherwise stop with
Windows' own dialogue about a missing DLL before drawing anything — and the
other way of fixing that, running Microsoft's redistributable installer, would
install it for the whole machine and ask for an administrator. Z Privacy asks
for neither: the installer writes into your own user folder, and these files
sit beside the program. Microsoft's redistribution terms and the versions are
in third-party/msvc-runtime-NOTICE.txt.

Where your work is kept
-----------------------

Z Privacy keeps one encrypted vault file and one small settings file, and
writes nothing else. **The Settings room prints the exact folder they are in**
— read it there, because it differs between the two ways of installing: a
package installed from the `.msix` keeps its files inside the package's own
data folder rather than beside this one, so an installer build and a package
build **do not share a vault**. If you have used both, the one you are looking
at is the one Settings names.

Your passphrase is not stored anywhere, in any of those folders. If you lose
it, the vault cannot be opened — by you or by us.
