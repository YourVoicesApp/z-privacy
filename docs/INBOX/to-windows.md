# To the Windows machine — what to run, and what to paste back

This file is for the session sitting at the Windows machine. Nothing in it is
decided here: each item is a command and the thing it is meant to answer, and
the answer goes back in `docs/INBOX/to-linux.md` with the commit it was
measured at.

---

## 098 · where does the vault live, for each of the two installs?

**The question.** `z_core/src/data_dir.rs` answers `%LOCALAPPDATA%\ZPrivacy`.
A **packaged** application (the MSIX) has its `%LOCALAPPDATA%` redirected into
the package's own data folder, so the same code may land in two different
places depending on which way Z Privacy was installed — and two installs on
one machine would then hold **two vaults**, with the person seeing only the one
they are in. The workflow's own comment named this as expected rather than
guessed; this is the measurement that replaces the guess.

**Run it twice: once after installing `zprivacy-v1-windows-x86_64-setup.exe`,
and once after installing the `.msix`.** Start the application first (it
creates the folder on its first run), then, in PowerShell:

```powershell
# 1 · the folder the application itself reports, which is the one it writes in
#     (printed in Settings since 098; if that line is not in the build you are
#     testing, read it from the window's own report instead)
#
# 2 · the two candidate paths, so that the answer is a listing and not a belief
dir "$env:LOCALAPPDATA\ZPrivacy"
dir "$env:LOCALAPPDATA\Packages" -Filter "*ZPrivacy*" -Directory |
  ForEach-Object { dir (Join-Path $_.FullName "LocalCache\Local\ZPrivacy") }
```

**Paste back:** the folder the application reported, and which of the two
listings held `vault.zv` — for **each** of the two installs. That is all; the
sentence in the Windows README and any migration are written from it, not
before it.

---

## 098 · does the installed application start on a machine with no Visual C++ runtime?

**The question.** The owner met a clean machine on 20 October where
`VCRUNTIME140.dll` was missing. Since 098 the three libraries travel beside
`zprivacy.exe` (app-local), so the loader should find them with nothing
installed system-wide.

```powershell
# beside the installed executable — the three must be there
dir "$env:LOCALAPPDATA\Programs\Z Privacy" -Filter "*140*.dll"
```

**Paste back:** the three file names with their versions, and whether the
application drew its first screen without any dialogue about a missing DLL.
